#!/bin/bash
# archiso-setup.sh - Instalação automatizada do Arch Linux via Arch ISO
# To do..
# 1. iniciar script a partir de /root
# 2. ativar numlock, se desligado
# 3. certificar que o LUKS não falhe se digitar "yes" minusculo

log_info() { echo -e "\e[1;34m[ i ]\e[0m $1"; sleep 0.5; }
log_success() { echo -e "\e[1;32m[ ✓ ]\e[0m $1"; sleep 0.5; }
log_warning() { echo -e "\e[1;33m[ ⚠ ]\e[0m $1"; sleep 0.5; }
log_error() { echo -e "\e[1;31m[ ✗ ]\e[0m $1"; sleep 0.5; }
pause_on_error() {
    echo ""
    log_error "Ocorreu um erro de execução do script"
    read -n1 -rsp "Pressione qualquer tecla para continuar..."
    clear
    exit 1
}
trap 'pause_on_error' ERR

check_exit() {
    if [[ "$1" == "sair" ]] || [[ "$1" == "SAIR" ]]; then
        log_warning "Instalação cancelada pelo usuário"
        exit 0
    fi
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
        echo ""
        log_info "Redes WiFi disponíveis:"
        local device=$(iwctl device list | awk 'NR>3 {print $2; exit}' | tr -d '[:space:]')
        
        if [[ -z "$device" ]]; then
            log_error "Nenhum dispositivo WiFi encontrado"
            exit 1
        fi
        
        iwctl station "$device" scan
        sleep 2
        iwctl station "$device" get-networks
        
        echo ""
        read -p "Digite o nome da rede WiFi (SSID): " WIFINAME
        check_exit "$WIFINAME"
        
        if [[ -z "$WIFINAME" ]]; then
            log_error "O nome da rede WiFi não pode ser vazio"
            continue
        fi
        
        read -sp "Digite a senha da rede WiFi: " WIFIPASSWD
        echo ""
        check_exit "$WIFIPASSWD"
        
        if [[ -z "$WIFIPASSWD" ]]; then
            log_error "A senha da rede WiFi não pode ser vazia"
            continue
        fi
        
        log_info "Conectando à rede '$WIFINAME'..."
        if iwctl --passphrase "$WIFIPASSWD" station "$device" connect "$WIFINAME" &>/dev/null; then
            sleep 3
            if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
                log_success "Conectado à internet com sucesso"
                break
            else
                log_error "Conexão estabelecida mas sem acesso à internet. Verifique a rede"
            fi
        else
            log_error "Falha ao conectar. Verifique o nome da rede e a senha"
        fi
    done
}

validate_kblayout() {
    while true; do
        echo ""
        log_info "Layouts de teclado disponíveis (exemplos):"
        localectl list-keymaps | head -20
        echo ""
        echo "... (use 'localectl list-keymaps' para ver todos)"
        echo ""
        read -p "Digite o layout do teclado (ex: br-abnt2, us), ou "sair" para encerrar a instalação: " KBLAYOUT
        check_exit "$KBLAYOUT"
        
        if [[ -z "$KBLAYOUT" ]]; then
            log_error "O layout do teclado não pode ser vazio"
            continue
        fi
        
        if localectl list-keymaps | grep -qx "$KBLAYOUT"; then
            log_success "Layout '$KBLAYOUT' validado com sucesso"
            break
        else
            log_error "Layout '$KBLAYOUT' não encontrado na lista de layouts disponíveis"
        fi
    done
}

validate_timezone() {
    while true; do
        echo ""
        log_info "Timezones disponíveis (exemplos para América):"
        timedatectl list-timezones | grep "America/" | head -15
        echo ""
        echo "... (use 'timedatectl list-timezones' para ver todos)"
        echo ""
        read -p "Digite o timezone (ex: America/Sao_Paulo), ou "sair" para encerrar a instalação: " TIMEZONE
        check_exit "$TIMEZONE"
        
        if [[ -z "$TIMEZONE" ]]; then
            log_error "O timezone não pode ser vazio"
            continue
        fi
        
        if timedatectl list-timezones | grep -qx "$TIMEZONE"; then
            log_success "Timezone '$TIMEZONE' validado com sucesso"
            break
        else
            log_error "Timezone '$TIMEZONE' não encontrado na lista de timezones disponíveis"
        fi
    done
}

