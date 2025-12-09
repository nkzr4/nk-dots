#!/bin/bash
# handler.sh - Sistema de logs e tratamento de erros para Bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

SCRIPT_NAME="${0##*/}"
SCRIPT_NAME="${SCRIPT_NAME%.sh}"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}_$(date +%Y%m%d_%H%M%S).log"

if ! touch "$LOG_FILE" 2>/dev/null; then
    LOG_FILE="/dev/null"
    echo "AVISO: Não foi possível criar arquivo de log. Logs serão exibidos apenas no terminal." >&2
fi

RESET="\e[0m"
BOLD="\e[1m"
BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
MAGENTA="\e[35m"

_log() {
    local label="$1"
    local color="$2"
    shift 2
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BOLD}${color}[${label}]${RESET} ${message}"
    echo "[$timestamp] [${label}] ${message}" >> "$LOG_FILE"
}

log_info()    { _log "   INFO   " "$BLUE"   "$@"; }
log_warning() { _log "   WARN   " "$YELLOW" "$@"; }
log_error()   { _log "   ERRO   " "$RED"    "$@"; }
log_success() { _log " SUCCESSO " "$GREEN"  "$@"; }

declare -g LAST_COMMAND=""
declare -g LAST_LINE=0
declare -g ERROR_OUTPUT=""

trap 'LAST_COMMAND=$BASH_COMMAND; LAST_LINE=$LINENO' DEBUG

error_handler() {
    local exit_code=$?
    local error_line=${BASH_LINENO[0]}
    local error_command="$LAST_COMMAND"
    local caller_script="${BASH_SOURCE[1]}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    [ $exit_code -eq 0 ] && return 0
    
    local error_message="Comando retornou código de erro: $exit_code"

    if [ -n "$error_command" ]; then
        ERROR_OUTPUT=$(eval "$error_command" 2>&1) || true
        if [ -n "$ERROR_OUTPUT" ]; then
            error_message="$ERROR_OUTPUT"
        fi
    fi

    echo ""
    log_error "Falha na execução do script"
    log_warning "$error_message"
    log_info "Código de saída: $exit_code"
    log_info "Linha: $error_line"
    log_info "Comando: $error_command"
    log_info "Reportado por: $caller_script"

    echo "" >> "$LOG_FILE"
    echo "────────────────────────────────────────────────────────────────────────" >> "$LOG_FILE"
    echo "ERRO CAPTURADO" >> "$LOG_FILE"
    echo "────────────────────────────────────────────────────────────────────────" >> "$LOG_FILE"
    echo "Horário:       $timestamp" >> "$LOG_FILE"
    echo "Código saída:  $exit_code" >> "$LOG_FILE"
    echo "Saída:         $error_message" >> "$LOG_FILE"
    echo "Linha:         $error_line" >> "$LOG_FILE"
    echo "Comando:       $error_command" >> "$LOG_FILE"
    echo "Reportado por: $caller_script" >> "$LOG_FILE"
    echo "────────────────────────────────────────────────────────────────────────" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    echo ""
    read -n 1 -s -r -p "Pressione qualquer tecla para encerrar..."
    echo ""
    
    exit $exit_code
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

set -eE
trap error_handler ERR

{
    echo "════════════════════════════════════════════════════════════════════════"
    echo "INÍCIO DA EXECUÇÃO: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Script: ${BASH_SOURCE[1]}"
    echo "Usuário: $(whoami)"
    echo "Diretório: $(pwd)"
    echo "════════════════════════════════════════════════════════════════════════"
    echo ""
} >> "$LOG_FILE"

log_success "Sistema de logs inicializado"
log_info "Arquivo de log: $LOG_FILE"

cleanup_handler() {
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "" >> "$LOG_FILE"
        echo "════════════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
        echo "FIM DA EXECUÇÃO: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Status: Sucesso (código 0)"
        echo "════════════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
        
        log_success "Script finalizado com sucesso"
    fi
}

trap cleanup_handler EXIT