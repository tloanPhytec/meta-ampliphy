PARTUP_PACKAGE_SUFFIX ?= ".partup"
PARTUP_PACKAGE_FILES ??= ""

PARTUP_LAYOUT_CONFIG ??= "${IMAGE_LINK_NAME}.yaml"
PARTUP_SEARCH_PATH ?= "${THISDIR}:${@':'.join('%s/partup' % p for p in '${BBPATH}'.split(':'))}"
PARTUP_LAYOUT_CONFIG_FULL_PATH = "${@bb.utils.which(d.getVar('PARTUP_SEARCH_PATH'), d.getVar('PARTUP_LAYOUT_CONFIG'))}"

USING_PARTUP = "${@bb.utils.contains('IMAGE_FSTYPES', 'partup', True, False, d)}"
USING_PARTUP[type] = "boolean"

PARTUP_BUILD_DIR = "${WORKDIR}/build-partup"
PSEUDO_IGNORE_PATHS .= ",${WORKDIR}/build-partup"

PARTUP_SECTIONS ??= ""
PARTUP_ARRAYS ??= ""

python do_copy_source_files() {
    import shutil

    deploy_dir_image = d.getVar('DEPLOY_DIR_IMAGE')
    imgdeploydir = d.getVar('IMGDEPLOYDIR')
    build_dir = d.getVar('PARTUP_BUILD_DIR')

    # We always regenerate files in the build directory, so remove previous ones
    if os.path.exists(build_dir):
        shutil.rmtree(build_dir)

    os.mkdir(build_dir)

    # Copy source files from deploy directory to build directory
    for f in d.getVar('PARTUP_PACKAGE_FILES').split():
        deploy_dir_image_f = os.path.join(deploy_dir_image, f)
        imgdeploydir_f = os.path.join(imgdeploydir, f)
        build_dir_f = os.path.join(build_dir, f)
        if os.path.exists(deploy_dir_image_f):
            shutil.copy(deploy_dir_image_f, build_dir_f)
        elif os.path.exists(imgdeploydir_f):
            shutil.copy(imgdeploydir_f, build_dir_f)
        else:
            bb.fatal('File \'{}\' neither found in DEPLOY_DIR_IMAGE nor IMGDEPLOYDIR'.format(f))
}
do_copy_source_files[vardeps] += "PARTUP_PACKAGE_FILES"

python do_layout_config() {
    import re

    config_in = d.getVar('PARTUP_LAYOUT_CONFIG_FULL_PATH')
    config_out = os.path.join(d.getVar('PARTUP_BUILD_DIR'), 'layout.yaml')

    sections = d.getVar('PARTUP_SECTIONS').split()
    arrays = d.getVar('PARTUP_ARRAYS').split()
    reflags = re.DOTALL | re.MULTILINE

    with open(config_in, 'r') as f:
        content = d.expand(f.read())
        for s in sections:
            d.setVarFlag('PARTUP_SECTION_' + s, 'type', 'boolean')
            if oe.data.typed_value('PARTUP_SECTION_' + s, d):
                exp = r'#\s?(BEGIN|END)_{0}(\n|$)'.format(s.upper())
                content = re.sub(exp, r'', content, flags=reflags)
            else:
                exp = r'#\s?BEGIN_{0}(.*?)(?:#\s?END_{0}(\n|$))'.format(s.upper())
                content = re.sub(exp, r'', content, flags=reflags)
        for a in arrays:
            exp = r'#\s?ARRAY_{0}(.*?)(?:#\s?ARRAY_{0})'.format(a.upper())
            inst = re.findall(exp, content, flags=reflags)
            for i in inst:
                repl = ''
                for e in d.getVar('PARTUP_ARRAY_' + a).split():
                    repl += i.replace(r'@KEY@', e)
                content = re.sub(exp, repl, content, flags=reflags)

    with open(config_out, 'w') as f:
        f.write(re.sub(r'[\t ]+\n', r'\n', content, flags=reflags))
}
do_layout_config[vardeps] += " \
    PARTUP_LAYOUT_CONFIG \
    PARTUP_SECTIONS \
    PARTUP_ARRAYS \
"

DEPENDS += "partup-native"

IMAGE_CMD:partup() {
    partup \
        package \
        ${IMGDEPLOYDIR}/${IMAGE_NAME}${IMAGE_NAME_SUFFIX}${PARTUP_PACKAGE_SUFFIX} \
        -C ${PARTUP_BUILD_DIR} \
        ${PARTUP_PACKAGE_FILES} layout.yaml
}
do_image_partup[depends] += "partup-native:do_populate_sysroot"
# Make sure build artifacts are deployed
do_image_partup[recrdeptask] += "do_deploy"
do_image_partup[deptask] += "do_image_complete"

python() {
    if oe.data.typed_value('USING_PARTUP', d):
        image_fstypes = d.getVar('IMAGE_FSTYPES')
        package_files = d.getVar('PARTUP_PACKAGE_FILES')
        image_basename = d.getVar('IMAGE_BASENAME')
        fstypes = []

        # Generate dependencies of required IMAGE_FSTYPES based on files in
        # PARTUP_PACKAGE_FILES
        for f in package_files.split():
            if image_basename in f:
                # Files may contain multiple extensions, like .tar.gz, so get
                # both of them
                p, extc = os.path.splitext(f)
                b, ext = os.path.splitext(p)
                if ext:
                    ext += extc
                else:
                    ext = extc

                fstype = ext
                if fstype[0] == '.':
                    fstype = fstype[1:]
                if fstype not in d.getVar('IMAGE_TYPES'):
                    bb.fatal('Invalid image type \'{}\''.format(fstype))
                fstypes.append(fstype)

        d.setVar('IMAGE_TYPEDEP:partup', ' '.join(fstypes))
        task_deps = ['do_image_' + f for f in fstypes]

        bb.build.addtask('do_copy_source_files', 'do_layout_config', ' '.join(task_deps), d)
        bb.build.addtask('do_layout_config', 'do_image_partup', 'do_image', d)
        bb.build.addtask('do_image_partup', 'do_image_complete', None, d)
}
