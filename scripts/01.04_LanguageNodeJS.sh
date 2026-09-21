#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 01.04_LanguageNodeJS.sh
# Instalacao do Node.js 100% local: runtime em lib/node, npm prefix em
# lib/npm, bun em lib/bun. Executaveis linkados em bin/.
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
NODE_LIB_DIR="$OFFICEAI_ROOT/lib/node"
NPM_PREFIX_DIR="$OFFICEAI_ROOT/lib/npm"
BUN_LIB_DIR="$OFFICEAI_ROOT/lib/bun"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/01.04_setenv_nodejs.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Node.js + npm + bun (local em lib/)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export NODE_HOME="$OFFICEAI_ROOT/lib/node"
export NPM_CONFIG_PREFIX="$OFFICEAI_ROOT/lib/npm"
export BUN_INSTALL="$OFFICEAI_ROOT/lib/bun"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    cat > "$SETENV_MARKER" << 'EOF'
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export NODE_HOME="$OFFICEAI_ROOT/lib/node"
export NPM_CONFIG_PREFIX="$OFFICEAI_ROOT/lib/npm"
export BUN_INSTALL="$OFFICEAI_ROOT/lib/bun"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/01.04_unsetenv_nodejs.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Node.js
unset NODE_HOME NPM_CONFIG_PREFIX BUN_INSTALL
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO DO NODE.JS
# ============================================================================
install_nodejs() {
    log_step "=== Node.js LTS (local em lib/node) ==="

    if [[ -x "$NODE_LIB_DIR/bin/node" ]]; then
        log_info "Node.js ja instalado: $("$NODE_LIB_DIR/bin/node" --version)"
    else
        mkdir -p "$NODE_LIB_DIR"
        local NODE_VERSION="v22.16.0"
        local NODE_TARBALL="node-${NODE_VERSION}-${OS}-${ARCH}.tar.xz"
        local NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/${NODE_TARBALL}"
        local TMP_DIR
        TMP_DIR=$(mktemp -d)

        log_info "URL: $NODE_URL"
        if ! curl -fSL --progress-bar "$NODE_URL" -o "$TMP_DIR/$NODE_TARBALL"; then
            log_error "Falha ao baixar Node.js"
            rm -rf "$TMP_DIR"
            return 1
        fi

        log_step "Extraindo Node.js..."
        tar -xJf "$TMP_DIR/$NODE_TARBALL" -C "$TMP_DIR"
        local EXTRACTED_DIR="$TMP_DIR/node-${NODE_VERSION}-${OS}-${ARCH}"
        if [[ -d "$EXTRACTED_DIR" ]]; then
            cp -a "$EXTRACTED_DIR/"* "$NODE_LIB_DIR/"
        else
            log_error "Diretorio extraido nao encontrado"
            rm -rf "$TMP_DIR"
            return 1
        fi
        rm -rf "$TMP_DIR"

        if [[ ! -x "$NODE_LIB_DIR/bin/node" ]]; then
            log_error "Falha ao instalar Node.js"
            return 1
        fi
        log_success "Node.js instalado: $("$NODE_LIB_DIR/bin/node" --version)"
    fi
}

# ============================================================================
# GERENCIADORES DE PACOTES
# ============================================================================
install_yarn() {
    log_step "Instalando yarn (npm prefix em lib/npm)..."
    [[ -x "$NPM_PREFIX_DIR/bin/yarn" ]] && { log_info "yarn ja instalado"; return 0; }
    NPM_CONFIG_PREFIX="$NPM_PREFIX_DIR" PATH="$NODE_LIB_DIR/bin:$NPM_PREFIX_DIR/bin:$PATH" \
        "$NODE_LIB_DIR/bin/npm" install -g yarn --no-audit --no-fund || { log_error "Falha ao instalar yarn"; return 1; }
    link_bin_dir "" "$NPM_PREFIX_DIR/bin"
}

install_pnpm() {
    log_step "Instalando pnpm (npm prefix em lib/npm)..."
    [[ -x "$NPM_PREFIX_DIR/bin/pnpm" ]] && { log_info "pnpm ja instalado"; return 0; }
    NPM_CONFIG_PREFIX="$NPM_PREFIX_DIR" PATH="$NODE_LIB_DIR/bin:$NPM_PREFIX_DIR/bin:$PATH" \
        "$NODE_LIB_DIR/bin/npm" install -g pnpm --no-audit --no-fund || { log_error "Falha ao instalar pnpm"; return 1; }
    link_bin_dir "" "$NPM_PREFIX_DIR/bin"
}

install_bun() {
    log_step "Instalando bun em lib/bun..."
    [[ -x "$BUN_LIB_DIR/bin/bun" ]] && { log_info "bun ja instalado"; return 0; }
    BUN_INSTALL="$BUN_LIB_DIR" curl -fsSL https://bun.sh/install | bash || {
        # fallback: copiar de ~/.bun/bin se instalou fora
        if [[ -x "$HOME/.bun/bin/bun" ]]; then
            mkdir -p "$BUN_LIB_DIR/bin"
            cp "$HOME/.bun/bin/bun" "$BUN_LIB_DIR/bin/bun"
        else
            log_error "Falha ao instalar bun"
            return 1
        fi
    }
    [[ -x "$BUN_LIB_DIR/bin/bun" ]] && link_bin "bun" "$BUN_LIB_DIR/bin/bun"
}

# ============================================================================
# INSTALACAO COMPLETA
# ============================================================================
install_all() {
    log_step "=== Instalacao Completa: Node.js + Gerenciadores ==="

    mkdir -p "$NODE_LIB_DIR" "$NPM_PREFIX_DIR" "$BUN_LIB_DIR"

    install_nodejs

    # Linkar binarios do runtime (node, npm, npx)
    link_bin_dir "" "$NODE_LIB_DIR/bin"

    install_yarn
    install_pnpm
    install_bun

    # npm global installs (eslint, typescript...) caem em lib/npm
    if [[ -x "$NODE_LIB_DIR/bin/npm" ]]; then
        NPM_CONFIG_PREFIX="$NPM_PREFIX_DIR" PATH="$NODE_LIB_DIR/bin:$NPM_PREFIX_DIR/bin:$PATH" \
            "$NODE_LIB_DIR/bin/npm" install -g pnpm eslint prettier typescript ts-node nodemon \
            --no-audit --no-fund || log_warn "Algumas ferramentas globais nao instaladas"
        link_bin_dir "" "$NPM_PREFIX_DIR/bin"
    fi

    generate_setenv
    generate_unsetenv

    log_success "=== Instalacao Concluida ==="
    log_info "Node.js: $("$NODE_LIB_DIR/bin/node" --version)"
    log_info "npm:     $("$NODE_LIB_DIR/bin/npm" --version)"
    [[ -x "$NPM_PREFIX_DIR/bin/yarn" ]] && log_info "yarn:    $("$NPM_PREFIX_DIR/bin/yarn" --version)"
    [[ -x "$NPM_PREFIX_DIR/bin/pnpm" ]] && log_info "pnpm:    $("$NPM_PREFIX_DIR/bin/pnpm" --version)"
    [[ -x "$BUN_LIB_DIR/bin/bun" ]] && log_info "bun:     $("$BUN_LIB_DIR/bin/bun" --version)"
}

# ============================================================================
# EXECUCAO
# ============================================================================
main() {
    log_info "Iniciando instalacao do Node.js..."
    detect_arch
    detect_os
    install_all
    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
}

if [[ "${1:-}" == "--menu" ]]; then
    main
else
    main "$@"
fi