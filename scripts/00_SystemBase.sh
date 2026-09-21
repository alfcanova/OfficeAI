#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 00_SystemBase.sh
# Fase 0: prerequisitos 100% LOCAIS - nenhum apt/sudo/Docker.
#   [1] Python 3 (prerequisito do sistema - apenas verificacao)
#   [2] uv        (binario local -> lib/languages/uv, executavel em bin/)
#   [A] Ativacao automatica no .bashrc (bloco condicional unico)
#
# RuleSet: nada escapa da pasta OfficeAI.
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

script_init "$(basename "$0" .sh)"
prefix_ensure_structure

# ============================================================================
# CONSTANTES
# ============================================================================
UV_INSTALL_DIR="$OFFICEAI_ROOT/lib/languages/uv"

# ============================================================================
# SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/00_setenv_SystemBase.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: SystemBase (layout auto-contido)
# Ativacao completa: source etc/00_envGeneral.sh
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export OFFICEAI_ROOT
export UV_INSTALL_DIR="$OFFICEAI_ROOT/lib/languages/uv"
if [[ -f "$OFFICEAI_ROOT/etc/00_envGeneral.sh" ]]; then
    # shellcheck source=/dev/null
    source "$OFFICEAI_ROOT/etc/00_envGeneral.sh"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    cat > "$SETENV_MARKER" << 'EOF'
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export OFFICEAI_ROOT
export UV_INSTALL_DIR="$OFFICEAI_ROOT/lib/languages/uv"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/00_unsetenv_SystemBase.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: SystemBase
# Desativacao completa: source etc/00_unenvGeneral.sh
unset UV_INSTALL_DIR
if [[ -f "$OFFICEAI_ROOT/etc/00_unenvGeneral.sh" ]]; then
    # shellcheck source=/dev/null
    source "$OFFICEAI_ROOT/etc/00_unenvGeneral.sh"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# [1] PYTHON (verificacao - prerequisito do host)
# ============================================================================
check_python() {
    log_step "=== Python 3 (prerequisito) ==="
    if command_exists python3; then
        log_info "Python encontrado: $(python3 --version)"
        if python3 -m venv --help >/dev/null 2>&1; then
            log_info "python3-venv disponivel"
        else
            log_warn "python3-venv ausente. Instale no host OU use uv (que baixa Pythons locais)."
            log_warn "  uv python install 3.12  (faz download local em lib/uv-tools/python)"
        fi
        return 0
    fi
    log_error "python3 nao encontrado. Instale via apt (python3 python3-venv) OU use uv."
    return 1
}

# ============================================================================
# [2] UV (binario local, 100% dentro da pasta)
# ============================================================================
install_uv() {
    log_step "=== uv (local em lib/languages/uv) ==="

    if [[ -x "$UV_INSTALL_DIR/uv" ]]; then
        log_info "uv ja instalado no OfficeAI: $("$UV_INSTALL_DIR/uv" --version)"
    else
        local UV_PLATFORM
        case "$(uname -s)" in
            Linux*)  UV_PLATFORM="x86_64-unknown-linux-gnu" ;;
            Darwin*) UV_PLATFORM="aarch64-apple-darwin" ;;
            *)       UV_PLATFORM="" ;;
        esac

        local UV_ARCHIVE="uv-${UV_PLATFORM}.tar.gz"
        local TMP_DIR
        TMP_DIR=$(mktemp -d)

        mkdir -p "$UV_INSTALL_DIR"
        log_step "Baixando uv (binario direto)..."
        if curl -fsSL "https://github.com/astral-sh/uv/releases/latest/download/${UV_ARCHIVE}" -o "$TMP_DIR/$UV_ARCHIVE" 2>/dev/null; then
            tar -xzf "$TMP_DIR/$UV_ARCHIVE" -C "$TMP_DIR"
            # O tarball contem uv-x86_64-unknown-linux-gnu/uv e uvx
            find "$TMP_DIR" -type f \( -name "uv" -o -name "uvx" \) -exec cp {} "$UV_INSTALL_DIR/" \;
        else
            log_warn "Download direto falhou; tentando script oficial com UV_INSTALL_DIR local..."
            UV_INSTALL_DIR="$UV_INSTALL_DIR" curl -LsSf https://astral.sh/uv/install.sh | sh
        fi
        rm -rf "$TMP_DIR"

        if [[ ! -x "$UV_INSTALL_DIR/uv" ]]; then
            log_error "Falha ao instalar uv"
            return 1
        fi
    fi

    # Executaveis em bin/
    link_bin "uv" "$UV_INSTALL_DIR/uv"
    [[ -x "$UV_INSTALL_DIR/uvx" ]] && link_bin "uvx" "$UV_INSTALL_DIR/uvx"

    log_success "uv pronto: $("$UV_INSTALL_DIR/uv" --version)"
}

