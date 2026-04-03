#!/bin/bash
# system.sh

DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$DIR/handler.sh"

config_installation() {
    show_header "CONFIGURANDO SISTEMA"
    source "$DIR/vars.sh"
    run set_sys_settings
    run set_sys_rootpasswd
    run set_sys_userpasswd
    run set_sys_pacman
    run enable_sys_services
}

set_sys_settings() {
    log_info "Definindo configurações de sistema"
    ln -sf /usr/share/zoneinfo/$VAR_TIMEZONE /etc/localtime
    hwclock --systohc
    sed -i "s/^#\($VAR_LOCALE\)/\1/" /etc/locale.gen
    locale-gen
    echo "LANG=$VAR_LOCALE" >> /etc/locale.conf
    echo "$VAR_KBLAYOUT" >> /etc/vconsole.conf
    echo "$VAR_PCNAME" >> /etc/hostname
    pacman -Sy --noconfirm sudo
}

set_sys_rootpasswd() {
    log_info "Definindo senha do root"
    read -r ROOTPASSWD < /keys/ROOTPASSWD.pass
    rm -f /keys/ROOTPASSWD.pass
    printf '%s\n%s\n' "$ROOTPASSWD" "$ROOTPASSWD" | passwd root || fatal "Falha ao definir senha do root"
    unset ROOTPASSWD
}

set_sys_userpasswd() {
    log_info "Criando usuário"
    useradd -m -g users -G wheel $VAR_USERNAME
    log_success "Usuário '$VAR_USERNAME' criado"
    read -r USERPASSWD < /keys/USERPASSWD.pass
    rm -f /keys/USERPASSWD.pass
    printf '%s\n%s\n' "$USERPASSWD" "$USERPASSWD" | passwd $VAR_USERNAME || fatal "Falha ao definir senha do usuário"
    unset USERPASSWD
    echo "$VAR_USERNAME ALL=(ALL) ALL" >> /etc/sudoers.d/$VAR_USERNAME || fatal "Falha ao garantir permissões ao usuário"
}

check_sys_vendor() {
    CPU="intel-ucode"
    CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
    if [[ $CPU_VENDOR != "GenuineIntel" ]]; then
        CPU="amd-ucode"
    fi
}

set_sys_pacman() {
    log_info "Instalando aplicações e dependencias"
    check_sys_vendor
    pacman -Sy --noconfirm base-devel grub-btrfs mtools networkmanager network-manager-applet dialog wpa_supplicant dosfstools openssh git pipewire pipewire-pulse pipewire-jack wireplumber pavucontrol bluez bluez-utils xdg-utils xdg-user-dirs alsa-utils inetutils $CPU man-db man-pages texinfo ipset firewalld acpid hyprland kitty uwsm thunar waybar wofi xdg-desktop-portal-hyprland qt5-wayland qt6-wayland polkit-kde-agent grim slurp inotify-tools noto-fonts ttf-font-awesome ttf-jetbrains-mono-nerd
}
    
enable_sys_services() {
    log_info "Ativando serviços instalados"
    systemctl enable NetworkManager
    systemctl enable bluetooth
    systemctl enable sshd
    systemctl enable firewalld
    systemctl enable fstrim.timer
    systemctl enable acpid
}
