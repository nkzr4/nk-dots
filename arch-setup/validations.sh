#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $DIR/logs.sh
source $DIR/handler.sh

validate_kblayout() {
    while true; do
        log_info "Definindo layout do teclado"
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o layout do teclado (default: br-abnt2): " KBLAYOUT
        if [[ -z "$KBLAYOUT" ]]; then
            KBLAYOUT="br-abnt2"
            log_success "Layout '$KBLAYOUT' definido"
            break
        fi
        if localectl list-keymaps | grep -qx "$KBLAYOUT"; then
            log_success "Layout '$KBLAYOUT' definido"
            break
        else
            log_error "Layout '$KBLAYOUT' inválido"
            continue
        fi
    done
}

validate_timezone() {
    while true; do
        log_info "Definindo fuso horário"
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o timezone (default: America/Recife): " TIMEZONE
        if [[ -z "$TIMEZONE" ]]; then
            TIMEZONE="America/Recife"
            log_success "Fuso horário '$TIMEZONE' definido"
            timedatectl set-ntp true
            timedatectl set-timezone $TIMEZONE
            DATE1=$(date +"%Y-%m-%d %H:%M:%S")
            break
        fi
        if timedatectl list-timezones | grep -qx "$TIMEZONE"; then
            log_success "Fuso horário '$TIMEZONE' definido"
            timedatectl set-ntp true
            timedatectl set-timezone $TIMEZONE
            DATE1=$(date +"%Y-%m-%d %H:%M:%S")
            break
        else
            log_error "Fuso horário '$TIMEZONE' inválido"
            continue
        fi
    done
}

validate_language() {
    while true; do
        log_info "Definindo idioma"
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o locale (default: en_US.UTF-8): " LANGUAGE
        if [[ -z "$LANGUAGE" ]]; then
            LANGUAGE="en_US.UTF-8"
            log_success "Idioma '$LANGUAGE' definido"
            break
        fi
        if grep "${LANGUAGE}" /etc/locale.gen; then
            log_success "Idioma '$LANGUAGE' definido"
            break
        else
            log_error "Idioma '$LANGUAGE' inválido"
            continue
        fi
    done
}

