#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 03.01_LlmvLLM.sh
# Instalacao do vLLM 100% local: venv em lib/vllm, executavel linkado em bin/.
# Layout auto-contido: nada e instalado no sistema, HOME ou /usr/local.
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
VLLM_LIB_DIR="$OFFICEAI_ROOT/lib/vllm"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.01_setenv_vllm.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: vLLM (local em lib/vllm)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export VLLM_API_URL="${VLLM_API_URL:-http://127.0.0.1:8000}"
export VLLM_WORKSPACE="${VLLM_WORKSPACE:-$OFFICEAI_ROOT/share/vllm}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export VLLM_API_URL="${VLLM_API_URL:-http://127.0.0.1:8000}"
export VLLM_WORKSPACE="${VLLM_WORKSPACE:-$OFFICEAI_ROOT/share/vllm}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.01_unsetenv_vllm.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: vLLM
unset VLLM_API_URL
unset VLLM_WORKSPACE
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO (venv local + console script vllm)
# ============================================================================
install_vllm() {
    log_step "=== vLLM (lib/vllm) ==="

    if tool_installed vllm; then
        log_info "vLLM ja instalado"
        "$OFFICEAI_ROOT/bin/vllm" --version 2>/dev/null || true
        return 0
    fi

    if ! command_exists python3; then
        log_error "python3 nao encontrado (instale a fase 00/01 primeiro)"
        return 1
    fi

    # NOTA (CUDA): vLLM exige um torch compilado para CUDA. Em GPU NVIDIA
    # instalamos o torch do index CUDA antes do vLLM; em CPU/AMD usamos o
    # torch padrao do PyPI (documentado, sem sudo).
    if command_exists nvidia-smi && nvidia-smi &>/dev/null; then
        log_info "GPU NVIDIA detectada - usando torch CUDA (index cu128)"
        mkdir -p "$VLLM_LIB_DIR"
        if ! python3 -m venv "$VLLM_LIB_DIR/venv"; then
            log_error "Falha ao criar venv do vLLM"
            return 1
        fi
        log_step "venv: pip install torch CUDA (pode demorar)..."
        "$VLLM_LIB_DIR/venv/bin/pip" install --quiet \
            torch --index-url https://download.pytorch.org/whl/cu128 || return 1
        log_step "venv: pip install vllm (pode demorar)..."
        "$VLLM_LIB_DIR/venv/bin/pip" install --quiet vllm || return 1
        link_bin vllm "$VLLM_LIB_DIR/venv/bin/vllm"
    else
        log_info "Sem GPU NVIDIA - instalando vLLM com torch padrao (CPU)"
        python_venv_tool vllm "$VLLM_LIB_DIR" python3 vllm || return 1
    fi

    "$OFFICEAI_ROOT/bin/vllm" --version 2>/dev/null || true
    log_success "vLLM instalado em $VLLM_LIB_DIR"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do vLLM..."
    generate_setenv
    generate_unsetenv
    install_vllm

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Servidor:  vllm serve --model <modelo> --port 8000"
    log_info "API:       http://127.0.0.1:8000"
}

main "$@"