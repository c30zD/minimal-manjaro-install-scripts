#!/bin/bash

set -euo pipefail

# Set console keyboard and font
cat << EOF > /etc/vconsole.conf
KEYMAP=es
FONT=eurlatgr
FONT_MAP=
EOF

# set settings related to locale
sed -i -e 's|#es_ES.UTF-8 UTF-8|es_ES.UTF-8 UTF-8|' -e 's|#en_US.UTF-8 UTF-8|en_US.UTF-8 UTF-8|' /etc/locale.gen

locale-gen

cat << EOF > /etc/locale.conf
LANG=en_US.UTF-8
LANGUAGE=en_US:en:C:es_ES
LC_COLLATE=C
LC_NUMERIC=C
LC_TIME=es_ES.UTF-8
EOF

# set the time zone
#echo -n "Enter Time Zone: "
#read -r TIME_ZONE
ln -sf /usr/share/zoneinfo/CET /etc/localtime
hwclock --systohc --utc

# set hostname
echo -n "Enter hostname: "
read -r HOSTNAME
echo "${HOSTNAME}" >/etc/hostname

# configure hosts file
cat <<EOF >>/etc/hosts
127.0.0.1	localhost
127.0.1.1	${HOSTNAME}
::1	localhost ip6-localhost ip6-loopback
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
EOF

# set root user password
passwd

# configure mkinitcpio
sed -i '/^HOOKS/s/\(block \)\(.*filesystems\)/\1encrypt lvm2 \2/' /etc/mkinitcpio.conf

# generate initramfs
mkinitcpio -P

# enable NetworkManager systemd service
systemctl enable NetworkManager

# Enable timesync daemon
systemctl enable systemd-timesyncd
