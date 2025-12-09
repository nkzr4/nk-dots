#!/bin/bash
# first-init.sh - Script de primeira inicialização

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/logs.sh
source $SCRIPT_DIR/vars.sh

validate_internet() {
    log_info "Verificando conexão com a internet..."
    nmcli radio wifi on
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        log_success "Conexão com a internet já está ativa.."
    fi
    log_warning "Sem conexão com a internet. Configurando WiFi com nmcli..."
    local WLAN=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')
    if [[ -z "$WLAN" ]]; then
        log_error "Nenhum dispositivo WiFi encontrado"
        echo ""
        read -p "Pressione qualquer tecla para encerrar.."
        exit
    fi
    while true; do
        log_info "Redes WiFi disponíveis:"
        nmcli device wifi list
        read -p "Digite o nome da rede WiFi (SSID): " WIFINAME
        if [[ -z "$WIFINAME" ]]; then
            log_error "O nome da rede WiFi não pode ser vazio. Tente novamente.."
            continue
        fi
        read -sp "Digite a senha da rede WiFi: " WIFIPASSWD
        echo ""
        if [[ -z "$WIFIPASSWD" ]]; then
            log_error "A senha da rede WiFi não pode ser vazia. Tente novamente"
            continue
        fi
        log_info "Conectando à rede '$WIFINAME'..."
        if nmcli device wifi connect "$WIFINAME" password "$WIFIPASSWD" ifname "$WLAN" &>/dev/null; then
            sleep 3
            if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
                log_success "Conectado à internet com sucesso.."
                break
            else
                log_error "Conexão estabelecida mas sem acesso à internet. Verifique a rede.."
                echo ""
                read -p "Pressione qualquer tecla para encerrar.."
                exit 1
            fi
        else
            log_error "Falha ao conectar. Verifique o nome da rede e a senha.."
            echo ""
            read -p "Pressione qualquer tecla para encerrar.."
            exit 1
        fi
    done
}

calc_diff() {
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
    read HORAS1 MINUTOS1 SEGUNDOS1 <<< "$(calc_diff "$TS1" "$TS2")"
    read HORAS2 MINUTOS2 SEGUNDOS2 <<< "$(calc_diff "$TS2" "$TS3")"
    read HORAS3 MINUTOS3 SEGUNDOS3 <<< "$(calc_diff "$TS1" "$TS3")"
    echo "────────────────────────────────────────────────────────────────────────"
    echo "Tempo total de instalação:"
    printf "%02dh %02dm %02ds\n" "$HORAS3" "$MINUTOS3" "$SEGUNDOS3"
    echo "Tempo de instalação do Arch Linux:"
    printf "%02dh %02dm %02ds\n" "$HORAS1" "$MINUTOS1" "$SEGUNDOS1"
    echo "Tempo de instalação do caelestia-shell:"
    printf "%02dh %02dm %02ds\n" "$HORAS2" "$MINUTOS2" "$SEGUNDOS2"
    echo "────────────────────────────────────────────────────────────────────────"
}

show_header "CONFIGURAÇÃO DE PRIMEIRA INICIALIZAÇÃO"
log_info "Conectando-se a internet.."
validate_internet

log_info "Iniciando instalação do Paru AUR helper.."
mkdir -p ~/.config/nk-dots/repos/paru
git clone https://aur.archlinux.org/paru.git ~/.config/nk-dots/repos/paru
cd ~/.config/nk-dots/repos/paru
log_info "Instalando Paru.."
makepkg -sri
if command -v paru >/dev/null 2>&1; then
    log_success "Paru instalado com sucesso."
else
    log_error "A instalação do Paru falhou. Tente novamente.."
    echo ""
    read -p "Pressione qualquer tecla para encerrar.."
    exit
fi
log_success "Paru instalado com sucesso.."

log_info "Iniciando instalação do caelestia-dots.."
git clone https://github.com/caelestia-dots/caelestia.git ~/.local/share/caelestia
~/.local/share/caelestia/install.fish
if command -v caelestia shell >/dev/null 2>&1; then
    log_success "caelestia-dots instalado com sucesso."
else
    log_error "A instalação do caelestia-dots falhou. Tente novamente.."
    echo ""
    read -p "Pressione qualquer tecla para encerrar.."
    exit
fi
log_success "caelestia-dots instalado com sucesso.."

