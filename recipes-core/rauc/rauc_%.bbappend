FILESEXTRAPATHS:prepend := "${CERT_PATH}/rauc:"
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

DEPENDS += "phytec-dev-ca-native config-partition"
do_fetch[depends] += "phytec-dev-ca-native:do_install"

# set path to the rauc keyring, which is installed in the image
RAUC_KEYRING_FILE ?= "${CERT_PATH}/main-ca/mainca-rsa.crt.pem"

SRC_URI += " \
    file://10-update-usb.rules \
    file://update-usb@.service \
    file://update_usb.sh \
    file://rauc_downgrade_barrier.sh \
    ${@bb.utils.contains('MACHINE_FEATURES', 'emmc', 'file://system_emmc.conf', 'file://system_nand.conf', d)} \
    file://rauc-pre-install.sh \
    file://rauc-handle-secrets.sh \
    file://rauc-post-install.sh \
"

PACKAGE_ARCH = "${MACHINE_ARCH}"

PACKAGES =+ "rauc-update-usb"

SYSTEMD_PACKAGES += "rauc-update-usb"
SYSTEMD_SERVICE:rauc-update-usb = "update-usb@.service"
SYSTEMD_AUTO_ENABLE:rauc-update-usb = "enable"

# configure the downgrade barrier, here you could move back from a
# production system to a development mode by setting r0
DOWNGRADE_BARRIER_VERSION ?= "${RAUC_BUNDLE_VERSION}"

# Default eMMC and raw NAND device used in the system.conf. These variables must
# be set in the machine configuration.
EMMC_DEV ??= "0"
NAND_DEV ??= "0"

ROOTFS_0_DEV ??= "/dev/mmcblk${EMMC_DEV}p5"
ROOTFS_1_DEV ??= "/dev/mmcblk${EMMC_DEV}p6"
ROOTFS_0_DEV:fileauthorenc ?= "/dev/dm-0"
ROOTFS_1_DEV:fileauthorenc ?= "/dev/dm-1"
ROOTFS_0_DEV:fileauthandenc ?= "/dev/dm-1"
ROOTFS_1_DEV:fileauthandenc ?= "/dev/dm-3"

USE_BOOTLOADER_SLOT ?= "${USE_BOOTLOADER_SLOT_WEAK_DEFAULT}"
# we don't use overrides directly to set a default, as this cannot be
# overridden by normal assignment later on
USE_BOOTLOADER_SLOT_WEAK_DEFAULT = "true"
USE_BOOTLOADER_SLOT_WEAK_DEFAULT:ti33x = "false"
USE_BOOTLOADER_SLOT_WEAK_DEFAULT:rk3288 = "false"

# We want system.conf to be fetched before any of the following variables are
# changed. This is needed because ${WORKDIR}/system.conf is overridden by
# system_{emmc,nand}.conf and parsed using these variables afterwards. The
# parsing, however, does not do anything unless the template
# system_{emmc,nand}.conf is copied over before it, which only happens if the
# default system.conf exists in WORKDIR.
do_fetch[vardeps] += " \
    PREFERRED_PROVIDER_virtual/bootloader \
    EMMC_DEV \
    NAND_DEV \
    ROOTFS_0_DEV \
    ROOTFS_1_DEV \
    RAUC_KEYRING_FILE \
    USE_BOOTLOADER_SLOT \
"

# Returns the correct string for the key "bootloader" used in RAUC's system.conf
# depending on the currently set bootloader in Yocto. See
# https://rauc.readthedocs.io/en/latest/reference.html#system-section for all
# supported values.
def map_system_conf_bootloader(d):
    bootloader_map = {
        "u-boot": "uboot",
        "u-boot-imx": "uboot",
        "barebox": "barebox",
        "u-boot-ti": "uboot"
    }
    return bootloader_map[d.getVar("PREFERRED_PROVIDER_virtual/bootloader")]

