#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 05.02_VisualVSCodium.sh
# Instalacao do VSCodium 100% local: release tarball do GitHub extraido em
# lib/vscodium, binario "codium" linkado em bin/. Nada fora da pasta.
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
VSCODIUM_LIB_DIR="$OFFICEAI_ROOT/lib/vscodium"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/05.02_setenv_vscodium.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: VSCodium (local em lib/vscodium)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export VSCODIUM_LIB_DIR="$OFFICEAI_ROOT/lib/vscodium"
# Extensoes ficam no HOME virtual (var/home/.vscode-oss/extensions)
export VSCODE_EXTENSIONS="${VSCODE_EXTENSIONS:-$OFFICEAI_ROOT/var/home/.vscode-oss/extensions}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export VSCODIUM_LIB_DIR="$OFFICEAI_ROOT/lib/vscodium"
export VSCODE_EXTENSIONS="${VSCODE_EXTENSIONS:-$OFFICEAI_ROOT/var/home/.vscode-oss/extensions}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/05.02_unsetenv_vscodium.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: VSCodium
unset VSCODIUM_LIB_DIR
unset VSCODE_EXTENSIONS
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# OBTER ULTIMO ASSET DE RELEASE
# ============================================================================
get_latest_asset() {
    local arch="$1"
    local api_url="https://api.github.com/repos/VSCodium/vscodium/releases/latest"
    local version asset
    version=$(curl -fsSL "$api_url" 2>/dev/null | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
    asset=$(curl -fsSL "$api_url" 2>/dev/null \
        | grep -o "\"name\":\"VSCodium-linux-${arch}-[^\"]*\.tar\.gz\"" | head -1 | cut -d'"' -f4 || echo "")
    if [[ -z "$version" || -z "$asset" ]]; then
        log_error "Nao foi possivel obter o release do VSCodium"
        return 1
    fi
    echo "https://github.com/VSCodium/vscodium/releases/download/${version}/${asset}"
}

# ============================================================================
# INSTALACAO (release tarball -> lib/vscodium, link_bin codium)
# ============================================================================
install_codium() {
    log_step "=== VSCodium (lib/vscodium) ==="

    if tool_installed codium; then
        log_info "VSCodium ja instalado"
        "$OFFICEAI_ROOT/bin/codium" --version 2>/dev/null | head -1 || true
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

    local URL
    URL=$(get_latest_asset "$ARCH_NAME") || return 1
    local TMP_DIR
    TMP_DIR=$(mktemp -d)

    log_info "Baixando: $URL"
    if ! curl -fSL --progress-bar "$URL" -o "$TMP_DIR/codium.tar.gz"; then
        log_error "Falha ao baixar o VSCodium"
        rm -rf "$TMP_DIR"
        return 1
    fi

    log_step "Extraindo em $VSCODIUM_LIB_DIR..."
    mkdir -p "$VSCODIUM_LIB_DIR"
    tar -xzf "$TMP_DIR/codium.tar.gz" -C "$VSCODIUM_LIB_DIR"
    rm -rf "$TMP_DIR"

    local CODIUM_BIN=""
    CODIUM_BIN=$(find "$VSCODIUM_LIB_DIR" -maxdepth 3 -type f -name codium -executable | head -1)
    if [[ -z "$CODIUM_BIN" ]]; then
        log_error "Binario codium nao encontrado apos extracao"
        return 1
    fi

    link_bin codium "$CODIUM_BIN"

    "$OFFICEAI_ROOT/bin/codium" --version 2>/dev/null | head -1 || true
    log_success "VSCodium instalado em $VSCODIUM_LIB_DIR"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do VSCodium..."
    generate_setenv
    generate_unsetenv
    install_codium

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Executar:  codium"
}

main "$@"