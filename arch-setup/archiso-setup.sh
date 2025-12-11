#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MOUNTPOINT="/mnt"

download_links() {
    echo -e "\e[1m[\e[34m  INFO  \e[39m]\e[0m $(date '+%H:%M:%S') - Carregando links"
    curl -LO "https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch-setup/links.sh"
    if [[ ! -f "$DIR/links.sh" ]] || grep -qx "404: Not Found" "$DIR/links.sh"; then
        echo -e "\e[1m[\e[31m  ERRO  \e[39m]\e[0m $(date '+%H:%M:%S') - Arquivo 'links.sh' inválido ou inexistente"
        echo ""
        read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
        exit 1
    fi
    chmod +x $DIR/links.sh
    source $DIR/links.sh
    echo -e "\e[1m[\e[32m  SUCC  \e[39m]\e[0m $(date '+%H:%M:%S') - 'links.sh' carregado"
}

download_logs() {
    echo -e "\e[1m[\e[34m  INFO  \e[39m]\e[0m $(date '+%H:%M:%S') - Carregando 'logs.sh'"
    curl -LO $LOGSLINK
    if [[ ! -f "$DIR/logs.sh" ]] || grep -qx "404: Not Found" "$DIR/logs.sh"; then
        echo -e "\e[1m[\e[31m  ERRO  \e[39m]\e[0m $(date '+%H:%M:%S') - Arquivo 'logs.sh' inválido ou inexistente"
        echo ""
        read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
        exit 1
    fi
    chmod +x $DIR/logs.sh
    source $DIR/logs.sh
    echo -e "\e[1m[\e[32m  SUCC  \e[39m]\e[0m $(date '+%H:%M:%S') - 'logs.sh' carregado"
}

download_handler() {
    log_info "Carregando 'handler.sh'"
    curl -LO $HANDLERLINK
    if [[ ! -f "$DIR/handler.sh" ]] || grep -qx "404: Not Found" "$DIR/handler.sh"; then
        log_error "Arquivo 'handler.sh' inválido ou inexistente"
        echo ""
        read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
        exit 1
    fi
    chmod +x $DIR/handler.sh
    source $DIR/handler.sh
    log_success "'handler.sh' carregado"
}

download_validations() {
    log_info "Carregando 'validations.sh'"
    curl -LO $VALIDATIONSLINK
    if [[ ! -f "$DIR/validations.sh" ]] || grep -qx "404: Not Found" "$DIR/validations.sh"; then
        log_error "Arquivo 'validations.sh' inválido ou inexistente"
        echo ""
        read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
        exit 1
    fi
    chmod +x $DIR/validations.sh
    source $DIR/validations.sh
    log_success "'validations.sh' carregado"
}

download_chroot_setup() {
    log_info "Carregando 'chroot-setup.sh'"
    curl -LO $CHROOTSETUPLINK
    if [[ ! -f "$DIR/chroot-setup.sh" ]] || grep -qx "404: Not Found" "$DIR/chroot-setup.sh"; then
        log_error "Arquivo 'chroot-setup.sh' inválido ou inexistente"
        echo ""
        read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
        exit 1
    fi
    chmod +x $DIR/chroot-setup.sh
    log_success "'chroot-setup.sh' carregado"
}

initiate() {
    echo -e "\e[1m[\e[34m  INFO  \e[39m]\e[0m $(date '+%H:%M:%S') - Inicializando script de instalação"
    download_links
    echo -e "\e[1m[\e[34m  INFO  \e[39m]\e[0m $(date '+%H:%M:%S') - Obtendo dependências iniciais"
    download_logs
    download_handler
    run log_info "Obtendo scripts complementares"
    run download_validations
    run download_chroot_setup
    run log_info "Iniciando script.."
    run sleep 5
}

get_input_info() {
    run log_info "Iniciando coleta de dados"
    run validate_kblayout
    run validate_timezone
    run validate_language
    run validate_pcname
    run validate_username
    run validate_rootpasswd
    run validate_diskname
}

