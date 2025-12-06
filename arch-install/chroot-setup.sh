#!/bin/bash
# chroot-setup.sh - Preparação do chroot via Arch ISO

source /logs.sh
source /vars.sh
source /links.sh

set -euo pipefail

service_user() {
    log_info "Definindo fuso horário.."
    run ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    run hwclock --systohc
    log_success "Fuso horário definido como: $TIMEZONE.."
    log_info "Definindo idioma.."
    run sed -i "s/^#\($LANGUAGE\)/\1/" /etc/locale.gen
    run locale-gen
    run echo "LANG=$LANGUAGE" >> /etc/locale.conf
    log_success "Idioma definido como: $LANGUAGE.."
    log_info "Definindo layout do teclado.."
    run echo "$KBLAYOUT" >> /etc/vconsole.conf
    log_success "Layout definido como: $KBLAYOUT.."
    log_info "Definindo nome do computador.."
    run echo "$PCNAME" >> /etc/hostname
    log_success "Nome do computador definido como: $PCNAME.."
    log_info "Definindo senha do root.."
    run echo -e "$ROOTPASSWD\n$ROOTPASSWD" | passwd root
    log_success "Senha do root definida com sucesso.."
    log_info "Criando usuário.."
    run useradd -m -g users -G wheel $USERNAME
    log_success "Usuário '$USERNAME' criado com sucesso.."
    log_info "Definindo senha de $USERNAME.."
    run echo -e "$USERPASSWD\n$USERPASSWD" | passwd $USERNAME
    log_success "Senha de $USERNAME definida com sucesso.."
    log_info "Garantindo a $USERNAME permissões de root.."
    run pacman -Sy --noconfirm sudo
    run echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers.d/$USERNAME
    log_success "Permissões garantidas com sucesso.."
}

service_installer() {
    log_info "Preparando repositórios.."
    run curl -O https://download.sublimetext.com/sublimehq-pub.gpg
    run pacman-key --add sublimehq-pub.gpg
    run pacman-key --lsign-key 8A8F901A
    run rm sublimehq-pub.gpg
    run echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" >> /etc/pacman.conf
    run sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf
    run sed -i '/^\[multilib\]/{n;s/^#Include/Include/}' /etc/pacman.conf	
    log_success "Repositórios adicionados com sucesso.."
    log_info "Definindo vendor do processador.."
    CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
    if [[ $CPU_VENDOR == "GenuineIntel" ]]; then
        cpu="intel-ucode"
    else
        cpu="amd-ucode"
    fi
    log_success "Vendor definido como '$CPU_VENDOR'.."
    log_info "Iniciando instalação.."
    run pacman -Sy --noconfirm base-devel grub-btrfs mtools networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools openssh git pipewire pipewire-pulse pipewire-jack wireplumber bluez bluez-utils xdg-utils xdg-user-dirs alsa-utils inetutils $cpu man-db man-pages texinfo ipset firewalld acpid hyprland dunst kitty uwsm thunar xdg-desktop-portal-hyprland qt5-wayland qt6-wayland polkit-kde-agent grim slurp noto-fonts ttf-font-awesome firefox vlc vlc-plugins-all okular sublime-text spotify-launcher discord steam libreoffice-fresh qbittorrent virtualbox virtualbox-host-modules-arch inotify-tools fish gnome-calculator obs-studio bash-completion
    log_success "Aplicações e dependências instaladas sucesso.."
    log_info "Ativando serviços.."
    run systemctl enable NetworkManager
    run systemctl enable bluetooth
    run systemctl enable sshd
    run systemctl enable firewalld
    run systemctl enable fstrim.timer
    run systemctl enable acpid
    log_success "Serviços ativados com sucesso.."
}

service_boot() {
    log_info "Configurando mkinitcpio.conf.."
    run sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf
    run sed -i '/^HOOKS=/ s/filesystems/sd-encrypt filesystems/' /etc/mkinitcpio.conf
    run mkinitcpio -p linux
    log_success "mkinitcpio concluído com sucesso.."
    log_info "Configurando GRUB.."
    run grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    run grub-mkconfig -o /boot/grub/grub.cfg
    DISK_LUKS_UUID=$(run blkid -s UUID -o value $DISKNAME2)
    run sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet rd.luks.name=$DISK_LUKS_UUID=main root=/dev/mapper/main rootflags=subvol=@\"|" /etc/default/grub
    run grub-mkconfig -o /boot/grub/grub.cfg
    log_success "GRUB configurado com sucesso.."
    log_info "Configurando script de primeira inicialização.."
    run mkdir -p /home/$USERNAME/.config/{nk-dots,hypr}
    run chown -R $USERNAME:wheel /home/$USERNAME/.config
    run curl -LO $LINKFIRSTINIT
    run mv /first-init.sh /home/$USERNAME/.config/nk-dots/first-init.sh
    run chmod +x /home/$USERNAME/.config/nk-dots/first-init.sh
    run cp /logs.sh /home/$USERNAME/.config/nk-dots/logs.sh
    run chmod +x /home/$USERNAME/.config/nk-dots/logs.sh
    log_success "Script preparado com sucesso.."
    log_info "Finalizando preparação.."
    run curl -LO $LINKHYPRCONF
    run mv /hyprland.conf.default /home/$USERNAME/.config/hypr/hyprland.conf
    run chown $USERNAME:wheel /home/$USERNAME/.config/hypr
cat <<EOF > /home/$USERNAME/.bash_profile
if [[ -z \$DISPLAY && \$TTY = /dev/tty1 ]]; then
    exec Hyprland
fi
EOF
    run chown $USERNAME:wheel /home/$USERNAME/.bash_profile
    log_success "Configuração do hyprland criada com sucesso.."
    log_info "Saindo de ambiente chroot.."
}

cd
show_header "ETAPA 4 - CONFIGURAÇÕES DO USUÁRIO"
run service_user

show_header "ETAPA 5 - INSTALANDO APLICAÇÕES"
run service_installer

show_header "ETAPA 6 - PREPARANDO INICIALIZAÇÃO"
run service_boot

exit
