#!/bin/bash

# Install dependencies
pacman -S help2man autogen

git clone https://aur.archlinux.org/bdf-unifont.git

cd bdf-unifont
gpg --recv-keys 1A09227B1F435A33
makepkg -si

cd ..

# Install GRUB (improved) from AUR
git clone https://aur.archlinux.org/grub-improved-luks2-git.git
cd grub-improved-luks2-git
makepkg -si
