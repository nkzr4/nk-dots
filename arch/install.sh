#!/bin/bash
# install.sh

DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
LOGGERLINK="https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch/services/logger.sh"
HANDLERLINK="https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch/services/handler.sh"
SETTINGSLINK="https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch/services/settings.sh"
DISKLINK="https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch/services/disk.sh"
SYSTEMLINK="https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch/services/system.sh"
BOOTLINK="https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch/services/boot.sh"
CHROOTLINK="https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch/chroot.sh"

check_internet() {
    curl -fsS --max-time 3 https://geo.mirror.pkgbuild.com >/dev/null
}

download_file() {
    local FILE_NAME="$1"
    local FILE_URL="$2"
    FILE_DIR="/root/$FILE_NAME"
    curl -fsSL "$FILE_URL" -o "$FILE_DIR"
    if [[ ! -f "$FILE_DIR" ]] || grep -qx "404: Not Found" "$FILE_DIR"; then
        echo "Arquivo '$FILE_NAME' inválido ou inexistente"
        echo ""
        read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
        exit 1
    fi
    chmod +x "$FILE_DIR"
    if [[ $FILE_URL != "$CHROOTLINK" ]]; then
        mv "$FILE_DIR" "/root/services/$FILE_NAME"
        source "/root/services/$FILE_NAME"
    fi
}

download_scripts() {
    mkdir -p /root/services
    download_file "logger.sh" "$LOGGERLINK"
    download_file "handler.sh" "$HANDLERLINK"
    download_file "settings.sh" "$SETTINGSLINK"
    download_file "disk.sh" "$DISKLINK"
    download_file "system.sh" "$SYSTEMLINK"
    download_file "boot.sh" "$BOOTLINK"
    download_file "chroot.sh" "$CHROOTLINK"
}

start_chroot() {
    log_info "Iniciando chroot"
    cp -r /root/services /mnt/services || fatal "Falha em copiar 'services' para chroot"
    mv /root/chroot.sh /mnt/chroot.sh || fatal "Falha em mover script para chroot"
    install -d -m 700 /mnt/keys || fatal "Falha em criar diretório para FIFOs"
    mount --bind /tmp /mnt/keys || fatal "Falha em montar espelho de FIFOs"
    arch-chroot /mnt /bin/bash -c "/chroot.sh" || fatal "Falha em iniciar chroot"
}

countdown_reboot() {
    for i in 5 4 3 2 1 0; do
        show_header "INSTALAÇÃO FINALIZADA"
        log_info "Reiniciando em $i..."
        sleep 1
    done
    reboot
}

finish_setup() {
    rm -rf /root/services
    rm -rf /mnt/services
    rm /mnt/chroot.sh
    countdown_reboot
}

if check_internet; then
    download_scripts
    get_config_settings
    config_disk
    run start_chroot
    run finish_setup
else
    exit 0
fi
