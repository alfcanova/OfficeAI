#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 02.00_CLIs.sh
# Menu interativo para instalacao de CLIs
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

# ============================================================================
# DESCOBRIR SCRIPTS DE CLIs
# ============================================================================
discover_clis() {
    local SCRIPTS_DIR="$OFFICEAI_ROOT/scripts"
    CLIS=()
    CLI_NAMES=()
    CLI_SCRIPTS=()
    
    for script in "$SCRIPTS_DIR"/02.[0-9][0-9]_CLI*.sh; do
        [[ -f "$script" ]] || continue
        
        local basename
        basename=$(basename "$script")
        
        # Pular o proprio script 02.00_CLIs.sh
        [[ "$basename" == "02.00_CLIs.sh" ]] && continue
        
        # Extrair nome da CLI do nome do arquivo
        # Formato: 02.XX_CLIs{Nome}.sh ou 02.XX_CLI{Nome}.sh
        local cli_name
        cli_name=$(echo "$basename" | sed -n 's/^02\.[0-9]*_CLIs\?\([^.]*\)\.sh$/\1/p')
        
        if [[ -n "$cli_name" ]]; then
            CLIS+=("$cli_name")
            CLI_NAMES+=("${cli_name,,}")  # lowercase
            CLI_SCRIPTS+=("$script")
        fi
    done
    
    log_info "CLIs encontradas: ${#CLIS[@]}"
}

# ============================================================================
# FUNCAO DE DETECCAO (layout auto-contido: tool_installed via lib/prefix.sh)
# ============================================================================
is_installed_cli() {
    local script="$1"
    local basename
    basename=$(basename "$script" .sh)
    # Extrair nome da ferramenta: 02.01_CLIsOpenCode -> opencode
    # (sed aceita "CLIs" e "CLI" e mantém nomes como AntiGravity)
    local cli
    cli=$(echo "$basename" | sed 's/^02\.[0-9]*_CLIs\?//' | tr 'A-Z' 'a-z')

    # Casos especiais de nome/binario
    local tool="$cli"
    case "$cli" in
        antigravity) tool="antigravity" ;;  # 02.05 gera bin/antigravity
        *)           tool="$cli" ;;
    esac

    # Ferramentas instaladas: bin/<tool> OU lib/<tool> existem
    tool_installed "$tool"
}

# ============================================================================
# EXECUTAR SUB-SCRIPT E CAPTURAR SETENV
# ============================================================================
# Função centralizada em lib/loader.sh

# ============================================================================
# MENU INTERATIVO
# ============================================================================
show_menu() {
    clear
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo -e "${BOLD}${CYAN}   OfficeAI - Instalacao de CLIs            ${RESET}"
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo ""
    echo -e "${BOLD}CLIs disponiveis:${RESET}"
    echo ""
    
    local i=1
    for script in "${CLI_SCRIPTS[@]}"; do
        local clr
        is_installed_cli "$script" && clr="$GREEN" || clr="$RED"
        echo -e "  ${clr}[$i]${RESET} ${CLIS[$((i-1))]}"
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
    log_info "OfficeAI - Instalacao de CLIs"
    log_info "========================================="
    
    # Descobrir CLIs disponiveis
    discover_clis
    
    if [[ ${#CLIS[@]} -eq 0 ]]; then
        log_warn "Nenhum script de CLI encontrado"
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
                bash "$OFFICEAI_ROOT/scripts/01.00_Languages.sh"
                exit 0
                ;;
            x|exit)
                exit 0
                ;;
            n|next)
                bash "$OFFICEAI_ROOT/scripts/03.00_LlmServers.sh"
                exit 0
                ;;
            a|all)
                for script in "${CLI_SCRIPTS[@]}"; do
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
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#CLIS[@]}" ]]; then
                    local idx=$((choice - 1))
                    local script="${CLI_SCRIPTS[$idx]}"
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

# Output final setenv para eval do pai
if [[ -s "$ALL_SETENV" ]]; then
    cat "$ALL_SETENV"
    rm -f "$ALL_SETENV"
fi
