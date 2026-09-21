#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 01_Languages.sh
# Menu interativo para instalacao de linguagens
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

# Inicialização padrão
script_init "$(basename "$0" .sh)"

# ============================================================================
# DESCOBRIR SCRIPTS DE LINGUAGENS
# ============================================================================
discover_languages() {
    local SCRIPTS_DIR="$OFFICEAI_ROOT/scripts"
    LANGUAGES=()
    LANG_NAMES=()
    LANG_SCRIPTS=()
    
    for script in "$SCRIPTS_DIR"/01.[0-9][0-9]_Language*.sh; do
        [[ -f "$script" ]] || continue
        
        local basename
        basename=$(basename "$script")
        
        # Pular o proprio script 01.00_Languages.sh
        [[ "$basename" == "01.00_Languages.sh" ]] && continue
        
        # Extrair nome da linguagem do nome do arquivo
        # Formato: 01.XX_Language{Nome}.sh
        local lang_name
        lang_name=$(echo "$basename" | sed -n 's/^01\.[0-9]*_Language\([^.]*\)\.sh$/\1/p')
        
        if [[ -n "$lang_name" ]]; then
            LANGUAGES+=("$lang_name")
            LANG_NAMES+=("${lang_name,,}")  # lowercase
            LANG_SCRIPTS+=("$script")
        fi
    done
    
    log_info "Linguagens encontradas: ${#LANGUAGES[@]}"
}

# ============================================================================
# FUNCAO DE DETECCAO (layout auto-contido: lib/<tool> ou bin/<tool>)
# ============================================================================
is_installed_lang() {
    local script="$1"
    local basename
    basename=$(basename "$script" .sh)
    # Mapear: 01.01_LanguageRust -> rust | rustc
    local lang
    lang=$(echo "$basename" | sed 's/^01\.[0-9]*_Language//' | tr 'A-Z' 'a-z')

    case "$lang" in
        rust)   [[ -x "$OFFICEAI_ROOT/lib/rust/cargo/bin/rustc" || -e "$OFFICEAI_ROOT/bin/rustc" ]] ;;
        zig)    [[ -x "$OFFICEAI_ROOT/lib/zig/zig" || -e "$OFFICEAI_ROOT/bin/zig" ]] ;;
        go)     [[ -x "$OFFICEAI_ROOT/lib/go/bin/go" || -e "$OFFICEAI_ROOT/bin/go" ]] ;;
        nodejs) [[ -x "$OFFICEAI_ROOT/lib/node/bin/node" || -e "$OFFICEAI_ROOT/bin/node" ]] ;;
        uv)     [[ -x "$OFFICEAI_ROOT/lib/languages/uv/uv" || -e "$OFFICEAI_ROOT/bin/uv" ]] ;;
        *)      [[ -e "$OFFICEAI_ROOT/bin/$lang" || -d "$OFFICEAI_ROOT/lib/$lang" ]] ;;
    esac
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
    echo -e "${BOLD}${CYAN}   OfficeAI - Instalacao de Linguagens      ${RESET}"
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo ""
    echo -e "${BOLD}Linguagens disponiveis:${RESET}"
    echo ""
    
    local i=1
    for script in "${LANG_SCRIPTS[@]}"; do
        local clr
        is_installed_lang "$script" && clr="$GREEN" || clr="$RED"
        echo -e "  ${clr}[$i]${RESET} ${LANGUAGES[$((i-1))]}"
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
    log_info "OfficeAI - Instalacao de Linguagens"
    log_info "========================================="
    
    # Descobrir linguagens disponiveis
    discover_languages
    
    if [[ ${#LANGUAGES[@]} -eq 0 ]]; then
        log_warn "Nenhum script de linguagem encontrado"
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
                bash "$OFFICEAI_ROOT/scripts/00_SystemBase.sh"
                exit 0
                ;;
            x|exit)
                exit 0
                ;;
            n|next)
                bash "$OFFICEAI_ROOT/scripts/02.00_CLIs.sh"
                exit 0
                ;;
            0)
                exit 0
                ;;
            a|all)
                for script in "${LANG_SCRIPTS[@]}"; do
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
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#LANGUAGES[@]}" ]]; then
                    local idx=$((choice - 1))
                    local script="${LANG_SCRIPTS[$idx]}"
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
