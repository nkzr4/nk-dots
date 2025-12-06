#!/bin/bash
# archiso-setup.sh - Instalação automatizada do Arch Linux via Arch ISO

# Todo
# Arrumar automatização de senha do luksFormat e luksOpen

CONTINUE_ON_ERROR=false
[[ "$1" == "--continue-on-error" ]] && CONTINUE_ON_ERROR=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LINKS="https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/nkzr4-arch-setup/arch-install/links.sh"
curl -LO $LINKS
chmod +x $SCRIPT_DIR/links.sh
source $SCRIPT_DIR/links.sh

curl -LO $LINKLOGS
chmod +x $SCRIPT_DIR/logs.sh
source $SCRIPT_DIR/logs.sh

run curl -LO $LINKVALIDATIONS
run chmod +x $SCRIPT_DIR/validations.sh
source $SCRIPT_DIR/validations.sh

run curl -LO $LINKCHROOT
run chmod +x /root/chroot-setup.sh
run cp /root/chroot-setup.sh /mnt/chroot-setup.sh

set -euo pipefail

service_start() {
    validate_internet

    log_info "Iniciando coleta de dados..."
    show_header "ETAPA 1 - COLETA DE DADOS"
    run validate_kblayout
    run validate_timezone
    run validate_diskname
    run validate_language
    run validate_pcname
    run validate_username
    run validate_rootpasswd
    run validate_userpasswd
    run validate_luks_passwd
    run validate_overview

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
    run sgdisk --zap-all $DISK
    run sgdisk -n 1:0:+1024M -t 1:EF00 $DISK
    run sgdisk -n 2:0:0 -t 2:8300 $DISK
    log_success "Partições '$DISKNAME1' e '$DISKNAME2' criadas com sucesso.."
    log_info "Configurando criptografia LUKS na partição Linux.."
    run printf "YES\n%s\n%s\n" "$LUKSPASSWD" "$LUKSPASSWD" | cryptsetup luksFormat "$DISKNAME2"
    run printf "%s\n" "$LUKSPASSWD" | cryptsetup luksOpen "$DISKNAME2" main
    log_success "Partição '$DISKNAME2' criptografada com sucesso.."
    log_info "Formatando partição '$DISKNAME2' como Btrfs.."
    run mkfs.btrfs /dev/mapper/main
    log_success "Partição '$DISKNAME2' formatada com sucesso.."
    log_info "Criando subvolumes Btrfs.."
    run mount /dev/mapper/main /mnt
    run cd /mnt
    run btrfs subvolume create @
    run btrfs subvolume create @home
    run btrfs subvolume create @snapshots
    run btrfs subvolume list /mnt
    cd
    run umount /mnt
    log_success "Subvolumes Btrfs criados com sucesso.."
    log_info "Montando subvolumes.."
    run mount -o noatime$ssdIfSsd,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/mapper/main /mnt
    run mkdir /mnt/home
    run mount -o noatime$ssdIfSsd,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/mapper/main /mnt/home
    run mkdir /mnt/.snapshots
    run mount -o noatime$ssdIfSsd,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/main /mnt/.snapshots
    run findmnt -t btrfs
    log_success "Subvolumes montados com sucesso.."
    log_info "Montando partição de boot.."
    run mkfs.fat -F32 $DISKNAME1
    run mkdir /mnt/boot
    run mount $DISKNAME1 /mnt/boot
    log_success "Boot montado com sucesso.."
    log_info "Iniciando preparação de disco..."
    show_header "ETAPA 3 - EXECUTANDO BOOTSTRAP"
    log_info "Instalando pacotes base.."
    run pacstrap /mnt base linux linux-headers linux-firmware nano btrfs-progs grub efibootmgr --noconfirm
    log_success "Pacotes instalados com sucesso.."
    log_info "Gerando fstab.."
    run genfstab -U -p /mnt > /mnt/etc/fstab
    log_success "fstab gerado com sucesso.."
}

cd
show_header "nk-dots - ARCH LINUX BTRFS"
run service_start

show_header "ETAPA 2 - PREPARANDO DISCO BTRFS"
run service_disk

show_header "ETAPA 3 - ENTRANDO EM CHROOT"
log_info "Preparando scripts.."
run mv /root/chroot-setup.sh /mnt/chroot-setup.sh
run cp /root/logs.sh /mnt/logs.sh
run cp /root/links.sh /mnt/links.sh
log_success "Scripts gerados com sucesso.."
echo ""
read -p "Pressione qualquer tecla para continuar.."
echo ""
run arch-chroot /mnt /bin/bash -c "/chroot-setup.sh"

show_header "INSTALAÇÃO DO ARCH LINUX FINALZIADA"
log_info "Removendo resquícios da instalação.."
run rm $SCRIPT_DIR/links.sh
run rm $SCRIPT_DIR/logs.sh
run rm $SCRIPT_DIR/validations.sh
run rm /mnt/chroot-setup.sh
log_success "Removendo resquícios da instalação.."
echo ""
read -n1 -rsp "Pressione qualquer tecla para reiniciar..."
run reboot
