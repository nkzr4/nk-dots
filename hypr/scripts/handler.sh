#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
source "$DIR/logs.sh"

set -o errtrace

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