#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 02.05_CLIsAntiGravity.sh
# Instalacao do Antigravity CLI (agy) 100% local:
# - binario direto em lib/antigravity se houver URL de release
# - fallback: npm prefix local (lib/npm/antigravity, pacote @google/antigravity)
# O executavel e linkado em bin/ como "antigravity" (nome desta fase).
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
TOOL_NAME="antigravity"
SETENV_MARKER="/tmp/officeai_setenv_$$.sh"

# ============================================================================
# GERAR SCRIPTS DE AMBIENTE (nomes mantidos: 02.05_setenv_antigravity.sh)
# ============================================================================
generate_setenv() {
    local SCRIPT="$OFFICEAI_ROOT/bin/02.05_setenv_antigravity.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - SetEnv: Antigravity (agy, npm local em lib/npm/antigravity)
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
    local SCRIPT="$OFFICEAI_ROOT/bin/02.05_unsetenv_antigravity.sh"
    cat > "$SCRIPT" << 'EOF'
#!/usr/bin/env bash
# OfficeAI - UnsetEnv: Antigravity
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EOF
    chmod +x "$SCRIPT"
    log_info "Gerado: $SCRIPT"
}

# ============================================================================
# INSTALACAO
# ============================================================================
install_antigravity() {
    log_step "=== Antigravity CLI (agy) ==="

    # a. Ja instalado? (bin/antigravity ou lib/antigravity)
    if tool_installed "$TOOL_NAME"; then
        log_info "Antigravity ja instalado no OfficeAI: $("$OFFICEAI_ROOT/bin/antigravity" --version 2>/dev/null || echo "versao desconhecida")"
        return 0
    fi

    # b. Metodo 1: binario direto (somente se houver URL de release definida)
    local AG_BINARY_URL="${AG_BINARY_URL:-}"
    if [[ -n "$AG_BINARY_URL" ]] && command_exists curl; then
        mkdir -p "$OFFICEAI_ROOT/lib/antigravity"
        if curl -fsSL "$AG_BINARY_URL" -o "$OFFICEAI_ROOT/lib/antigravity/agy" 2>/dev/null; then
            chmod +x "$OFFICEAI_ROOT/lib/antigravity/agy"
            link_bin antigravity "$OFFICEAI_ROOT/lib/antigravity/agy"
            log_success "Antigravity instalado via release binario"
            "$OFFICEAI_ROOT/bin/antigravity" --version 2>/dev/null || true
            return 0
        fi
        log_warn "Falha via release binario, tentando npm..."
    fi

    # b2. Metodo 2 (fallback): npm prefix local (pacote instala binario "agy")
    export PATH="$OFFICEAI_ROOT/lib/node/bin:$OFFICEAI_ROOT/lib/npm/bin:$PATH"
    if npm_prefix_install antigravity @google/antigravity; then
        # O pacote gera bin/agy; esta fase gera tambem bin/antigravity
        if [[ -x "$OFFICEAI_ROOT/lib/npm/antigravity/bin/agy" && ! -e "$OFFICEAI_ROOT/bin/antigravity" ]]; then
            link_bin antigravity "$OFFICEAI_ROOT/lib/npm/antigravity/bin/agy"
        fi
        log_success "Antigravity instalado via npm (fallback)"
        "$OFFICEAI_ROOT/bin/antigravity" --version 2>/dev/null || "$OFFICEAI_ROOT/bin/agy" --version 2>/dev/null || true
        return 0
    fi

    # c. Validacao final tolerante
    if [[ -x "$OFFICEAI_ROOT/bin/antigravity" ]]; then
        log_success "Antigravity disponivel em bin/antigravity"
        "$OFFICEAI_ROOT/bin/antigravity" -h 2>/dev/null || "$OFFICEAI_ROOT/bin/antigravity" --version 2>/dev/null || true
        return 0
    fi

    log_error "Falha ao instalar Antigravity CLI"
    return 1
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================
main() {
    log_info "Iniciando instalacao do Antigravity CLI..."
    generate_setenv
    generate_unsetenv
    install_antigravity
    log_info "Instalacao concluida!"
    log_info "Ativar: source etc/00_envGeneral.sh"
}

main "$@"