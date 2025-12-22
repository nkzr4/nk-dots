#!/bin/bash
# validations.sh

DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$DIR/handler.sh"

get_config_settings() {
    show_header "CONFIGURAÇÕES PESSOAIS"
    run set_timezone
    run set_kblayout
    run set_locale
    run set_pcname
    run set_username
    run set_rootpasswd
    run set_global_password
    run set_userpasswd
    run set_lukspasswd
    run set_diskname
    run set_dualboot
    run set_overview
}

set_timezone() {
    while :; do
        read_input "Defina o timezone (padrão: America/Recife):" TIMEZONE
        [[ -z "$TIMEZONE" ]] && TIMEZONE="America/Recife"
        if timedatectl list-timezones | grep -qxi "$TIMEZONE"; then
            break
        fi
        log_error "Fuso horário '$TIMEZONE' inválido"
    done
    timedatectl set-ntp true
    timedatectl set-timezone $TIMEZONE
    START_DATE=$(date +"%Y-%m-%d %H:%M:%S")
    log_success "Fuso horário '$TIMEZONE' definido"
}

set_kblayout() {
    while :; do
        read_input "Defina o layout de teclado (padrão: br-abnt2):" KBLAYOUT
        [[ -z "$KBLAYOUT" ]] && KBLAYOUT="br-abnt2"
        if localectl list-keymaps | grep -qxi "$KBLAYOUT"; then
            break
        fi
        log_error "Layout '$KBLAYOUT' inválido"
    done
    log_success "Layout '$KBLAYOUT' definido"
}

set_locale() {
    # VALID_LOCALES=$(awk '!/^[[:space:]]*$/ {print $1}' /etc/locale.gen | sed 's/^#//')
    while :; do
        read_input "Defina o idioma (padrão: en_US.UTF-8):" LOCALE
        [[ -z "$LOCALE" ]] && LOCALE="en_US.UTF-8"
        if awk '!/^[[:space:]]*$/ {print $1}' /etc/locale.gen | sed 's/^#//' | grep -qxi "$LOCALE"; then
            break
        fi
        log_error "Idioma'$LOCALE' inválido"
    done
    log_success "Idioma '$LOCALE' definido"
}

