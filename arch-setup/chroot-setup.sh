#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $DIR/vars.sh
source $DIR/logs.sh
source $DIR/handler.sh

setup_user() {
    log_info "Definindo fuso horário"
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc
    log_success "Fuso horário '$TIMEZONE' definido"
    log_info "Definindo idioma"
    sed -i "s/^#\($LANGUAGE\)/\1/" /etc/locale.gen
    locale-gen
    echo "LANG=$LANGUAGE" >> /etc/locale.conf
    log_success "Idioma '$LANGUAGE' definido"
    log_info "Definindo layout do teclado"
    echo "$KBLAYOUT" >> /etc/vconsole.conf
    log_success "Layout '$KBLAYOUT' definido"
    log_info "Definindo hostname"
    echo "$PCNAME" >> /etc/hostname
    log_success "Hostname '$PCNAME' definido"
    log_info "Definindo senha do root"
    echo -e "$ROOTPASSWD\n$ROOTPASSWD" | passwd root
    log_success "Senha do root definida"
    log_info "Criando usuário"
    useradd -m -g users -G wheel $USERNAME
    log_success "Usuário '$USERNAME' criado"
    log_info "Definindo senha de '$USERNAME'"
    echo -e "$USERPASSWD\n$USERPASSWD" | passwd $USERNAME
    log_success "Senha de $USERNAME definida"
    log_info "Garantindo permissões de root"
    pacman -Sy --noconfirm sudo
    echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers.d/$USERNAME
    log_success "Permissões a '$USERNAME' garantidas"
}

setup_apps() {
    log_info "Preparando repositórios do pacman"
    curl -O https://download.sublimetext.com/sublimehq-pub.gpg
    pacman-key --add sublimehq-pub.gpg
    pacman-key --lsign-key 8A8F901A
    rm sublimehq-pub.gpg
    echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" >> /etc/pacman.conf
    sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf
    sed -i '/^\[multilib\]/{n;s/^#Include/Include/}' /etc/pacman.conf	
    log_success "Repositórios preparados"
    log_info "Definindo vendor do processador"
    CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
    if [[ $CPU_VENDOR == "GenuineIntel" ]]; then
        cpu="intel-ucode"
    else
        cpu="amd-ucode"
    fi
    log_success "Vendor '$CPU_VENDOR' definido"
    log_info "Iniciando instalação de aplicações e dependencias"
    pacman -Sy --noconfirm base-devel grub-btrfs mtools networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools openssh git pipewire pipewire-pulse pipewire-jack wireplumber bluez bluez-utils xdg-utils xdg-user-dirs alsa-utils inetutils $cpu man-db man-pages texinfo ipset firewalld acpid hyprland kitty uwsm thunar xdg-desktop-portal-hyprland qt5-wayland qt6-wayland polkit-kde-agent grim slurp noto-fonts ttf-font-awesome firefox vlc vlc-plugins-all okular sublime-text spotify-launcher discord steam libreoffice-fresh qbittorrent virtualbox virtualbox-host-modules-arch inotify-tools fish gnome-calculator obs-studio bash-completion gnome-keyring libsecret seahorse
    log_success "Aplicações e dependências instaladas"
    log_info "Desfazendo alterações no '/etc/pacman.conf'"
    sudo sed -i 's/^\[multilib\]/#[multilib]/' /etc/pacman.conf
    sudo sed -i '/^\[multilib\]/{n;s/^Include/#Include/}' /etc/pacman.conf
    sudo sed -i '/\[sublime-text\]/,/^Server/d' /etc/pacman.conf
    log_info "'/etc/pacman.conf' restaurado"
    log_info "Ativando serviços instalados"
    systemctl enable NetworkManager
    systemctl enable bluetooth
    systemctl enable sshd
    systemctl enable firewalld
    systemctl enable fstrim.timer
    systemctl enable acpid
    log_success "Serviços instalados ativados"
}

setup_boot() {
    log_info "Configurando mkinitcpio.conf"
    sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/filesystems/sd-encrypt filesystems/' /etc/mkinitcpio.conf
    mkinitcpio -p linux
    log_success "mkinitcpio configurado"
    log_info "Configurando GRUB"
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    DISK_LUKS_UUID=$(blkid -s UUID -o value $DISKNAME2)
    sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet rd.luks.name=$DISK_LUKS_UUID=main root=/dev/mapper/main rootflags=subvol=@\"|" /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
    log_success "GRUB configurado"
    log_info "Configurando primeira inicialização"
    mkdir -p /home/$USERNAME/.config/hypr
    git clone https://github.com/nkzr4/nk-dots.git /home/$USERNAME/.config/nk-dots
    DATE2=$(date +"%Y-%m-%d %H:%M:%S")
cat >> /vars.sh <<EOF
DATE2="$DATE2"
EOF
    cp /vars.sh /home/$USERNAME/.config/nk-dots/arch-setup/vars.sh
    chmod +x /home/$USERNAME/.config/nk-dots/arch-setup/first-init.sh
    chmod +x /home/$USERNAME/.config/nk-dots/arch-setup/logs.sh
    chmod +x /home/$USERNAME/.config/nk-dots/arch-setup/handler.sh
    chmod +x /home/$USERNAME/.config/nk-dots/arch-setup/vars.sh
    log_success "Primeira inicialização configurada"
    log_info "Preparando inicialização do hyprland"
    sed -i -E "s/\bUSERNAME\b/$USERNAME/g" /home/$USERNAME/.config/nk-dots/arch-setup/hyprland.conf.default
    cp /home/$USERNAME/.config/nk-dots/arch-setup/hyprland.conf.default /home/$USERNAME/.config/hypr/hyprland.conf
cat >> /home/$USERNAME/.bash_profile << 'EOF'
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec Hyprland
fi
EOF
    chown $USERNAME:wheel /home/$USERNAME/.bash_profile
    log_success "Inicialização do hyprland configurada"
    chown -R $USERNAME:wheel /home/$USERNAME/.config
}

setup_autologin() {
    local USERNAME="$1"
    log_info "Configurando autologin de '$USERNAME' no tty1"
    mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${USERNAME} --noclear %I \$TERM
Type=idle
EOF
    systemctl daemon-reload
    systemctl enable getty@tty1.service
    log_sucess "Autologin configurado"
}

cd
show_header "CONFIGURANDO USUÁRIO"
run setup_user

show_header "INSTALANDO APLICAÇÕES"
run setup_apps

show_header "PREPARANDO INICIALIZAÇÃO"
run setup_boot
run setup_autologin "$USERNAME"
log_info "Saindo de ambiente chroot"