#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 05.00_Visual.sh
# Menu interativo para gerenciamento de ferramentas visuais
# ============================================================================

set -euo pipefail

# ============================================================================
# CARREGAR LIBS
# ============================================================================
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "$0")/.." && pwd)}"
source "$OFFICEAI_ROOT/lib/colors.sh"
source "$OFFICEAI_ROOT/lib/log.sh"
source "$OFFICEAI_ROOT/lib/system.sh"
source "$OFFICEAI_ROOT/lib/utils.sh"
source "$OFFICEAI_ROOT/lib/loader.sh"
source "$OFFICEAI_ROOT/lib/prefix.sh"

# Inicialização padrão
script_init "$(basename "$0" .sh)"
prefix_ensure_structure

# ============================================================================
# DESCOBRIR FERRAMENTAS VISUAIS
# ============================================================================
discover_visual() {
    local SCRIPTS_DIR="$OFFICEAI_ROOT/scripts"
    VISUALS=()
    VISUAL_NAMES=()
    VISUAL_SCRIPTS=()
    
    for script in "$SCRIPTS_DIR"/05.[0-9][0-9]_Visual*.sh; do
        [[ -f "$script" ]] || continue
        
        local basename
        basename=$(basename "$script")
        
        # Pular o proprio script 05.00_Visual.sh
        [[ "$basename" == "05.00_Visual.sh" ]] && continue
        
        # Extrair nome da ferramenta visual do nome do arquivo
        # Formato: 05.XX_Visual{Nome}.sh
        local visual_name
        visual_name=$(echo "$basename" | sed -n 's/^05\.[0-9]*_Visual\([^.]*\)\.sh$/\1/p')
        
        if [[ -n "$visual_name" ]]; then
            VISUALS+=("$visual_name")
            VISUAL_NAMES+=("${visual_name,,}")  # lowercase
            VISUAL_SCRIPTS+=("$script")
        fi
    done
    
    log_info "Ferramentas visuais encontradas: ${#VISUALS[@]}"
}

# ============================================================================
# VERIFICAR SE ESTA INSTALADO (layout auto-contido: bin/<tool> ou lib/<tool>)
# ============================================================================
is_visual_installed() {
    local script="$1"
    local basename
    basename=$(basename "$script" .sh)

    # Mapear: 05.01_VisualVSCode -> code, 05.02_VisualVSCodium -> codium
    local tool=""
    case "$basename" in
        *VSCode*)   tool="code" ;;
        *VSCodium*) tool="codium" ;;
    esac

    if [[ -n "$tool" ]] && tool_installed "$tool"; then
        return 0
    fi

    # Fallback generico: bin/<tool> ou lib/<tool>
    tool=$(echo "$basename" | sed 's/^05\.[0-9]*_Visual//' | tr 'A-Z' 'a-z')
    tool_installed "$tool"
}

# ============================================================================
# MENU INTERATIVO
# ============================================================================
show_menu() {
    clear
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo -e "${BOLD}${CYAN}   OfficeAI - Instalacao de Ferramentas Visuais${RESET}"
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo ""
    echo -e "${BOLD}Ferramentas visuais disponiveis:${RESET}"
    echo ""
    
    local i=1
    for script in "${VISUAL_SCRIPTS[@]}"; do
        local clr
        is_visual_installed "$script" && clr="$GREEN" || clr="$RED"
        echo -e "  ${clr}[$i]${RESET} ${VISUALS[$((i-1))]}"
        ((i++))
    done
    
    echo ""
    echo -e "  ${YELLOW}[A]${RESET} ${BOLD}Instalar ALL${RESET}"
    echo ""
    echo -e "${CYAN}============================================${RESET}"
    echo -e "  ${RED}[P]${RESET} Previous    ${GREEN}[N]${RESET} Next    ${RED}[X]${RESET} Exit"
    echo -e "${CYAN}============================================${RESET}"
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "========================================="
    log_info "OfficeAI - Instalacao de Ferramentas Visuais"
    log_info "========================================="
    
    # Descobrir ferramentas visuais disponiveis
    discover_visual
    
    if [[ ${#VISUALS[@]} -eq 0 ]]; then
        log_warn "Nenhum script de ferramenta visual encontrado"
        exit 1
    fi
    
    while true; do
        # Mostrar menu
        show_menu
        
        # Ler opcao
        local choice
        read -r -p "Opcao: " choice
        
        case "${choice,,}" in
            p|previous)
                bash "$OFFICEAI_ROOT/scripts/04.00_SDDs.sh"
                exit 0
                ;;
            x|exit)
                exit 0
                ;;
            n|next)
                echo -e "${YELLOW}Proxima fase ainda nao disponivel${RESET}"
                read -r -p "Pressione Enter para continuar..."
                ;;
            a|all)
                for script in "${VISUAL_SCRIPTS[@]}"; do
                    local basename
                    basename=$(basename "$script" .sh)
                    
                    echo -e "${BOLD}${CYAN}============================================${RESET}"
                    echo -e "${BOLD}${CYAN}   Instalando: $basename${RESET}"
                    echo -e "${BOLD}${CYAN}============================================${RESET}"
                    echo ""
                    
                    if run_and_capture "$script"; then
                        log_info "[$basename] OK"
                    else
                        log_error "[$basename] FAIL"
                    fi
                    echo ""
                done
                echo ""
                read -r -p "Pressione Enter para continuar..."
                ;;
            *)
                # Verificar se e um numero valido
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#VISUALS[@]}" ]]; then
                    local idx=$((choice - 1))
                    local script="${VISUAL_SCRIPTS[$idx]}"
                    local basename
                    basename=$(basename "$script" .sh)
                    
                    echo -e "${BOLD}${CYAN}============================================${RESET}"
                    echo -e "${BOLD}${CYAN}   Instalando: $basename${RESET}"
                    echo -e "${BOLD}${CYAN}============================================${RESET}"
                    echo ""
                    
                    if run_and_capture "$script"; then
                        log_info "[$basename] OK"
                    else
                        log_error "[$basename] FAIL"
                    fi
                    echo ""
                    read -r -p "Pressione Enter para continuar..."
                else
                    log_warn "Opcao invalida"
                    sleep 1
                fi
                ;;
        esac
    done
}

# Executar
main "$@"