validate_diskname() {
    while true; do
        echo ""
        log_info "Discos disponíveis no sistema:"
        lsblk -d -o NAME,SIZE,TYPE,MODEL
        echo ""
        log_warning "ATENÇÃO: O disco selecionado será completamente APAGADO!"
        read -p "Digite o nome do disco (ex: sda, nvme0n1), ou "sair" para encerrar a instalação: " DISKNAME
        check_exit "$DISKNAME"
        
        if [[ -z "$DISKNAME" ]]; then
            log_error "O nome do disco não pode ser vazio"
            continue
        fi
        
        if lsblk -d -o NAME | grep -qx "$DISKNAME"; then
            read -p "Confirma o uso do disco /dev/$DISKNAME? (s/N): " confirm
            if [[ "$confirm" == "s" ]] || [[ "$confirm" == "S" ]]; then
                log_success "Disco '/dev/$DISKNAME' selecionado"
                break
            else
                log_warning "Seleção de disco cancelada"
            fi
        else
            log_error "Disco '$DISKNAME' não encontrado"
        fi
    done
}

validate_language() {
    while true; do
        echo ""
        log_info "Linguagens disponíveis (exemplos):"
        grep "^#" /etc/locale.gen | grep -v "^#[[:space:]]*$" | head -20
        echo "... (veja /etc/locale.gen para lista completa)"
        echo ""
        read -p "Digite o locale (ex: pt_BR.UTF-8, en_US.UTF-8), ou "sair" para encerrar a instalação: " LANGUAGE
        check_exit "$LANGUAGE"
        
        if [[ -z "$LANGUAGE" ]]; then
            log_error "A linguagem não pode ser vazia"
            continue
        fi
        
        if grep -q "^#$LANGUAGE" /etc/locale.gen; then
            log_success "Locale '$LANGUAGE' validado com sucesso"
            break
        else
            log_error "Locale '$LANGUAGE' não encontrado em /etc/locale.gen"
        fi
    done
}

