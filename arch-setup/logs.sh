#!/bin/bash
# logs.sh 

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="$LOG_DIR/$(date '+%Y-%m-%d')-$(date '+%H%M%S').log"
fi

trap 'pause_on_error $? "$BASH_COMMAND" "$LINENO"' ERR

_write_log_file() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

log_info() {
    echo -e "\e[0m[\e[1;34m  INFO  \e[0m] $(date '+%H:%M:%S') - $1"
    _write_log_file "INFO    - $1"
    sleep 0.4
}

log_success() {
    echo -e "\e[0m[\e[1;32m SUCESS \e[0m] $(date '+%H:%M:%S') - $1"
    _write_log_file "SUCCESS - $1"
    sleep 0.4
}

log_warning() {
    echo -e "\e[0m[\e[1;33m ALERTA \e[0m] $(date '+%H:%M:%S') - $1"
    _write_log_file "WARNING - $1"
    sleep 0.4
}

log_error() {
    echo -e "\e[0m[\e[1;31m  ERRO  \e[0m] $(date '+%H:%M:%S') - $1"
    _write_log_file "ERROR   - $1"
    sleep 0.4
}

show_header() {
    local title="$1"
    local width=72
    local inner_width=$((width - 2))
    local title_len=${#title}
    local total_spaces=$((inner_width - title_len))
    local left_spaces=$(( total_spaces / 2 ))
    local right_spaces=$(( total_spaces - left_spaces ))

    clear
    echo "╭──────────────────────────────────────────────────────────────────────╮"
    printf "│%*s%s%*s│\n" "$left_spaces" "" "$title" "$right_spaces" ""
    echo "╰──────────────────────────────────────────────────────────────────────╯"
    echo ""
}

pause_on_error() {
    local exit_code="$1"
    local cmd="$2"
    local line="$3"

    echo "────────────────────────────────────────────────────────────────────────"
    log_error "Ocorreu um erro na execução do script:"
    log_info "Comando: $cmd"
    log_info "Código:  $exit_code"
    log_info "Linha:   $line"

    {
        echo "────────────────────────────────────────────────────────────────────────"
        echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Script: $0"
        echo "PWD: $PWD"
        echo "Comando com falha: $cmd"
        echo "Código de saída:   $exit_code"
        echo "Linha do erro:     $line"
        echo "────────────────────────────────────────────────────────────────────────"
    } >> "$LOG_FILE"

    log_warning "O erro foi registrado em: $LOG_FILE"

    if [[ "$CONTINUE_ON_ERROR" == true ]]; then
        read -p "Pressione qualquer tecla para continuar.."
        echo ""
        return 0
    else
        log_info "Encerrando execução."
        exit 1
    fi
}

check_exit() {
    if [[ "$1" == "sair" ]] || [[ "$1" == "SAIR" ]]; then
        echo ""
        log_warning "Instalação cancelada pelo usuário.."
        echo ""
        read -p "Pressione qualquer tecla para encerrar.."
        echo ""
        exit 0
    fi
}

run() {
    local cmd=("$@")
    local cmd_str="$*"
    local line="${BASH_LINENO[0]}"

    # Executa o comando exatamente como chamado
    "${cmd[@]}"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        pause_on_error "$exit_code" "$cmd_str" "$line"
    fi
}
