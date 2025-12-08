#!/bin/bash
# first-init.sh - Script de primeira inicialização

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/logs.sh

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
log_success "Instalação finalizada.."
echo ""
read -p "Pressione qualquer tecla para encerrar.."
