#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 03.05_LlmJan.sh
# Instalacao do Jan AI 100% local: AppImage em lib/jan, extraido via
# --appimage-extract quando possivel (sem FUSE). Executavel linkado em bin/.
# Nunca usa /opt, .deb ou sudo.
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
JAN_LIB_DIR="$OFFICEAI_ROOT/lib/jan"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.05_setenv_jan.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Jan AI (local em lib/jan)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export JAN_HOME="${JAN_HOME:-$OFFICEAI_ROOT/var/home/.jan}"
export JAN_API_URL="${JAN_API_URL:-http://127.0.0.1:1337}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export JAN_HOME="${JAN_HOME:-$OFFICEAI_ROOT/var/home/.jan}"
export JAN_API_URL="${JAN_API_URL:-http://127.0.0.1:1337}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.05_unsetenv_jan.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Jan AI
unset JAN_HOME
unset JAN_API_URL
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO (AppImage -> lib/jan, extract -> link real)
# ============================================================================
install_jan() {
    log_step "=== Jan AI (lib/jan) ==="

    if tool_installed jan; then
        log_info "Jan ja instalado"
        return 0
    fi

    local ARCH
    ARCH=$(uname -m)
    local APPIMAGE_URL=""
    case "$ARCH" in
        x86_64|amd64)
            APPIMAGE_URL="https://app.jan.ai/download/latest/linux-amd64-appimage"
            ;;
        aarch64|arm64)
            log_error "AppImage ARM64 nao disponivel para o Jan"
            log_info "Consulte: https://github.com/janhq/jan/releases"
            return 1
            ;;
        *) log_error "Arquitetura nao suportada: $ARCH"; return 1 ;;
    esac

    mkdir -p "$JAN_LIB_DIR"
    local JAN_APPIMAGE="$JAN_LIB_DIR/jan.AppImage"

    log_info "Baixando AppImage: $APPIMAGE_URL"
    if ! curl -fSL --progress-bar "$APPIMAGE_URL" -o "$JAN_APPIMAGE"; then
        log_error "Falha ao baixar o Jan AI"
        return 1
    fi
    chmod +x "$JAN_APPIMAGE"

    # Tentar extrair (funciona sem FUSE); senao, linkar o AppImage.
    local TMP_DIR
    TMP_DIR=$(mktemp -d)
    local linked=""
    if ( cd "$TMP_DIR" && "$JAN_APPIMAGE" --appimage-extract >/dev/null 2>&1 ); then
        log_info "AppImage extraido, procurando executavel real..."
        local real_bin
        real_bin=$(find "$TMP_DIR/squashfs-root" -maxdepth 2 -type f \( -name jan -o -name lms \) -executable 2>/dev/null | head -1)
        if [[ -n "$real_bin" ]]; then
            cp "$real_bin" "$JAN_LIB_DIR/jan"
            chmod +x "$JAN_LIB_DIR/jan"
            link_bin jan "$JAN_LIB_DIR/jan"
            linked="yes"
        fi
    fi

    if [[ -z "$linked" ]]; then
        log_warn "Extracao nao disponivel - linkando o AppImage diretamente"
        link_bin jan "$JAN_APPIMAGE"
    fi
    rm -rf "$TMP_DIR" "$JAN_APPIMAGE" 2>/dev/null || true

    log_success "Jan AI instalado em $JAN_LIB_DIR"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Jan AI..."
    generate_setenv
    generate_unsetenv
    install_jan

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Executar:  jan"
    log_info "API:       http://127.0.0.1:1337"
}

main "$@"