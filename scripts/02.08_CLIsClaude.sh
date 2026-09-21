#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 02.08_CLIsClaude.sh
# Instalacao do Claude Code CLI 100% local:
# npm prefix local (lib/npm/claude, pacote @anthropic-ai/claude-code) + link
# bin/claude. Configuracoes ficam no HOME virtual (var/home/.claude).
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
TOOL_NAME="claude"
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE (nomes mantidos: 02.08_setenv_claude.sh)
# ============================================================================
generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.08_setenv_claude.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Claude (npm local em lib/npm/claude, link em bin/)
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
    local SCRIPT="$OFFICEAI_ROOT/bin/02.08_unsetenv_claude.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Claude
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_claude() {
    log_step "=== Claude Code CLI (npm local em lib/npm/claude) ==="

    # a. Ja instalado?
    if tool_installed "$TOOL_NAME"; then
        log_info "Claude ja instalado no OfficeAI: $("$OFFICEAI_ROOT/bin/claude" --version 2>/dev/null || echo "versao desconhecida")"
        return 0
    fi

    # b. Garantir PATH com Node local (fase 01) e instalar via npm prefix
    export PATH="$OFFICEAI_ROOT/lib/node/bin:$OFFICEAI_ROOT/lib/npm/bin:$PATH"
    if npm_prefix_install claude @anthropic-ai/claude-code; then
        log_success "Claude instalado com sucesso"
        "$OFFICEAI_ROOT/bin/claude" --version 2>/dev/null || "$OFFICEAI_ROOT/bin/claude" -h 2>/dev/null || true
        return 0
    fi

    log_error "Falha ao instalar Claude"
    return 1
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Claude Code CLI..."
    generate_setenv
    generate_unsetenv
    install_claude
    log_info "Instalacao concluida!"
    log_info "Ativar: source etc/00_envGeneral.sh"
}

main "$@"