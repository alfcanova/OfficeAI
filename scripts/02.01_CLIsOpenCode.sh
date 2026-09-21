#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 02.01_CLIsOpenCode.sh
# Instalacao do OpenCode CLI 100% local (auto-contido):
# - binario direto do GitHub release em lib/opencode/bin/opencode
# - fallback: npm prefix local (lib/npm/opencode) + link para bin/
# Nenhum arquivo escapa para o host (instalacao 100% contida na pasta).
# ============================================================================

set -euo pipefail

# ============================================================================
# HEADER PADRAO - LIBS
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
TOOL_NAME="opencode"
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE (nomes mantidos: 02.01_setenv_opencode.sh)
# ============================================================================
generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.01_setenv_opencode.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: OpenCode (binario em lib/opencode, link em bin/)
# OFFICEAI_ROOT resolvido dinamicamente (portabilidade da pasta)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai capturar (mesmos exports)
    cat > "$SETENV_MARKER" << 'EOF'
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.01_unsetenv_opencode.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: OpenCode
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_opencode() {
    log_step "=== OpenCode CLI (local em lib/opencode) ==="

    # a. Ja instalado? (bin/opencode ou lib/opencode existe)
    if tool_installed "$TOOL_NAME"; then
        log_info "OpenCode ja instalado no OfficeAI: $("$OFFICEAI_ROOT/bin/opencode" --version 2>/dev/null || echo "versao desconhecida")"
        return 0
    fi

    local INSTALL_DIR="$OFFICEAI_ROOT/lib/opencode/bin"
    local BINARY_URL=""
    local platform arch

    case "$(uname -s)" in
        Linux*)  platform="linux" ;;
        Darwin*) platform="darwin" ;;
        *)       platform="linux" ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)       arch="x64" ;;
        aarch64|arm64)      arch="arm64" ;;
        *)                  arch="x64" ;;
    esac
    BINARY_URL="https://github.com/sst/opencode/releases/latest/download/opencode-${platform}-${arch}"

    # b. Metodo 1: binario direto do GitHub release
    if command_exists curl && mkdir -p "$INSTALL_DIR" && curl -fsSL "$BINARY_URL" -o "$INSTALL_DIR/opencode"; then
        chmod +x "$INSTALL_DIR/opencode"
        link_bin opencode "$INSTALL_DIR/opencode"
        log_success "OpenCode instalado via release binario"
        "$OFFICEAI_ROOT/bin/opencode" --version 2>/dev/null || true
        return 0
    fi
    log_warn "Falha via release binario, tentando npm..."

    # b. Metodo 2 (fallback): npm prefix local (Node instalado pela fase 01)
    export PATH="$OFFICEAI_ROOT/lib/node/bin:$OFFICEAI_ROOT/lib/npm/bin:$PATH"
    if npm_prefix_install opencode opencode-ai; then
        log_success "OpenCode instalado via npm (fallback)"
        "$OFFICEAI_ROOT/bin/opencode" --version 2>/dev/null || true
        return 0
    fi

    # c. Validacao final tolerante
    if [[ -x "$OFFICEAI_ROOT/bin/opencode" ]]; then
        log_success "OpenCode disponivel em bin/opencode"
        "$OFFICEAI_ROOT/bin/opencode" -h 2>/dev/null || "$OFFICEAI_ROOT/bin/opencode" --version 2>/dev/null || true
        return 0
    fi

    log_error "Falha ao instalar OpenCode"
    return 1
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do OpenCode CLI..."
    generate_setenv
    generate_unsetenv
    install_opencode
    log_info "Instalacao concluida!"
    log_info "Ativar: source etc/00_envGeneral.sh"
}

main "$@"