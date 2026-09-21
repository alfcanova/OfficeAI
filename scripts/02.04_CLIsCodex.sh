#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 02.04_CLIsCodex.sh
# Instalacao do Codex CLI 100% local:
# - npm prefix local (lib/npm/codex) + link bin/codex (metodo recomendado)
# - fallback: binario direto do GitHub release se a URL estiver disponivel
# ============================================================================

set -euo pipefail

# ============================================================================
# HEADER PADRAO - LIBS
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
TOOL_NAME="codex"
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE (nomes mantidos: 02.04_setenv_codex.sh)
# ============================================================================
generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.04_setenv_codex.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Codex (npm local em lib/npm/codex, link em bin/)
# OFFICEAI_ROOT resolvido dinamicamente (portabilidade da pasta)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"

    # Marker para o hub pai capturar (mesmos exports)
    cat > "$SETENV_MARKER" << 'EOF'
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
}

generate_unsetenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.04_unsetenv_codex.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Codex
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_codex() {
    log_step "=== Codex CLI (npm local em lib/npm/codex) ==="

    # a. Ja instalado?
    if tool_installed "$TOOL_NAME"; then
        log_info "Codex ja instalado no OfficeAI: $("$OFFICEAI_ROOT/bin/codex" --version 2>/dev/null || echo "versao desconhecida")"
        return 0
    fi

    # b. Metodo 1: npm prefix local (Node local da fase 01)
    export PATH="$OFFICEAI_ROOT/lib/node/bin:$OFFICEAI_ROOT/lib/npm/bin:$PATH"
    if npm_prefix_install codex @openai/codex; then
        log_success "Codex instalado via npm"
        "$OFFICEAI_ROOT/bin/codex" --version 2>/dev/null || true
        return 0
    fi
    log_warn "Falha via npm, tentando binario direto do release..."

    # b2. Metodo 2 (fallback): binario direto do GitHub release
    local platform arch asset_url
    case "$(uname -s)" in
        Linux*)  platform="unknown-linux-gnu" ;;
        Darwin*) platform="apple-darwin" ;;
        *)       platform="" ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)  arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *)             arch="" ;;
    esac
    asset_url=""

    if [[ -n "$platform" && -n "$arch" ]] && command_exists curl; then
        local tmp
        tmp=$(mktemp -d)
        asset_url="https://github.com/openai/codex/releases/latest/download/codex-${arch}-${platform}.tar.zst"
        if curl -fsSL "$asset_url" -o "$tmp/codex.tar.zst" 2>/dev/null; then
            mkdir -p "$OFFICEAI_ROOT/lib/codex/bin"
            if tar --zstd -xf "$tmp/codex.tar.zst" -C "$tmp" 2>/dev/null; then
                local found
                found=$(find "$tmp" -type f -name codex -perm -u+x 2>/dev/null | head -1 || true)
                if [[ -n "$found" ]]; then
                    cp "$found" "$OFFICEAI_ROOT/lib/codex/bin/codex"
                    chmod +x "$OFFICEAI_ROOT/lib/codex/bin/codex"
                    link_bin codex "$OFFICEAI_ROOT/lib/codex/bin/codex"
                    log_success "Codex instalado via release binario"
                    "$OFFICEAI_ROOT/bin/codex" --version 2>/dev/null || true
                    rm -rf "$tmp"
                    return 0
                fi
            fi
        fi
        rm -rf "$tmp"
    fi

    # c. Validacao final tolerante
    if [[ -x "$OFFICEAI_ROOT/bin/codex" ]]; then
        log_success "Codex disponivel em bin/codex"
        "$OFFICEAI_ROOT/bin/codex" -h 2>/dev/null || "$OFFICEAI_ROOT/bin/codex" --version 2>/dev/null || true
        return 0
    fi

    log_error "Falha ao instalar Codex"
    return 1
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Codex CLI..."
    generate_setenv
    generate_unsetenv
    install_codex
    log_info "Instalacao concluida!"
    log_info "Ativar: source etc/00_envGeneral.sh"
}

main "$@"