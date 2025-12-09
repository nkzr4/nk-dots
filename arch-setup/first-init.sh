#!/bin/bash
# first-init.sh - Script de primeira inicialização
# ToDo
# exec-once = /usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/logs.sh
source $SCRIPT_DIR/handler.sh
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

show_header "INSTALANDO NK-DOTS"
log_info "Conectando-se a internet.."
validate_internet
echo ""
read -p "Pressione qualquer tecla para encerrar.."
exit