#!/bin/bash
set -euo pipefail

# Set pacman mirror based on geolocation and use stable branch
pacman-mirrors --api --set-branch stable --continent

# Download package database and install keyrings
pacman -Syy archlinux-keyring manjaro-keyring

# Create trust database, populate, and refresh keys
pacman-key --init
pacman-key --populate archlinux manjaro
pacman-key --refresh-keys
