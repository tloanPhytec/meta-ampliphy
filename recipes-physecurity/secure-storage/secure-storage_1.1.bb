# Copyright (C) 2022 PHYTEC Messtechnik GmbH,
# Author: Maik Otto <m.otto@phytec.de>
# Released under the MIT license (see COPYING.MIT for the terms)

SUMMARY = "securestorage ramdisk required files for file authentication and encryption"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"
SRC_URI = " \
    file://securestorage-init.sh \
"

S = "${WORKDIR}"

do_install() {
    install -m 0755 securestorage-init.sh ${D}/init
}

# Do not create debug/devel packages
PACKAGES = "${PN}"

FILES:${PN} = "/"