setup_disk() {
    if [[ $(cat /sys/block/$(basename "$DISK")/queue/rotational) -eq 0 ]]; then
        SSDIFSSD=",ssd"
    else
        SSDIFSSD=""
    fi
    log_info "Criando partições"
    sgdisk --zap-all $DISK
    sgdisk -n 1:0:+1024M -t 1:EF00 $DISK
    sgdisk -n 2:0:0 -t 2:8300 $DISK
    log_success "Partições '$DISKNAME1' e '$DISKNAME2' criadas com sucesso.."
    log_info "Configurando criptografia de '$DISKNAME2'"
    echo -n "$LUKSPASSWD" > /tmp/keyfile
    chmod 600 /tmp/keyfile
    cryptsetup luksFormat "$DISKNAME2" --batch-mode --key-file=/tmp/keyfile
    cryptsetup luksOpen "$DISKNAME2" main --key-file=/tmp/keyfile
    rm -f /tmp/keyfile
    log_success "Partição '$DISKNAME2' criptografada"
    log_info "Definindo '$DISKNAME2' como Btrfs.."
    mkfs.btrfs /dev/mapper/main
    log_success "'$DISKNAME2' definido como Btrfs"
    log_info "Criando subvolumes Btrfs"
    mount /dev/mapper/main $MOUNTPOINT
    cd $MOUNTPOINT
    btrfs subvolume create @
    btrfs subvolume create @home
    btrfs subvolume create @snapshots
    btrfs subvolume list $MOUNTPOINT
    cd
    umount $MOUNTPOINT
    log_success "Subvolumes Btrfs criados"
    log_info "Montando subvolumes"
    mount -o noatime$SSDIFSSD,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/mapper/main $MOUNTPOINT
    mkdir $MOUNTPOINT/home
    mount -o noatime$SSDIFSSD,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/mapper/main $MOUNTPOINT/home
    mkdir $MOUNTPOINT/.snapshots
    mount -o noatime$SSDIFSSD,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/main $MOUNTPOINT/.snapshots
    findmnt -t btrfs
    log_success "Subvolumes montados"
    log_info "Definindo '$DISKNAME1' como boot"
    mkfs.fat -F32 $DISKNAME1
    log_success "'$DISKNAME1' definido como boot"
    log_info "Montando '$DISKNAME1'"
    mkdir $MOUNTPOINT/boot
    mount $DISKNAME1 $MOUNTPOINT/boot
    log_success "'$DISKNAME1' montado"
}

setup_bootsrap() {
    log_info "Inicializando sistema de arquivos raiz"
    pacstrap $MOUNTPOINT base linux linux-headers linux-firmware nano btrfs-progs grub efibootmgr --noconfirm
    log_success "Pacstrap executado"
    log_info "Exportando '/etc/fstab'"
    genfstab -U -p $MOUNTPOINT > $MOUNTPOINT/etc/fstab
    log_success "'/etc/fstab' exportado"
}

setup_chroot() {
    log_info "Preparando scripts"
    mv $DIR/chroot-setup.sh $MOUNTPOINT/chroot-setup.sh
    cp $DIR/logs.sh $MOUNTPOINT/logs.sh
    cp $DIR/handler.sh $MOUNTPOINT/handler.sh
    cp $DIR/vars.sh $MOUNTPOINT/vars.sh
    log_success "Scripts preparados para chroot"
    log_info "Entrando em chroot"
    arch-chroot $MOUNTPOINT /bin/bash -c "/chroot-setup.sh"
}

erase_scripts() {
    [ -d "$LOG_DIR" ] && rm -rf "$LOG_DIR"
    rm $DIR/links.sh
    rm $DIR/logs.sh
    rm $DIR/handler.sh
    rm $DIR/validations.sh
    rm $DIR/vars.sh
    rm $MOUNTPOINT/chroot-setup.sh
    rm $MOUNTPOINT/logs.sh
    rm $MOUNTPOINT/handler.sh
    rm $MOUNTPOINT/vars.sh
}

initiate
show_header "COLETANDO DADOS"
get_input_info

show_header "CONFIRMANDO INFORMAÇÕES"
run validate_overview
log_info "Atualizando Arch ISO"
run pacman -Syy --noconfirm

show_header "PREPARANDO DISCO BTRFS"
run setup_disk

show_header "EXECUTANDO PACSTRAP"
run setup_bootsrap

show_header "INICIANDO CHROOT"
run setup_chroot

show_header "INSTALAÇÃO FINALZIADA"
erase_scripts
echo ""
read -n 1 -s -p "Pressione qualquer tecla para reiniciar..."
reboot
