#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 02.11_CLIsCline.sh
# Instalacao do Cline CLI 100% local: npm prefix local (lib/npm/cline) + link
# bin/cline. Instalacao 100% contida na pasta OfficeAI (nada sai do prefixo).
# CLINE_HOME aponta para lib/cline (contido).
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
TOOL_NAME="cline"
CLINE_HOME_DIR="$OFFICEAI_ROOT/lib/cline"
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE (nomes mantidos: 02.11_setenv_cline.sh)
# ============================================================================
generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.11_setenv_cline.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Cline CLI (npm local em lib/npm/cline, link em bin/)
# OFFICEAI_ROOT resolvido dinamicamente (portabilidade da pasta)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export CLINE_HOME="$OFFICEAI_ROOT/lib/cline"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai capturar (mesmos exports)
    cat > "$SETENV_MARKER" << 'EOF'
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export CLINE_HOME="$OFFICEAI_ROOT/lib/cline"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.11_unsetenv_cline.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Cline CLI
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
unset CLINE_HOME
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_cline() {
    log_step "=== Cline CLI (npm local em lib/npm/cline) ==="

    # a. Ja instalado?
    if tool_installed "$TOOL_NAME"; then
        log_info "Cline ja instalado no OfficeAI: $("$OFFICEAI_ROOT/bin/cline" --version 2>/dev/null || echo "versao desconhecida")"
        return 0
    fi

    # b. Garantir PATH com Node local (fase 01) e instalar via npm prefix
    export PATH="$OFFICEAI_ROOT/lib/node/bin:$OFFICEAI_ROOT/lib/npm/bin:$PATH"
    if npm_prefix_install cline cline; then
        mkdir -p "$CLINE_HOME_DIR"
        log_success "Cline instalado com sucesso"
        "$OFFICEAI_ROOT/bin/cline" --version 2>/dev/null || "$OFFICEAI_ROOT/bin/cline" -h 2>/dev/null || true
        return 0
    fi

    log_error "Falha ao instalar Cline CLI"
    return 1
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Cline CLI..."
    generate_setenv
    generate_unsetenv
    install_cline
    log_info "Instalacao concluida!"
    log_info "Ativar: source etc/00_envGeneral.sh"
}

main "$@"