#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 03.08_LlmOpenClaw.sh
# Instalacao do OpenClaw 100% local: binario direto em lib/openclaw quando
# houver release; senao script oficial com HOME virtual (var/home) e binario
# movido para lib/openclaw. Nunca /usr/local nem ~/.local do host.
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
OPENCLAW_LIB_DIR="$OFFICEAI_ROOT/lib/openclaw"
OPENCLAW_BIN_DIR="$OPENCLAW_LIB_DIR/bin"
OPENCLAW_INSTALL_URL="https://openclaw.ai/install.sh"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.08_setenv_openclaw.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: OpenClaw (local em lib/openclaw)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export OPENCLAW_HOME="${OPENCLAW_HOME:-$OFFICEAI_ROOT/var/home}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export OPENCLAW_HOME="${OPENCLAW_HOME:-$OFFICEAI_ROOT/var/home}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.08_unsetenv_openclaw.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: OpenClaw
unset OPENCLAW_HOME
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO (binario direto; fallback script oficial com HOME virtual)
# ============================================================================
install_openclaw() {
    log_step "=== OpenClaw (lib/openclaw) ==="

    if tool_installed openclaw; then
        log_info "OpenClaw ja instalado"
        "$OFFICEAI_ROOT/bin/openclaw" --version 2>/dev/null || true
        return 0
    fi

    mkdir -p "$OPENCLAW_BIN_DIR"

    # Metodo 1: binario direto de release do GitHub (se existir)
    local ARCH
    ARCH=$(uname -m)
    local asset_name=""
    case "$ARCH" in
        x86_64|amd64)  asset_name="openclaw-linux-amd64" ;;
        aarch64|arm64) asset_name="openclaw-linux-arm64" ;;
    esac
    local direct_url="https://github.com/openclaw/openclaw/releases/latest/download/${asset_name}"
    if [[ -n "$asset_name" ]] && curl -fsSL -o "$OPENCLAW_BIN_DIR/openclaw" "$direct_url" 2>/dev/null; then
        chmod +x "$OPENCLAW_BIN_DIR/openclaw"
        link_bin openclaw "$OPENCLAW_BIN_DIR/openclaw"
        log_success "OpenClaw instalado via binario direto"
        "$OFFICEAI_ROOT/bin/openclaw" --version 2>/dev/null || true
        return 0
    fi

    # Metodo 2: script oficial com HOME virtual (tudo dentro de var/home)
    log_info "Binario direto indisponivel - usando script oficial com HOME virtual"
    export HOME="$OFFICEAI_ROOT/var/home"
    mkdir -p "$HOME/.local/bin"

    if ! curl -fsSL "$OPENCLAW_INSTALL_URL" | bash; then
        log_warn "Instalador oficial falhou (sem sudo, e o esperado em alguns casos)"
    fi

    # Localizar o binario dentro do HOME virtual e move-lo para lib/openclaw
    local bin_path=""
    bin_path=$(find "$HOME" -type f -name openclaw -executable 2>/dev/null | head -1)
    if [[ -z "$bin_path" ]]; then
        # Alguns instaladores usam wrapper com nome distinto
        bin_path=$(find "$HOME" -type f \( -name "*openclaw*" \) -executable 2>/dev/null | head -1)
    fi
    if [[ -z "$bin_path" ]]; then
        log_error "OpenClaw nao encontrado apos a instalacao"
        return 1
    fi

    cp "$bin_path" "$OPENCLAW_BIN_DIR/openclaw"
    chmod +x "$OPENCLAW_BIN_DIR/openclaw"
    link_bin openclaw "$OPENCLAW_BIN_DIR/openclaw"

    log_success "OpenClaw instalado em $OPENCLAW_BIN_DIR"
    "$OFFICEAI_ROOT/bin/openclaw" --version 2>/dev/null || true
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do OpenClaw..."
    generate_setenv
    generate_unsetenv
    install_openclaw

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Executar:  openclaw"
}

main "$@"