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
    run set_autologin
}

set_mkinitcpio_conf() {
    log_info "Configurando mkinitcpio.conf"
    sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf
    grep -q '^MODULES=(btrfs)' /etc/mkinitcpio.conf || fatal "MODULES não configurado"
    sed -i '/^HOOKS=/ s/filesystems/sd-encrypt filesystems/' /etc/mkinitcpio.conf
    grep -q '^HOOKS=.*sd-encrypt.*filesystems' /etc/mkinitcpio.conf || fatal "HOOKS sd-encrypt não aplicado"
    mkinitcpio -p linux || fatal "mkinitcpio falhou"
    [[ -f /boot/initramfs-linux.img ]] || fatal "initramfs não foi gerado"
}

set_grub_conf() {
    log_info "Configurando GRUB"
    mount /dev/nvme0n1p1 /boot || fatal "Falha ao montar EFI"
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Grub || fatal "Falha no grub-install"
    DISK_LUKS_UUID=$(blkid -s UUID -o value "$VAR_LINUX_PARTITION") || fatal "Não foi possível obter UUID LUKS"
    [[ -n "$DISK_LUKS_UUID" ]] || fatal "UUID LUKS vazio"
    sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"loglevel=3 quiet rd.luks.name=$DISK_LUKS_UUID=main root=/dev/mapper/main rootflags=subvol=@\"|" /etc/default/grub
    grep -q "rd.luks.name=$DISK_LUKS_UUID=main" /etc/default/grub || fatal "CMDLINE do GRUB não aplicada corretamente"
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    [[ $VAR_DUAL_BOOT == "true" ]] && os-prober
    grub-mkconfig -o /boot/grub/grub.cfg || fatal "Falha ao gerar grub.cfg"
    grep -q "@ " /boot/grub/grub.cfg || fatal "rootflags não presentes no grub.cfg"
}

set_repos() {
    log_info "Clonando repositório"
    git clone https://github.com/nkzr4/nk-dots.git /home/$VAR_USERNAME/.config/nk-dots || fatal "Falha ao clonar nk-dots"
    [[ -d /home/$VAR_USERNAME/.config/nk-dots ]] || fatal "Repositório não encontrado após clone"
    cp /services/vars.sh /home/$VAR_USERNAME/.config/nk-dots/arch/services/vars.sh || fatal "Falha ao copiar vars.sh"
    chmod +x /home/$VAR_USERNAME/.config/nk-dots/arch/shell.sh
}

set_autologin() {
    log_info "Configurando autologin de '$VAR_USERNAME'"
    mkdir -p /etc/systemd/system/getty@tty1.service.d || fatal "Falha ao criar diretório systemd override"
    cat_autologin_conf
    [[ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]] || fatal "Arquivo autologin.conf não foi criado"
    systemctl enable getty@tty1.service || fatal "Falha ao habilitar autologin"
    systemctl is-enabled getty@tty1.service >/dev/null || fatal "Autologin não está habilitado"
    chown -R $VAR_USERNAME:wheel /home/$VAR_USERNAME/.config
}

cat_autologin_conf() {
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${VAR_USERNAME} --noclear %I \$TERM
Type=idle
EOF
}
