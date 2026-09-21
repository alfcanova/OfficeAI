#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 01.02_LanguageZig.sh
# Instalacao do Zig 100% local: runtimes em lib/zig, executavel em bin/
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
# CONSTANTES
# ============================================================================
TOOL_NAME="zig"
ZIG_LIB_DIR="$OFFICEAI_ROOT/lib/zig"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/01.02_setenv_zig.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Zig (runtime em lib/zig, binario em bin/)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export ZIG_LIB_DIR="$OFFICEAI_ROOT/lib/zig"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    cat > "$SETENV_MARKER" << 'EOF'
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export ZIG_LIB_DIR="$OFFICEAI_ROOT/lib/zig"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/01.02_unsetenv_zig.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Zig
unset ZIG_LIB_DIR
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_zig() {
    log_step "=== Zig 0.13.0 (local em lib/zig) ==="

    if [[ -x "$ZIG_LIB_DIR/zig" ]]; then
        log_info "Zig ja instalado no OfficeAI: $("$ZIG_LIB_DIR/zig" version)"
    else
        local ZIG_VERSION="0.13.0"
        local ZIG_PLATFORM ZIG_ARCH
        case "$(uname -s)" in
            Linux*)  ZIG_PLATFORM="linux" ;;
            Darwin*) ZIG_PLATFORM="macos" ;;
            *)       log_error "Plataforma nao suportada"; return 1 ;;
        esac
        case "$ARCH" in
            x86_64) ZIG_ARCH="x86_64" ;;
            arm64)  ZIG_ARCH="aarch64" ;;
            *)      log_error "Arquitetura nao suportada"; return 1 ;;
        esac

        local ZIG_DIR="zig-${ZIG_PLATFORM}-${ZIG_ARCH}-${ZIG_VERSION}"
        log_step "Baixando Zig ${ZIG_VERSION}..."
        wget -q "https://ziglang.org/download/${ZIG_VERSION}/${ZIG_DIR}.tar.xz" -P /tmp/

        mkdir -p "$ZIG_LIB_DIR"
        log_step "Instalando Zig em $ZIG_LIB_DIR..."
        tar -C "$ZIG_LIB_DIR" --strip-components=1 -xJf "/tmp/${ZIG_DIR}.tar.xz"
        rm -f "/tmp/${ZIG_DIR}.tar.xz"
    fi

    log_step "Linkando zig em bin/..."
    link_bin "zig" "$ZIG_LIB_DIR/zig"

    log_success "Zig instalado com sucesso!"
    "$ZIG_LIB_DIR/zig" version
}

main() {
    log_info "Iniciando instalacao do Zig..."
    detect_arch
    generate_setenv
    generate_unsetenv
    install_zig
    log_info "Instalacao concluida!"
    log_info "Ativar:      source etc/00_envGeneral.sh"
}

main "$@"