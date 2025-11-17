#!/usr/bin/env bash
set -e

ROOT=$(pwd)
OUTPUT="$ROOT/output"
SRC="$ROOT/src"
SCDF="$ROOT/package.scdf"

mkdir -p "$OUTPUT"
mkdir -p "$SRC"

apt-get install -y git
# Install missing tools if running inside Docker
if ! command -v depmod >/dev/null 2>&1; then
    echo "Installing kmod (for depmod)..."
    apt-get update
    apt-get install -y kmod
fi

# Clone or update Linux source
if [ ! -d "$SRC/linux" ]; then
    git clone --depth=1 https://github.com/torvalds/linux.git "$SRC/linux"
else
    git -C "$SRC/linux" pull
fi

cd "$SRC/linux"

# Kernel config
make defconfig

# Build kernel
make -j"$(nproc)"

# Extract kernel version
VERSION=$(make kernelrelease)

echo "Kernel version: $VERSION"

# Install modules into staging dir
STAGING="$ROOT/pkgroot"
mkdir -p "$STAGING"

make INSTALL_MOD_PATH="$STAGING/kernel" modules_install

# Copy bzImage
mkdir -p "$STAGING/kernel/boot"
cp "arch/x86/boot/bzImage" "$STAGING/kernel/boot/vmlinuz-$VERSION"

# Add package metadata
cp "$SCDF" "$STAGING/package.scdf"

# Create SCB tarball
mkdir -p "$OUTPUT"
tar -cJf "$OUTPUT/main.scb" -C "$STAGING" .

# Clean
rm -rf "$STAGING"

echo "main.scb built successfully"
