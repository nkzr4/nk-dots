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
    run set_iwd_to_nm
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

set_autohypr() {
    log_info "Preparando inicialização do hyprland"
    [[ -f /home/$VAR_USERNAME/.config/nk-dots/hypr/hyprland.conf.default ]] || fatal "hyprland.conf.default não encontrado"
    sed -i -E "s/\bUSERNAME\b/$VAR_USERNAME/g" /home/$VAR_USERNAME/.config/nk-dots/hypr/hyprland.conf.default || fatal "Falha ao configurar hyprland.conf"
    grep -q "$VAR_USERNAME" /home/$VAR_USERNAME/.config/nk-dots/hypr/hyprland.conf.default || fatal "Username não foi aplicado no Hyprland conf"
    mkdir -p /home/$VAR_USERNAME/.config/hypr
    cp /home/$VAR_USERNAME/.config/nk-dots/hypr/hyprland.conf.default /home/$VAR_USERNAME/.config/hypr/hyprland.conf
    cat_bash_profile
    [[ -f /home/$VAR_USERNAME/.bash_profile ]] || fatal ".bash_profile não criado"
    chown $VAR_USERNAME:wheel /home/$VAR_USERNAME/.bash_profile
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

set_startshell() {
    log_info "Configurando serviço de conclusão de instalação"
    SERVICE_PATH="/etc/systemd/system/nkshell.service"
    cat << 'EOF' > "$SERVICE_PATH"
[Unit]
Description=Finish nk-dots configuration (first boot)
After=network.target

[Service]
Type=oneshot
ExecStart=/home/USERNAME/.config/nk-dots/arch/shell.sh
RemainAfterExit=yes

# Remove o próprio serviço após rodar (one-shot real)
ExecStartPost=/bin/systemctl disable nkshell.service

[Install]
WantedBy=multi-user.target
EOF
    sed -i "s|USERNAME|$VAR_USERNAME|g" "$SERVICE_PATH"
    chmod 644 "$SERVICE_PATH"
    systemctl enable nkshell.service
    log_success "Serviço de execução de script finalizado"
}

set_iwd_to_nm() {
    IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
    TYPE=$(cat /sys/class/net/"$IFACE"/type 2>/dev/null)
    if [ "$TYPE" = "1" ]; then
        return 0
    else
        log_info "Obtendo credenciais de acesso a internet"
        WIFI_DEV=$(iwctl device list | awk '/station/ {print $2; exit}')
        if [ -z "$WIFI_DEV" ]; then
            echo "Nenhuma interface Wi-Fi encontrada."
            return 1
        fi
        SSID=$(iwctl station "$WIFI_DEV" show | awk -F': ' '/Connected network/ {print $2}')
        if [ -z "$SSID" ]; then
            echo "Não conectado a nenhuma rede via iwctl."
            return 1
        fi
        IWD_FILE="/var/lib/iwd/${SSID}.psk"
        if [ ! -f "$IWD_FILE" ]; then
            echo "Arquivo de credenciais não encontrado: $IWD_FILE"
            return 1
        fi
        PASSWORD=$(grep -i '^PreSharedKey=' "$IWD_FILE" | cut -d= -f2)
        if [ -z "$PASSWORD" ]; then
            echo "Não foi possível extrair a senha."
            return 1
        fi
        log_info "SSID: $SSID"
        log_info "Importando para NetworkManager..."
        nmcli connection add type wifi \
            ifname "$WIFI_DEV" \
            con-name "$SSID" \
            ssid "$SSID" >/dev/null 2>&1
        nmcli connection modify "$SSID" \
            wifi-sec.key-mgmt wpa-psk \
            wifi-sec.psk "$PASSWORD" \
            connection.autoconnect yes
        chmod 600 "/etc/NetworkManager/system-connections/$SSID.nmconnection" 2>/dev/null
        log_sucess "Conexão criada com sucesso no NetworkManager."
        NMCLI_SET="true"
    fi
}

cat_autologin_conf() {
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${VAR_USERNAME} --noclear %I \$TERM
Type=idle
EOF
}
