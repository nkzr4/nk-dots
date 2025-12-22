#!/bin/bash
# chroot.sh

source "/services/system.sh"
source "/services/boot.sh"

check_internet() {
    curl -fsS --max-time 3 https://geo.mirror.pkgbuild.com >/dev/null
}

if check_internet; then
    config_installation
    config_boot
else
    exit 0
fi