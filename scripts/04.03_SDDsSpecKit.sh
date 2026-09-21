#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 04.03_SDDsSpecKit.sh
# Instalacao do SpecKit CLI (github/spec-kit) 100% local: uv tool local
# (lib/uv-tools, bin/ direto) com from git; fallback via venv local.
# Nada e instalado no sistema; console script gerado e "specify".
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
SPECKIT_LIB_DIR="$OFFICEAI_ROOT/lib/speckit"
SPECKIT_REPO="https://github.com/github/spec-kit.git"
SPECKIT_PACKAGE="specify-cli"
UV_BIN="$OFFICEAI_ROOT/lib/languages/uv/uv"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE
# ============================================================================
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/04.03_setenv_speckit.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: SpecKit CLI (local em lib/uv-tools)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export SPECKIT_HOME="$OFFICEAI_ROOT/lib/uv-tools"
export SPECKIT_INTEGRATION="${SPECKIT_INTEGRATION:-copilot}"
export SPECKIT_SCRIPT_TYPE="${SPECKIT_SCRIPT_TYPE:-sh}"
if [[ ":$PATH:" != *":$OFFICEAI_ROOT/bin:"* ]]; then
    export PATH="$OFFICEAI_ROOT/bin:$PATH"
fi
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai
    cat > "$SETENV_MARKER" << 'EOF'
export SPECKIT_HOME="$OFFICEAI_ROOT/lib/uv-tools"
export SPECKIT_INTEGRATION="${SPECKIT_INTEGRATION:-copilot}"
export SPECKIT_SCRIPT_TYPE="${SPECKIT_SCRIPT_TYPE:-sh}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/04.03_unsetenv_speckit.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: SpecKit CLI
unset SPECKIT_HOME
unset SPECKIT_INTEGRATION
unset SPECKIT_SCRIPT_TYPE
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO (uv tool local; fallback venv local)
# ============================================================================
install_speckit() {
    log_step "=== SpecKit CLI (lib/uv-tools ou lib/speckit) ==="

    if tool_installed speckit; then
        log_info "SpecKit ja instalado"
        "$OFFICEAI_ROOT/bin/speckit" --version 2>/dev/null || true
        return 0
    fi

    # Metodo 1: uv tool local (usa o uv interno do OfficeAI se existir)
    if [[ -x "$UV_BIN" ]] || command_exists uv; then
        log_info "Instalando via uv tool (from git)"
        if uv_tool_install speckit "${SPECKIT_PACKAGE} --from git+${SPECKIT_REPO}"; then
            # O console script e "specify"; garante bin/speckit como alias
            [[ -x "$OFFICEAI_ROOT/bin/specify" ]] && link_bin speckit "$OFFICEAI_ROOT/bin/specify"
            "$OFFICEAI_ROOT/bin/speckit" version 2>/dev/null || true
            log_success "SpecKit instalado via uv tool"
            return 0
        fi
        log_warn "uv falhou - tentando fallback venv"
    fi

    # Metodo 2: fallback venv local (console script: specify)
    if ! command_exists python3; then
        log_error "python3 nao encontrado (instale a fase 00/01 primeiro)"
        return 1
    fi
    mkdir -p "$SPECKIT_LIB_DIR"
    if ! python3 -m venv "$SPECKIT_LIB_DIR/venv"; then
        log_error "Falha ao criar venv do SpecKit"
        return 1
    fi
    log_step "venv: pip install specify-cli (git)..."
    "$SPECKIT_LIB_DIR/venv/bin/pip" install --quiet "git+${SPECKIT_REPO}" || return 1
    link_bin speckit "$SPECKIT_LIB_DIR/venv/bin/specify"

    "$OFFICEAI_ROOT/bin/speckit" version 2>/dev/null || true
    log_success "SpecKit instalado via venv em $SPECKIT_LIB_DIR"
    return 0
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do SpecKit CLI..."
    generate_setenv
    generate_unsetenv
    install_speckit

    log_info "Instalacao concluida!"
    log_info "Ativar:    source etc/00_envGeneral.sh"
    log_info "Inicializar: specify init meu-projeto --integration copilot"
    log_info "Verificar: specify check"
}

main "$@"