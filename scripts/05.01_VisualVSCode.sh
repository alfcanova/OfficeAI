#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 05.01_VisualVSCode.sh
# Instalacao do VS Code 100% local: tarball oficial extraido em lib/vscode,
# binario "code" linkado em bin/. Nenhum pacote do sistema e tocado.
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
VSCODE_LIB_DIR="$OFFICEAI_ROOT/lib/vscode"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/05.01_setenv_vscode.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: VS Code (local em lib/vscode)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export VSCODE_LIB_DIR="$OFFICEAI_ROOT/lib/vscode"
# Extensoes ficam no HOME virtual (var/home/.vscode/extensions)
export VSCODE_EXTENSIONS="${VSCODE_EXTENSIONS:-$OFFICEAI_ROOT/var/home/.vscode/extensions}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export VSCODE_LIB_DIR="$OFFICEAI_ROOT/lib/vscode"
export VSCODE_EXTENSIONS="${VSCODE_EXTENSIONS:-$OFFICEAI_ROOT/var/home/.vscode/extensions}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/05.01_unsetenv_vscode.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: VS Code
unset VSCODE_LIB_DIR
unset VSCODE_EXTENSIONS
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO (tarball oficial -> lib/vscode, link_bin code)
# ============================================================================
install_vscode() {
    log_step "=== VS Code (lib/vscode) ==="

    if tool_installed code; then
        log_info "VS Code ja instalado"
        "$OFFICEAI_ROOT/bin/code" --version 2>/dev/null | head -1 || true
        return 0
    fi

    local ARCH
    ARCH=$(uname -m)
    local ARCH_NAME=""
    case "$ARCH" in
        x86_64|amd64)  ARCH_NAME="x64" ;;
        aarch64|arm64) ARCH_NAME="arm64" ;;
        *) log_error "Arquitetura nao suportada: $ARCH"; return 1 ;;
    esac

    local VSCODE_URL="https://update.code.visualstudio.com/latest/linux-${ARCH_NAME}/stable"
    local TMP_DIR
    TMP_DIR=$(mktemp -d)

    log_info "Baixando: $VSCODE_URL"
    if ! curl -fSL --progress-bar "$VSCODE_URL" -o "$TMP_DIR/vscode.tar.gz"; then
        log_error "Falha ao baixar o VS Code"
        rm -rf "$TMP_DIR"
        return 1
    fi

    log_step "Extraindo em $VSCODE_LIB_DIR..."
    mkdir -p "$VSCODE_LIB_DIR"
    tar -xzf "$TMP_DIR/vscode.tar.gz" -C "$VSCODE_LIB_DIR"
    rm -rf "$TMP_DIR"

    # O tarball contem a pasta VSCode-linux-<arch>/ com o binario code
    local CODE_BIN=""
    CODE_BIN=$(find "$VSCODE_LIB_DIR" -maxdepth 2 -type f -name code -path "*/bin/code" | head -1)
    if [[ -z "$CODE_BIN" ]]; then
        CODE_BIN=$(find "$VSCODE_LIB_DIR" -maxdepth 3 -type f -name code -executable | head -1)
    fi
    if [[ -z "$CODE_BIN" ]]; then
        log_error "Binario code nao encontrado apos extracao"
        return 1
    fi

    link_bin code "$CODE_BIN"

    "$OFFICEAI_ROOT/bin/code" --version 2>/dev/null | head -1 || true
    log_success "VS Code instalado em $VSCODE_LIB_DIR"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do VS Code..."
    generate_setenv
    generate_unsetenv
    install_vscode

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Executar:  code"
}

main "$@"