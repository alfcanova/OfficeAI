#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 04.00_SDDs.sh
# Menu interativo para gerenciamento de especificações (Spec Driven Development)
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
# DESCOBRIR ESPECIFICAÇÕES
# ============================================================================
discover_sdds() {
    local SCRIPTS_DIR="$OFFICEAI_ROOT/scripts"
    SDDS=()
    SDD_NAMES=()
    SDD_SCRIPTS=()
    
    for script in "$SCRIPTS_DIR"/04.[0-9][0-9]_SDDs*.sh; do
        [[ -f "$script" ]] || continue
        
        local basename
        basename=$(basename "$script")
        
        # Pular o proprio script 04.00_SDDs.sh
        [[ "$basename" == "04.00_SDDs.sh" ]] && continue
        
        # Extrair nome da ferramenta SDD do nome do arquivo
        # Formato: 04.XX_SDDs{Nome}.sh
        local sdd_name
        sdd_name=$(echo "$basename" | sed -n 's/^04\.[0-9]*_SDDs\([^.]*\)\.sh$/\1/p')
        
        if [[ -n "$sdd_name" ]]; then
            SDDS+=("$sdd_name")
            SDD_NAMES+=("${sdd_name,,}")  # lowercase
            SDD_SCRIPTS+=("$script")
        fi
    done
    
    log_info "Ferramentas SDD encontradas: ${#SDDS[@]}"
}

# ============================================================================
# VERIFICAR SE ESTÁ INSTALADO (layout auto-contido: bin/<tool> ou lib/<tool>)
# ============================================================================
is_spec_installed() {
    local script="$1"
    local basename
    basename=$(basename "$script" .sh)
    # Mapear: 04.01_SDDsKiro -> kiro, 04.02_SDDsOpenSpec -> openspec, ...
    local tool
    case "$basename" in
        *Kiro*)     tool="kiro" ;;
        *OpenSpec*) tool="openspec" ;;
        *SpecKit*)  tool="speckit" ;;
        *)          tool=$(echo "$basename" | sed 's/^04\.[0-9]*_SDDs//' | tr 'A-Z' 'a-z') ;;
    esac
    tool_installed "$tool"
}

# ============================================================================
# MENU INTERATIVO
# ============================================================================
show_menu() {
    clear
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo -e "${BOLD}${CYAN}   OfficeAI - Instalacao de Ferramentas SDD ${RESET}"
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo ""
    echo -e "${BOLD}Ferramentas SDD disponiveis:${RESET}"
    echo ""
    
    local i=1
    for script in "${SDD_SCRIPTS[@]}"; do
        local clr
        is_spec_installed "$script" && clr="$GREEN" || clr="$RED"
        echo -e "  ${clr}[$i]${RESET} ${SDDS[$((i-1))]}"
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
# EXECUÇÃO PRINCIPAL
# ============================================================================
main() {
    log_info "========================================="
    log_info "OfficeAI - Instalacao de Ferramentas SDD"
    log_info "========================================="
    
    # Descobrir ferramentas SDD disponiveis
    discover_sdds
    
    if [[ ${#SDDS[@]} -eq 0 ]]; then
        log_warn "Nenhum script de ferramenta SDD encontrado"
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
                bash "$OFFICEAI_ROOT/scripts/03.00_LlmServers.sh"
                exit 0
                ;;
            x|exit)
                exit 0
                ;;
            n|next)
                bash "$OFFICEAI_ROOT/scripts/05.00_Visual.sh"
                exit 0
                ;;
            a|all)
                for script in "${SDD_SCRIPTS[@]}"; do
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
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#SDDS[@]}" ]]; then
                    local idx=$((choice - 1))
                    local script="${SDD_SCRIPTS[$idx]}"
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