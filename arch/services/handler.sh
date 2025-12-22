#!/bin/bash
# handler.sh

DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$DIR/logger.sh"

set -o errexit
set -o errtrace
set -o pipefail

_stacktrace() {
    for ((i=1; i<${#BASH_SOURCE[@]}; i++)); do
        echo "  -> ${FUNCNAME[$i]}() em ${BASH_SOURCE[$i]}:${BASH_LINENO[$((i-1))]}"
    done
}

_error_handler() {
    local fn="$1"
    local exit_code="$?"
    echo "────────────────────────────────────────────────────────────────────────"
    log_error "Ocorreu um erro na execução da função: '$fn'"
    log_info "Erro detectado na função: '$fn'"
    log_info "Comando que falhou : $BASH_COMMAND"
    log_info "Arquivo            : ${BASH_SOURCE[1]}"
    log_info "Linha              : ${BASH_LINENO[0]}"
    log_info "Exit code          : $exit_code"
    log_info "Stacktrace:"
    _stacktrace | while read -r line; do log_error "$line"; done
    echo "────────────────────────────────────────────────────────────────────────"
    log_warning "Verifique os logs em: $LOG_FILE"
    echo ""
    read -p "Pressione qualquer tecla para encerrar.."
    exit 1
}

run() {
    local fn="$1"
    shift
    trap "_error_handler \"$fn\"" ERR
    "$fn" "$@"
    local status=$?
    trap - ERR
    return $status
}

fatal() {
    log_error "$*" >&2
    echo
    read -n 1 -s -p "Pressione qualquer tecla para encerrar a instalação..."
    exit 1
}

show_header() {
    local title="$1"
    local width=72
    local title_len=${#title}
    local total_spaces=$((width - title_len))
    local left_spaces=$(( (total_spaces ) / 2 ))
    local right_spaces=$(( total_spaces - left_spaces ))
    local left_string="$(printf '%*s' "$left_spaces" '')"
    local right_string="$(printf '%*s' "$right_spaces" '')"
    clear
    echo "╭──────────────────────────────────────────────────────────────────────────╮"
    echo -e "│$left_string" "${BOLD}${MAGENTA}$title${RESET}" "$right_string│"
    echo "╰──────────────────────────────────────────────────────────────────────────╯"
    echo ""
}