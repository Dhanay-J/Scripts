#!/bin/bash

# Configuration
VM_NAME="win11"  # Change this to your exact virsh VM name
VM_IP="192.168.122.50"  # Change this to your VM's IP address

# 2. Start the VM using virsh
echo "Starting VM: $VM_NAME..." >&2
virsh start "$VM_NAME" > /dev/null 2>&1

# 3. Display a progress bar while waiting for Windows to boot up
(
echo "# Initializing virtual machine hardware..." ; sleep 2
echo "20"

# Loop until the guest agent answers successfully
current_progress=20
while true; do
    # Try to ping the VM
    if ping -c 1 -W 2 "$VM_IP" > /dev/null 2>&1; then
        # VM is reachable! The login screen is ready.
        echo "100"
        echo "# Windows 11 has reached the login screen!" >&2
        break
    else
        # Still booting... advance the fake progress bar up to 95%
        current_progress=$((current_progress + 15))
        if [ $current_progress -gt 95 ]; then 
            current_progress=95
        fi
        
        echo "$current_progress"
        echo "# Waiting for Windows 11 to reach the home login page..." >&2
        
        sleep 3
    fi
done

) | zenity --progress \
  --title="Booting Windows 11" \
  --text="Starting initialization..." \
  --percentage=0 \
  --auto-close \
  --no-cancel \
  --width=400

# Run vm client to connect to the VM
$HOME/Apps/LookingGlassClient/looking-glass-client &
