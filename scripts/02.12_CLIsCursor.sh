#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 02.12_CLIsCursor.sh
# Instalacao do Cursor CLI (agent) 100% local:
# - AppImage binario baixado do instalador oficial com HOME virtual (contido)
#   para var/home/.cursor/AppImage/agent, copiado para lib/cursor/
# - extraido com --appimage-extract quando aplicavel; executavel linkado em
#   bin/cursor. Nada e gravado fora da pasta OfficeAI.
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
TOOL_NAME="cursor"
CURSOR_LIB_DIR="$OFFICEAI_ROOT/lib/cursor"
CURSOR_HOME_VIRTUAL="$OFFICEAI_ROOT/var/home"
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE (nomes mantidos: 02.12_setenv_cursor.sh)
# ============================================================================
generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.12_setenv_cursor.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Cursor CLI (agent em lib/cursor, link em bin/)
# OFFICEAI_ROOT resolvido dinamicamente (portabilidade da pasta)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export CURSOR_HOME="$OFFICEAI_ROOT/lib/cursor"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai capturar (mesmos exports)
    cat > "$SETENV_MARKER" << 'EOF'
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export CURSOR_HOME="$OFFICEAI_ROOT/lib/cursor"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.12_unsetenv_cursor.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Cursor CLI
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
unset CURSOR_HOME
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_cursor() {
    log_step "=== Cursor CLI (agent em lib/cursor) ==="

    # a. Ja instalado?
    if tool_installed "$TOOL_NAME"; then
        log_info "Cursor ja instalado no OfficeAI: $("$OFFICEAI_ROOT/bin/cursor" --version 2>/dev/null || echo "versao desconhecida")"
        return 0
    fi

    mkdir -p "$CURSOR_LIB_DIR"
    local REAL_BIN=""

    # b. Metodo 1: baixar AppImage 'agent' via instalador oficial, com HOME
    #    virtual (var/home) para nada escapar para o host.
    if command_exists curl; then
        log_info "Baixando Cursor agent (instalador oficial, HOME virtual)..."
        curl -fsSL https://cursor.com/install | HOME="$CURSOR_HOME_VIRTUAL" bash >/dev/null 2>&1 || true
    fi

    local appimage="$CURSOR_HOME_VIRTUAL/.cursor/AppImage/agent"
    if [[ -f "$appimage" ]]; then
        cp "$appimage" "$CURSOR_LIB_DIR/agent"
        chmod +x "$CURSOR_LIB_DIR/agent"
        REAL_BIN="$CURSOR_LIB_DIR/agent"
    fi

    # b2. Extrair AppImage com --appimage-extract (nao depende de FUSE)
    if [[ -n "$REAL_BIN" && -x "$REAL_BIN" ]] && "$REAL_BIN" --appimage-extract >/dev/null 2>&1; then
        local root="$CURSOR_LIB_DIR/squashfs-root"
        local extracted=""
        [[ -x "$root/usr/bin/agent" ]] && extracted="$root/usr/bin/agent"
        [[ -z "$extracted" && -x "$root/agent" ]] && extracted="$root/agent"
        if [[ -z "$extracted" ]]; then
            extracted=$(find "$root" -type f -name agent -perm -u+x 2>/dev/null | head -1 || true)
        fi
        if [[ -n "$extracted" ]]; then
            mv -f "$extracted" "$CURSOR_LIB_DIR/agent"
            REAL_BIN="$CURSOR_LIB_DIR/agent"
        fi
        rm -rf "$root"
    fi

    # c. Linkar executavel em bin/cursor e validar
    if [[ -n "$REAL_BIN" && -x "$REAL_BIN" ]]; then
        link_bin cursor "$REAL_BIN"
        log_success "Cursor instalado com sucesso"
        "$OFFICEAI_ROOT/bin/cursor" --version 2>/dev/null || "$OFFICEAI_ROOT/bin/cursor" -h 2>/dev/null || true
        return 0
    fi

    log_error "Falha ao instalar Cursor CLI"
    return 1
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Cursor CLI..."
    generate_setenv
    generate_unsetenv
    install_cursor
    log_info "Instalacao concluida!"
    log_info "Ativar: source etc/00_envGeneral.sh"
}

main "$@"