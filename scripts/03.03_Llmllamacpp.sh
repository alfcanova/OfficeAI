#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 03.03_Llmllamacpp.sh
# Instalacao do llama.cpp 100% local: release tarball extraido em lib/llamacpp,
# binarios linkados em bin/ via link_bin_dir. Nada fora da pasta OfficeAI.
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
LLAMA_LIB_DIR="$OFFICEAI_ROOT/lib/llamacpp"
LLAMA_BIN_DIR="$LLAMA_LIB_DIR/bin"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.03_setenv_llamacpp.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: llama.cpp (local em lib/llamacpp)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export LLAMA_CPP_HOME="$OFFICEAI_ROOT/lib/llamacpp"
export LLAMA_SERVER_HOST="${LLAMA_SERVER_HOST:-127.0.0.1}"
export LLAMA_SERVER_PORT="${LLAMA_SERVER_PORT:-8080}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export LLAMA_CPP_HOME="$OFFICEAI_ROOT/lib/llamacpp"
export LLAMA_SERVER_HOST="${LLAMA_SERVER_HOST:-127.0.0.1}"
export LLAMA_SERVER_PORT="${LLAMA_SERVER_PORT:-8080}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.03_unsetenv_llamacpp.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: llama.cpp
unset LLAMA_CPP_HOME
unset LLAMA_SERVER_HOST
unset LLAMA_SERVER_PORT
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# DETECCAO DE BACKEND
# ============================================================================
detect_backend() {
    local backend="cpu"
    if command_exists nvidia-smi && nvidia-smi &>/dev/null; then
        backend="cuda12"
        log_info "NVIDIA CUDA detectado (usando asset CPU pre-built, sem driver no container)"
    elif command_exists rocminfo; then
        backend="rocm"
        log_info "AMD ROCm detectado"
    elif command_exists vulkaninfo; then
        backend="vulkan"
        log_info "Vulkan detectado"
    else
        log_info "Usando backend CPU"
    fi
    echo "$backend"
}

# ============================================================================
# OBTER VERSAO MAIS RECENTE
# ============================================================================
get_latest_version() {
    local api_url="https://api.github.com/repos/ggml-org/llama.cpp/releases/latest"
    local version
    version=$(curl -fsSL "$api_url" 2>/dev/null | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4 || echo "")
    if [[ -z "$version" ]]; then
        version="b9975"
        log_warn "Nao foi possivel obter versao mais recente, usando $version"
    fi
    echo "$version"
}

# ============================================================================
# INSTALACAO (release tarball -> lib/llamacpp/bin, link_bin_dir)
# ============================================================================
install_llamacpp() {
    log_step "=== llama.cpp (lib/llamacpp) ==="

    if tool_installed llamacpp || [[ -x "$LLAMA_BIN_DIR/llama-server" ]]; then
        log_info "llama.cpp ja instalado"
        "$LLAMA_BIN_DIR/llama-server" --version 2>/dev/null || true
        return 0
    fi

    local ARCH
    ARCH=$(uname -m)
    local ARCH_NAME=""
    case "$ARCH" in
        x86_64|amd64)  ARCH_NAME="x64" ;;
        aarch64|arm64) ARCH_NAME="arm64" ;;
        s390x)         ARCH_NAME="s390x" ;;
        *) log_error "Arquitetura nao suportada: $ARCH"; return 1 ;;
    esac

    local BACKEND
    BACKEND=$(detect_backend)
    local VERSION
    VERSION=$(get_latest_version)
    log_info "Versao: $VERSION"

    local ASSET="llama-${VERSION}-bin-ubuntu-${ARCH_NAME}.tar.gz"
    case "$BACKEND" in
        vulkan) ASSET="llama-${VERSION}-bin-ubuntu-vulkan-${ARCH_NAME}.tar.gz" ;;
        rocm)   ASSET="llama-${VERSION}-bin-ubuntu-rocm-7.2-${ARCH_NAME}.tar.gz" ;;
        *)      ASSET="llama-${VERSION}-bin-ubuntu-${ARCH_NAME}.tar.gz" ;;
    esac

    local DOWNLOAD_URL="https://github.com/ggml-org/llama.cpp/releases/download/${VERSION}/${ASSET}"
    local TMP_DIR
    TMP_DIR=$(mktemp -d)

    log_info "Baixando: $DOWNLOAD_URL"
    if ! curl -fsSL -o "$TMP_DIR/$ASSET" "$DOWNLOAD_URL"; then
        log_error "Falha ao baixar $ASSET"
        rm -rf "$TMP_DIR"
        return 1
    fi

    log_step "Extraindo..."
    tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR"

    local EXTRACTED_DIR
    EXTRACTED_DIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "llama-*" | head -1)
    if [[ -z "$EXTRACTED_DIR" ]]; then
        log_error "Diretorio extraido nao encontrado"
        rm -rf "$TMP_DIR"
        return 1
    fi

    log_step "Instalando binarios em $LLAMA_BIN_DIR"
    mkdir -p "$LLAMA_BIN_DIR"
    local bin
    for bin in llama-server llama-cli llama-bench llama-quantize llama-perplexity \
               llama-embedding llama-gguf-split llama; do
        if [[ -f "$EXTRACTED_DIR/$bin" ]]; then
            cp "$EXTRACTED_DIR/$bin" "$LLAMA_BIN_DIR/"
            chmod +x "$LLAMA_BIN_DIR/$bin"
        fi
    done
    rm -rf "$TMP_DIR"

    # Linkar TODOS os executaveis para bin/ do prefixo
    link_bin_dir "" "$LLAMA_BIN_DIR"
    if [[ ! -e "$OFFICEAI_ROOT/bin/llama" && -x "$LLAMA_BIN_DIR/llama-server" ]]; then
        link_bin llama "$LLAMA_BIN_DIR/llama-server"
    fi

    if [[ -x "$LLAMA_BIN_DIR/llama-server" ]]; then
        log_success "llama.cpp instalado em $LLAMA_BIN_DIR"
        "$LLAMA_BIN_DIR/llama-server" --version 2>/dev/null || true
        return 0
    fi

    log_error "Falha ao instalar llama.cpp"
    return 1
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do llama.cpp..."
    generate_setenv
    generate_unsetenv
    install_llamacpp

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Servidor:  llama-server -m model.gguf --port 8080"
    log_info "CLI:       llama-cli -m model.gguf"
    log_info "Benchmark: llama-bench"
}

main "$@"