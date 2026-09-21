#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 01.03_LanguageGo.sh
# Instalacao do Go 100% local: runtimes em lib/go, executaveis em bin/
# GOBIN aponta para bin/ -> `go install` cai direto no prefixo.
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
TOOL_NAME="go"
GO_LIB_DIR="$OFFICEAI_ROOT/lib/go"
GOBIN_DIR="$OFFICEAI_ROOT/bin"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/01.03_setenv_go.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Go (runtime em lib/go, GOBIN=bin/)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export GOPATH="$OFFICEAI_ROOT/var/home/go"
export GOBIN="$OFFICEAI_ROOT/bin"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    cat > "$SETENV_MARKER" << 'EOF'
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export GOPATH="$OFFICEAI_ROOT/var/home/go"
export GOBIN="$OFFICEAI_ROOT/bin"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/01.03_unsetenv_go.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Go
unset GOPATH GOBIN
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_go() {
    log_step "=== Go + Ferramentas (local em lib/go) ==="

    if [[ -x "$GO_LIB_DIR/bin/go" ]]; then
        log_info "Go ja instalado no OfficeAI: $("$GO_LIB_DIR/bin/go" version)"
    else
        local GO_VERSION="1.22.5"
        local GO_PLATFORM GO_ARCH
        case "$(uname -s)" in
            Linux*)  GO_PLATFORM="linux" ;;
            Darwin*) GO_PLATFORM="darwin" ;;
            *)       log_error "Plataforma nao suportada"; return 1 ;;
        esac
        case "$ARCH" in
            x86_64) GO_ARCH="amd64" ;;
            arm64)  GO_ARCH="arm64" ;;
            *)      log_error "Arquitetura nao suportada"; return 1 ;;
        esac

        local GO_ARCHIVE="go${GO_VERSION}.${GO_PLATFORM}-${GO_ARCH}.tar.gz"
        log_step "Baixando Go ${GO_VERSION}..."
        wget -q "https://go.dev/dl/${GO_ARCHIVE}" -P /tmp/

        mkdir -p "$GO_LIB_DIR"
        log_step "Instalando Go em $GO_LIB_DIR..."
        tar -C "$GO_LIB_DIR" --strip-components=1 -xzf "/tmp/${GO_ARCHIVE}"
        rm -f "/tmp/${GO_ARCHIVE}"
        log_info "Go instalado em $GO_LIB_DIR"
    fi

    log_step "Instalando ferramentas Go (GOBIN=bin/)..."
    export GOBIN="$GOBIN_DIR"
    mkdir -p "$GOBIN_DIR"
    PATH="$GO_LIB_DIR/bin:$PATH" GOPATH="$OFFICEAI_ROOT/var/home/go" HOME="$OFFICEAI_ROOT/var/home" \
        go install golang.org/x/tools/gopls@latest || true
    PATH="$GO_LIB_DIR/bin:$PATH" GOPATH="$OFFICEAI_ROOT/var/home/go" HOME="$OFFICEAI_ROOT/var/home" \
        go install github.com/go-delve/delve/cmd/dlv@latest || true
    PATH="$GO_LIB_DIR/bin:$PATH" GOPATH="$OFFICEAI_ROOT/var/home/go" HOME="$OFFICEAI_ROOT/var/home" \
        go install honnef.co/go/tools/cmd/staticcheck@latest || true
    PATH="$GO_LIB_DIR/bin:$PATH" GOPATH="$OFFICEAI_ROOT/var/home/go" HOME="$OFFICEAI_ROOT/var/home" \
        go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest || true

    # Linkar binarios do runtime
    log_step "Linkando go/gofmt e ferramentas em bin/..."
    link_bin_dir "" "$GO_LIB_DIR/bin"
    link_bin_dir "" "$GOBIN_DIR"

    log_success "Go instalado com sucesso!"
    "$GO_LIB_DIR/bin/go" version
}

main() {
    log_info "Iniciando instalacao do Go..."
    detect_arch
    generate_setenv
    generate_unsetenv
    install_go
    log_info "Instalacao concluida!"
    log_info "Ativar:      source etc/00_envGeneral.sh"
}

main "$@"