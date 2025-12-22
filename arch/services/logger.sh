#!/bin/bash

DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
LOGS_DIR="$DIR/logs"
LOGS_FILE="$LOGS_DIR/$(date '+%Y-%m-%d %H:%M:%S').log"

mkdir -p "$LOGS_DIR"

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
    local LEVEL="$1"
    local COLOR="$2"
    local MESSAGE="$3"
    shift
    echo -e "${BOLD}[${COLOR}${LEVEL}${COLOR_RESET}]${RESET} $(_timestamp) - ${MESSAGE}"
    echo "[${LEVEL}] $(_timestamp) - ${MESSAGE}" >> "$LOGS_FILE"
}

log_message() {
    local LEVEL="$1"
    local COLOR="$2"
    local MESSAGE="$3"
    _log "$LEVEL" "$COLOR" "$MESSAGE"
}

log_info()    { log_message "  INFO  " "$BLUE" "$@"; }
log_warning() { log_message "  WARN  " "$YELLOW" "$@"; }
log_error()   { log_message "  ERRO  " "$RED" "$@"; }
log_success() { log_message "  SUCC  " "$GREEN" "$@"; }

read_input() {
    local PROMPT="$1"
    local VAR="$2"
    read -rp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - $PROMPT " "$VAR"
}

read_password() {
    local PROMPT="$1"
    local VAR="$2"
    read -s -rp $'\033[0m[\033[1;36m  INPT  \033[0m] '"$(date '+%H:%M:%S') - $PROMPT " "$VAR"
    echo
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