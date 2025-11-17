#!/usr/bin/env bash
set -euo pipefail

KERNEL_VERSION="${KERNEL_VERSION:-6.17.8}"
PKG_NAME="linux-base"
SCB_NAME="main.scb"

REPO_ROOT="/packages/@linux/kernel"
OUTPUT_DIR="/out"
BUILD_DIR="/build"

mkdir -p "$OUTPUT_DIR" "$BUILD_DIR/staging/kernel" "$BUILD_DIR/pkg"

echo "=== Download Linux kernel $KERNEL_VERSION ==="
cd "$BUILD_DIR"
wget -O linux.tar.xz "https://www.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz"
tar -xf linux.tar.xz
cd "linux-${KERNEL_VERSION}"

echo "=== Building kernel (threads: $(nproc)) ==="
make defconfig
make -j"$(nproc)" bzImage modules
make modules_install INSTALL_MOD_PATH="$BUILD_DIR/staging/kernel"

cp arch/*/boot/bzImage "$BUILD_DIR/staging/kernel/vmlinuz-${KERNEL_VERSION}"
cp System.map "$BUILD_DIR/staging/kernel/System.map-${KERNEL_VERSION}"
cp .config "$BUILD_DIR/staging/kernel/config-${KERNEL_VERSION}"

echo "=== Generating package.scdf ==="
cat > "$BUILD_DIR/pkg/package.scdf" <<EOF
name: ${PKG_NAME}
version: ${KERNEL_VERSION}
type: kernel
dependencies: []
install:
  - cp -a kernel/* /usr/
EOF

echo "=== Creating kernel.tar.xz payload ==="
cd "$BUILD_DIR/staging"
tar -cJf "$BUILD_DIR/pkg/kernel.tar.xz" kernel

echo "=== Creating SCB: ${SCB_NAME} ==="
cd "$BUILD_DIR/pkg"
tar -cJf "$OUTPUT_DIR/${SCB_NAME}" package.scdf kernel.tar.xz

echo "=== Preparing runtime container ==="
RUNTIME_DIR="$BUILD_DIR/runtime"
mkdir -p "$RUNTIME_DIR/packages/@linux/kernel"
cp "$OUTPUT_DIR/${SCB_NAME}" "$RUNTIME_DIR/packages/@linux/kernel/${SCB_NAME}"

cat > "$RUNTIME_DIR/Dockerfile" <<EOF
FROM scratch
ADD packages/@linux/kernel/main.scb /packages/@linux/kernel/main.scb
EOF

echo "=== Building runtime container image ==="
cd "$RUNTIME_DIR"
docker build -t kernel-scb:${KERNEL_VERSION} .

echo "=== Saving image tar ==="
docker save kernel-scb:${KERNEL_VERSION} \
    -o "$OUTPUT_DIR/kernel-scb-${KERNEL_VERSION}.tar"

echo "=== DONE ==="
