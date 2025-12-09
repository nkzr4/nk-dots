#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
LOG_DIR="$DIR/logs"
LOG_FILE="$LOG_DIR/$(date '+%Y-%m-%d %H:%M:%S').log"
mkdir -p "$LOG_DIR"

RESET="\e[0m"
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
COLOR_RESET="\e[39m"

_timestamp() { date +"%H:%M:%S"; }

_log() {
    local level="$1"
    local color="$2"
    local message="$3"
    shift
    echo -e "${BOLD}[${color}${level}${COLOR_RESET}]${RESET} $(_timestamp) - ${message}"
    echo "[${level}] $(_timestamp) - ${message}" >> "$LOG_FILE"
    sleep 0.1
}

log_info()    { _log "  INFO  " "$BLUE" "$@"; }
log_warning() { _log "  WARN  " "$YELLOW" "$@"; }
log_error()   { _log "  ERRO  " "$RED" "$@"; }
log_success() { _log "  SUCC  " "$GREEN" "$@"; }
log_input() { 
    echo -e "${BOLD}[${CYAN}  INPT  ${COLOR_RESET}]${RESET} $(_timestamp) - " 
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