#!/bin/bash
# validations.sh 

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/logs.sh

validate_scripts() {
    log_info "Verificando downloads de scripts..."
    if [[ ! -f "$SCRIPT_DIR/links.sh" ]]; then
        log_error "Arquivo 'links.sh' não encontrado. Verifique sua conexão com a internet.."
        echo ""
        read -p "Pressione qualquer tecla para continuar.."
        exit 1
    fi
    if [[ ! -f "$SCRIPT_DIR/logs.sh" ]]; then
        log_error "Arquivo 'logs.sh' não encontrado. Verifique sua conexão com a internet.."
        echo ""
        read -p "Pressione qualquer tecla para continuar.."
        exit 1
    fi
    if [[ ! -f "$SCRIPT_DIR/validations.sh" ]]; then
        log_error "Arquivo 'validations.sh' não encontrado. Verifique sua conexão com a internet.."
        echo ""
        read -p "Pressione qualquer tecla para continuar.."
        exit 1
    fi
    if [[ ! -f "$SCRIPT_DIR/chroot-setup.sh" ]]; then
        log_error "Arquivo 'chroot-setup.sh' não encontrado. Verifique sua conexão com a internet.."
        echo ""
        read -p "Pressione qualquer tecla para continuar.."
        exit 1
    fi
    if [[ ! -f "$SCRIPT_DIR/first-init.sh" ]]; then
        log_error "Arquivo 'first-init.sh' não encontrado. Verifique sua conexão com a internet.."
        echo ""
        read -p "Pressione qualquer tecla para continuar.."
        exit 1
    fi
    log_success "Scripts carregados com sucesso..."
}

validate_internet() {
    log_info "Verificando conexão com a internet..."
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        log_success "Conexão com a internet já está ativa"
        WIFINAME=""
        WIFIPASSWD=""
        return 0
    fi
    log_warning "Sem conexão com a internet. Configurando WiFi..."
    while true; do
        log_info "Redes WiFi disponíveis:"
        local device=$(iwctl device list | awk 'NR>3 {print $2; exit}' | tr -d '[:space:]')
        if [[ -z "$device" ]]; then
            log_error "Nenhum dispositivo WiFi encontrado.."
            echo ""
            read -p "Pressione qualquer tecla para encerrar.."
            exit 1
        fi
        iwctl station "$device" scan
        sleep 2
        iwctl station "$device" get-networks
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o nome da rede WiFi (SSID): " WIFINAME
        check_exit "$WIFINAME"
        if [[ -z "$WIFINAME" ]]; then
            log_error "O nome da rede WiFi não pode ser vazio. Tente novamente..."
            continue
        fi
        read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite a senha da rede WiFi: " WIFIPASSWD
        check_exit "$WIFIPASSWD"
        if [[ -z "$WIFIPASSWD" ]]; then
            log_error "A senha da rede WiFi não pode ser vazia. Tente novamente.."
            continue
        fi
        log_info "Conectando à rede '$WIFINAME'..."
        if iwctl --passphrase "$WIFIPASSWD" station "$device" connect "$WIFINAME" &>/dev/null; then
            sleep 3
            if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
                log_success "Conectado à internet com sucesso.."
                break
            else
                log_error "Conexão estabelecida mas sem acesso à internet. Tente novamente.."
                continue
            fi
        else
            log_error "Falha ao conectar. Verifique o nome da rede e a senha e tente novamente.."
            continue
        fi
    done
}

validate_kblayout() {
    while true; do
        log_info "Defina o layout do seu teclado..."
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o layout do teclado (default: br-abnt2): " KBLAYOUT
        check_exit "$KBLAYOUT"
        if [[ -z "$KBLAYOUT" ]]; then
            KBLAYOUT="br-abnt2"
            log_success "Layout padrão '$KBLAYOUT' definido com sucesso.."
            break
        fi
        log_info "Definindo layout de teclado.."
        if localectl list-keymaps | grep -qx "$KBLAYOUT"; then
            log_success "Layout '$KBLAYOUT' definido com sucesso.."
            break
        else
            log_error "Layout '$KBLAYOUT' não encontrado. Tente novamente.."
            continue
        fi
    done
}

