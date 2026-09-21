#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 04.02_SDDsOpenSpec.sh
# Instalacao do OpenSpec CLI 100% local: npm prefix em lib/npm/openspec via
# npm_prefix_install. NUNCA sudo npm -g (nada sai da pasta OfficeAI).
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
# CONSTANTES (layout auto-contido)
# ============================================================================
OPENSPEC_LIB_DIR="$OFFICEAI_ROOT/lib/npm/openspec"
NPM_PACKAGE="@openspec/cli"
NODEJS_MIN_VERSION="20.19.0"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/04.02_setenv_openspec.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: OpenSpec CLI (npm prefix em lib/npm/openspec)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export OPENSPEC_HOME="$OFFICEAI_ROOT/lib/npm/openspec"
export OPENSPEC_TELEMETRY="${OPENSPEC_TELEMETRY:-1}"
export OPENSPEC_CONCURRENCY="${OPENSPEC_CONCURRENCY:-6}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export OPENSPEC_HOME="$OFFICEAI_ROOT/lib/npm/openspec"
export OPENSPEC_TELEMETRY="${OPENSPEC_TELEMETRY:-1}"
export OPENSPEC_CONCURRENCY="${OPENSPEC_CONCURRENCY:-6}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/04.02_unsetenv_openspec.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: OpenSpec CLI
unset OPENSPEC_HOME
unset OPENSPEC_TELEMETRY
unset OPENSPEC_CONCURRENCY
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO (npm prefix local)
# ============================================================================
install_openspec() {
    log_step "=== OpenSpec CLI (lib/npm/openspec) ==="

    if tool_installed openspec; then
        log_info "OpenSpec ja instalado"
        "$OFFICEAI_ROOT/bin/openspec" --version 2>/dev/null || true
        return 0
    fi

    if ! command_exists npm; then
        log_error "npm nao encontrado (instale o Node.js: 01.04_LanguageNodeJS.sh)"
        return 1
    fi

    # Instala em lib/npm/openspec e linka bin/openspec (sem sudo)
    npm_prefix_install openspec "$NPM_PACKAGE" || return 1

    "$OFFICEAI_ROOT/bin/openspec" --version 2>/dev/null || true
    log_success "OpenSpec CLI instalado em $OPENSPEC_LIB_DIR"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do OpenSpec CLI..."
    generate_setenv
    generate_unsetenv
    install_openspec

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Inicializar: cd seu-projeto && openspec init"
}

main "$@"