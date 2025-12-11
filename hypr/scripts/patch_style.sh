#!/bin/bash
# patch_style.sh - Adequa apps ao tema dinamico

set -e

SCHEME_JSON="$HOME/.local/state/caelestia/scheme.json"
source $DIR/logs.sh
source $DIR/handler.sh

while inotifywait -e modify "$SCHEME_JSON"; do
    if [ ! -f "$SCHEME_JSON" ]; then
        log_error "scheme.json não encontrado em $SCHEME_JSON"
        exit 1
    else
        COLOR_MODE=$(grep -o '"mode":[^,]*' "$SCHEME_JSON" | sed -E 's/.*"mode": *"([^"]+)".*/\1/')
        log_info "Modo detectado: $COLOR_MODE"
        sleep 1
    fi

    # Discord
    DISC_PREFS="$HOME/.config/Vencord/themes/caelestia.theme.css"
    if [ ! -f "$DISC_PREFS" ]; then
        log_error "Tema não encontrado em $DISC_PREFS"
    else
        sed -i 's/--font: "figtree"/--font: ""/' "$DISC_PREFS"
        perl -0777 -pi -e 's/--top-bar-height:\s*var\((.*?)\);/--top-bar-height: 36px;/s' "$DISC_PREFS"
        log_info "Vencord atualizado"
    fi

    # Sublime Text
    # NOTA: Criar arquivo de preferências?
    SUBL_PREFS="$HOME/.config/sublime-text/Packages/User/Preferences.sublime-settings"
    if [ ! -f "$SUBL_PREFS" ]; then
        log_error "Preferências não encontradas em $SUBL_PREFS"
    else
        if [ "$COLOR_MODE" = "light" ]; then
            sed -i \
                -e 's/"theme": *"[^"]*"/"theme": "Default.sublime-theme"/' \
                -e 's/"color_scheme": *"[^"]*"/"color_scheme": "Breakers.sublime-color-scheme"/' \
                "$SUBL_PREFS"
            log_info "Sublime Text atualizado"
        else
            sed -i \
                -e 's/"theme": *"[^"]*"/"theme": "Default Dark.sublime-theme"/' \
                -e 's/"color_scheme": *"[^"]*"/"color_scheme": "Mariana.sublime-color-scheme"/' \
                "$SUBL_PREFS"
            log_info "Sublime Text atualizado"
        fi
    fi
done


