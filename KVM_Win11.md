# KVM Win 11 Setup for GPU Passthrough
1. Install windows vm
2. Do PCI Pass through of Nvidia GPU to KVM (using virt-manager after gpu driver block)
3. Disable Secure boot in win vm boot menu
4. Install Nvidia App and install driver
5. Viirtio-win-guest-tools-setup
6. Install Looking Glass B7
7. winget install --id=VirtualDrivers.Virtual-Display-Driver -e
8. ```xml
	<domain xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0" type="kvm">
	<qemu:commandline>
	  <qemu:arg value="-acpitable"/>
	  <qemu:arg value="file=/home/ubuntu/storage/vms/SSDT1.dat"/>
	  <qemu:arg value="-device"/>
	  <qemu:arg value="{'driver':'ivshmem-plain','id':'shmem0','memdev':'looking-glass'}"/>
	  <qemu:arg value="-object"/>
	  <qemu:arg value="{'qom-type':'memory-backend-file','id':'looking-glass','mem-path':'/dev/kvmfr0','size':33554432,'share':true}"/>
    </qemu:commandline>
 ```   
9. Advanced Display->Display : Display 2 VDD by MTT
	Presentation mode : Display 2 
	Both spice and LG clients are blank.
	Force Reset VM (this runs the LG server on startup)
	Run LG client

# SSTD1 creation

```bash
echo 'U1NEVKEAAAAB9EJPQ0hTAEJYUENTU0RUAQAAAElOVEwYEBkgoA8AFVwuX1NCX1BDSTAGABBMBi5fU0JfUENJMFuCTwVCQVQwCF9ISUQMQdAMCghfVUlEABQJX1NUQQCkCh8UK19CSUYApBIjDQELcBcLcBcBC9A5C1gCCywBCjwKPA0ADQANTElPTgANABQSX0JTVACkEgoEAAALcBcL0Dk=' | base64 -d > SSDT1.dat  
```


# /dev/kvmfr0 creation

```bash
echo '/dev/kvmfr0 rw,' | sudo tee -a /etc/apparmor.d/abstractions/libvirt-qemu
echo "options kvmfr static_size_mb=32" | sudo tee /etc/modprobe.d/kvmfr.conf
echo "kvmfr" | sudo tee -a /etc/modules-load.d/kvmfr.conf
echo 'SUBSYSTEM=="kvmfr", OWNER="root", GROUP="kvm", MODE="0660"' | sudo tee /etc/udev/rules.d/99-kvmfr.rules
```
