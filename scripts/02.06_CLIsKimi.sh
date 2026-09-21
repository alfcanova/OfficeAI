#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 02.06_CLIsKimi.sh
# Instalacao do Kimi CLI 100% local:
# - uv tool install (lib/uv-tools) com link em bin/ via helper
# - fallback: venv Python local (lib/kimi/venv) + link bin/kimi
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
TOOL_NAME="kimi"
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE (nomes mantidos: 02.06_setenv_kimi.sh)
# ============================================================================
generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.06_setenv_kimi.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Kimi (uv tool/venv local, link em bin/)
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
    local SCRIPT="$OFFICEAI_ROOT/bin/02.06_unsetenv_kimi.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Kimi
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_kimi() {
    log_step "=== Kimi CLI (uv tool / venv local) ==="

    # a. Ja instalado?
    if tool_installed "$TOOL_NAME"; then
        log_info "Kimi ja instalado no OfficeAI: $("$OFFICEAI_ROOT/bin/kimi" --version 2>/dev/null || echo "versao desconhecida")"
        return 0
    fi

    # b. Metodo 1: uv tool install
    if uv_tool_install kimi kimi-cli; then
        log_success "Kimi instalado via uv tool"
        "$OFFICEAI_ROOT/bin/kimi" --version 2>/dev/null || true
        return 0
    fi
    log_warn "Falha via uv tool, criando venv local..."

    # b2. Metodo 2 (fallback): venv Python local
    if command_exists python3 && python_venv_tool kimi "$OFFICEAI_ROOT/lib/kimi" python3 kimi-cli; then
        log_success "Kimi instalado via venv local"
        "$OFFICEAI_ROOT/bin/kimi" --version 2>/dev/null || true
        return 0
    fi

    log_error "Falha ao instalar Kimi"
    return 1
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Kimi CLI..."
    generate_setenv
    generate_unsetenv
    install_kimi
    log_info "Instalacao concluida!"
    log_info "Ativar: source etc/00_envGeneral.sh"
}

main "$@"