set_pcname() {
    while :; do
        read_input "Defina o nome do computador (padrão: nk-arch):" PCNAME
        [[ -z "$PCNAME" ]] && PCNAME="nk-arch"
        if [[ "$PCNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
            break
        fi
        log_error "Nome '$PCNAME' inválido"
    done
    log_success "Hostname '$PCNAME' definido"
}

set_username() {
    while :; do
        read_input "Defina o nome do usuário (padrão: nkzr4):" USERNAME
        [[ -z "$USERNAME" ]] && USERNAME="nkzr4"
        if [[ "$USERNAME" =~ ^[a-z_]([a-z0-9_-]{0,31})$ ]]; then
            break
        fi
        log_error "Nome '$USERNAME' inválido"
    done
    log_success "Nome de usuário '$USERNAME' definido"
}

set_rootpasswd() {
    while :; do
        read_password "Defina a senha para o root" ROOTPASSWD
        if [[ -n "$ROOTPASSWD" ]]; then
            read_password "Digite a senha novamente" ROOTPASSWD_CONFIRM
            if [[ "$ROOTPASSWD" == "$ROOTPASSWD_CONFIRM" ]]; then
                set_passwd "ROOTPASSWD"
                log_success "Senha do root definida"
                break
            else
                log_error "Senhas não conferem"
            fi
        else
            log_error "Senha não pode ser vazia"
        fi
    done
}

set_global_password() {
    GLOBALPASSWD="false"
    read_input "Deseja a mesma senha para '$USERNAME' e criptografia de disco? (s/N)" GLOBAL_CONFIRM
    if [[ -z "$GLOBAL_CONFIRM" || "${GLOBAL_CONFIRM,,}" == "s" ]]; then
        USERPASSWD="$ROOTPASSWD"
        set_passwd "USERPASSWD"
        LUKSPASSWD="$ROOTPASSWD"
        set_passwd "LUKSPASSWD"
        GLOBALPASSWD="true"
        log_success "Senha global definida"        
    fi
}

set_userpasswd() {
    if [[ "$GLOBALPASSWD" != "true" ]]; then
        while :; do
            read_password "Defina a senha para '$USERNAME'" USERPASSWD
            if [[ -n "$USERPASSWD" ]]; then
                read_password "Digite a senha novamente" USERPASSWD_CONFIRM
                if [[ "$USERPASSWD" == "$USERPASSWD_CONFIRM" ]]; then
                    set_passwd "USERPASSWD"
                    log_success "Senha de '$USERNAME' definida"
                    break
                else
                    log_error "Senhas não conferem"
                fi
            else
                log_error "Senha não pode ser vazia"
            fi
        done
    fi
}

set_lukspasswd() {
    if [[ "$GLOBALPASSWD" != "true" ]]; then
        while :; do
            read_password "Defina a senha de criptografia" LUKSPASSWD
            if [[ -n "$LUKSPASSWD" ]]; then
                read_password "Digite a senha novamente" LUKSPASSWD_CONFIRM
                if [[ "$LUKSPASSWD" == "$LUKSPASSWD_CONFIRM" ]]; then
                    set_passwd "LUKSPASSWD"
                    log_success "Senha de criptografia definida"
                    break
                else
                    log_error "Senhas não conferem"
                fi
            else
                log_error "Senha não pode ser vazia"
            fi
        done
    fi
}

set_diskname() {
    while :; do
        echo
        lsblk -d -o NAME,SIZE,TYPE,MODEL
        echo
        read_input "Defina o disco que receberá a instalação (ex: sda, nvme0n1):" DISK_BASENAME
        if lsblk -dn -o NAME | grep -qxi "$DISK_BASENAME"; then
            read_input "Confirma o uso do disco /dev/$DISK_BASENAME? (digite 'SIM' em caixa alta): " DISK_CONFIRM
            if [[ "$DISK_CONFIRM" == "SIM" ]]; then
                DISK="/dev/$DISK_BASENAME"
                break
            fi
        fi
        log_error "Disco inválido"
    done
    log_success "Disco '/dev/$DISK_BASENAME' definido"
}

set_dualboot() {
    DUAL_BOOT="false"
    read_input "Deseja instalar em dual boot? (s/N): " DUAL_CONFIRM
    if [[ -z "$DUAL_CONFIRM" || "${DUAL_CONFIRM,,}" == "s" ]]; then
        DUAL_BOOT="true"
    fi
}

set_overview() {
    show_header "CONFIRME AS CONFIGURAÇÕES"
    log_info "Resumo das configurações:"
    echo
    echo "  Layout do teclado: $KBLAYOUT"
    echo "  Timezone: $TIMEZONE"
    echo "  Disco: /dev/$DISK_BASENAME"
    echo "  Locale: $LOCALE"
    echo "  Hostname: $PCNAME"
    echo "  Usuário: $USERNAME"
    echo "  Dual Boot: $DUAL_BOOT"
    echo
    read_input "Confirma e deseja prosseguir? (s/N):" FINAL_CONFIRM
    if [[ -z "$FINAL_CONFIRM" || "${FINAL_CONFIRM,,}" == "s" ]]; then
        set_configs
    else
        call_validations
    fi
}

set_passwd() {
    local VAR="$1"
    local FIFO="/tmp/$VAR.pass"
    [[ -p "$FIFO" ]] || mkfifo "$FIFO"
    chmod 600 "$FIFO"
    {
        printf '%s\n' "${!VAR}"
        unset "$VAR"
    } > "$FIFO" &

}

set_configs() {
cat <<EOF > $DIR/vars.sh
VAR_TIMEZONE="$TIMEZONE"
VAR_KBLAYOUT="$KBLAYOUT"
VAR_LOCALE="$LOCALE"
VAR_PCNAME="$PCNAME"
VAR_USERNAME="$USERNAME"
VAR_GLOBALPASSWD="$GLOBALPASSWD"
VAR_DISK_BASENAME="$DISK_BASENAME"
VAR_DISK="$DISK"
VAR_DUAL_BOOT="$DUAL_BOOT"
VAR_EFI_PARTITION="EFI_PLACEHLDR"
VAR_LINUX_PARTITION="LINUX_PLACEHLDR"
EOF
}