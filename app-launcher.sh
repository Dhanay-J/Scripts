#!/usr/bin/env bash

###############################################################################
# App Launcher for Bliss OS VMs
# 
# Description:
#   This script automates the process of launching Android apps on Bliss OS
#   running inside a KVM virtual machine on Ubuntu. It handles VM startup,
#   ADB connection, app launching, and GUI attachment.
#
# Author: Dhanay-J
# GitHub: https://github.com/Dhanay-J/scripts
#
# Requirements:
#   - virt-manager / libvirt
#   - virt-viewer
#   - adb (Android Debug Bridge)
#   - zenity (for GUI error dialogs)
#   - notify-send (for desktop notifications)
#
# Installation:
#   sudo apt install virt-manager virt-viewer adb zenity libnotify-bin
#
# Usage:
#   ./app-launcher.sh
#
# Configuration:
#   Edit the configuration section below to match your setup.
###############################################################################

set -euo pipefail  # Strict mode: exit on error, undefined vars, pipe failures

###############################################################################
# CONFIGURATION SECTION
# Modify these variables to match your environment
###############################################################################

# Name of your VM as shown in virt-manager
VM_NAME="Bliss"

# IP Address of Bliss OS VM
# Use 'export EDITOR=nano && virsh net-edit default' to set static IP
VM_IP="192.168.122.100"

# Standard ADB port (default is 5555)
ADB_PORT="5555"

# Android package name of the app to launch
# Find package names with: adb shell pm list packages
PACKAGE_NAME="com.whatsapp"

# Optional: Specific activity to launch
# Example: "com.whatsapp/.MainActivity"
# Leave empty to use monkey launcher
ACTIVITY_NAME=""

# ADB connection timeout in seconds
ADB_TIMEOUT=45

###############################################################################
# FUNCTIONS
###############################################################################

# Display error dialog using zenity
# Arguments:
#   $1 - Error message to display
show_error() {
    zenity --error \
        --text="$1" \
        --title="Bliss OS Launcher Error" \
        --width=400
}

# Check if required commands exist
# Returns: 0 if all dependencies are met, 1 otherwise
check_dependencies() {
    local missing_deps=()
    local deps=("virsh" "adb" "zenity" "notify-send" "virt-viewer")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        show_error "Missing dependencies: ${missing_deps[*]}\n\nInstall with:\nsudo apt install ${missing_deps[*]}"
        return 1
    fi
    return 0
}

# Check if the VM exists
# Returns: 0 if VM exists, 1 otherwise
check_vm_exists() {
    if ! virsh -c qemu:///system dominfo "$VM_NAME" &> /dev/null; then
        show_error "Virtual Machine '$VM_NAME' does not exist.\nCheck VM_NAME in script configuration."
        return 1
    fi
    return 0
}

###############################################################################
# MAIN SCRIPT
###############################################################################

# Validate dependencies and VM
check_dependencies || exit 1
check_vm_exists || exit 1

# Step 1: Check and start VM if needed
VM_STATUS=$(virsh -c qemu:///system list --name | grep "^${VM_NAME}$" || true)

if [ -z "$VM_STATUS" ]; then
    # VM is not running - start it
    notify-send "Bliss OS" "Starting Virtual Machine..." -i system-run
    
    if ! virsh -c qemu:///system start "$VM_NAME"; then
        show_error "Failed to start Virtual Machine '$VM_NAME'.\nCheck virt-manager permissions and VM configuration."
        exit 1
    fi
    
    # Notify user of boot process
    notify-send "Bliss OS" "Waiting for Android system to boot..." -i network-idle
else
    # VM is already running - minimal notification
    notify-send "Bliss OS" "Connecting to running VM..." -i network-idle
fi

# Step 2: Wait for ADB connection
MAX_RETRIES=$((ADB_TIMEOUT / 3))
COUNT=0
CONNECTED=false

while [ $COUNT -lt $MAX_RETRIES ]; do
    # Connect to ADB daemon
    adb connect "${VM_IP}:${ADB_PORT}" > /dev/null 2>&1
    
    # Verify device is connected and authorized
    ADB_STATUS=$(adb devices | grep "${VM_IP}:${ADB_PORT}" | grep "device" || true)
    
    if [ -n "$ADB_STATUS" ]; then
        CONNECTED=true
        break
    fi
    
    sleep 3
    ((COUNT++))
done

if [ "$CONNECTED" = false ]; then
    show_error "Timed out connecting to Bliss OS over ADB at ${VM_IP}:${ADB_PORT}\n\n\
Ensure:\n\
1. Network Debugging is enabled inside Android\n\
2. VM has network connectivity\n\
3. ADB is properly installed\n\
4. Firewall is not blocking port ${ADB_PORT}"
    exit 1
fi

# Step 3: Launch the Android app via ADB
notify-send "Bliss OS" "Launching ${PACKAGE_NAME}..." -i application-x-executable

if [ -n "$ACTIVITY_NAME" ]; then
    # Launch specific activity
    adb shell am start -n "${PACKAGE_NAME}/${ACTIVITY_NAME}" > /dev/null 2>&1
else
    # Use monkey launcher to start the app
    adb shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
fi

# Check if app launch was successful
if [ $? -ne 0 ]; then
    show_error "Failed to launch package '$PACKAGE_NAME'.\n\n\
Make sure the app is installed inside Bliss OS.\n\
To list installed packages: adb shell pm list packages"
    exit 1
fi

# Step 4: Open GUI viewer for the VM
notify-send "Bliss OS" "Opening VM GUI..." -i video-display

# Launch virt-viewer in background
virt-viewer -c qemu:///system --attach "$VM_NAME" &

# Wait a moment for viewer to start, then exit
sleep 1
echo "Bliss OS VM launched successfully!"
exit 0

###############################################################################
# ADDITIONAL CONFIGURATION OPTIONS (uncomment to use)
###############################################################################

# Optional: Use virt-manager instead of virt-viewer
# virt-manager -c qemu:///system --show-domain-config "$VM_NAME" &

# Optional: Enable USB redirection for better peripheral support
# virt-viewer -c qemu:///system --attach --spice-usbredir-auto-redirect "$VM_NAME" &

# Optional: Launch in fullscreen mode
# virt-viewer -c qemu:///system --attach --full-screen "$VM_NAME" &
