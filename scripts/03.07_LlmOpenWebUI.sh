#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 03.07_LlmOpenWebUI.sh
# Instalacao do Open WebUI 100% local: venv em lib/openwebui via
# python_venv_tool (console script open-webui linkado em bin/).
# NUNCA usa pip install --break-system-packages no sistema.
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
OPENWEBUI_LIB_DIR="$OFFICEAI_ROOT/lib/openwebui"
OPENWEBUI_DATA_DIR="$OFFICEAI_ROOT/share/openwebui"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.07_setenv_openwebui.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Open WebUI (local em lib/openwebui)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export OPEN_WEBUI_HOME="$OFFICEAI_ROOT/lib/openwebui"
export OPEN_WEBUI_DATA_DIR="${OPEN_WEBUI_DATA_DIR:-$OFFICEAI_ROOT/share/openwebui}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export OPEN_WEBUI_HOME="$OFFICEAI_ROOT/lib/openwebui"
export OPEN_WEBUI_DATA_DIR="${OPEN_WEBUI_DATA_DIR:-$OFFICEAI_ROOT/share/openwebui}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.07_unsetenv_openwebui.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Open WebUI
unset OPEN_WEBUI_HOME
unset OPEN_WEBUI_DATA_DIR
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO (venv local + console script open-webui)
# ============================================================================
install_openwebui() {
    log_step "=== Open WebUI (lib/openwebui) ==="

    if tool_installed open-webui || tool_installed openwebui; then
        log_info "Open WebUI ja instalado"
        "$OFFICEAI_ROOT/bin/open-webui" --version 2>/dev/null || true
        return 0
    fi

    if ! command_exists python3; then
        log_error "python3 nao encontrado (instale a fase 00/01 primeiro)"
        return 1
    fi

    # O pacote pip instala o console script "open-webui"; o helper cria a
    # venv em lib/openwebui/venv e linka bin/open-webui.
    python_venv_tool open-webui "$OPENWEBUI_LIB_DIR" python3 open-webui || return 1

    mkdir -p "$OPENWEBUI_DATA_DIR"
    "$OFFICEAI_ROOT/bin/open-webui" --version 2>/dev/null || true
    log_success "Open WebUI instalado em $OPENWEBUI_LIB_DIR"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Open WebUI..."
    generate_setenv
    generate_unsetenv
    install_openwebui

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Executar:  open-webui serve"
    log_info "WebUI:     http://127.0.0.1:8080"
}

main "$@"