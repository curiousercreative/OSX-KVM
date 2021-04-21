#!/usr/bin/env bash

# Special thanks to:
# https://github.com/Leoyzen/KVM-Opencore
# https://github.com/thenickdude/KVM-Opencore/
# https://github.com/qemu/qemu/blob/master/docs/usb2.txt
#
# qemu-img create -f qcow2 mac_hdd_ng.img 128G
#
echo 1 | sudo tee /sys/module/kvm/parameters/ignore_msrs > /dev/null
echo 0 | sudo tee /sys/module/kvm/parameters/report_ignored_msrs > /dev/null

############################################################################
# NOTE: Tweak the "MY_OPTIONS" line in case you are having booting problems!
############################################################################

MY_OPTIONS="+pcid,+ssse3,+sse4.2,+popcnt,+avx,+avx2,+aes,+xsave,+xsaveopt,+pdpe1gb,check,+vmx"

# This script works for Big Sur, Catalina, Mojave, and High Sierra. Tested with
# macOS 10.15.6, macOS 10.14.6, and macOS 10.13.6

REPO_PATH="."
OVMF_DIR="."

# This causes high cpu usage on the *host* side
# qemu-system-x86_64 -enable-kvm -m 3072 -cpu Penryn,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,hypervisor=off,vmx=on,kvm=off,$MY_OPTIONS\

# shellcheck disable=SC2054
args=(
  -enable-kvm
  -m 32G -mem-prealloc
  -cpu host,vendor=GenuineIntel,kvm=on,vmware-cpuid-freq=on,+invtsc,+hypervisor
  -machine pc-q35-4.2
  # -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,"$MY_OPTIONS"
  # -machine q35,accel=kvm
  -usb -device usb-kbd -device usb-tablet
  # -smp 24,threads=2
  -smp 16,cores=8,sockets=2
  -device usb-ehci,id=ehci
  # -device usb-kbd,bus=ehci.0
  # -device usb-mouse,bus=ehci.0
  # -device nec-usb-xhci,id=xhci
  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
  -drive if=pflash,format=raw,readonly,file="$REPO_PATH/$OVMF_DIR/OVMF_CODE.fd"
  -drive if=pflash,format=raw,file="$REPO_PATH/$OVMF_DIR/OVMF_VARS-1024x768.fd"
  -smbios type=2
  -device ich9-intel-hda -device hda-duplex
  -device ich9-ahci,id=sata
  -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore-Catalina/OpenCore.qcow2"
  # -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore-Catalina/OpenCore-nopicker.qcow2"
  # -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore-Catalina/OpenCore-Passthrough.qcow2"
  -device ide-hd,bus=sata.2,drive=OpenCoreBoot
  -drive id=MacHDD,if=none,file="$REPO_PATH/bigsur.img",format=qcow2
  -device ide-hd,bus=sata.3,drive=MacHDD
  -device ide-hd,bus=sata.4,drive=InstallMedia
  -drive id=InstallMedia,if=none,file="$REPO_PATH/BaseSystem.img",format=raw
  -netdev tap,id=net0,ifname=tap0,script=no,downscript=no
  -device virtio-net-pci,netdev=net0,id=eth0,mac=52:54:00:c9:18:27
  -netdev tap,id=net1,ifname=tap1,script=no,downscript=no
  -device virtio-net-pci,netdev=net1,id=eth1,mac=52:54:00:8e:e2:66
  -device pcie-root-port,bus=pcie.0,multifunction=on,port=1,chassis=1,id=port.1
  -device vfio-pci,host=03:00.0,bus=port.1,multifunction=on,x-vga=on
  -device vfio-pci,host=03:00.1,bus=port.1
  -vga ${1:-none}
  -monitor stdio
  # -vga qxl
)

# create bridge
sudo ip tuntap add dev tap0 mode tap user $(whoami)
sudo ip link set tap0 master br0
sudo ip link set dev tap0 up
sudo ip link set dev tap0 mtu 9000

sudo ip tuntap add dev tap1 mode tap user $(whoami)
sudo ip link set tap1 master br100
sudo ip link set dev tap1 up
sudo ip link set dev tap1 mtu 9000

sudo qemu-system-x86_64 "${args[@]}"

# destroy bridge
sudo ip link set dev tap0 down
sudo ip tuntap del tap0 mode tap
sudo ip link set dev tap1 down
sudo ip tuntap del tap1 mode tap
