#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 03.02_LlmOllama.sh
# Instalacao do Ollama 100% local: binario oficial baixado para lib/ollama,
# executavel linkado em bin/. Modelos em share/ollama-models.
# NUNCA usa o install.sh oficial (instalaria em /usr/local), nem ~/.ollama.
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
OLLAMA_LIB_DIR="$OFFICEAI_ROOT/lib/ollama"
OLLAMA_MODELS_DIR="$OFFICEAI_ROOT/share/ollama-models"

# URLs oficiais de download direto do binario (nao e o install.sh!)
OLLAMA_URL_AMD64="https://ollama.com/download/ollama-linux-amd64.tgz"
OLLAMA_URL_ARM64="https://ollama.com/download/ollama-linux-arm64.tgz"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.02_setenv_ollama.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Ollama (local em lib/ollama, modelos em share/)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"
export OLLAMA_MODELS="${OLLAMA_MODELS:-$OFFICEAI_ROOT/share/ollama-models}"
export OLLAMA_KEEP_ALIVE="${OLLAMA_KEEP_ALIVE:-24h}"
export OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL:-4}"
export OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS:-2}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"
export OLLAMA_MODELS="${OLLAMA_MODELS:-$OFFICEAI_ROOT/share/ollama-models}"
export OLLAMA_KEEP_ALIVE="${OLLAMA_KEEP_ALIVE:-24h}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.02_unsetenv_ollama.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Ollama
unset OLLAMA_HOST
unset OLLAMA_MODELS
unset OLLAMA_KEEP_ALIVE
unset OLLAMA_NUM_PARALLEL
unset OLLAMA_MAX_LOADED_MODELS
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO (binario oficial direto, sem install.sh)
# ============================================================================
install_ollama() {
    log_step "=== Ollama (lib/ollama) ==="

    if tool_installed ollama; then
        log_info "Ollama ja instalado"
        "$OFFICEAI_ROOT/bin/ollama" --version 2>/dev/null || true
        return 0
    fi

    local ARCH
    ARCH=$(uname -m)
    local OLLAMA_URL=""
    case "$ARCH" in
        x86_64|amd64)   OLLAMA_URL="$OLLAMA_URL_AMD64" ;;
        aarch64|arm64)  OLLAMA_URL="$OLLAMA_URL_ARM64" ;;
        *) log_error "Arquitetura nao suportada: $ARCH"; return 1 ;;
    esac

    local TMP_DIR
    TMP_DIR=$(mktemp -d)
    log_info "Baixando binario oficial: $OLLAMA_URL"
    if ! curl -fSL --progress-bar "$OLLAMA_URL" -o "$TMP_DIR/ollama.tgz"; then
        log_error "Falha ao baixar o Ollama"
        rm -rf "$TMP_DIR"
        return 1
    fi

    log_step "Extraindo..."
    tar -xzf "$TMP_DIR/ollama.tgz" -C "$TMP_DIR"

    # O tarball oficial contem o binario em bin/ollama (com libs auxiliares)
    local OLLAMA_BIN=""
    OLLAMA_BIN=$(find "$TMP_DIR" -type f -path "*/bin/ollama" | head -1)
    if [[ -z "$OLLAMA_BIN" ]]; then
        log_error "Binario ollama nao encontrado no tarball"
        rm -rf "$TMP_DIR"
        return 1
    fi

    mkdir -p "$OLLAMA_LIB_DIR/bin"
    cp "$OLLAMA_BIN" "$OLLAMA_LIB_DIR/bin/ollama"
    chmod +x "$OLLAMA_LIB_DIR/bin/ollama"
    rm -rf "$TMP_DIR"

    link_bin ollama "$OLLAMA_LIB_DIR/bin/ollama"

    # Modelos sempre dentro da pasta (share/ollama-models)
    mkdir -p "$OLLAMA_MODELS_DIR"
    export OLLAMA_MODELS="$OLLAMA_MODELS_DIR"

    "$OFFICEAI_ROOT/bin/ollama" --version 2>/dev/null || true
    log_success "Ollama instalado em $OLLAMA_LIB_DIR"
    log_info "Modelos ficam em: $OLLAMA_MODELS_DIR"
    return 0
}

# ============================================================================
# CONFIGURAR MODELOS (dica de uso)
# ============================================================================
setup_models() {
    log_step "Configurando modelos Ollama..."
    log_info "Inicie com: ollama serve"
    log_info "Baixe modelos com: ollama pull <modelo>"
    log_info "Recomendados: qwen2.5-coder:7b | llama3.1:8b | codellama:7b"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Ollama..."
    generate_setenv
    generate_unsetenv
    install_ollama
    setup_models

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Servidor:  ollama serve"
    log_info "Modelos:   ollama pull <modelo>"
}

main "$@"