validate_pcname() {
    while true; do
        log_info "Definindo hostname"
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o nome do computador (default: nkarch) " PCNAME
        if [[ -z "$PCNAME" ]]; then
            PCNAME="nkarch"
            log_success "Hostname '$PCNAME' definido"
            break
        fi
        if [[ "$PCNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
            log_success "Hostname '$PCNAME' definido"
            break
        else
            log_error "Hostname '$PCNAME' inválido"
            continue
        fi
    done
}

validate_username() {
    while true; do
        log_info "Definindo nome de usuário"
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o nome do usuário (default: nkzr4): " USERNAME
        if [[ -z "$USERNAME" ]]; then
            USERNAME="nkzr4"
            log_success "Nome de usuário '$USERNAME' definido"
            break
        fi
        if [[ "$USERNAME" =~ ^[a-z_]([a-z0-9_-]{0,31})$ ]]; then
            log_success "Nome de usuário '$USERNAME' definido"
            break
        else
            log_error "Nome de usuário '$USERNAME' inválido"
            continue
        fi
    done
}

validate_rootpasswd() {
    GLOBALPASSWD="false"
    while true; do
        log_info "Definindo senha do root"
        read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite a senha do root: " ROOTPASSWD
        if [[ -z "$ROOTPASSWD" ]]; then
            log_error "A senha do root não pode ser vazia"
            continue
        fi
        echo ""
        read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirme a senha do root: " ROOTPASSWD_CONFIRM
        echo ""
        if [[ "$ROOTPASSWD" == "$ROOTPASSWD_CONFIRM" ]]; then
            read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Deseja atribuir a mesma senha para o usuário e criptografia? (s/N): " confirm
            if [[ -z "$confirm" || "$confirm" == "s" || "$confirm" == "S" ]]; then
                LUKSPASSWD="$ROOTPASSWD"
                USERPASSWD="$ROOTPASSWD"
                GLOBALPASSWD="true"
                log_success "Senha do root definida"
                log_success "Senha do usuário '$USERNAME' definida"
                log_success "Senha de criptografia definida"
                break
            else
                log_success "Senha do root definida"
                break
            fi
        else
            log_error "As senhas não coincidem"
            continue
        fi
    done
}

validate_userpasswd() {
    if [[ "$GLOBALPASSWD" != "true" ]]; then
        while true; do
            log_info "Definindo senha do usuário"
            read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite a senha do usuário '$USERNAME': " USERPASSWD
            if [[ -z "$USERPASSWD" ]]; then
                log_error "A senha do usuário não pode ser vazia"
                continue
            fi
            echo ""
            read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirme a senha do usuário '$USERNAME': " USERPASSWD_CONFIRM
            echo ""
            if [[ "$USERPASSWD" == "$USERPASSWD_CONFIRM" ]]; then
                log_success "Senha do usuário '$USERNAME' definida"
                break
            else
                log_error "As senhas não coincidem"
                continue
            fi
        done
    fi
}

validate_luks_passwd() {
    if [[ "$GLOBALPASSWD" != "true" ]]; then
        while true; do
            log_info "Definindo senha de criptografia"
            read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite a senha para criptografia: " LUKSPASSWD
            if [[ -z "$LUKSPASSWD" ]]; then
                log_error "A senha de criptografia não pode ser vazia"
                continue
            fi
            echo ""
            read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirme a senha para criptografia: " USERPASSWD_CONFIRM
            echo ""
            if [[ "$LUKSPASSWD" == "$LUKSPASSWD_CONFIRM" ]]; then
                log_success "Senha de criptografia definida"
                break
            else
                log_error "As senhas não coincidem"
                continue
            fi
        done
    fi
}

validate_diskname() {
    while true; do
        log_info "Definindo disco para instalação"
        lsblk -d -o NAME,SIZE,TYPE,MODEL
        log_warning "ATENÇÃO: O disco selecionado será completamente APAGADO!"
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o nome do disco (ex: sda, nvme0n1): " DISKNAME
        if [[ -z "$DISKNAME" ]]; then
            log_error "O nome do disco não pode ser vazio"
            continue
        fi
        if lsblk -d -o NAME | grep -qx "$DISKNAME"; then
            read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirma o uso do disco /dev/$DISKNAME? (digite 'SIM' em caixa alta): " confirm
            if [[ "$confirm" == "SIM" ]]; then
                DISK="/dev/$DISKNAME"
                DISKNAME1="${DISK}1"
                DISKNAME2="${DISK}2"
                log_success "Disco '/dev/$DISKNAME' definido"
                break
            else
                log_warning "Seleção de disco cancelada"
                continue
            fi
        else
            log_error "Disco '$DISKNAME' não encontrado"
            continue
        fi
    done
}

validate_internet() {
    while true; do
        log_info "Verificando conexão com a internet"
        nmcli radio wifi on
        if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
            log_success "Conexão com a internet ativa"
            break
        fi
        log_warning "Sem conexão com a internet"
        local WLAN=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')
        if [[ -z "$WLAN" ]]; then
            log_error "Nenhum dispositivo WiFi encontrado"
            echo ""
            read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
            exit 1
        fi
        while true; do
            log_info "Redes WiFi disponíveis:"
            nmcli device wifi list
            read -p "Digite o nome da rede WiFi (SSID): " WIFINAME
            if [[ -z "$WIFINAME" ]]; then
                log_error "Nome não pode ser vazio"
                continue
            fi
            read -sp "Digite a senha da rede WiFi: " WIFIPASSWD
            echo ""
            if [[ -z "$WIFIPASSWD" ]]; then
                log_error "A senha da rede WiFi não pode ser vazia. Tente novamente"
                continue
            fi
            log_info "Conectando à rede '$WIFINAME'"
            if nmcli device wifi connect "$WIFINAME" password "$WIFIPASSWD" ifname "$WLAN" &>/dev/null; then
                sleep 3
                if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
                    log_success "Conectado à internet"
                    break
                else
                    log_error "Conexão sem acesso à internet"
                    continue
                fi
            else
                log_error "Falha ao conectar"
                continue
            fi
        done
        break
    done
}

validate_overview () {
    log_info "Resumo das configurações:"
    echo ""
    echo "  Layout do teclado: $KBLAYOUT"
    echo "  Timezone: $TIMEZONE"
    [[ -n "$WIFINAME" ]] && echo "  Rede WiFi: $WIFINAME"
    echo "  Disco: /dev/$DISKNAME"
    echo "  Locale: $LANGUAGE"
    echo "  Hostname: $PCNAME"
    echo "  Usuário: $USERNAME"
    echo ""
    read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirma as configurações e deseja prosseguir? (s/N): " FINAL_CONFIRM
    if [[ -n "$FINAL_CONFIRM" && "$FINAL_CONFIRM" != "s" && "$FINAL_CONFIRM" != "S" ]]; then
        log_warning "Configurações recusadas"
        echo ""
        read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
        exit 1
    fi
    log_info "Exportando variáveis"
cat <<EOF > $DIR/vars.sh
KBLAYOUT="$KBLAYOUT"
TIMEZONE="$TIMEZONE"
WIFIPASSWD="$WIFIPASSWD"
WIFINAME="$WIFINAME"
DISKNAME="$DISKNAME"
DISK="$DISK"
DISKNAME1="$DISKNAME1"
DISKNAME2="$DISKNAME2" 
LANGUAGE="$LANGUAGE"
PCNAME="$PCNAME"
ROOTPASSWD="$ROOTPASSWD"
USERNAME="$USERNAME"
USERPASSWD="$USERPASSWD"
LUKSPASSWD="$LUKSPASSWD"
DATE1="$DATE1"
EOF
    if [[ ! -f "$DIR/vars.sh" ]]; then
        log_error "Arquivo 'vars.sh' inexistente"
        echo ""
        read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
        exit 1
    fi
    chmod +x $DIR/vars.sh
    log_success "Arquivo 'vars.sh' exportado"
    log_info "Iniciando instalação"
}