validate_timezone() {
    while true; do
        log_info "Defina o seu fuso horário..."
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o timezone (default: America/Recife): " TIMEZONE
        check_exit "$TIMEZONE"
        if [[ -z "$TIMEZONE" ]]; then
            TIMEZONE="America/Recife"
            log_success "Fuso horário padrão '$TIMEZONE' definido com sucesso.."
            break
        fi
        log_info "Definindo fuso horário.."
        if timedatectl list-timezones | grep -qx "$TIMEZONE"; then
            log_success "Fuso horário '$TIMEZONE' definido com sucesso.."
            break
        else
            log_error "Fuso horário '$TIMEZONE' não encontrado. Tente novamente.."
            continue
        fi
    done
}

validate_diskname() {
    while true; do
        log_info "Defina o disco para instalação..."
        lsblk -d -o NAME,SIZE,TYPE,MODEL
        log_warning "ATENÇÃO: O disco selecionado será completamente APAGADO!"
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o nome do disco (ex: sda, nvme0n1): " DISKNAME
        check_exit "$DISKNAME"
        if [[ -z "$DISKNAME" ]]; then
            log_error "O nome do disco não pode ser vazio. Tente novamente.."
            continue
        fi
        if lsblk -d -o NAME | grep -qx "$DISKNAME"; then
            read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirma o uso do disco /dev/$DISKNAME? (digite 'SIM' em caixa alta): " confirm
            if [[ "$confirm" == "SIM" ]]; then
                DISK="/dev/$DISKNAME"
                DISKNAME1="${DISK}1"
                DISKNAME2="${DISK}2"
                log_success "Disco '/dev/$DISKNAME' definido com sucesso.."
                break
            else
                log_warning "Seleção de disco cancelada.."
                echo ""
                read -p "Pressione qualquer tecla para encerrar.."
                exit 
            fi
        else
            log_error "Disco '$DISKNAME' não encontrado. Tente novamente.."
            continue
        fi
    done
}

validate_language() {
    while true; do
        log_info "Defina o idioma do sistema..."
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o locale (default: en_US.UTF-8): " LANGUAGE
        check_exit "$LANGUAGE"
        if [[ -z "$LANGUAGE" ]]; then
            LANGUAGE="en_US.UTF-8"
            log_success "Idioma padrão '$LANGUAGE' definido com sucesso.."
            break
        fi
        if grep "${LANGUAGE}" /etc/locale.gen; then
            log_success "Idioma '$LANGUAGE' validado com sucesso"
            break
        else
            log_error "Idioma '$LANGUAGE' não encontrado. Tente novamente.."
            continue
        fi
    done
}

