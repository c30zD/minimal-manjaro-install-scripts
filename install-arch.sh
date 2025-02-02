#!/bin/bash

set -euo pipefail

# check if boot type is UEFI
ls /sys/firmware/efi/efivars || { echo "Boot Type Is Not UEFI!; "exit 1; }

# check if internet connection exists
ping -q -c 1 archlinux.org >/dev/null || { echo "No Internet Connection!; "exit 1; }

# update system clock
timedatectl set-ntp true

# read the block device path you want to install Arch on
echo -n "Enter the block device path you want to install Arch on: "
read -r BLOCK_DEVICE

# ask if the user wants default partitioning or wants to do partitioning manually with cfdisk?
echo -n "Do you want to do partitioning manually with cfdisk? [y/N]: "
read -r PARTITIONING

# if the user wants to create [one] LUKS partition manually with cfdisk (in case there are already other OS's installed)
if [ "${PARTITIONING}" == "y" ]; then
    # partition the block device with cfdisk
    cfdisk "${BLOCK_DEVICE}"
else
    # make a 550 MiB EFI partition and use the rest of the disk for LUKS partition
    sgdisk --clear -n 1:0:+550M -t 1:ef00 -n 2:0:0 -t 2:8309 "${BLOCK_DEVICE}"

    # format EFI partition
    mkfs.fat -F32 -n ESP "${BLOCK_DEVICE}1"
fi

# show partitions
lsblk

# read the boot/efi partition path
echo -n "Enter the boot/efi partition path: "
read -r BOOT_PARTITION

# read the LUKS partition path
echo -n "Enter the LUKS partition path: "
read -r NEW_PARTITION

# create a LUKS partiton
cryptsetup luksFormat -y -v -s 512 --pbkdf argon2id --pbkdf-force-iterations 22 "${NEW_PARTITION}"

# open the LUKS partition
cryptsetup open "${NEW_PARTITION}" cryptlvm

# create physical volume on the LUKS partition
pvcreate /dev/mapper/cryptlvm

# create logical volume group on the physical volume
vgcreate vg1 /dev/mapper/cryptlvm

# create logical volumes named root<num> on the volume group with 80 GB of space
lvcreate -L 80G vg1 -n root1
lvcreate -L 80G vg1 -n root2
lvcreate -L 80G vg1 -n root3

# create logical volume named home on the volume group with the rest of the space
lvcreate -l 100%FREE vg1 -n data

# format root LV partition with ext4 filesystem
mkfs.ext4 -m 1 -L Manjaro /dev/vg1/root1

# format home lv partition with ext4 filesystem
mkfs.ext4 -m 1 -L DATA /dev/vg1/data

# Set the number of reserved block space to 10 GiB (this assumes a very large disk size) and a blocksize of 4096 bytes
tune2fs -r $((10 * 1024**3 / 4096)) /dev/vg1/data

# mount the root partition
mount /dev/vg1/root1 /mnt

# create home directory
#mkdir -p /mnt/home

# mount the home partition
#mount /dev/vg1/home /mnt/home

# create boot directory
mkdir -p /mnt/boot/efi

# mount the EFI partiton
mount "${BOOT_PARTITION}" /mnt/boot/efi

# show the mounted partitions
lsblk

# install necessary packages
basestrap /mnt base base-devel linux linux-lts linux-firmware lvm2 vim git networkmanager refind os-prober efibootmgr exfatprogs dosfstools f2fs-tools mhwd man-db texinfo

# refind-install hook
cat <<EOF >/etc/pacman.d/hooks/refind.hook
[Trigger]
Operation=Upgrade
Type=Package
Target=refind

[Action]
Description = Updating rEFInd on ESP
When=PostTransaction
Exec=/usr/bin/refind-install
EOF

# Generate an fstab config
fstabgen -U /mnt >>/mnt/etc/fstab

# copy chroot-script.sh to /mnt
cp chroot-script.sh /mnt

# chroot into the new system and run the chroot-script.sh script
manjaro-chroot /mnt ./chroot-script.sh

# get the UUID of the LUKS partition
LUKS_UUID=$(blkid -s UUID -o value "${NEW_PARTITION}")

# prepare boot options for refind
BLK_OPTIONS="cryptdevice=UUID=${LUKS_UUID}:cryptlvm root=/dev/vg1/root1"
RW_LOGLEVEL_OPTIONS="rw loglevel=3"
INITRD_OPTIONS="initrd=initramfs-%v.img"
# configure refind
cat <<EOF >/mnt/boot/refind_linux.conf
"Boot with standard options"     "${BLK_OPTIONS} ${RW_LOGLEVEL_OPTIONS} ${INITRD_OPTIONS}"
"Boot using fallback initramfs"  "${BLK_OPTIONS} ${RW_LOGLEVEL_OPTIONS} initrd=initramfs-%v-fallback.img"
"Boot to terminal"               "${BLK_OPTIONS} ${RW_LOGLEVEL_OPTIONS} ${INITRD_OPTIONS} systemd.unit=multi-user.target"
"Boot to single-user mode"       "${BLK_OPTIONS} ${RW_LOGLEVEL_OPTIONS} ${INITRD_OPTIONS} single"
"Boot with minimal options"      "${BLK_OPTIONS} ${INITRD_OPTIONS} ro"
EOF
sed -i 's|#extra_kernel_version_strings|extra_kernel_version_strings|' /mnt/boot/efi/EFI/refind/refind.conf
sudo sed -i 's|#fold_linux_kernels|fold_linux_kernels|' /mnt/boot/efi/EFI/refind/refind.conf

# unmount partitions
#umount /mnt/home 
umount /mnt/boot/efi
umount /mnt
