#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 01.01_LanguageRust.sh
# Instalacao do Rust 100% local: runtimes em lib/rust, executaveis em bin/
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

# Inicializacao padrao
script_init "$(basename "$0" .sh)"
prefix_ensure_structure

# ============================================================================
# CONSTANTES (layout auto-contido)
# ============================================================================
TOOL_NAME="rust"
RUST_LIB_DIR="$OFFICEAI_ROOT/lib/rust"          # runtimes
CARGO_HOME_DIR="$RUST_LIB_DIR/cargo"
RUSTUP_HOME_DIR="$RUST_LIB_DIR/rustup"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE (dinamicos -> portabilidade)
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/01.01_setenv_rust.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Rust (runtimes em lib/rust, binarios em bin/)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
if [[ -d "$OFFICEAI_ROOT/lib/rust/home" ]]; then
    export CARGO_HOME="$OFFICEAI_ROOT/lib/rust/home"
    export RUSTUP_HOME="$OFFICEAI_ROOT/lib/rust/home"
else
    export CARGO_HOME="$OFFICEAI_ROOT/lib/rust/cargo"
    export RUSTUP_HOME="$OFFICEAI_ROOT/lib/rust/rustup"
fi
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    cat > "$SETENV_MARKER" << 'EOF'
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
if [[ -d "$OFFICEAI_ROOT/lib/rust/home" ]]; then
    export CARGO_HOME="$OFFICEAI_ROOT/lib/rust/home"
    export RUSTUP_HOME="$OFFICEAI_ROOT/lib/rust/home"
else
    export CARGO_HOME="$OFFICEAI_ROOT/lib/rust/cargo"
    export RUSTUP_HOME="$OFFICEAI_ROOT/lib/rust/rustup"
fi
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/01.01_unsetenv_rust.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Rust
unset CARGO_HOME RUSTUP_HOME
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_rust() {
    log_step "=== Rust + Cargo Tools (local em lib/rust) ==="

    mkdir -p "$CARGO_HOME_DIR" "$RUSTUP_HOME_DIR"

    if [[ -x "$CARGO_HOME_DIR/bin/rustc" ]]; then
        log_info "Rust ja instalado: $(CARGO_HOME="$CARGO_HOME_DIR" RUSTUP_HOME="$RUSTUP_HOME_DIR" "$CARGO_HOME_DIR/bin/rustc" --version)"
    else
        log_step "Instalando Rust via rustup (RUSTUP_HOME=$RUSTUP_HOME_DIR)..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
            env CARGO_HOME="$CARGO_HOME_DIR" RUSTUP_HOME="$RUSTUP_HOME_DIR" sh -s -- -y --default-toolchain stable --no-modify-path

        if [[ ! -x "$CARGO_HOME_DIR/bin/rustc" ]]; then
            log_error "Falha ao instalar Rust"
            return 1
        fi
    fi

    local RUST_ENV=(
        "CARGO_HOME=$CARGO_HOME_DIR"
        "RUSTUP_HOME=$RUSTUP_HOME_DIR"
        "PATH=$CARGO_HOME_DIR/bin:$PATH"
    )

    log_step "Instalando componentes Rust..."
    env "${RUST_ENV[@]}" rustup default stable 2>/dev/null || true
    env "${RUST_ENV[@]}" rustup component add rustfmt clippy rust-analyzer 2>/dev/null || true

    log_step "Instalando cargo tools..."
    local cargo_tools=(cargo-edit cargo-watch cargo-nextest cargo-audit cargo-deny)
    for tool in "${cargo_tools[@]}"; do
        if ! env "${RUST_ENV[@]}" cargo install --list 2>/dev/null | grep -q "^${tool} v"; then
            log_info "Instalando $tool..."
            env "${RUST_ENV[@]}" cargo install --locked "$tool" || true
        fi
    done

    # Linkar binarios para bin/ do prefixo (rustup shims + toolchain)
    log_step "Linkando rustc/cargo/ferramentas em bin/..."
    link_bin_dir "" "$CARGO_HOME_DIR/bin"
    local tc_bin
    for tc_bin in "$RUSTUP_HOME_DIR"/toolchains/*/bin; do
        [[ -d "$tc_bin" ]] && link_bin_dir "" "$tc_bin"
    done

    log_success "Rust instalado com sucesso!"
    env "${RUST_ENV[@]}" "$CARGO_HOME_DIR/bin/rustc" --version
    env "${RUST_ENV[@]}" "$CARGO_HOME_DIR/bin/cargo" --version
}

main() {
    log_info "Iniciando instalacao do Rust..."
    detect_arch
    generate_setenv
    generate_unsetenv
    install_rust
    log_info "Instalacao concluida!"
    log_info "Ativar:      source etc/00_envGeneral.sh"
    log_info "Desativar:   source etc/00_unenvGeneral.sh"
}

main "$@"