#!/bin/bash
# disk.sh

DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$DIR/handler.sh"

config_disk() {
    show_header "INSTALAÇÃO DO SISTEMA"
    source "$DIR/vars.sh"
    run set_partitions
    run set_cryptsetup
    run set_btrfs_volumes
    run set_mounts
    run download_pacstrap
}

get_efi_partition() {
    lsblk -lpno NAME,PARTTYPE "$VAR_DISK" | awk '$2=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"{print $1; exit}'
}

get_linux_partition() {
    lsblk -lpno NAME,PARTTYPE "$VAR_DISK" | awk '$2=="0fc63daf-8483-4772-8e79-3d69d8477de4"{print $1}' | tail -n1
}

check_if_ssd() {
    IF_SSD=""
    if [[ $(cat /sys/block/$(basename "$VAR_DISK")/queue/rotational) -eq 0 ]]; then
        IF_SSD=",ssd"
    else
        IF_SSD=""
    fi
}

set_partitions() {
    log_info "Preparando partições"
    if [[ $VAR_DUAL_BOOT == "false" ]]; then
        sgdisk --zap-all $VAR_DISK
        sgdisk -n 1:0:+1024M -t 1:EF00 $VAR_DISK
        sgdisk -n 2:0:0 -t 2:8300 $VAR_DISK
    else
        sgdisk -n 0:0:0 -t 0:8300 "$VAR_DISK"
    fi
    partprobe "$VAR_DISK"
    sleep 1
    EFI_PARTITION="$(get_efi_partition)"
    LINUX_PARTITION="$(get_linux_partition)"
    [[ -b "$EFI_PARTITION" ]] || fatal "Partição EFI não encontrada"
    [[ -b "$LINUX_PARTITION" ]] || fatal "Partição Linux não encontrada"
    sed -i "s|EFI_PLACEHLDR|$EFI_PARTITION|g" "$DIR/vars.sh"
    sed -i "s|LINUX_PLACEHLDR|$LINUX_PARTITION|g" "$DIR/vars.sh"
    log_success "Partições preparadas"
}

set_cryptsetup() {
    log_info "Configurando criptografia"
    command -v cryptsetup >/dev/null || fatal "cryptsetup não disponível"
    read -r LUKSPASSWD < /tmp/LUKSPASSWD.pass
    rm -f /tmp/LUKSPASSWD.pass
    [[ -n "$LUKSPASSWD" ]] || fatal "Senha LUKS vazia"
    printf '%s' "$LUKSPASSWD" | cryptsetup luksFormat "$LINUX_PARTITION" --batch-mode - || fatal "Falha ao formatar LUKS"
    printf '%s' "$LUKSPASSWD" | cryptsetup luksOpen "$LINUX_PARTITION" main - || fatal "Falha ao abrir volume LUKS"
    [[ -b /dev/mapper/main ]] || fatal "Mapper LUKS não foi criado"
    unset LUKSPASSWD
    log_success "Partição criptografada"
}

set_btrfs_volumes() {
    log_info "Preparando subvolumes Btrfs"
    mountpoint -q /mnt && fatal "/mnt já está montado"
    mkfs.btrfs -f /dev/mapper/main || fatal "Falha ao formatar Btrfs"
    mount /dev/mapper/main /mnt || fatal "Falha ao montar Btrfs em /mnt"
    btrfs subvolume create /mnt/@ || fatal "Falha ao criar @"
    btrfs subvolume create /mnt/@home || fatal "Falha ao criar @home"
    btrfs subvolume create /mnt/@log || fatal "Falha ao criar @log"
    btrfs subvolume create /mnt/@pkg || fatal "Falha ao criar @pkg"
    btrfs subvolume create /mnt/@snapshots || fatal "Falha ao criar @snapshots"
    btrfs subvolume list /mnt | grep -q "@home" || fatal "Subvolumes não detectados corretamente"
    umount /mnt || fatal "Falha ao desmontar /mnt"
    log_success "Subvolumes criados"
}

set_mounts() {
    log_info "Montando partições"
    check_if_ssd
    mount -o noatime$IF_SSD,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/mapper/main /mnt || fatal "Falha ao montar subvolume @"
    mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}
    mount -o noatime$IF_SSD,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/mapper/main /mnt/home || fatal "Falha ao montar @home"
    mount -o noatime$IF_SSD,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/main /mnt/var/log || fatal "Falha ao montar @log"
    mount -o noatime$IF_SSD,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/main /mnt/var/cache/pacman/pkg || fatal "Falha ao montar @pkg"
    mount -o noatime$IF_SSD,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/main /mnt/.snapshots || fatal "Falha ao montar @snapshots"
    mkfs.fat -F32 "$EFI_PARTITION" || fatal "Falha ao formatar EFI"
    mount "$EFI_PARTITION" /mnt/boot || fatal "Falha ao montar EFI"
    mountpoint -q /mnt/boot || fatal "EFI não montada corretamente"
    log_success "Partições montadas"
}

download_pacstrap() {
    log_info "Criando sistema raiz"
    command -v pacstrap >/dev/null || fatal "pacstrap indisponível"
    pacstrap /mnt base linux linux-headers linux-firmware nano btrfs-progs grub efibootmgr --noconfirm || fatal "Falha no pacstrap"
    genfstab -U /mnt > /mnt/etc/fstab || fatal "Falha ao gerar fstab"
    [[ -s /mnt/etc/fstab ]] || fatal "fstab gerado está vazio"
    log_success "Bootstrap concluído"
}