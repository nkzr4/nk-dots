#!/bin/bash
# auto_mount.sh - Montar drivers automáticamente

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISKFILE="$DIR/disks.sh"
source $DIR/logs.sh
source $DIR/handler.sh

SILENT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --silent)
            SILENT=true
            shift
            ;;
        *)
            echo "Opção desconhecida: $1"
            exit 1
            ;;
    esac
done





check_disk_file() {
    EXIST=false
    if [[ ! -f "$DISKFILE" ]]; then
        EXIST=true
    fi
    if [[ "$EXIST" == true ]]; then
        read -rp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Deseja iniciar uma nova configuração? (s/N): " CONFIRMCONFIG
        if [[ -z "$CONFIRMCONFIG" || "$CONFIRMCONFIG" =~ ^[sS]$ ]]; then
            > $DISKFILE
        fi
    else
    touch "$DISKFILE"
    fi
}

add_disks() {
    check_disk_file
    while true; do
        LINES=$(wc -l < "$DISKFILE")
        if [[ "$LINES" != 0 ]]; then
            read -rp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Deseja registrar um novo disco? (s/N): " DISKADD
            if [[ -z "$DISKADD" || "$DISKADD" =~ ^[sS]$ ]]; then
                (( i = LINES / 2 + 1 ))
            else
                (( i = LINES / 2 ))
                break
            fi
        fi
        (( i = LINES / 2 + 1 ))
        log_info "Exibindo discos conectados"
        lsblk
        while true; do
            read -rp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite o nome do disco (ex: sda1, nvme0n1p1): " DISKNAME
            if lsblk -n -r -o NAME,TYPE | awk '$2=="part"{print $1}' | grep -qx "$DISKNAME"; then
                if grep -qF "$DISKNAME" disks.sh; then
                    log_warning "Disco já cadastrado"
                    continue
                else
                    read -rp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Confirma o disco '$DISKNAME'? (s/N): " CONFIRMDISK
                    if [[ -z "$CONFIRMDISK" || "$CONFIRMDISK" =~ ^[sS]$ ]]; then
                        log_success "Disco '$DISKNAME' definido"
                        break
                    else
                        read -rp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Deseja finalizar o script? (s/N):" ENDSCRIPT
                        if [[ -z "$ENDSCRIPT" || "$ENDSCRIPT" =~ ^[sS]$ ]]; then
                            log_warning "Script finalizado"
                            sleep 2
                            exit
                        fi
                    fi
                fi
            else
                log_error "Disco '$DISKNAME' não encontrado"
                read -rp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Deseja finalizar o script? (s/N):" ENDSCRIPT
                if [[ -z "$ENDSCRIPT" || "$ENDSCRIPT" =~ ^[sS]$ ]]; then
                    log_warning "Script finalizado"
                    sleep 2
                    exit
                else
                    continue
                fi
            fi
            continue
        done
        read -rp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - Digite a label do disco: " DISKLABEL
        log_info "Registrando disco"
        echo "DISK${i}=\"/dev/${DISKNAME}\"" >> "$DISKFILE"
        echo "DISKNAME${i}=\"${DISKLABEL}\"" >> "$DISKFILE"
        log_success "Disco '$DISKNAME' registrado como '$DISKLABEL'"
        continue
    done

}

mount_disks() {
    while true; do
        source $DIR/disks.sh
        if [[ "$i" == 0 ]]; then
            log_warning "Script finalizado"
            sleep 2
            break
        else
            DISK_VAR="DISK${i}"
            DISKNAME_VAR="DISKNAME${i}"
            DISKX="${!DISK_VAR}"
            DISKNAMEX="${!DISKNAME_VAR}"
            if mountpoint -q "/mnt/$DISKNAMEX"; then
                sudo umount "/mnt/$DISKNAMEX"
            fi
            log_info "Criando diretório de '$DISKX'"
            sudo mkdir -p "/mnt/$DISKNAMEX"
            log_info "Montando '$DISKX'"
            [ -b $DISKX ] && sudo mount $DISKX /mnt/$DISKNAMEX
            log_success "'$DISKX' montado em '/mnt/$DISKNAMEX'"
            log_info "Criando symlink"
            [ -L "$HOME/$DISKNAMEX" ] && rm -rf $HOME/$DISKNAMEX && ln -s /mnt/$DISKNAMEX $HOME/$DISKNAMEX || ln -s /mnt/$DISKNAMEX $HOME/$DISKNAMEX
            log_success "'$DISKX' cadastrado"
            i=$((i - 1))
            continue
        fi
    done
}

if [[ "$SILENT" == false ]]; then
    show_header "REGISTRAR DISCOS"
    run add_disks
else
    LINES=$(wc -l < "$DISKFILE")
    (( i = LINES / 2 ))
fi

show_header "MONTAGEM AUTOMÁTICA"
run mount_disks