# Copyright (C) 2015 PHYTEC Messtechnik GmbH,
# Author: Stefan Christ <s.christ@phytec.de>
# Released under the MIT license (see COPYING.MIT for the terms)

# Usage example:
#   $ clinfo 0:0 -a
#    Platform #0
#      Name:                                  Vivante OpenCL Platform
#      Vendor:                                Vivante Corporation
#      Version:                               OpenCL 1.1
#      Profile:                               EMBEDDED_PROFILE
#      Extensions:                            cl_khr_icd
#
#      Device #0
#        Name:                                Vivante OpenCL Device
#        Type:                                GPU
#        Vendor:                              Vivante Corporation
#        Vendor ID:                           5654870
#        Profile:                             EMBEDDED_PROFILE

DESCRIPTION = "OpenCL Info Utility"
HOMEPAGE = "https://github.com/simleb/clinfo"
SECTION = "extras"
DEPENDS = "gpu-viv-bin-mx6q"

LICENSE = "GPLv3+"
LIC_FILES_CHKSUM = "file://License.txt;md5=9eef91148a9b14ec7f9df333daebc746"

S = "${WORKDIR}/git"
PATCHTOOL = "git"

SRC_URI = " \
    git://github.com/simleb/clinfo.git \
    file://0001-Makefile-fix-some-build-issues.patch \
"
SRCREV = "3abd53d107ce8817e7e042ed275d52f1436cac84"

PV = "0.1+git${SRCPV}"
PR = "r0"

CFLAGS += "-Wall -std=c99"

# The gpu-viv-bin-mx6q library libOpenCL.so needs dlopen, dlclose, dlsym.
# So add "-ldl" to variable LIBS from Makefile.
LIBS_mx6 = "-lOpenCL -lm -ldl"

LDFLAGS_mx6 += "-Wl,--no-as-needed"

do_compile () {
    oe_runmake LIBS="${LIBS}"
}

do_install() {
    oe_runmake install prefix="${D}"
}

RDEPENDS_${PN} +=  "libopencl-mx6"

COMPATIBLE_MACHINE = "mx6"
