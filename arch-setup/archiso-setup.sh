#!/bin/bash
# archiso-setup.sh - Instalação automatizada do Arch Linux via Arch ISO

CONTINUE_ON_ERROR=false
[[ "$1" == "--continue-on-error" ]] && CONTINUE_ON_ERROR=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOUNTPOINT="/mnt"

download_scripts() {
    LINKS="https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch-setup/links.sh"
    curl -LO $LINKS
    chmod +x $SCRIPT_DIR/links.sh
    source $SCRIPT_DIR/links.sh

    curl -LO $LINKLOGS
    chmod +x $SCRIPT_DIR/logs.sh
    source $SCRIPT_DIR/logs.sh

    curl -LO $LINKVALIDATIONS
    chmod +x $SCRIPT_DIR/validations.sh
    source $SCRIPT_DIR/validations.sh

    curl -LO $LINKCHROOT
    chmod +x /root/chroot-setup.sh

    curl -LO $LINKFIRSTINIT
    chmod +x /root/first-init.sh
}

service_start() {
    log_info "Iniciando coleta de dados..."
    show_header "ETAPA 1 - COLETA DE DADOS"
    validate_kblayout
    validate_timezone
    validate_language
    validate_pcname
    validate_username
    validate_rootpasswd
    validate_diskname
    validate_overview

    log_info "Atualizando Arch ISO.."
    pacman -Syy --noconfirm
}

service_disk() {
    log_info "Verificando tipo do disco.."
    if [[ $(cat /sys/block/$(basename "$DISK")/queue/rotational) -eq 0 ]]; then
        ssdIfSsd=",ssd"
    else
        ssdIfSsd=""
    fi
    log_info "Criando tabela GPT e partições.."
    sgdisk --zap-all $DISK
    sgdisk -n 1:0:+1024M -t 1:EF00 $DISK
    sgdisk -n 2:0:0 -t 2:8300 $DISK
    log_success "Partições '$DISKNAME1' e '$DISKNAME2' criadas com sucesso.."
    log_info "Configurando criptografia LUKS na partição Linux.."
    echo -n "$LUKSPASSWD" > /tmp/keyfile
    chmod 600 /tmp/keyfile
    cryptsetup luksFormat "$DISKNAME2" --batch-mode --key-file=/tmp/keyfile
    cryptsetup luksOpen "$DISKNAME2" main --key-file=/tmp/keyfile
    rm -f /tmp/keyfile
    log_success "Partição '$DISKNAME2' criptografada com sucesso.."
    log_info "Formatando partição '$DISKNAME2' como Btrfs.."
    mkfs.btrfs /dev/mapper/main
    log_success "Partição '$DISKNAME2' formatada com sucesso.."
    log_info "Criando subvolumes Btrfs.."
    mount /dev/mapper/main $MOUNTPOINT
    cd $MOUNTPOINT
    btrfs subvolume create @
    btrfs subvolume create @home
    btrfs subvolume create @snapshots
    btrfs subvolume list $MOUNTPOINT
    cd
    umount $MOUNTPOINT
    log_success "Subvolumes Btrfs criados com sucesso.."
    log_info "Montando subvolumes.."
    mount -o noatime$ssdIfSsd,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/mapper/main $MOUNTPOINT
    mkdir $MOUNTPOINT/home
    mount -o noatime$ssdIfSsd,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/mapper/main $MOUNTPOINT/home
    mkdir $MOUNTPOINT/.snapshots
    mount -o noatime$ssdIfSsd,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/main $MOUNTPOINT/.snapshots
    findmnt -t btrfs
    log_success "Subvolumes montados com sucesso.."
    log_info "Montando partição de boot.."
    mkfs.fat -F32 $DISKNAME1
    mkdir $MOUNTPOINT/boot
    mount $DISKNAME1 $MOUNTPOINT/boot
    log_success "Boot montado com sucesso.."
    log_info "Iniciando preparação de disco..."
    show_header "ETAPA 3 - EXECUTANDO BOOTSTRAP"
    log_info "Instalando pacotes base.."
    pacstrap $MOUNTPOINT base linux linux-headers linux-firmware nano btrfs-progs grub efibootmgr --noconfirm
    log_success "Pacotes instalados com sucesso.."
    log_info "Gerando fstab.."
    genfstab -U -p $MOUNTPOINT > $MOUNTPOINT/etc/fstab
    log_success "fstab gerado com sucesso.."
}

prepare_chroot() {
    log_info "Preparando scripts.."
    mv /root/chroot-setup.sh $MOUNTPOINT/chroot-setup.sh
    cp /root/logs.sh $MOUNTPOINT/logs.sh
    cp /root/links.sh $MOUNTPOINT/links.sh
    cp /root/vars.sh $MOUNTPOINT/vars.sh
    log_success "Scripts gerados com sucesso.."
    arch-chroot $MOUNTPOINT /bin/bash -c "/chroot-setup.sh"
}

clean_root_dir() {
    rm $SCRIPT_DIR/links.sh
    rm $SCRIPT_DIR/logs.sh
    rm $SCRIPT_DIR/validations.sh
    rm $SCRIPT_DIR/vars.sh
    rm $MOUNTPOINT/chroot-setup.sh
    rm $MOUNTPOINT/vars.sh
    rm $MOUNTPOINT/logs.sh
    rm $MOUNTPOINT/links.sh
}

set -euo pipefail

show_header "INICIANDO INSTALAÇÃO DO ARCH LINUX"
run download_scripts
run validate_internet
run validate_scripts

cd
show_header "nk-dots - ARCH LINUX BTRFS"
run service_start

show_header "ETAPA 2 - PREPARANDO DISCO BTRFS"
run service_disk

show_header "ETAPA 3 - ENTRANDO EM CHROOT"
run prepare_chroot

show_header "INSTALAÇÃO DO ARCH LINUX FINALZIADA"
run clean_root_dir
run reboot
