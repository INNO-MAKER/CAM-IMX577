#!/bin/bash
# Install modified IMX477 driver with IMX577 support (pre-compiled)
# This driver handles BOTH IMX477 and IMX577 sensors

set -e

echo "========================================="
echo "IMX477/IMX577 Driver Installation (Pre-compiled)"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METHOD_DIR="$(dirname "$SCRIPT_DIR")"
KERNEL_VERSION=$(uname -r)

echo "Configuration:"
echo "  Kernel version: $KERNEL_VERSION"
echo "  Method directory: $METHOD_DIR"
echo ""

# Step 1: Install modified IMX477 driver
echo "Step 1: Installing modified IMX477 driver (with IMX577 support)..."
DRIVER_SRC="${METHOD_DIR}/driver/imx477.ko"
DRIVER_DEST="/lib/modules/${KERNEL_VERSION}/kernel/drivers/media/i2c/"

if [ ! -f "$DRIVER_SRC" ]; then
    echo "  ERROR: Driver not found at $DRIVER_SRC"
    exit 1
fi

# Remove compressed stock driver if it exists (prevents loading wrong driver)
if [ -f "${DRIVER_DEST}/imx477.ko.xz" ]; then
    mv "${DRIVER_DEST}/imx477.ko.xz" "${DRIVER_DEST}/imx477.ko.xz.backup.$(date +%Y%m%d-%H%M%S)"
    echo "  Compressed stock driver backed up (prevents conflict)"
fi

# Backup original uncompressed driver if it exists
if [ -f "${DRIVER_DEST}/imx477.ko" ]; then
    cp "${DRIVER_DEST}/imx477.ko" "${DRIVER_DEST}/imx477.ko.backup.$(date +%Y%m%d-%H%M%S)"
    echo "  Original imx477.ko backed up"
fi

cp "$DRIVER_SRC" "$DRIVER_DEST/"
depmod -a
echo "  Modified driver installed to $DRIVER_DEST"
echo ""

# Step 2: Install device tree overlay
echo "Step 2: Installing IMX577 device tree overlay..."
DTS_SRC="${METHOD_DIR}/dts/imx577-overlay.dtbo"
DTS_DEST="/boot/firmware/overlays/"

if [ ! -f "$DTS_SRC" ]; then
    echo "  ERROR: Overlay not found at $DTS_SRC"
    exit 1
fi

cp "$DTS_SRC" "$DTS_DEST/"
echo "  Overlay installed to $DTS_DEST"
echo ""

# Step 3: Install IPA library with IMX577 camera helper
echo "Step 3: Installing IPA library with IMX577 camera helper..."
IPA_SRC="${METHOD_DIR}/ipa_rpi_pisp.so"
IPA_DEST="/usr/lib/aarch64-linux-gnu/libcamera/ipa/"

if [ ! -f "$IPA_SRC" ]; then
    echo "  WARNING: IPA library not found at $IPA_SRC"
    echo "  IMX577 camera helper may not be available"
else
    # Backup original
    if [ -f "${IPA_DEST}/ipa_rpi_pisp.so" ]; then
        cp "${IPA_DEST}/ipa_rpi_pisp.so" "${IPA_DEST}/ipa_rpi_pisp.so.backup.$(date +%Y%m%d-%H%M%S)"
        echo "  Original IPA library backed up"
    fi

    cp "$IPA_SRC" "$IPA_DEST/"
    echo "  IPA library installed to $IPA_DEST"
fi
echo ""

# Step 4: Setup tuning file
echo "Step 4: Setting up IMX577 tuning file..."
TUNING_DIR="/usr/share/libcamera/ipa/rpi/pisp"
IMX477_JSON="${TUNING_DIR}/imx477.json"
IMX577_JSON="${TUNING_DIR}/imx577.json"

if [ -f "$IMX477_JSON" ]; then
    # Remove old symlink if exists
    if [ -L "$IMX577_JSON" ]; then
        rm "$IMX577_JSON"
    fi

    # Create symlink
    ln -sf imx477.json "$IMX577_JSON"
    echo "  Created symlink: imx577.json -> imx477.json"
else
    echo "  WARNING: IMX477 tuning file not found"
fi
echo ""

# Step 5: Configure config.txt
echo "Step 5: Configuring /boot/firmware/config.txt..."
CONFIG_FILE="/boot/firmware/config.txt"

# Backup config.txt
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
echo "  Backup created"

# Remove old camera configurations
sed -i '/^dtoverlay=imx577/d' "$CONFIG_FILE"
sed -i '/^dtoverlay=imx477/d' "$CONFIG_FILE"
sed -i '/^camera_auto_detect/d' "$CONFIG_FILE"

# Add new configuration
echo "" >> "$CONFIG_FILE"
echo "# IMX577 and IMX477 camera configuration" >> "$CONFIG_FILE"
echo "camera_auto_detect=0" >> "$CONFIG_FILE"
echo "dtoverlay=imx577-overlay,cam0" >> "$CONFIG_FILE"
echo "dtoverlay=imx477,cam1" >> "$CONFIG_FILE"

echo "  Camera configuration added"
echo ""

# Summary
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "Installed components:"
echo "  ✓ Modified IMX477 driver (supports IMX477 and IMX577)"
echo "  ✓ IMX577 device tree overlay"
echo "  ✓ IPA library with IMX577 camera helper"
echo "  ✓ IMX577 tuning file (symlink)"
echo "  ✓ Camera configuration in config.txt"
echo ""
echo "How it works:"
echo "  - Modified imx477.ko driver handles BOTH sensors"
echo "  - IMX577 sensor detected via chip ID 0x0577"
echo "  - IMX477 sensor detected via chip ID 0x0477"
echo ""
echo "Configuration:"
echo "  CAM0: IMX577 (dtoverlay=imx577-overlay,cam0)"
echo "  CAM1: IMX477 (dtoverlay=imx477,cam1)"
echo ""
echo "IMPORTANT: Reboot required for changes to take effect"
echo ""
echo "After reboot, test with:"
echo "  rpicam-hello --list-cameras"
echo "  rpicam-hello -t 5000"
echo ""
