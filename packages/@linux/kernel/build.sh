#!/usr/bin/env bash
set -euo pipefail

KERNEL_VERSION="${KERNEL_VERSION:-6.17.8}"
KERNEL_URL="${KERNEL_URL:-}"
OUTPUT_DIR="${OUTPUT_DIR:-/out}"
BUILD_DIR="${BUILD_DIR:-/build}"
SCB_NAME_PREFIX="${SCB_NAME_PREFIX:-linux-base}"
JOBS="${JOBS:-$(nproc)}"

mkdir -p "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}/src"
cd "${BUILD_DIR}"

TARBALL="linux-${KERNEL_VERSION}.tar.xz"
if [ -n "${KERNEL_URL}" ]; then
    echo "Downloading kernel from KERNEL_URL: ${KERNEL_URL}"
    wget -O "${TARBALL}" "${KERNEL_URL}"
else
    echo "Downloading kernel.org tarball for ${KERNEL_VERSION}"
    wget -O "${TARBALL}" "https://www.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/${TARBALL}"
fi

rm -rf src/linux-${KERNEL_VERSION}
tar -xf "${TARBALL}" -C src
cd "src/linux-${KERNEL_VERSION}"

echo "Using defconfig, then build kernel..."
make defconfig

make -j"${JOBS}" bzImage modules
# install modules and headers into staging area
STAGING="${BUILD_DIR}/staging"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"

KIMAGE="$(ls arch/*/boot/bzImage | head -n1 || true)"
if [ -z "${KIMAGE}" ]; then
  # older kernels use arch/x86/boot/bzImage
  KIMAGE="arch/x86/boot/bzImage"
fi

mkdir -p "${STAGING}/boot" "${STAGING}/lib/modules" "${STAGING}/usr/include"
cp -v "${KIMAGE}" "${STAGING}/boot/vmlinuz-${KERNEL_VERSION}" || true
cp -v System.map "${STAGING}/boot/System.map-${KERNEL_VERSION}" || true
cp -v .config "${STAGING}/boot/config-${KERNEL_VERSION}" || true

make modules_install INSTALL_MOD_PATH="${STAGING}" -j"${JOBS}"

make headers_install INSTALL_HDR_PATH="${STAGING}/usr" -j"${JOBS}"

SCDF_FILE="${STAGING}/package.scdf"
cat > "${SCDF_FILE}" <<'EOF'
name: linux-base
version: {KERNEL_VERSION}
arch: x86_64
description: "Linux Kernel"
maintainer: "Klydra <klydra@wheedev.org>"

dependencies: busybox, kmod
files:
  - boot/vmlinuz-{KERNEL_VERSION}
  - boot/System.map-{KERNEL_VERSION}
  - boot/config-{KERNEL_VERSION}
  - lib/modules/

install_steps:
  - "mkdir -p /boot"
  - "cp -a boot/vmlinuz-{KERNEL_VERSION} /boot/vmlinuz-{KERNEL_VERSION}"
  - "cp -a boot/System.map-{KERNEL_VERSION} /boot/System.map-{KERNEL_VERSION}"
  - "cp -a boot/config-{KERNEL_VERSION} /boot/config-{KERNEL_VERSION}"
  - "cp -a lib/modules /lib/"

post_install: "Remember to update your bootloader entries (grub, syslinux, etc)."

EOF

sed -i "s/{KERNEL_VERSION}/${KERNEL_VERSION}/g" "${SCDF_FILE}"
PACKAGE_FILENAME="${SCB_NAME_PREFIX}-${KERNEL_VERSION}.scb"
echo "Packaging into ${PACKAGE_FILENAME} (tar.xz archive but using .scb extension)"

cd "${STAGING}"
mkdir -p package
rsync -a --delete boot package/boot
rsync -a --delete lib package/lib
rsync -a --delete usr package/usr
cp -a package.scdf package/package.scdf

tar -c --numeric-owner --owner=0 --group=0 -I 'xz -9 -T0' -f "${OUTPUT_DIR}/${PACKAGE_FILENAME}" package

ln -sf "${PACKAGE_FILENAME}" "${OUTPUT_DIR}/main.scb"

echo "Artifact(s) in ${OUTPUT_DIR}:"
ls -l "${OUTPUT_DIR}"

echo "Done. main.scb -> ${OUTPUT_DIR}/main.scb"
