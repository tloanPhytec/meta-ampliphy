SUMMARY = "Low Level Skeleton Library for Communication on Intel platforms"
SECTION = "libs"
AUTHOR = "Brendan Le Foll, Tom Ingleby"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://COPYING;md5=66493d54e65bfc12c7983ff2e884f37f"

inherit setuptools3-base pkgconfig python3-dir cmake

EXTRA_OECMAKE:append = " -DINSTALLTOOLS:BOOL=ON -DFIRMATA=ON -DPYTHON2_PACKAGES_PATH:FILEPATH=../${PYTHON_SITEPACKAGES_DIR} -DBASE_LIB_INSTALL_DIR=${base_libdir} -DCMAKE_SKIP_RPATH=ON"

FILES:${PN}-doc += "${datadir}/mraa/examples/"

# Prepend mraa-utils to make sure bindir ends up in there
PACKAGES =+ "${PN}-utils "

DEPENDS += " json-c"

FILES:${PN}-utils = "${bindir}/ \
                    "

# override this in local.conf to get a subset of bindings.
# BINDINGS:pn-mraa="python"
# will result in only the python bindings being built/packaged.
BINDINGS ?= "nodejs python"

PACKAGECONFIG ??= "${@bb.utils.contains('PACKAGES', 'node-${PN}', 'nodejs', '', d)} \
 ${@bb.utils.contains('PACKAGES', 'python-${PN}', 'python', '', d)} \
 ${@bb.utils.contains('PACKAGES', '${PN}-java', 'java', '', d)}"

PACKAGECONFIG[python] = "-DBUILDSWIGPYTHON=ON, -DBUILDSWIGPYTHON=OFF, swig-native python,"
PACKAGECONFIG[nodejs] = "-DNODEJS_EXECUTABLE=NONE -DBUILDSWIGNODE=ON, -DBUILDSWIGNODE=OFF, swig-native nodejs,"
PACKAGECONFIG[java] = "-DBUILDSWIGJAVA=ON, -DBUILDSWIGJAVA=OFF, swig-native openjdk-8-native,"
PACKAGECONFIG[ft4222] = "-DUSBPLAT=ON -DFTDI4222=ON, -DUSBPLAT=OFF -DFTDI4222=OFF,, libft4222"

do_compile:prepend () {
  # when yocto builds in ${D} it does not have access to ../git/.git so git
  # describe --tags fails. In order not to tag our version as dirty we use this
  # trick
  sed -i 's/-dirty//' src/version.c
}

### Python ###

# python-mraa package containing Python bindings
FILES:python-${PN} = "${PYTHON_SITEPACKAGES_DIR}/ \
                      ${datadir}/mraa/examples/python/ \
                      ${prefix}/src/debug/${BPN}/${PV}-${PR}/build/src/python/ \
                     "
RDEPENDS:python-${PN} += "python"
INSANE_SKIP:python-${PN} = "debug-files"


### Node ###

# node-mraa package containing Nodejs bindings
FILES:node-${PN} = "${prefix}/lib/node_modules/ \
                    ${datadir}/mraa/examples/javascript/ \
                   "
RDEPENDS:node-${PN} += "nodejs"
INSANE_SKIP:node-${PN} = "debug-files"


### Java ###

# mraa-java package containing Java bindings
FILES:${PN}-java = "${libdir}/libmraajava.so \
                    ${libdir}/java/ \
                    ${datadir}/mraa/examples/java/ \
                    ${libdir}/pkgconfig/mraajava.pc \
                    ${prefix}/src/debug/${BPN}/${PV}-${PR}/build/src/java/ \
                    ${libdir}/.debug/libmraajava.so \
                   "

RDEPENDS:${PN}-java += "${@bb.utils.contains('PACKAGES', '${PN}-java', 'java2-runtime', '', d)}"
INSANE_SKIP:${PN}-java = "debug-files"

export JAVA_HOME="${STAGING_DIR}/${BUILD_SYS}/usr/lib/jvm/openjdk-8-native"

cmake_do_generate_toolchain_file:append() {
  echo "
set (JAVA_AWT_INCLUDE_PATH ${JAVA_HOME}/include CACHE PATH \"AWT include path\" FORCE)
set (JAVA_AWT_LIBRARY ${JAVA_HOME}/jre/lib/amd64/libjawt.so CACHE FILEPATH \"AWT Library\" FORCE)
set (JAVA_INCLUDE_PATH ${JAVA_HOME}/include CACHE PATH \"java include path\" FORCE)
set (JAVA_INCLUDE_PATH2 ${JAVA_HOME}/include/linux CACHE PATH \"java include path\" FORCE)
set (JAVA_JVM_LIBRARY ${JAVA_HOME}/jre/lib/amd64/libjvm.so CACHE FILEPATH \"path to JVM\" FORCE)
" >> ${WORKDIR}/toolchain.cmake
}

### Include desired language bindings ###
PACKAGES =+ "${@bb.utils.contains('BINDINGS', 'java', '${PN}-java', '', d)}"
PACKAGES =+ "${@bb.utils.contains('BINDINGS', 'nodejs', 'node-${PN}', '', d)}"
PACKAGES =+ "${@bb.utils.contains('BINDINGS', 'python', 'python-${PN}', '', d)}"