validate_pcname() {
    while true; do
        echo ""
        read -p "Digite o nome do computador (hostname), ou "sair" para encerrar a instalação: " PCNAME
        check_exit "$PCNAME"
        
        if [[ -z "$PCNAME" ]]; then
            log_error "O nome do computador não pode ser vazio"
            continue
        fi
        
        # Hostname válido: letras, números, hífen (não no início/fim), até 63 caracteres
        if [[ "$PCNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
            log_success "Nome do computador '$PCNAME' validado com sucesso"
            break
        else
            log_error "Nome inválido. Use apenas letras, números e hífen (não no início/fim)"
        fi
    done
}

validate_rootpasswd() {
    while true; do
        echo ""
        read -sp "Digite a senha do root, ou "sair" para encerrar a instalação: " ROOTPASSWD
        echo ""
        check_exit "$ROOTPASSWD"
        
        if [[ -z "$ROOTPASSWD" ]]; then
            log_error "A senha do root não pode ser vazia"
            continue
        fi
        
        read -sp "Confirme a senha do root: " ROOTPASSWD_CONFIRM
        echo ""
        check_exit "$ROOTPASSWD_CONFIRM"
        
        if [[ "$ROOTPASSWD" == "$ROOTPASSWD_CONFIRM" ]]; then
            log_success "Senha do root definida com sucesso"
            break
        else
            log_error "As senhas não coincidem. Tente novamente"
        fi
    done
}

validate_username() {
    while true; do
        echo ""
        read -p "Digite o nome do usuário, ou "sair" para encerrar a instalação: " USERNAME
        check_exit "$USERNAME"
        
        if [[ -z "$USERNAME" ]]; then
            log_error "O nome do usuário não pode ser vazio"
            continue
        fi
        
        # Username válido: letras minúsculas, números, underline, hífen (não no início), até 32 caracteres
        if [[ "$USERNAME" =~ ^[a-z_]([a-z0-9_-]{0,31})$ ]]; then
            log_success "Nome de usuário '$USERNAME' validado com sucesso"
            break
        else
            log_error "Nome inválido. Use letras minúsculas, números, _ e - (comece com letra ou _)"
        fi
    done
}

validate_userpasswd() {
    while true; do
        echo ""
        read -sp "Digite a senha do usuário '$USERNAME', ou "sair" para encerrar a instalação: " USERPASSWD
        echo ""
        check_exit "$USERPASSWD"
        
        if [[ -z "$USERPASSWD" ]]; then
            log_error "A senha do usuário não pode ser vazia"
            continue
        fi
        
        read -sp "Confirme a senha do usuário: " USERPASSWD_CONFIRM
        echo ""
        check_exit "$USERPASSWD_CONFIRM"
        
        if [[ "$USERPASSWD" == "$USERPASSWD_CONFIRM" ]]; then
            log_success "Senha do usuário definida com sucesso"
            break
        else
            log_error "As senhas não coincidem. Tente novamente"
        fi
    done
}

validate_chroot_script() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local chroot_script="$script_dir/root/chroot-setup.sh"
    
    echo ""
    log_info "Verificando dependências do script..."
    
    if [[ -f "$chroot_script" ]]; then
        log_success "Arquivo 'chroot-setup.sh' encontrado em: $script_dir"
        
        # Verifica se o arquivo tem permissão de execução
        if [[ -x "$chroot_script" ]]; then
            log_success "Arquivo 'chroot-setup.sh' possui permissão de execução"
        else
            log_warning "Arquivo 'chroot-setup.sh' não possui permissão de execução"
            log_info "Corrigindo permissões..."
            chmod +x "$chroot_script"
            log_success "Permissões corrigidas"
        fi
    else
        log_error "Arquivo 'chroot-setup.sh' NÃO encontrado no diretório: $script_dir"
        log_error "O arquivo 'chroot-setup.sh' deve estar no mesmo diretório deste script"
        echo ""
        log_info "Estrutura esperada:"
        echo "  $(basename "$0")"
        echo "  chroot-setup.sh  <- FALTANDO"
        echo ""
        exit 1
    fi
}

setup_luks_encryption() {
    local cryptdisk="$1"
    
    # Desabilita temporariamente o trap de erro para gerenciar tentativas
    trap - ERR
    
    # Formatação LUKS
    log_info "Configurando criptografia LUKS em $cryptdisk"
    log_warning "Você precisará definir uma senha forte para criptografar o disco"
    echo ""
    
    while true; do
        log_info "Tentativa de formatação LUKS..."
        echo ""
        
        if cryptsetup luksFormat "$cryptdisk"; then
            log_success "Disco formatado com LUKS com sucesso"
            break
        else
            echo ""
            log_error "Falha na formatação LUKS"
            read -p "Deseja tentar novamente? (s/N): " retry
            
            if [[ "$retry" != "s" ]] && [[ "$retry" != "S" ]]; then
                log_error "Instalação cancelada pelo usuário"
                exit 1
            fi
            echo ""
        fi
    done
    
    # Abertura do container LUKS
    echo ""
    log_info "Abrindo container LUKS..."
    log_warning "Digite a mesma senha que você definiu anteriormente"
    echo ""
    
    while true; do
        if cryptsetup luksOpen "$cryptdisk" main; then
            log_success "Container LUKS aberto com sucesso como '/dev/mapper/main'"
            break
        else
            echo ""
            log_error "Falha ao abrir o container LUKS"
            log_warning "Verifique se você digitou a senha correta"
            read -p "Deseja tentar novamente? (s/N): " retry
            
            if [[ "$retry" != "s" ]] && [[ "$retry" != "S" ]]; then
                log_error "Instalação cancelada pelo usuário"
                exit 1
            fi
            echo ""
        fi
    done
    
    # Reabilita o trap de erro
    trap 'pause_on_error' ERR
    
    log_success "Criptografia LUKS configurada e pronta para uso"
}

cd
clear
echo ""
echo "╭──────────────────────────────────────────────────────────────────────╮"
echo "│                      nk-dots - ARCH LINUX BTRFS                      │"
echo "╰──────────────────────────────────────────────────────────────────────╯"
echo ""

log_info "Iniciando coleta de dados..."
validate_internet
validate_kblayout
validate_timezone
validate_diskname
validate_language
validate_pcname
validate_rootpasswd
validate_username
validate_userpasswd

echo ""
echo "╭──────────────────────────────────────────────────────────────────────╮"
echo "│                        INFORMAÇÕES VALIDADAS                         │"
echo "╰──────────────────────────────────────────────────────────────────────╯"
echo ""

log_info "Resumo das configurações:"
echo "  Layout do teclado: $KBLAYOUT"
echo "  Timezone: $TIMEZONE"
[[ -n "$WIFINAME" ]] && echo "  Rede WiFi: $WIFINAME"
echo "  Disco: /dev/$DISKNAME"
echo "  Locale: $LANGUAGE"
echo "  Hostname: $PCNAME"
echo "  Usuário: $USERNAME"
echo ""
read -p "Confirma as configurações e deseja prosseguir? (s/N): " final_confirm

if [[ "$final_confirm" != "s" ]] && [[ "$final_confirm" != "S" ]]; then
    log_warning "Instalação cancelada pelo usuário"
    exit 0
fi

log_success "Configurações confirmadas. Iniciando instalação..."
echo ""

log_info "Atualizando Arch ISO.."
pacman -Syy --noconfirm
echo ""
echo "╭──────────────────────────────────────────────────────────────────────╮"
echo "│                     ETAPA 1 - PREPARAÇÃO DO DISCO                    │"
echo "╰──────────────────────────────────────────────────────────────────────╯"
echo ""

log_info "Criando tabela GPT e partições.."
DISK="/dev/$DISKNAME"
sgdisk --zap-all $DISK
sgdisk -n 1:0:+1024M -t 1:EF00 $DISK
sgdisk -n 2:0:0 -t 2:8300 $DISK
DISKNAME1="${DISK}1"
DISKNAME2="${DISK}2"
echo ""

log_info "Configurando criptografia LUKS na partição Linux.."
setup_luks_encryption "$DISKNAME2"
echo ""

log_info "Formatando partição criptografada como Btrfs.."
mkfs.btrfs /dev/mapper/main
echo ""

log_info "Criando subvolumes Btrfs.."
mount /dev/mapper/main /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @snapshots
btrfs subvolume list /mnt
cd
umount /mnt

log_info "Verificando tipo do disco.."
if [[ $(cat /sys/block/$(basename "$DISK")/queue/rotational) -eq 0 ]]; then
    ssdIfSsd=",ssd"
else
    ssdIfSsd=""
fi

log_info "Montando subvolumes.."
mount -o noatime$ssdIfSsd,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/mapper/main /mnt
mkdir /mnt/home
mount -o noatime$ssdIfSsd,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/mapper/main /mnt/home
mkdir /mnt/.snapshots
mount -o noatime$ssdIfSsd,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/main /mnt/.snapshots
findmnt -t btrfs
mkfs.fat -F32 $DISKNAME1
mkdir /mnt/boot
mount $DISKNAME1 /mnt/boot

echo ""
echo "╭──────────────────────────────────────────────────────────────────────╮"
echo "│                     ETAPA 2 - EXECUTANDO PACSTRAP                    │"
echo "╰──────────────────────────────────────────────────────────────────────╯"
echo ""

log_info "Instalando pacotes base.."
pacstrap /mnt base linux linux-headers linux-firmware nano btrfs-progs grub efibootmgr --noconfirm

log_info "Gerando fstab.."
genfstab -U -p /mnt >> /mnt/etc/fstab

log_info "Preparando script para chroot.."
curl -LO https://raw.githubusercontent.com/nkzr4/nk-dots/refs/heads/main/arch-install/chroot-setup.sh
mv /root/chroot-setup.sh /mnt/chroot-setup.sh
chmod +x /mnt/chroot-setup.sh
cat <<EOF > /mnt/vars.sh
KBLAYOUT="$KBLAYOUT"
TIMEZONE="$TIMEZONE"
WIFIPASSWD="$WIFIPASSWD"
WIFINAME="$WIFINAME"
DISKNAME="$DISKNAME"
DISK="$DISK"
DISKNAME1="$DISKNAME1"
DISKNAME2="$DISKNAME2" 
LANGUAGE="$LANGUAGE"
LANG_SHORT=$(echo "$LANGUAGE" | cut -d. -f1 | sed 's/_/-/' | tr 'A-Z' 'a-z')
PCNAME="$PCNAME"
ROOTPASSWD="$ROOTPASSWD"
USERNAME="$USERNAME"
USERPASSWD="$USERPASSWD"
DISK_LUKS_UUID="$DISK_LUKS_UUID"
EOF

log_info "Entrando em chroot.."
arch-chroot /mnt /bin/bash -c "/chroot-setup.sh"

echo ""
echo "╭──────────────────────────────────────────────────────────────────────╮"
echo "│                  INSTALAÇÃO DO ARCH LINUX FINALIZADA                 │"
echo "╰──────────────────────────────────────────────────────────────────────╯"
echo ""
read -n1 -rsp "Pressione qualquer tecla para reiniciar..."
reboot