do_patch[postfuncs] += "parse_system_conf"
parse_system_conf() {
	# check for default system.conf from meta-rauc
	shasum=$(sha256sum "${WORKDIR}/system.conf" | cut -d' ' -f1)
	if [ "$shasum" = "ed3e288f19d6ac5c4db2debf35d0e01bcda174e033d1c0219a67d7fe3026c1b1" ]; then
		bbnote "No project specific system.conf has been provided. We use the Phytec RDK specific config files."
		cp ${WORKDIR}/${@bb.utils.contains('MACHINE_FEATURES', 'emmc', 'system_emmc.conf', 'system_nand.conf', d)} ${WORKDIR}/system.conf
		sed -i \
			-e 's/@MACHINE@/${MACHINE}/g' \
			-e 's/@BOOTLOADER@/${@map_system_conf_bootloader(d)}/g' \
			-e 's/@EMMC_DEV@/${EMMC_DEV}/g' \
			-e 's/@NAND_DEV@/${NAND_DEV}/g' \
			-e 's!@ROOTFS_0_DEV@!${ROOTFS_0_DEV}!g' \
			-e 's!@ROOTFS_1_DEV@!${ROOTFS_1_DEV}!g' \
			-e 's/@RAUC_KEYRING_FILE@/${@os.path.basename(d.getVar("RAUC_KEYRING_FILE"))}/g' \
			${@bb.utils.contains("USE_BOOTLOADER_SLOT", "true", "", "-e '/@IF_BOOTLOADER_SLOT@/,/@ENDIF_BOOTLOADER_SLOT@/d'", d)} \
			-e '/@\(IF\|ENDIF\)[A-Z_]\+@/d' \
			${WORKDIR}/system.conf
	fi

	echo "${DOWNGRADE_BARRIER_VERSION}" > ${WORKDIR}/downgrade_barrier_version
}

do_install:append() {
	# check for problematic certificate setups
	shasum=$(sha256sum "${WORKDIR}/${RAUC_KEYRING_FILE}" | cut -d' ' -f1)
	if [ "$shasum" = "91efd86dfbffa360c909b06b54902348075c5ba7902ad1ec30d25527a1f8ca09" ]; then
		bbwarn "You're including Phytec's Development Keyring in the rauc bundle. Please create your own!"
	fi

	install -d ${D}${bindir}
	install -d ${D}${libdir}
	install -d ${D}${libdir}/rauc

	install -m 0774 ${WORKDIR}/update_usb.sh ${D}${bindir}
	install -m 0774 ${WORKDIR}/rauc_downgrade_barrier.sh ${D}${bindir}

	install -d ${D}${systemd_unitdir}/system/
	install -m 0644 ${WORKDIR}/update-usb@.service ${D}${systemd_unitdir}/system/

	install -d ${D}${nonarch_base_libdir}/udev/rules.d/
	install -m 0644 ${WORKDIR}/10-update-usb.rules ${D}${nonarch_base_libdir}/udev/rules.d/

	install -d ${D}${sysconfdir}/rauc
	install -m 0644 ${WORKDIR}/downgrade_barrier_version ${D}${sysconfdir}/rauc/downgrade_barrier_version

	install -m 0774 ${WORKDIR}/rauc-pre-install.sh ${D}${libdir}/rauc
	install -m 0774 ${WORKDIR}/rauc-handle-secrets.sh ${D}${libdir}/rauc
	install -m 0774 ${WORKDIR}/rauc-post-install.sh ${D}${libdir}/rauc
}

FILES:rauc-update-usb += " \
    ${bindir}/update_usb.sh \
    ${systemd_unitdir}/system/update-usb@.service \
    ${nonarch_base_libdir}/udev/rules.d/10-update-usb.rules \
"

RDEPENDS:${PN} += " \
    ${@bb.utils.contains_any('PREFERRED_PROVIDER_virtual/bootloader', 'u-boot u-boot-imx', 'libubootenv-bin', '', d)} \
    ${@bb.utils.contains('MACHINE_FEATURES', 'emmc', 'dosfstools e2fsprogs', '', d)} \
"
