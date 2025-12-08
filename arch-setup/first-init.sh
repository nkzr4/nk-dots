#!/bin/bash
# first-init.sh - Script de primeira inicialização

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/logs.sh
source $SCRIPT_DIR/vars.sh

validate_internet() {
    log_info "Verificando conexão com a internet..."
    run nmcli radio wifi on
    if run ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        log_success "Conexão com a internet já está ativa"
        echo ""
        read -p "Pressione qualquer tecla para continuar.."
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
        run nmcli device wifi list
        read -p "Digite o nome da rede WiFi (SSID): " WIFINAME
        echo ""
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
        if nmcli run device wifi connect "$WIFINAME" password "$WIFIPASSWD" ifname "$WLAN" &>/dev/null; then
            sleep 3
            if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
                log_success "Conectado à internet com sucesso via nmcli.."
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

show_header "CONFIGURAÇÃO DE PRIMEIRA INICIALIZAÇÃO"
log_info "Conectando-se a internet.."
run validate_internet

log_info "Iniciando instalação do Paru AUR helper.."
run mkdir -p ~/temp-repos/paru
run git clone https://aur.archlinux.org/paru.git ~/temp-repos/paru
run cd ~/temp-repos/paru
run log_info "Instalando Paru.."
run makepkg -sri
if run command -v paru >/dev/null 2>&1; then
    log_success "Paru instalado com sucesso."
else
    log_error "A instalação do Paru falhou. Tente novamente.."
    echo ""
    read -p "Pressione qualquer tecla para encerrar.."
    exit
fi
log_info "Iniciando instalação do caelestia-dots.."
run git clone https://github.com/caelestia-dots/caelestia.git ~/.local/share/caelestia
run ~/.local/share/caelestia/install.fish
if run command -v caelestia shell >/dev/null 2>&1; then
    log_success "caelestia-dots instalado com sucesso."
else
    log_error "A instalação do caelestia-dots falhou. Tente novamente.."
    echo ""
    read -p "Pressione qualquer tecla para encerrar.."
    exit
fi

# Hyprland.conf
KEYMAPDIR=".config/hypr/hyprland/keymap.xkb"
INPUTCONF="$HOME/.config/hypr/hyprland/input.conf"
sed -i -E \
    "s/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*us[[:space:]]*$/kb_layout = br\
kb_file = \/home\/$USERNAME\/$KEYMAPDIR/" "$INPUTCONF"
xkbcli dump-keymap-wayland > "$HOME/$KEYMAPDIR"
sed -i -E 's/action= *LockMods\( *modifiers=Lock *\);/action= LockMods(modifiers=Lock, unlockOnPress=true);/' "$HOME/$KEYMAPDIR"
sed -i -E 's/zen-browser/firefox/' "$HOME/.config/hypr/variables.conf"
hyprctl reload

# Fastfetch
cp -r "$HOME/.config/nk-dots/hypr-setup/fish/ascii_frames" "$HOME/.config/fish"
cp "$HOME/.config/nk-dots/hypr-setup/fish/functions/fish_greeting.fish" "$HOME/.config/fish/functions/fish_greeting.fish"
cp "$HOME/.config/nk-dots/hypr-setup/fish/functions/display_animation.fish" "$HOME/.config/fish/functions/display_animation.fish"
cp "$HOME/.config/nk-dots/hypr-setup/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"

# Wallpapers & GIFs
mkdir -p "$HOME/Wallpapers"
mv "$HOME/.config/nk-dots/hypr-setup/wallpapers/"* "$HOME/Wallpapers/"
sudo mv "$HOME/.config/nk-dots/hypr-setup/assets/"* /etc/xdg/quickshell/caelestia/assets/
cp "$HOME/.config/nk-dots/hypr-setup/caelestia/shell.jsonc" "$HOME/.config/caelestia/shell.jsonc"
caelestia scheme set -n dynamic
caelestia shell wallpaper set "/home/$USERNAME/Wallpapers/white-mountains.jpg"

# Apps
paru -S --noconfirm github-desktop-bin
paru -S --noconfirm vscodium-bin

# Snapshot
sudo pacman -S --noconfirm timeshift
sudo /etc/grub.d/41_snapshots-btrfs
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo systemctl enable grub-btrfsd
sudo systemctl start grub-btrfsd
sudo mkdir -p /etc/systemd/system/grub-btrfsd.service.d

sudo tee /etc/systemd/system/grub-btrfsd.service.d/override.conf >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/grub-btrfsd --syslog -t
EOF

sudo systemctl daemon-reload
sudo systemctl.restart grub-btrfsd.service
sudo timeshift --create --tags O --comments "[NK-DOTS] - Instalação concluída"

log_success "Instalação finalizada.."
echo ""
read -p "Pressione qualquer tecla para encerrar.."