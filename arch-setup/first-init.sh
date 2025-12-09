#!/bin/bash
# first-init.sh - Script de primeira inicialização
# ToDo
# exec-once = /usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $DIR/logs.sh
source $DIR/handler.sh
source $DIR/vars.sh
source $DIR/validations.sh

setup_paru() {
    while true; do
        log_info "Clonando repositório do Paru"
        mkdir -p ~/.config/nk-dots/repos/paru
        git clone https://aur.archlinux.org/paru.git ~/.config/nk-dots/repos/paru
        cd ~/.config/nk-dots/repos/paru
        log_success "Repositório clonado"
        log_info "Instalando Paru"
        makepkg -sri
        if command -v paru >/dev/null 2>&1; then
            log_success "Paru instalado"
            break
        else
            log_error "A instalação do Paru falhou"
            rm -rf ~/.config/nk-dots/repos/paru
            continue
        fi
    done
}

setup_caelestia() {
    while true; do
        log_info "Clonando repositório do caelestia-dots.."
        git clone https://github.com/caelestia-dots/caelestia.git ~/.local/share/caelestia
        ~/.local/share/caelestia/install.fish
        if command -v caelestia shell >/dev/null 2>&1; then
            log_success "caelestia-dots instalado"
            break
        else
            log_error "A instalação do caelestia-dots falhou. Tente novamente.."
            rm -rf ~/.local/share/caelestia
            continue
        fi
    done
}

setup_user() {
    log_info "Definindo layout do teclado"
    KEYMAPDIR=".config/hypr/hyprland/keymap.xkb"
    INPUTCONF="$HOME/.config/hypr/hyprland/input.conf"
    if [[ "$KBLAYOUT" == "br-abnt2" ]]; then
        sed -i -E \
            's/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*us[[:space:]]*$/kb_layout = br\
        kb_file = \/home\/$USERNAME\/$KEYMAPDIR/' "$INPUTCONF"
        log_success "Layout 'br' definido"
    else
        sed -i -E \
            's/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*us[[:space:]]*$/kb_layout = us\
        kb_file = \/home\/$USERNAME\/$KEYMAPDIR/' "$INPUTCONF"
        log_success "Layout 'us' definido"
    fi
    log_info "Exportando keymap.xkb"
    xkbcli dump-keymap-wayland > "$HOME/$KEYMAPDIR"
    log_info "Removendo delay do capslock"
    sed -i -E 's/action= *LockMods\( *modifiers=Lock *\);/action= LockMods(modifiers=Lock, unlockOnPress=true);/' "$HOME/$KEYMAPDIR"
    hyprctl reload
    log_success "Keymap exportada"
    log_info "Definindo navegador padrão"
    sed -i -E 's/zen-browser/firefox/' "$HOME/.config/hypr/variables.conf"
    log_success "Navegador 'firefox' definido"
}

setup_fastfetch() {
    log_info "Animando fastfetch"
    cp -r "$HOME/.config/nk-dots/hypr-setup/fish/ascii_frames" "$HOME/.config/fish"
    cp "$HOME/.config/nk-dots/hypr-setup/fish/functions/fish_greeting.fish" "$HOME/.config/fish/functions/fish_greeting.fish"
    cp "$HOME/.config/nk-dots/hypr-setup/fish/functions/display_animation.fish" "$HOME/.config/fish/functions/display_animation.fish"
    cp "$HOME/.config/nk-dots/hypr-setup/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    log_success "Animação ASCII instalada"
}

setup_aur_apps() {
    log_info "Instalando GitHub Desktop"
    paru -S --noconfirm github-desktop-bin
    if command -v github-desktop >/dev/null 2>&1; then
        log_success "GitHub Desktop instalado"
    else
        log_error "A instalação do GitHub Desktop falhou"
        log_info "Tente instalar novamente após a conclusão do script"
    fi
    log_info "Instalando VSCodium"
    paru -S --noconfirm vscodium-bin
    if command -v vscodium >/dev/null 2>&1; then
        log_success "VSCodium instalado"
    else
        log_error "A instalação do VSCodium falhou"
        log_info "Tente instalar novamente após a conclusão do script"
    fi
}

