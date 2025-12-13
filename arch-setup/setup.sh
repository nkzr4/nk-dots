#!/bin/bash
# setup.sh - Script de serviços para setup

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $DIR/logs.sh
source $DIR/handler.sh
source $DIR/vars.sh

setup_services() {
    log_info "Ativando serviços"
    systemctl --user enable --now gcr-ssh-agent.socket
    systemctl --user enable --now gnome-keyring-daemon.service
    systemctl --user enable --now gnome-keyring-daemon.socket
    log_success "Serviços ativados"
}

setup_paru() {
    while true; do
        log_info "Clonando repositório do Paru"
        mkdir -p ~/.config/nk-dots/repos/paru
        git clone https://aur.archlinux.org/paru.git ~/.config/nk-dots/repos/paru
        cd ~/.config/nk-dots/repos/paru
        log_success "Repositório clonado"
        log_info "Instalando Paru"
        makepkg -si
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

setup_hypr() {
    log_info "Definindo layout do teclado"
    KEYMAPDIR="$HOME/.config/nk-dots/hypr/hyprland/keymap.xkb"
    INPUTCONF="$HOME/.config/nk-dots/hypr/hyprland/input.conf"
    if [[ "$KBLAYOUT" == "br-abnt2" ]]; then
        sed -i "s/KBLAYOUT/br/g" $INPUTCONF
        log_success "Layout 'br' definido"
    else
        sed -i "s/KBLAYOUT/us/g" $INPUTCONF
        log_success "Layout 'us' definido"
    fi
    sed -i "s@KEYMAPDIR@$KEYMAPDIR@g" $INPUTCONF
    log_info "Criando symlink"
    cp $HOME/.config/hypr/hyprland/input.conf $HOME/.config/hypr/hyprland/input.conf.bak
    rm $HOME/.config/hypr/hyprland/input.conf
    ln -s $INPUTCONF $HOME/.config/hypr/hyprland/input.conf
    log_info "Criando keymap.xkb"
    xkbcli dump-keymap-wayland > "$KEYMAPDIR"
    log_info "Removendo delay do capslock"
    sed -i -E 's/action= *LockMods\( *modifiers=Lock *\);/action= LockMods(modifiers=Lock, unlockOnPress=true);/' "$KEYMAPDIR"
    log_info "Exportando keymap.xkb"
    log_success "keymap.xkb exportado"
    log_info "Copiando 'variables.conf'"
    cp $HOME/.config/hypr/variables.conf $HOME/.config/hypr/variables.conf.bak
    rm $HOME/.config/hypr/variables.conf
    ln -s $HOME/.config/nk-dots/hypr/variables.conf $HOME/.config/hypr/variables.conf
    log_success "'variables.conf' copiado"
    hyprctl reload
}

setup_fastfetch() {
    log_info "Configurando animação ASCII"
    log_info "Adequando fish"
    cp "$HOME/.config/fish/functions/fish_greeting.fish" "$HOME/.config/fish/functions/fish_greeting.fish.bak"
    rm "$HOME/.config/fish/functions/fish_greeting.fish"
    ln -s "$HOME/.config/nk-dots/fish/functions/fish_greeting.fish" "$HOME/.config/fish/functions/fish_greeting.fish"
    ln -s "$HOME/.config/nk-dots/fish/functions/display_animation.fish" "$HOME/.config/fish/functions/display_animation.fish"
    log_info "Adequando fastfetch"
    cp "$HOME/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc.bak"
    rm "$HOME/.config/fastfetch/config.jsonc"
    ln -s "$HOME/.config/nk-dots/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    log_success "Animação ASCII configurada"
}

setup_caelestia_theme() {
    log_info "Configurando UserPaths.qml"
    sed -i "s/USERNAME/$USERNAME/g" /home/$USERNAME/.config/nk-dots/caelestia/config/UserPaths.qml 
    sudo cp /etc/xdg/quickshell/caelestia/config/UserPaths.qml /etc/xdg/quickshell/caelestia/config/UserPaths.qml.bak
    sudo rm /etc/xdg/quickshell/caelestia/config/UserPaths.qml
    sudo ln -s /home/$USERNAME/.config/nk-dots/caelestia/config/UserPaths.qml /etc/xdg/quickshell/caelestia/config/UserPaths.qml
    log_success "UserPaths.qml configurado"
    log_info "Configurando UtilitiesConfig.qml"
    sudo cp /etc/xdg/quickshell/caelestia/config/UtilitiesConfig.qml /etc/xdg/quickshell/caelestia/config/UtilitiesConfig.qml.bak
    sudo rm /etc/xdg/quickshell/caelestia/config/UtilitiesConfig.qml
    sudo ln -s /home/$USERNAME/.config/nk-dots/caelestia/config/UtilitiesConfig.qml /etc/xdg/quickshell/caelestia/config/UtilitiesConfig.qml
    log_success "UtilitiesConfig.qml configurado"
    log_info "Configurando ServiceConfig.qml"
    sudo cp /etc/xdg/quickshell/caelestia/config/ServiceConfig.qml /etc/xdg/quickshell/caelestia/config/ServiceConfig.qml.bak
    sudo rm /etc/xdg/quickshell/caelestia/config/ServiceConfig.qml
    sudo ln -s /home/$USERNAME/.config/nk-dots/caelestia/config/ServiceConfig.qml /etc/xdg/quickshell/caelestia/config/ServiceConfig.qml
    log_success "ServiceConfig.qml configurado"
    log_info "Configurando SessionConfig.qml"
    sudo cp /etc/xdg/quickshell/caelestia/config/SessionConfig.qml /etc/xdg/quickshell/caelestia/config/SessionConfig.qml.bak
    sudo rm /etc/xdg/quickshell/caelestia/config/SessionConfig.qml
    sudo ln -s /home/$USERNAME/.config/nk-dots/caelestia/config/SessionConfig.qml /etc/xdg/quickshell/caelestia/config/SessionConfig.qml
    log_success "SessionConfig.qml configurado"
    log_info "Criando symlink de wallpapers"
    ln -s "$HOME/.config/nk-dots/wallpapers" "$HOME/Wallpapers"
    caelestia wallpaper -f "/home/$USERNAME/Wallpapers/mountains-dark.jpg"
    caelestia scheme set -n dynamic
    log_info "Adicionando serviço de patch de estilos"
    chmod +x /home/$USERNAME/.config/nk-dots/hypr/scripts/patch_style.sh
    sed -i "s/USERNAME/$USERNAME/g" /home/$USERNAME/.config/nk-dots/hypr/scripts/patch-style.service
    cp /home/$USERNAME/.config/nk-dots/hypr/scripts/patch-style.service /home/$USERNAME/.config/systemd/user/patch-style.service
    systemctl --user daemon-reload
    systemctl --user enable --now patch-style.service
    log_success "Serviço de patch ativado"
    log_success "Tema definido"
}

setup_vscodium() {
    log_info "Configurando VSCodium"
    vscodium
    sleep 5
    read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Você já encerrou o VSCodium?: " SPOTIFY_LOGIN
    if [[ -n "$SPOTIFY_LOGIN" && "$SPOTIFY_LOGIN" != "s" && "$SPOTIFY_LOGIN" != "S" ]]; then
        log_warning "Configuração do VSCodium cancelada"
    else
        log_info "Criando symlinks"
        ln -s /home/$USERNAME/.local/share/caelestia/vscode/settings.json /home/$USERNAME/.config/VSCodium/User/settings.json
        ln -s /home/$USERNAME/.local/share/caelestia/vscode/keybindings.json /home/$USERNAME/.config/VSCodium/User/keybindings.json
        ln -s /home/$USERNAME/.local/share/caelestia/vscode/flags.conf /home/$USERNAME/.config/codium-flags.conf
        log_info "Aplicando extensão"
        codium --install-extension /home/$USERNAME/.local/share/caelestia/vscode/caelestia-vscode-integration/caelestia-vscode-integration-*.vsix
        log_success "VSCodium configurado"
    fi
}

setup_spicetify() {
    log_info "Configurando Spotify"
    spotify-launcher
    sleep 5
    read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Você fez login no Spotify: " SPOTIFY_LOGIN
    if [[ -n "$SPOTIFY_LOGIN" && "$SPOTIFY_LOGIN" != "s" && "$SPOTIFY_LOGIN" != "S" ]]; then
        log_warning "Configuração do Spicetify cancelada"
    else
        log_info "Configurando Spicetify"
        spicetify
        spicetify backup apply enable-devtools
        log_info "Spicetify configurado"
        log_info "Instalando Marketplace"
        curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-marketplace/main/resources/install.sh | sh
        log_success "Marketplace instalado"
        log_info "Aplicando caelestia-theme"
        ln -s /home/$USERNAME/.local/share/caelestia/spicetify/Themes/caelestia/user.css /home/$USERNAME/.config/spicetify/Themes/caelestia/user.css
        log_info "Encerrando Spotify"
        sleep 2
        pkill -f spotify-launcher
        while pgrep -f "spotify-launcher" >/dev/null; do
            sleep 2
        done
        spicetify config current_theme caelestia color_scheme caelestia custom_apps marketplace
        spicetify apply
        log_success "caelestia-theme aplicado"
        log_warning "Encerre o Spotify para continuar"
        while pgrep -f "spotify-launcher" >/dev/null; do
            sleep 2
        done
        log_info "Spicetify configurado"
    fi
}

setup_vencord() {
    log_info "Instalando Vencord"
    sh -c "$(curl -sS https://vencord.dev/install.sh)"
    log_success "Vencord instalado"
}

setup_mounts() {
    log_info "Preparando 'auto_mount.sh'"
    SCRIPT_PATH="/home/$USERNAME/.config/nk-dots/hypr/scripts/auto_mount.sh"
    sed -i "s/USERNAME/$USERNAME/g" /home/$USERNAME/.config/nk-dots/hypr/scripts/auto-mount.service"
    sed -i "s@SCRIPTDIR@/home/$USERNAME/.config/nk-dots/hypr/scripts@g" $SCRIPT_PATH
    chmod +x $SCRIPT_PATH
    log_info "Ativando serviço 'auto_mount.sh'"
    sudo systemctl daemon-reload
    sudo systemctl enable auto-mount.service
    log_success "Serviço configurado"
    sh -c "sudo $SCRIPT_PATH"
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
    log_info "Instalando Spicetify"
    paru -S --noconfirm spicetify-cli
    if command -v spicetify >/dev/null 2>&1; then
        log_success "Spicetify instalado"
    else
        log_error "A instalação do Spicetify falhou"
        log_info "Tente instalar novamente após a conclusão do script"
    fi
    log_info "Instalando Millennium"
    paru -S --noconfirm millennium
    if command -v millennium >/dev/null 2>&1; then
        log_success "Millennium instalado"
    else
        log_error "A instalação do Millennium falhou"
        log_info "Tente instalar novamente após a conclusão do script"
    fi
    log_info "Instalando Zen Browser"
    paru -S --noconfirm zen-browser-bin
    if command -v zen-browser >/dev/null 2>&1; then
        log_success "Zen Browser instalado"
    else
        log_error "A instalação do Zen Browser falhou"
        log_info "Tente instalar novamente após a conclusão do script"
    fi
}

setup_hypr_execs() {
    log_info "Configurando 'exec-onces'"
    sed -i "s/USERNAME/$USERNAME/g" /home/$USERNAME/.config/nk-dots/hypr/hyprland/execs.conf
    sudo cp /home/$USERNAME/.config/hypr/hyprland/execs.conf /home/$USERNAME/.config/hypr/hyprland/execs.conf.bak
    sudo rm /home/$USERNAME/.config/hypr/hyprland/execs.conf
    sudo ln -s /home/$USERNAME/.config/nk-dots/hypr/hyprland/execs.conf /home/$USERNAME/.config/hypr/hyprland/execs.conf
    log_success "'execs.conf' configurado"
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
    log_info "Criando snapshot inicial"
    sudo timeshift --create --comments "[ARCH] - Instalação concluída"
    log_success "Snapshot criada"
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
sudo bash -c 'cat <<EOF > /etc/systemd/system/grub-btrfsd.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/grub-btrfsd --syslog -t
EOF'
    sudo systemctl daemon-reload
    sudo systemctl start grub-btrfsd.service
    log_success "Atualização automática ativada"
    log_info "Criando snapshot final"
    sudo timeshift --create --comments "[NK-DOTS] - Sistema configurado"
    sleep 2
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