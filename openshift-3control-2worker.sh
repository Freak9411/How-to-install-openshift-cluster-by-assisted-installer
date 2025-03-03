#!/bin/bash

# Exit script on error
set -e

# Define common parameters
BASE_VM_DIR="/d/VMware" 
ISO_URL="https://api.openshift.com/api/assisted-images/bytoken/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NDA5OTM0MjksInN1YiI6ImM2MmUxNTNjLTkwMWQtNDA4OS1hZGQ0LWY2ZGVmM2Q5MGVjOSJ9.4PMBYVK6xl1p6UecJ4-inl0cbGI68f-lTcUqAMtYSlM/4.18/x86_64/full.iso"
ISO_PATH="/c/Users/User3/Downloads/e3377d77-afed-4e11-91fd-94abdeff7754-discovery.iso"

# Ensure VMware Workstation is installed
if ! command -v vmrun &>/dev/null; then
    echo "❌ Error: VMware Workstation is not installed or vmrun is not in PATH."
    exit 1
fi

# Download the OpenShift ISO if not present
if [[ ! -f "$ISO_PATH" ]]; then
    echo "📥 Downloading OpenShift ISO..."
    wget -O "$ISO_PATH" "$ISO_URL"
fi

# Function to create a VM
create_vm() {
    local VM_NAME=$1
    local CPU_COUNT=$2
    local RAM_SIZE=$3
    local DISK_SIZE=$4

    VM_DIR="$BASE_VM_DIR/$VM_NAME"
    VMX_FILE="$VM_DIR/$VM_NAME.vmx"

    # Create VM directory
    mkdir -p "$VM_DIR"

    # Create a new VMware VM disk
    echo "💾 Creating VM: $VM_NAME with ${CPU_COUNT} vCPU, ${RAM_SIZE}MB RAM, ${DISK_SIZE}GB Disk..."
    vmware-vdiskmanager -c -s "${DISK_SIZE}MB" -a nvme -t 0 "$VM_DIR/$VM_NAME.vmdk"


    # Generate VMX file
    cat > "$VMX_FILE" <<EOL
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "16"
guestOS = "rhel9-64"
memsize = "$RAM_SIZE"
numvcpus = "$CPU_COUNT"
firmware = "efi"
efi.secureBoot.enabled = "FALSE"

# Enable PCIe Root Ports
pciBridge0.present = "TRUE"
pciBridge0.virtualDev = "pcieRootPort"
pciBridge0.pciSlotNumber = "32"

pciBridge1.present = "TRUE"
pciBridge1.virtualDev = "pcieRootPort"
pciBridge1.pciSlotNumber = "33"

# Attach NVMe to a proper PCIe slot
nvme0.present = "TRUE"
nvme0.pciSlotNumber = "34"
nvme0:0.present = "TRUE"
nvme0:0.fileName = "$VM_NAME.vmdk"

ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
usb.present = "TRUE"
sound.present = "TRUE"
sound.virtualDev = "hdaudio"
displayName = "$VM_NAME"
sata0.present = "TRUE"
sata0:1.present = "TRUE"
sata0:1.fileName = "$ISO_PATH"
sata0:1.deviceType = "cdrom-image"
floppy0.present = "FALSE"
EOL

    # Ensure VMware Workstation UI lists the VM
    VMWARE_UI_DIR="$HOME/.vmware"
    RECENT_VMS_FILE="$VMWARE_UI_DIR/preferences"

    mkdir -p "$VMWARE_UI_DIR"

    if ! grep -q "$VMX_FILE" "$RECENT_VMS_FILE" 2>/dev/null; then
        echo "📌 Adding $VM_NAME to VMware Workstation UI..."
        echo "pref.vmplayer.vmList = \"$VMX_FILE\"" >> "$RECENT_VMS_FILE"
    fi

    # Start the VM in GUI mode
    echo "🚀 Starting $VM_NAME in GUI mode..."
    vmrun start "$VMX_FILE" gui

    echo "✅ $VM_NAME deployment completed!"
}

# Create 3 control plane VMs
for i in {1..3}; do
    create_vm "ocp$i" 4 16384 150000  # 4 vCPU, 16GB RAM, 150GB Disk
done

# Create 2 worker VMs
for i in {1..2}; do
    create_vm "worker$i" 2 8192 100000  # 2 vCPU, 8GB RAM, 100GB Disk
done

echo "🎉 All OpenShift VMs are deployed!"
