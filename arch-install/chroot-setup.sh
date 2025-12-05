#!/bin/bash
# chroot-setup.sh - Preparação do chroot via Arch ISO

log_info() { echo -e "\e[1;34m[ i ]\e[0m $1"; sleep 0.5; }
log_success() { echo -e "\e[1;32m[ ✓ ]\e[0m $1"; sleep 0.5; }
log_warning() { echo -e "\e[1;33m[ ⚠ ]\e[0m $1"; sleep 0.5; }
log_error() { echo -e "\e[1;31m[ ✗ ]\e[0m $1"; sleep 0.5; }
pause_on_error() {
    echo ""
    log_error "Ocorreu um erro de execução do script"
    read -n1 -rsp "Pressione qualquer tecla para continuar..."
    clear
    exit 1
}
trap 'pause_on_error' ERR

validate_vars() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local chroot_script="$script_dir/vars.sh"
    
    echo ""
    log_info "Verificando dependências do script..."
    
    if [[ -f "$chroot_script" ]]; then
        log_success "Arquivo 'vars.sh' encontrado em: $script_dir"
        
        # Verifica se o arquivo tem permissão de execução
        if [[ -x "$chroot_script" ]]; then
            log_success "Arquivo 'vars.sh' possui permissão de execução"
        else
            log_warning "Arquivo 'vars.sh' não possui permissão de execução"
            log_info "Corrigindo permissões..."
            chmod +x "$chroot_script"
            log_success "Permissões corrigidas"
        fi
    else
        log_error "Arquivo 'vars.sh' NÃO encontrado no diretório: $script_dir"
        log_error "O arquivo 'vars.sh' deve estar no mesmo diretório deste script"
        echo ""
        log_info "Estrutura esperada:"
        echo "  $(basename "$0")"
        echo "  vars.sh  <- FALTANDO"
        echo ""
        exit 1
    fi
}

clear
echo ""
echo "╭──────────────────────────────────────────────────────────────────────╮"
echo "│                  ETAPA 3 - CONFIGURAÇÃO DE USUÁRIO                   │"
echo "╰──────────────────────────────────────────────────────────────────────╯"
echo ""

log_info "Carregando pré definições.."
validate_vars
source /vars.sh
echo ""

log_info "Definindo confiugurações.."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i "s/^#\($LANGUAGE\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LANGUAGE" >> /etc/locale.conf
echo "$KBLAYOUT" >> /etc/vconsole.conf
echo "$PCNAME" >> /etc/hostname
echo -e "$ROOTPASSWD\n$ROOTPASSWD" | passwd root
useradd -m -g users -G wheel $USERNAME
echo -e "$USERPASSWD\n$USERPASSWD" | passwd $USERNAME
pacman -S --noconfirm sudo
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers.d/$USERNAME

echo ""
echo "╭──────────────────────────────────────────────────────────────────────╮"
echo "│              ETAPA 4 - INSTALANDO PACOTES E APLICATIVOS              │"
echo "╰──────────────────────────────────────────────────────────────────────╯"
echo ""

log_info "Preparando repositórios.."
curl -O https://download.sublimetext.com/sublimehq-pub.gpg
pacman-key --add sublimehq-pub.gpg
pacman-key --lsign-key 8A8F901A
rm sublimehq-pub.gpg
echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" >> /etc/pacman.conf
sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf
sed -i '/^\[multilib\]/{n;s/^#Include/Include/}' /etc/pacman.conf	
echo ""

log_info "Definindo arquitetura do processador.."
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
if [[ $CPU_VENDOR == "GenuineIntel" ]]; then
    cpu="intel-ucode"
else
    cpu="amd-ucode"
fi

log_info "Iniciando instalação.."
pacman -Sy base-devel grub-btrfs mtools networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools openssh git pipewire pipewire-pulse pipewire-jack wireplumber bluez bluez-utils xdg-utils xdg-user-dirs alsa-utils inetutils $cpu man-db man-pages texinfo ipset firewalld acpid hyprland dunst kitty uwsm thunar xdg-desktop-portal-hyprland qt5-wayland qt6-wayland polkit-kde-agent grim slurp noto-fonts ttf-font-awesome firefox vlc vlc-plugins-all okular sublime-text spotify-launcher discord steam libreoffice-still libreoffice-still-$LANG_SHORT qbittorrent virtualbox virtualbox-host-modules-arch inotify-tools fish gnome-calculator obs-studio bash-completion

echo ""
echo "╭──────────────────────────────────────────────────────────────────────╮"
echo "│             ETAPA 5 - CONFIGURANDO PRIMEIRA INICIALIZAÇÃO            │"
echo "╰──────────────────────────────────────────────────────────────────────╯"
echo ""

log_info "Configurando mkinitcpio.conf.."
sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf
sed -i '/^HOOKS=/ s/filesystems/sd-encrypt filesystems/' /etc/mkinitcpio.conf
mkinitcpio -p linux
echo ""

log_info "Configurando GRUB.."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
DISK_LUKS_UUID=$(blkid -s UUID -o value $DISKNAME2)
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet rd.luks.name=$DISK_LUKS_UUID=main root=/dev/mapper/main rootflags=subvol=@\"|" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

log_info "Configurando scripts.."
mkdir -p /home/$USERNAME/.config/nk-dots
curl -LO https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch-install/first-init.sh
mv /first-init.sh /home/$USERNAME/.config/nk-dots/first-init.sh
chmod +x /home/$USERNAME/.config/nk-dots/first-init.sh
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/nk-dots

log_info "Ativando serviços.."
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable sshd
systemctl enable firewalld
systemctl enable fstrim.timer
systemctl enable acpid

log_info "Finalizando preparação.."
curl -LO https://https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/nkzr4-arch-setup/hyprland/hyprland.conf.default
mkdir -p /home/$USERNAME/.config/hypr
mv /hyprland.conf.default /home/$USERNAME/.config/hypr/hyprland.conf
chown $USERNAME:$USERNAME /home/$USERNAME/.config/hypr/hyprland.conf
cat <<EOF > /home/$USERNAME/.bash_profile
if [[ -z \$DISPLAY && \$TTY = /dev/tty1 ]]; then
    exec Hyprland
fi
EOF
chown $USERNAME:$USERNAME /home/$USERNAME/.bash_profile

log_info "Saindo de ambiente chroot.."

exit