setup_timeshift() {
    log_info "Instalando timeshift"
    sudo pacman -S --noconfirm timeshift
    if command -v github-desktop >/dev/null 2>&1; then
        log_success "Timeshift instalado"
    else
        log_error "A instalação do Timeshift falhou"
        log_info "Tente instalar novamente após a conclusão do script"
        echo ""
        read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
        exit 1
    fi
    log_info "Configurando GRUB-Btrfs"
    sudo /etc/grub.d/41_snapshots-btrfs
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    log_success "GRUB-Btrfs configurado"
    log_info "Ativando GRUB-Btrfs"
    sudo systemctl enable grub-btrfsd
    sudo systemctl start grub-btrfsd
    log_success "GRUB-Btrfs ativado"
    log_info "Configurando atualização automática de snapshots"
    sudo mkdir -p /etc/systemd/system/grub-btrfsd.service.d
cat <<EOF > /etc/systemd/system/grub-btrfsd.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/grub-btrfsd --syslog -t
EOF
    sudo systemctl daemon-reload
    sudo systemctl start grub-btrfsd.service
    log_success "Atualização automática ativada"
    log_info "Criando snapshot inicial"
    sudo timeshift --create --comments "[SNAPSHOT] - Instalação concluída"
    log_success "Snapshot criado"
}

setup_ending() {
    log_info "Removendo diretórios temporários"
    rm -rf ~/.config/nk-dots/repos
    log_info "Concluindo instalação"
    DATE3=$(date +"%Y-%m-%d %H:%M:%S")
cat >> /home/$USERNAME/.config/nk-dots/arch-setup/vars.sh <<EOF
DATE3="$DATE3"
EOF
    sleep 3
}

calc_time_diff() {
    local t1=$1
    local t2=$2
    local diff=$((t2 - t1))
    echo "$((diff / 3600)) $(((diff % 3600) / 60)) $((diff % 60))"
}

to_timestamp() {
    date -d "$1" +%s 2>/dev/null
}

setup_duration() {
    TS1=$(to_timestamp "$DATE1")
    TS2=$(to_timestamp "$DATE2")
    TS3=$(to_timestamp "$DATE3")
    read HORAS1 MINUTOS1 SEGUNDOS1 <<< "$(calc_time_diff "$TS1" "$TS2")"
    read HORAS2 MINUTOS2 SEGUNDOS2 <<< "$(calc_time_diff "$TS2" "$TS3")"
    read HORAS3 MINUTOS3 SEGUNDOS3 <<< "$(calc_time_diff "$TS1" "$TS3")"
    echo "────────────────────────────────────────────────────────────────────────"
    echo "Tempo total de instalação:"
    printf "%02dh %02dm %02ds\n" "$HORAS3" "$MINUTOS3" "$SEGUNDOS3"
    echo "Tempo de instalação do Arch Linux:"
    printf "%02dh %02dm %02ds\n" "$HORAS1" "$MINUTOS1" "$SEGUNDOS1"
    echo "Tempo de instalação do NK-DOTS:"
    printf "%02dh %02dm %02ds\n" "$HORAS2" "$MINUTOS2" "$SEGUNDOS2"
    echo "────────────────────────────────────────────────────────────────────────"
}

show_header "INICIANDO INSTALAÇÃO DE NK-DOTS"
run validate_internet

log_info "Ativando serviços"
run systemctl --user enable --now gcr-ssh-agent.socket
run systemctl --user enable --now gnome-keyring-daemon.service
run systemctl --user enable --now gnome-keyring-daemon.socket
log_success "Serviços ativados"

show_header "INSTALANDO AUR HELPER"
run setup_paru

show_header "INSTALANDO CAELESTIA-SHELL"
run setup_caelestia

show_header "INSTALANDO APLICATIVOS AUR"
run setup_aur_apps

show_header "DEFININDO PREFERÊNCIAS DE USUÁRIO"
run setup_user
run setup_fastfetch

show_header "CONFIGURANDO SNAPSHOTS"
run setup_timeshift

show_header "CONCLUINDO INSTALAÇÃO DE NK-DOTS"
run setup_ending

show_header "INSTALAÇÃO FINALIZADA"
run setup_duration
echo ""
log_success "A instalação foi concluída com sucesso"
echo ""
read -n 1 -s -p "Pressione qualquer tecla para encerrar.."
exit 1