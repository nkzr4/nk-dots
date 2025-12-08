function display_animation
    # Script de animação ULTRA-OTIMIZADO para máxima fluidez
    
    set frames_dir "$HOME/.config/fish/ascii_frames"
    set frame_delay 0.05
    
    # Verificar frames
    set frames (command ls -1v "$frames_dir"/frame_*.txt 2>/dev/null)
    if test (count $frames) -eq 0
        fastfetch
        return
    end
    
    # Capturar fastfetch
    set temp_ff (mktemp)
    fastfetch > "$temp_ff" 2>/dev/null
    set -l ff_lines
    while read -l line
        set -a ff_lines "$line"
    end < "$temp_ff"
    command rm "$temp_ff"
    
    # Ocultar cursor
    tput civis
    clear
    
    # PRÉ-RENDERIZAR TODOS OS FRAMES COMPLETOS (string única por frame)
    set -l rendered_frames
    set max_lines 0
    
    for frame_file in $frames
        # Ler frame
        set -l frame_lines
        while read -l line
            set -a frame_lines "$line"
        end < "$frame_file"
        
        # Calcular max lines
        set frame_max (count $frame_lines)
        if test (count $ff_lines) -gt $frame_max
            set frame_max (count $ff_lines)
        end
        if test $frame_max -gt $max_lines
            set max_lines $frame_max
        end
        
        # Construir frame completo como string única
        set -l frame_output ""
        for i in (seq 1 $frame_max)
            # ASCII art (esquerda)
            if test $i -le (count $frame_lines)
                set frame_output "$frame_output\x1b[38;5;16m\x1b[1m"(printf "%-35s" "$frame_lines[$i]")"\x1b[0m"
            else
                set frame_output "$frame_output"(printf "%-35s" "")
            end
            
            # Espaçamento
            set frame_output "$frame_output   "
            
            # Fastfetch (direita)
            if test $i -le (count $ff_lines)
                set frame_output "$frame_output$ff_lines[$i]\x1b[K"
            else
                set frame_output "$frame_output\x1b[K"
            end
            
            # Nova linha (exceto na última)
            if test $i -lt $frame_max
                set frame_output "$frame_output\n"
            end
        end
        
        # Armazenar frame pré-renderizado
        set -a rendered_frames "$frame_output"
    end
    
    # Configurar terminal
    set old_tty (stty -g)
    stty -icanon min 0 time 0 -echo
    
    # Loop de animação
    set frame_index 1
    set total_frames (count $frames)
    
    while true
        # Verificar tecla (não-bloqueante)
        set char (dd bs=1 count=1 2>/dev/null)
        if test -n "$char"
            break
        end
        
        # Voltar ao início
        tput cup 0 0
        
        # Calcular frame atual
        set current_frame_idx (math "($frame_index - 1) % $total_frames + 1")
        
        # IMPRIMIR FRAME PRÉ-RENDERIZADO (uma única operação!)
        printf "%b" "$rendered_frames[$current_frame_idx]"
        
        # Próximo frame
        set frame_index (math $frame_index + 1)
        
        # Sleep
        sleep $frame_delay
    end
    
    # Restaurar terminal
    stty "$old_tty"
    tput cnorm
    tput cup $max_lines 0
    echo ""
end