log_info "Definindo layout do teclado.."
KEYMAPDIR=".config/hypr/hyprland/keymap.xkb"
INPUTCONF="$HOME/.config/hypr/hyprland/input.conf"
if [[ "$KBLAYOUT" == "br-abnt2" ]]; then
    sed -i -E \
        's/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*us[[:space:]]*$/kb_layout = br\
    kb_file = \/home\/$USERNAME\/$KEYMAPDIR/' "$INPUTCONF"
    log_success "Layout definido com br-abnt2.."
else
    sed -i -E \
        's/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*us[[:space:]]*$/kb_layout = us\
    kb_file = \/home\/$USERNAME\/$KEYMAPDIR/' "$INPUTCONF"
    log_success "Layout definido com us.."
fi
log_info "Exportando keymap.xkb.."
xkbcli dump-keymap-wayland > "$HOME/$KEYMAPDIR"
log_info "Corrigindo capslock.."
sed -i -E 's/action= *LockMods\( *modifiers=Lock *\);/action= LockMods(modifiers=Lock, unlockOnPress=true);/' "$HOME/$KEYMAPDIR"
log_success "Keymap exportada.."
hyprctl reload

log_info "Definindo navegador padrão.."
sed -i -E 's/zen-browser/firefox/' "$HOME/.config/hypr/variables.conf"
log_success "Navegador padrão definido como firefox.."

log_info "Animando fastfetch.."
cp -r "$HOME/.config/nk-dots/hypr-setup/fish/ascii_frames" "$HOME/.config/fish"
cp "$HOME/.config/nk-dots/hypr-setup/fish/functions/fish_greeting.fish" "$HOME/.config/fish/functions/fish_greeting.fish"
cp "$HOME/.config/nk-dots/hypr-setup/fish/functions/display_animation.fish" "$HOME/.config/fish/functions/display_animation.fish"
cp "$HOME/.config/nk-dots/hypr-setup/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
log_success "Animação ASCII instalada.."

log_info "Movendo wallpapers.."
mkdir -p "$HOME/Wallpapers"
mv "$HOME/.config/nk-dots/hypr-setup/wallpapers/"* "$HOME/Wallpapers/"
log_info "Movendo GIFs.."
sudo mv "$HOME/.config/nk-dots/hypr-setup/assets/"* /etc/xdg/quickshell/caelestia/assets/
log_info "Criando shell.json.."
sed -i -E "s/\bUSERNAME\b/$USERNAME/g" "$HOME/.config/nk-dots/hypr-setup/caelestia/shell.json"
cp "$HOME/.config/nk-dots/hypr-setup/caelestia/shell.json" "$HOME/.config/caelestia/shell.json"
log_info "Definindo plano de fundo.."
caelestia wallpaper -f "/home/$USERNAME/Wallpapers/mountains-dark.jpg"
caelestia scheme set -n dynamic
log_success "Configurações do tema definidas com sucesso.."

log_info "Instalando github desktop.."
paru -S --noconfirm github-desktop-bin
log_info "Instalando VSCodium.."
paru -S --noconfirm vscodium-bin
log_success "GitHub Desktop e VSCodium instalados com sucesso.."

log_info "Configurando timeshift.."
sudo pacman -S --noconfirm timeshift
log_info "Iniciando GRUB-Btrfs.."
sudo /etc/grub.d/41_snapshots-btrfs
log_info "Configurando GRUB.."
sudo grub-mkconfig -o /boot/grub/grub.cfg
log_info "Configurando GRUB-Btrfs.."
sudo systemctl enable grub-btrfsd
sudo systemctl start grub-btrfsd
sudo mkdir -p /etc/systemd/system/grub-btrfsd.service.d
sudo tee /etc/systemd/system/grub-btrfsd.service.d/override.conf >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/grub-btrfsd --syslog -t
EOF
log_info "Finalizando configuração.."
sudo systemctl daemon-reload
sudo systemctl start grub-btrfsd.service
log_info "Criando snapshot de conclusão.."
sudo timeshift --create --tags O --comments "[NK-DOTS] - Instalação concluída"
log_success "Timeshift e GRUB-Btrfs configurados com sucesso.."

log_info "Removendo diretórios temporários.."
rm -rf ~/.config/nk-dots/repos
log_info "Concluindo instalação.."
DATE3=$(date +"%Y-%m-%d %H:%M:%S")
cat >> /home/$USERNAME/.config/nk-dots/arch-setup/vars.sh <<EOF
DATE3="$DATE3"
EOF
sleep 3

show_header "INSTALAÇÃO FINALIZADA"
setup_duration

echo ""
log_success "A instalação foi concluída com sucesso.."
echo ""
read -p "Pressione qualquer tecla para encerrar.."
