#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 02.03_CLIsAider.sh
# Instalacao do Aider CLI 100% local:
# - uv tool install (uv da fase 01 ou uv do PATH) -> bin/ direto via helper
# - se uv falhar: uv com python do sistema
# - fallback: venv Python local (lib/aider/venv) + link bin/aider
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
TOOL_NAME="aider"
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE (nomes mantidos: 02.03_setenv_aider.sh)
# ============================================================================
generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.03_setenv_aider.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Aider (uv tool/venv local, link em bin/)
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
    local SCRIPT="$OFFICEAI_ROOT/bin/02.03_unsetenv_aider.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Aider
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_aider() {
    log_step "=== Aider CLI (uv tool / venv local) ==="

    # a. Ja instalado?
    if tool_installed "$TOOL_NAME"; then
        log_info "Aider ja instalado no OfficeAI: $("$OFFICEAI_ROOT/bin/aider" --version 2>/dev/null || echo "versao desconhecida")"
        return 0
    fi

    # b. Metodo 1: uv tool install (uv de fase 01 ou uv do PATH; helper ja resolve)
    if uv_tool_install aider aider-chat; then
        log_success "Aider instalado via uv tool"
        "$OFFICEAI_ROOT/bin/aider" --version 2>/dev/null || true
        return 0
    fi
    log_warn "Falha via uv tool, tentando uv com python do sistema..."

    # b2. Metodo 2: uv com python do sistema (se python3 disponivel)
    local uv_bin="$OFFICEAI_ROOT/lib/languages/uv/uv"
    [[ -x "$uv_bin" ]] || uv_bin="$(command -v uv 2>/dev/null || true)"
    if command_exists python3 && [[ -n "$uv_bin" ]]; then
        mkdir -p "$OFFICEAI_ROOT/lib/uv-tools" "$OFFICEAI_ROOT/bin"
        export UV_TOOL_DIR="$OFFICEAI_ROOT/lib/uv-tools"
        export UV_TOOL_BIN_DIR="$OFFICEAI_ROOT/bin"
        export UV_CACHE_DIR="$OFFICEAI_ROOT/var/home/.cache/uv"
        if "$uv_bin" tool install --force --python python3 aider-chat; then
            log_success "Aider instalado via uv (python do sistema)"
            "$OFFICEAI_ROOT/bin/aider" --version 2>/dev/null || true
            return 0
        fi
        log_warn "Falha via uv+python do sistema, criando venv local..."
    fi

    # b3. Metodo 3 (fallback): venv Python local
    if command_exists python3 && python_venv_tool aider "$OFFICEAI_ROOT/lib/aider" python3 aider-chat; then
        log_success "Aider instalado via venv local"
        "$OFFICEAI_ROOT/bin/aider" --version 2>/dev/null || true
        return 0
    fi

    log_error "Falha ao instalar Aider"
    return 1
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Aider CLI..."
    generate_setenv
    generate_unsetenv
    install_aider
    log_info "Instalacao concluida!"
    log_info "Ativar: source etc/00_envGeneral.sh"
}

main "$@"