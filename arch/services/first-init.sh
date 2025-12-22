#!/bin/bash
# first-init.sh - Script de primeira inicialização

# ToDo
# Remover wait do archiso-setup e colocar links pra baixar silenciosamente
# Alternativa para executar todo o código sem precisar digitar senha
# Rever inputs de encerramento dos programas (Spotify, VSCodium e Steam)
# Instalar tema do GRUB (dentro do /boot)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $DIR/logger.sh
source $DIR/handler.sh
source $DIR/vars.sh
source $DIR/first-init-services.sh

check_internet() {
    curl -fsS --max-time 3 https://geo.mirror.pkgbuild.com >/dev/null
}

if check_internet; then
    show_header "INICIANDO INSTALAÇÃO DE NK-DOTS"
    run setup_services

    show_header "INSTALANDO AUR HELPER"
    run setup_paru

    show_header "INSTALANDO CAELESTIA-SHELL"
    run setup_caelestia

    show_header "INSTALANDO APLICATIVOS AUR"
    run setup_aur_apps

    show_header "DEFININDO PREFERÊNCIAS DE USUÁRIO"
    run setup_hypr
    run setup_fastfetch
    run setup_caelestia_theme
    run setup_vscodium
    run setup_spicetify
    run setup_vencord
    run setup_mounts
    run setup_hypr_execs

    show_header "CONFIGURANDO SNAPSHOTS"
    run setup_timeshift

    show_header "CONCLUINDO INSTALAÇÃO DE NK-DOTS"
    run setup_ending

    show_header "INSTALAÇÃO FINALIZADA"
    run setup_duration
    echo ""
    log_success "A instalação foi concluída com sucesso"
    echo ""
    read -n 1 -s -p "Pressione qualquer tecla para reiniciar.."
    sudo reboot now
else
    exit 0
fi