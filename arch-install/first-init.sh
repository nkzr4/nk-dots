#!/bin/bash
# after-setup.sh - Script de primeira inicialização

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

check_exit() {
    if [[ "$1" == "sair" ]] || [[ "$1" == "SAIR" ]]; then
        log_warning "Instalação cancelada pelo usuário"
        exit 0
    fi
}

validate_internet() {
    log_info "Verificando conexão com a internet..."
    
    nmcli radio wifi on
    
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        log_success "Conexão com a internet já está ativa"
        WIFINAME=""
        WIFIPASSWD=""
        return 0
    fi
    
    log_warning "Sem conexão com a internet. Configurando WiFi com nmcli..."
    
    local device=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')
    
    if [[ -z "$device" ]]; then
        log_error "Nenhum dispositivo WiFi encontrado"
        exit 1
    fi

    while true; do
        echo ""
        log_info "Redes WiFi disponíveis:"
        
        nmcli device wifi list
        
        echo ""
        read -p "Digite o nome da rede WiFi (SSID): " WIFINAME
        check_exit "$WIFINAME"
        
        if [[ -z "$WIFINAME" ]]; then
            log_error "O nome da rede WiFi não pode ser vazio"
            continue
        fi
        
        read -sp "Digite a senha da rede WiFi: " WIFIPASSWD
        echo ""
        check_exit "$WIFIPASSWD"
        
        if [[ -z "$WIFIPASSWD" ]]; then
            log_error "A senha da rede WiFi não pode ser vazia"
            continue
        fi
        
        log_info "Conectando à rede '$WIFINAME'..."
        
        if nmcli device wifi connect "$WIFINAME" password "$WIFIPASSWD" ifname "$device" &>/dev/null; then
            sleep 3
            if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
                log_success "Conectado à internet com sucesso via nmcli"
                break
            else
                log_error "Conexão estabelecida mas sem acesso à internet. Verifique a rede"
            fi
        else
            log_error "Falha ao conectar. Verifique o nome da rede e a senha"
        fi
    done
}

echo ""
echo "╭──────────────────────────────────────────────────────────────────────╮"
echo "│                CONFIGURAÇÃO DE PRIMEIRA INICIALIZAÇÃO                │"
echo "╰──────────────────────────────────────────────────────────────────────╯"
echo ""

log_info "Removendo resquícios de instalação do SO.."
sudo rm -rf /chroot-setup.sh
sudo rm -rf /vars.sh

log_info "Conectando-se a internet.."
validate_internet
echo ""

log_info "Iniciando instalação do Paru AUR helper.."
mkdir -p ~/temp-repos/paru
git clone https://aur.archlinux.org/paru.git ~/temp-repos/paru
cd ~/temp-repos/paru
log_info "Instalando Paru.."
makepkg -sri
if command -v paru >/dev/null 2>&1; then
    log_success "Paru instalado com sucesso."
else
    log_warning "A instalação do Paru falhou. Tente novamente.."
    exit
fi
echo ""

log_info "Iniciando instalação do caelestia-dots.."
git clone https://github.com/caelestia-dots/caelestia.git ~/.local/share/caelestia
~/.local/share/caelestia/install.fish
if command -v caelestia shell >/dev/null 2>&1; then
    log_success "caelestia-dots instalado com sucesso."
else
    log_warning "A instalação do caelestia-dots falhou. Tente novamente.."
    exit
fi
echo ""

log_info "Instalação finalizada.."
read -p "Pressione qualquer tecla para encerrar.."