validate_pcname() {
    while true; do
        log_info "Definindo hostname..."
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o nome do computador (default: nkarch) " PCNAME
        check_exit "$PCNAME"
        if [[ -z "$PCNAME" ]]; then
            PCNAME="nkarch"
            log_success "Hostname padrão '$PCNAME' definido com sucesso.."
            break
        fi
        if [[ "$PCNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
            log_success "Nome do computador '$PCNAME' definido com sucesso.."
            break
        else
            log_error "Nome inválido. Use apenas letras, números e hífen.."
            continue
        fi
    done
}

validate_username() {
    while true; do
        log_info "Definindo senha nome do usuário..."
        read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o nome do usuário (default: nkzr4): " USERNAME
        check_exit "$USERNAME"
        if [[ -z "$USERNAME" ]]; then
            USERNAME="nkzr4"
            log_success "Usuário padrão '$USERNAME' definido com sucesso.."
            break
        fi
        if [[ "$USERNAME" =~ ^[a-z_]([a-z0-9_-]{0,31})$ ]]; then
            log_success "Nome de usuário '$USERNAME' definido com sucesso.."
            break
        else
            log_error "Nome inválido. Use letras minúsculas, números, underline e hífen.."
            continue
        fi
    done
}

validate_rootpasswd() {
    while true; do
        log_info "Definindo senha do root..."
        read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite a senha do root: " ROOTPASSWD
        check_exit "$ROOTPASSWD"
        if [[ -z "$ROOTPASSWD" ]]; then
            log_error "A senha do root não pode ser vazia. Tente novamente.."
            continue
        fi
        echo ""
        read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirme a senha do root: " ROOTPASSWD_CONFIRM
        check_exit "$ROOTPASSWD_CONFIRM"
        echo ""
        if [[ "$ROOTPASSWD" == "$ROOTPASSWD_CONFIRM" ]]; then
            read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Deseja atribuir a mesma senha para o usuário e criptografia? (s/N): " confirm
            if [[ -z "$confirm" || "$confirm" == "s" || "$confirm" == "S" ]]; then
                LUKSPASSWD="$ROOTPASSWD"
                USERPASSWD="$ROOTPASSWD"
                log_success "Senha do root, usuário e criptografia definidas com sucesso.."
                break
            else
                log_success "Senha do root definida com sucesso.."
                validate_userpasswd
                validate_luks_passwd
                break
            fi
        else
            log_error "As senhas não coincidem. Tente novamente.."
            continue
        fi
    done
}

validate_userpasswd() {
    while true; do
        log_info "Definindo senha do usuário..."
        read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite a senha do usuário '$USERNAME': " USERPASSWD
        check_exit "$USERPASSWD"
        if [[ -z "$USERPASSWD" ]]; then
            log_error "A senha do usuário não pode ser vazia. Tente novamente.."
            continue
        fi
        echo ""
        read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirme a senha do usuário: " USERPASSWD_CONFIRM
        check_exit "$USERPASSWD_CONFIRM"
        echo ""
        if [[ "$USERPASSWD" == "$USERPASSWD_CONFIRM" ]]; then
            log_success "Senha do usuário definida com sucesso.."
            break
        else
            log_error "As senhas não coincidem. Tente novamente.."
            continue
        fi
    done
}

validate_luks_passwd() {
    while true; do
        log_info "Definindo senha de criptografia..."
        read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite a senha para criptografia LUKS: " LUKSPASSWD
        check_exit "$LUKSPASSWD"
        if [[ -z "$LUKSPASSWD" ]]; then
            log_error "A senha LUKS não pode ser vazia. Tente novamente.."
            continue
        fi
        echo ""
        read -sp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirme a senha LUKS: " LUKSPASSWD_CONFIRM
        check_exit "$LUKSPASSWD_CONFIRM"
        echo ""
        if [[ "$LUKSPASSWD" == "$LUKSPASSWD_CONFIRM" ]]; then
            log_success "Senha LUKS definida com sucesso.."
            break
        else
            log_error "As senhas não coincidem. Tente novamente.."
            continue
        fi
    done
}

validate_overview () {
    show_header "CONFIRME AS INFORMAÇÕES"
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
    read -p $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirma as configurações e deseja prosseguir? (s/N): " final_confirm
    if [[ -n "$final_confirm" && "$final_confirm" != "s" && "$final_confirm" != "S" ]]; then
        log_warning "Instalação cancelada pelo usuário.."
        echo ""
        read -p "Pressione qualquer tecla para encerrar.."
        exit 1
    fi
    timedatectl set-ntp true
    timedatectl set-timezone $TIMEZONE
    DATE1=$(date +"%Y-%m-%d %H:%M:%S")
    log_info "Exportando variáveis.."
cat <<EOF > $SCRIPT_DIR/vars.sh
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
    chmod +x $SCRIPT_DIR/vars.sh
    log_success "Variáveis exportadas para 'vars.sh' com sucesso.."
    log_success "Informações confirmadas. Iniciando instalação..."
}