# ============================================================================
# [A] BASHRC - bloco condicional unico
# ============================================================================
install_bashrc() {
    local BASHRC="$HOME/.bashrc"
    local MARKER="# >>> OfficeAI (auto-contido) >>>"
    local MARKER_END="# <<< OfficeAI (auto-contido) <<<"

    if [[ -f "$BASHRC" ]] && grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
        log_info "OfficeAI ja configurado no .bashrc"
        return 0
    fi

    log_step "Instalando bloco condicional no .bashrc..."
    if [[ ! -f "$BASHRC" ]]; then
        touch "$BASHRC"
    fi

    # Symlink $HOME/.officeai -> pasta OfficeAI (portabilidade: link_local.sh re-aponteia)
    if [[ -L "$HOME/.officeai" ]]; then
        rm -f "$HOME/.officeai"
    fi
    ln -sfn "$OFFICEAI_ROOT" "$HOME/.officeai"

    cat >> "$BASHRC" << BASHRCEOF

# >>> OfficeAI (auto-contido) >>>
# Gerado automaticamente - nao edite esta secao
if [[ -f "\${HOME}/.officeai/etc/00_envGeneral.sh" ]]; then
    source "\${HOME}/.officeai/etc/00_envGeneral.sh"
fi
# <<< OfficeAI (auto-contido) <<<
BASHRCEOF

    log_success "OfficeAI configurado no .bashrc"
    log_info "Symlink criado: $HOME/.officeai -> $OFFICEAI_ROOT"
    log_info "Se mover a pasta, rode:  bash $OFFICEAI_ROOT/scripts/link_local.sh"
    log_info "Reinicie o terminal ou execute: source ~/.bashrc"
}

# ============================================================================
# MENU
# ============================================================================
show_menu() {
    clear
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo -e "${BOLD}${CYAN}   OfficeAI - Sistema Base (100% local)      ${RESET}"
    echo -e "${BOLD}${CYAN}============================================${RESET}"
    echo ""
    echo -e "${BOLD}Sistema:${RESET} $(uname -s) $(uname -m)"
    echo ""
    echo -e "${BOLD}Opcoes:${RESET}"
    echo -e "  ${GREEN}[1]${RESET} Python 3 (verificar prerequisito)"
    echo -e "  ${GREEN}[2]${RESET} uv      (binario local em lib/languages/uv)"
    echo -e "  ${GREEN}[A]${RESET} Ativacao automatica no .bashrc (bloco condicional)"
    echo ""
    echo -e "  ${CYAN}============================================${RESET}"
    echo -e "           ${GREEN}[N]${RESET} Next    ${RED}[X]${RESET} Exit"
    echo -e "  ${CYAN}============================================${RESET}"
    echo ""
    echo -e "${GRAY}Nota: compiladores, Node.js, Docker => instalados por fases locais (01+)${RESET}"
}

main() {
    log_info "=== OfficeAI - Sistema Base (100% local) ==="

    generate_setenv
    generate_unsetenv

    while true; do
        show_menu
        local choice
        read -r -p "Opcao: " choice

        case "${choice,,}" in
            x|exit)
                exit 0
                ;;
            n|next)
                run_and_capture "$OFFICEAI_ROOT/scripts/01.00_Languages.sh"
                exit 0
                ;;
            1)
                check_python && log_info "[Python] OK" || log_error "[Python] FAIL"
                read -r -p "Pressione Enter para continuar..."
                ;;
            2)
                if install_uv; then
                    log_info "[uv] OK"
                else
                    log_error "[uv] FAIL"
                fi
                read -r -p "Pressione Enter para continuar..."
                ;;
            a|all)
                check_python || true
                install_uv || true
                # Nao instala bashrc automaticamente - decisao do usuario
                echo ""
                read -r -p "Pressione Enter para continuar..."
                ;;
            *)
                log_warn "Opcao invalida"
                sleep 1
                ;;
        esac
    done
}

main "$@"