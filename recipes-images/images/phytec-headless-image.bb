SUMMARY = "Phytec's headless image"
DESCRIPTION = "no graphics support in this image"
LICENSE = "MIT"
inherit core-image

IMAGE_ROOTFS_SIZE ?= "8192"

IMAGE_INSTALL = " \
    packagegroup-machine-base \
    packagegroup-core-boot \
    packagegroup-hwtools \
    packagegroup-benchmark \
    packagegroup-userland \
    ${@bb.utils.contains("MACHINE_FEATURES", "alsa", "packagegroup-audio", "", d)} \
    ${@bb.utils.contains("MACHINE_FEATURES", "wlan", "packagegroup-wifi", "", d)} \
"
