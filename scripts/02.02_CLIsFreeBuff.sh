#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 02.02_CLIsFreeBuff.sh
# Instalacao do FreeBuff CLI 100% local: npm prefix em lib/npm/freebuff,
# executavel linkado em bin/. Nenhum arquivo escapa para o host.
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
TOOL_NAME="freebuff"
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE (nomes mantidos: 02.02_setenv_freebuff.sh)
# ============================================================================
generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.02_setenv_freebuff.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: FreeBuff (npm local em lib/npm/freebuff, link em bin/)
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
    local SCRIPT="$OFFICEAI_ROOT/bin/02.02_unsetenv_freebuff.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: FreeBuff
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_freebuff() {
    log_step "=== FreeBuff CLI (npm local em lib/npm/freebuff) ==="

    # a. Ja instalado?
    if tool_installed "$TOOL_NAME"; then
        log_info "FreeBuff ja instalado no OfficeAI: $("$OFFICEAI_ROOT/bin/freebuff" --version 2>/dev/null || echo "versao desconhecida")"
        return 0
    fi

    # b. Garantir PATH com Node local (fase 01) e instalar via npm prefix
    export PATH="$OFFICEAI_ROOT/lib/node/bin:$OFFICEAI_ROOT/lib/npm/bin:$PATH"
    if npm_prefix_install freebuff freebuff; then
        log_success "FreeBuff instalado com sucesso"
        "$OFFICEAI_ROOT/bin/freebuff" --version 2>/dev/null || "$OFFICEAI_ROOT/bin/freebuff" -h 2>/dev/null || true
        return 0
    fi

    log_error "Falha ao instalar FreeBuff"
    return 1
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do FreeBuff CLI..."
    generate_setenv
    generate_unsetenv
    install_freebuff
    log_info "Instalacao concluida!"
    log_info "Ativar: source etc/00_envGeneral.sh"
}

main "$@"