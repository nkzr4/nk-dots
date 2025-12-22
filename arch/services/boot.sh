#!/bin/bash
# boot.sh

DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$DIR/handler.sh"

config_boot() {
    show_header "CONFIGURANDO INICIALIZAÇÃO"
    source "$DIR/vars.sh"
    run set_mkinitcpio_conf
    run set_grub_conf
    run set_repos
    run set_autohypr
    run set_autologin
}

set_mkinitcpio_conf() {
    log_info "Configurando mkinitcpio.conf"
    sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/filesystems/sd-encrypt filesystems/' /etc/mkinitcpio.conf
    mkinitcpio -p linux
}

set_grub_conf() {
    log_info "Configurando GRUB"
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
    DISK_LUKS_UUID=$(blkid -s UUID -o value $VAR_LINUX_PARTITION)
    sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"loglevel=3 quiet rd.luks.name=$DISK_LUKS_UUID=main root=/dev/mapper/main rootflags=subvol=@\"|" /etc/default/grub
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
}

set_repos() {
    log_info "Clonando repositório"
    git clone https://github.com/nkzr4/nk-dots.git /home/$VAR_USERNAME/.config/nk-dots
    cp /services/vars.sh /home/$VAR_USERNAME/.config/nk-dots/arch/services/vars.sh

    # PREPARAR E REFATORAR
    chmod +x /home/$VAR_USERNAME/.config/nk-dots/arch/services/first-init.sh
}

set_autohypr() {
    log_info "Preparando inicialização do hyprland"
    sed -i -E "s/\bUSERNAME\b/$VAR_USERNAME/g" /home/$VAR_USERNAME/.config/nk-dots/hypr/hyprland.conf.default
    mkdir -p /home/$VAR_USERNAME/.config/hypr
    cp /home/$VAR_USERNAME/.config/nk-dots/hypr/hyprland.conf.default /home/$VAR_USERNAME/.config/hypr/hyprland.conf
    cat_bash_profile
    chown $VAR_USERNAME:wheel /home/$VAR_USERNAME/.bash_profile
}

set_autologin() {
    log_info "Configurando autologin de '$VAR_USERNAME'"
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat_autologin_conf
    systemctl daemon-reload
    systemctl enable getty@tty1.service
    chown -R $VAR_USERNAME:wheel /home/$VAR_USERNAME/.config
}

cat_bash_profile() {
cat >> /home/$VAR_USERNAME/.bash_profile << 'EOF'
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec Hyprland
fi
EOF
}

cat_autologin_conf() {
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${VAR_USERNAME} --noclear %I \$TERM
Type=idle
EOF
}