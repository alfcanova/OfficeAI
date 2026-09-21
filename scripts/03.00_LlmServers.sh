#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 03.00_LlmServers.sh
# Menu interativo para instalacao de servidores LLM locais
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
# DESCOBRIR SCRIPTS DE LLM SERVERS
# ============================================================================
discover_llm_servers() {
    local SCRIPTS_DIR="$OFFICEAI_ROOT/scripts"
    LLM_SERVERS=()
    LLM_NAMES=()
    LLM_SCRIPTS=()
    
    for script in "$SCRIPTS_DIR"/03.[0-9][0-9]_Llm*.sh; do
        [[ -f "$script" ]] || continue
        
        local basename
        basename=$(basename "$script")
        
        # Pular o proprio script 03.00_LlmServers.sh
        [[ "$basename" == "03.00_LlmServers.sh" ]] && continue
        
        # Extrair nome do servidor do nome do arquivo
        # Formato: 03.XX_Llm{Nome}.sh
        local llm_name
        llm_name=$(echo "$basename" | sed -n 's/^03\.[0-9]*_Llm\([^.]*\)\.sh$/\1/p')
        
        if [[ -n "$llm_name" ]]; then
            LLM_SERVERS+=("$llm_name")
            LLM_NAMES+=("${llm_name,,}")  # lowercase
            LLM_SCRIPTS+=("$script")
        fi
    done
    
    log_info "Servidores LLM encontrados: ${#LLM_SERVERS[@]}"
}

# ============================================================================
# FUNCAO DE DETECCAO (layout auto-contido: bin/<tool> ou lib/<tool>)
# ============================================================================
is_installed_llm() {
    local script="$1"
    local basename
    basename=$(basename "$script" .sh)
    # Mapear: 03.01_LlmvLLM -> vllm, 03.06_LlmLMStudio -> lmstudio, ...
    local tool
    case "$basename" in
        *vLLM*)    tool="vllm" ;;
        *Ollama*)  tool="ollama" ;;
        *llamacpp*) tool="llamacpp" ;;
        *LocalAI*) tool="localai" ;;
        *Jan*)     tool="jan" ;;
        *LMStudio*) tool="lmstudio" ;;
        *OpenWebUI*) tool="open-webui" ;;
        *OpenClaw*) tool="openclaw" ;;
        *)         tool=$(echo "$basename" | sed 's/^03\.[0-9]*_Llm//' | tr 'A-Z' 'a-z') ;;
    esac
    tool_installed "$tool"
}

# ============================================================================
# EXECUTAR SUB-SCRIPT E CAPTURAR SETENV
# ============================================================================
run_and_capture() {
    local script="$1"
    local marker="/tmp/officeai_setenv_$$.sh"
    
    # Rodar sub-script
    bash "$script"
    local rc=$?
    
    # Capturar setenv se existe
    if [[ -f "$marker" ]]; then
        # Eval no contexto atual
        source "$marker"
        # Acumular para exportar ao pai
        cat "$marker" >> "$ALL_SETENV"
        rm -f "$marker"
    fi
    
    return $rc
}

# ============================================================================
# MENU INTERATIVO
# ============================================================================
show_menu() {
    clear
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo -e "${BOLD}${CYAN}   OfficeAI - Servidores LLM Locais        ${RESET}"
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo ""
    
    echo -e "${BOLD}Servidores LLM disponiveis:${RESET}"
    echo ""
    
    local i=1
    for script in "${LLM_SCRIPTS[@]}"; do
        local clr
        is_installed_llm "$script" && clr="$GREEN" || clr="$RED"
        echo -e "  ${clr}[$i]${RESET} ${LLM_SERVERS[$((i-1))]}"
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
    log_info "OfficeAI - Servidores LLM Locais"
    log_info "========================================="
    
    # Descobrir servidores LLM disponiveis
    discover_llm_servers
    
    if [[ ${#LLM_SERVERS[@]} -eq 0 ]]; then
        log_warn "Nenhum script de servidor LLM encontrado"
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
                bash "$OFFICEAI_ROOT/scripts/02.00_CLIs.sh"
                exit 0
                ;;
            x|exit)
                exit 0
                ;;
            n|next)
                bash "$OFFICEAI_ROOT/scripts/04.00_SDDs.sh"
                exit 0
                ;;
            0)
                exit 0
                ;;
            a|all)
                for script in "${LLM_SCRIPTS[@]}"; do
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
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#LLM_SERVERS[@]}" ]]; then
                    local idx=$((choice - 1))
                    local script="${LLM_SCRIPTS[$idx]}"
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
