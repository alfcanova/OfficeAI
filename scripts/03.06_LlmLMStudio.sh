#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 03.06_LlmLMStudio.sh
# Instalacao do LM Studio 100% local: AppImage em lib/lmstudio, extraido via
# --appimage-extract quando possivel; executavel (lms/llmster) linkado em bin/.
# Nunca usa o install.sh oficial nem ~/.lmstudio do host.
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
LM_LIB_DIR="$OFFICEAI_ROOT/lib/lmstudio"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.06_setenv_lmstudio.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: LM Studio (local em lib/lmstudio)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export LM_STUDIO_HOME="${LM_STUDIO_HOME:-$OFFICEAI_ROOT/var/home/.lmstudio}"
export LM_STUDIO_API_URL="${LM_STUDIO_API_URL:-http://127.0.0.1:1234/v1}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export LM_STUDIO_HOME="${LM_STUDIO_HOME:-$OFFICEAI_ROOT/var/home/.lmstudio}"
export LM_STUDIO_API_URL="${LM_STUDIO_API_URL:-http://127.0.0.1:1234/v1}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/03.06_unsetenv_lmstudio.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: LM Studio
unset LM_STUDIO_HOME
unset LM_STUDIO_API_URL
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO (AppImage -> lib/lmstudio, extract -> link real)
# ============================================================================
install_lmstudio() {
    log_step "=== LM Studio (lib/lmstudio) ==="

    if tool_installed lmstudio; then
        log_info "LM Studio ja instalado"
        "$OFFICEAI_ROOT/bin/lms" --version 2>/dev/null || true
        return 0
    fi

    local ARCH
    ARCH=$(uname -m)
    local APPIMAGE_URL=""
    case "$ARCH" in
        x86_64|amd64)  APPIMAGE_URL="https://lmstudio.ai/download/linux-x64" ;;
        aarch64|arm64) APPIMAGE_URL="https://lmstudio.ai/download/linux-arm64" ;;
        *) log_error "Arquitetura nao suportada: $ARCH"; return 1 ;;
    esac

    mkdir -p "$LM_LIB_DIR"
    local LM_APPIMAGE="$LM_LIB_DIR/lmstudio.AppImage"

    log_info "Baixando AppImage: $APPIMAGE_URL"
    if ! curl -fSL --progress-bar -L "$APPIMAGE_URL" -o "$LM_APPIMAGE"; then
        log_error "Falha ao baixar o LM Studio"
        return 1
    fi
    chmod +x "$LM_APPIMAGE"

    # Tentar extrair (funciona sem FUSE); senao, linkar o AppImage.
    local TMP_DIR
    TMP_DIR=$(mktemp -d)
    local linked=""
    if ( cd "$TMP_DIR" && "$LM_APPIMAGE" --appimage-extract >/dev/null 2>&1 ); then
        log_info "AppImage extraido, procurando executavel real..."
        local real_bin
        real_bin=$(find "$TMP_DIR/squashfs-root" -maxdepth 3 -type f \
            \( -name lms -o -name llmster -o -name "lm-studio" -o -name lmstudio \) \
            -executable 2>/dev/null | head -1)
        if [[ -n "$real_bin" ]]; then
            [[ "$(basename "$real_bin")" == "lms" ]] && ln -sf "$real_bin" "$TMP_DIR/.lms_link"
            cp "$real_bin" "$LM_LIB_DIR/lms"
            chmod +x "$LM_LIB_DIR/lms"
            link_bin lms "$LM_LIB_DIR/lms"
            link_bin lmstudio "$LM_LIB_DIR/lms"
            linked="yes"
        fi
    fi

    if [[ -z "$linked" ]]; then
        log_warn "Extracao nao disponivel - linkando o AppImage diretamente"
        link_bin lmstudio "$LM_APPIMAGE"
    fi
    rm -rf "$TMP_DIR" 2>/dev/null || true

    log_success "LM Studio instalado em $LM_LIB_DIR"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do LM Studio..."
    generate_setenv
    generate_unsetenv
    install_lmstudio

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Daemon:    lms daemon up"
    log_info "Servidor:  lms server start"
    log_info "Modelos:   lms get <modelo>"
}

main "$@"