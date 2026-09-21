#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 04.01_SDDsKiro.sh
# Instalacao do Kiro CLI 100% local: zip (ou zip musl) extraido em lib/kiro,
# executavel linkado em bin/kiro. Sem .deb, AppImage, sudo ou dpkg.
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
KIRO_LIB_DIR="$OFFICEAI_ROOT/lib/kiro"
KIRO_BIN_DIR="$KIRO_LIB_DIR/bin"

# URLs de download direto (zip)
KIRO_ZIP_X64_GLIBC="https://desktop-release.q.us-east-1.amazonaws.com/latest/kirocli-x64-linux.zip"
KIRO_ZIP_X64_MUSL="https://desktop-release.q.us-east-1.amazonaws.com/latest/kirocli-x64-linux-musl.zip"
KIRO_ZIP_ARM64="https://desktop-release.q.us-east-1.amazonaws.com/latest/kirocli-aarch64-linux.zip"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/04.01_setenv_kiro.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Kiro CLI (local em lib/kiro)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export KIRO_HOME="$OFFICEAI_ROOT/lib/kiro"
export KIRO_MODEL="${KIRO_MODEL:-claude-opus-4.6}"
export KIRO_THEME="${KIRO_THEME:-dark}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export KIRO_HOME="$OFFICEAI_ROOT/lib/kiro"
export KIRO_MODEL="${KIRO_MODEL:-claude-opus-4.6}"
export KIRO_THEME="${KIRO_THEME:-dark}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/04.01_unsetenv_kiro.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Kiro CLI
unset KIRO_HOME
unset KIRO_MODEL
unset KIRO_THEME
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# DETECTAR URL DO ZIP (glibc vs musl)
# ============================================================================
detect_zip_url() {
    local ARCH
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)
            # glibc nova (>= 2.34) -> zip normal; senao zip musl
            if command_exists ldd && ldd --version 2>&1 | grep -qE "2\.(3[4-9]|[4-9][0-9])"; then
                echo "$KIRO_ZIP_X64_GLIBC"
            else
                echo "$KIRO_ZIP_X64_MUSL"
            fi
            ;;
        aarch64|arm64)
            echo "$KIRO_ZIP_ARM64"
            ;;
        *)
            log_error "Arquitetura nao suportada: $ARCH"
            return 1
            ;;
    esac
}

# ============================================================================
# INSTALACAO (zip local -> lib/kiro, link_bin kiro)
# ============================================================================
install_kiro() {
    log_step "=== Kiro CLI (lib/kiro) ==="

    if tool_installed kiro; then
        log_info "Kiro ja instalado"
        "$OFFICEAI_ROOT/bin/kiro" --version 2>/dev/null || true
        return 0
    fi

    local ZIP_URL
    ZIP_URL=$(detect_zip_url) || return 1

    local TMP_DIR
    TMP_DIR=$(mktemp -d)
    log_info "Baixando: $ZIP_URL"
    if ! curl -fsSL "$ZIP_URL" -o "$TMP_DIR/kirocli.zip"; then
        log_error "Falha ao baixar o Kiro CLI"
        rm -rf "$TMP_DIR"
        return 1
    fi

    log_step "Extraindo..."
    unzip -q "$TMP_DIR/kirocli.zip" -d "$TMP_DIR"

    # Localizar executavel (kiro/kiro-cli) dentro do zip
    local KIRO_BIN=""
    KIRO_BIN=$(find "$TMP_DIR" -type f \( -name kiro -o -name kiro-cli \) -executable 2>/dev/null | head -1)
    if [[ -z "$KIRO_BIN" ]]; then
        KIRO_BIN=$(find "$TMP_DIR" -type f \( -name kiro -o -name kiro-cli \) 2>/dev/null | head -1)
    fi
    if [[ -z "$KIRO_BIN" ]]; then
        log_error "Binario kiro nao encontrado no zip"
        rm -rf "$TMP_DIR"
        return 1
    fi

    mkdir -p "$KIRO_BIN_DIR"
    cp "$KIRO_BIN" "$KIRO_BIN_DIR/kiro"
    chmod +x "$KIRO_BIN_DIR/kiro"
    rm -rf "$TMP_DIR"

    link_bin kiro "$KIRO_BIN_DIR/kiro"

    "$OFFICEAI_ROOT/bin/kiro" --version 2>/dev/null || true
    log_success "Kiro CLI instalado em $KIRO_BIN_DIR"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Kiro CLI..."
    generate_setenv
    generate_unsetenv
    install_kiro

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Executar:  kiro"
}

main "$@"