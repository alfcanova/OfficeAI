#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 03.04_LlmLocalAI.sh
# Instalacao do LocalAI 100% local: binario oficial direto em lib/localai,
# link_bin local-ai. Modelos em share/localai/models. Sem Docker/sudo//opt.
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
LOCALAI_LIB_DIR="$OFFICEAI_ROOT/lib/localai"
LOCALAI_BIN_DIR="$LOCALAI_LIB_DIR/bin"
LOCALAI_MODELS_DIR="$OFFICEAI_ROOT/share/localai/models"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.04_setenv_localai.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: LocalAI (local em lib/localai)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export LOCALAI_API_URL="${LOCALAI_API_URL:-http://127.0.0.1:8080}"
export LOCALAI_MODELS="${LOCALAI_MODELS:-$OFFICEAI_ROOT/share/localai/models}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export LOCALAI_API_URL="${LOCALAI_API_URL:-http://127.0.0.1:8080}"
export LOCALAI_MODELS="${LOCALAI_MODELS:-$OFFICEAI_ROOT/share/localai/models}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.04_unsetenv_localai.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: LocalAI
unset LOCALAI_API_URL
unset LOCALAI_MODELS
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO (binario direto -> lib/localai/bin/local-ai)
# ============================================================================
install_localai() {
    log_step "=== LocalAI (lib/localai) ==="

    if tool_installed localai; then
        log_info "LocalAI ja instalado"
        "$OFFICEAI_ROOT/bin/local-ai" --help 2>/dev/null | head -3 || true
        return 0
    fi

    local ARCH
    ARCH=$(uname -m)
    local BINARY_NAME=""
    case "$ARCH" in
        x86_64|amd64)  BINARY_NAME="local-ai" ;;
        aarch64|arm64) BINARY_NAME="local-ai-arm64" ;;
        *) log_error "Arquitetura nao suportada: $ARCH"; return 1 ;;
    esac

    local BINARY_URL="https://github.com/mudler/LocalAI/releases/latest/download/${BINARY_NAME}"
    mkdir -p "$LOCALAI_BIN_DIR"

    log_info "Baixando: $BINARY_URL"
    if ! curl -fSL --progress-bar "$BINARY_URL" -o "$LOCALAI_BIN_DIR/local-ai"; then
        log_error "Falha ao baixar o LocalAI"
        return 1
    fi
    chmod +x "$LOCALAI_BIN_DIR/local-ai"

    link_bin local-ai "$LOCALAI_BIN_DIR/local-ai"
    mkdir -p "$LOCALAI_MODELS_DIR"

    log_success "LocalAI instalado em $LOCALAI_BIN_DIR"
    log_info "Modelos ficam em: $LOCALAI_MODELS_DIR"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do LocalAI..."
    generate_setenv
    generate_unsetenv
    install_localai

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Servidor:  local-ai"
    log_info "API:       http://127.0.0.1:8080"
}

main "$@"