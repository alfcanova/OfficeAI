#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 10_migrate_layout.sh
# Migra instalacoes EXISTENTES de modules/ para o novo layout auto-contido:
#   modules/languages/<x>  ->  lib/<x>
#   modules/clis/<x>       ->  lib/<x>
#   modules/llm-servers/<x> -> lib/<x>
# Sem redownload: tudo e movido (mv local) e os symlinks de bin/ sao criados.
#
# Uso:  bash scripts/10_migrate_layout.sh
# ============================================================================
set -euo pipefail

OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "$0")/.." && pwd)}"
MODULES_DIR="$OFFICEAI_ROOT/modules"

# ----------------------------------------------------------------------------
source "$OFFICEAI_ROOT/lib/colors.sh" 2>/dev/null || true
GREEN="${GREEN:-}"
YELLOW="${YELLOW:-}"
RED="${RED:-}"
RESET="${RESET:-}"

log()   { echo -e "${GREEN}[migrate]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[migrate]${RESET} $*"; }
err()   { echo -e "${RED}[migrate]${RESET} $*" >&2; }

# ----------------------------------------------------------------------------
# move_into <origem> <destino_dir>  (mv preservando conteudo; sem redownload)
# ----------------------------------------------------------------------------
move_into() {
    local src="$1" dst="$2"
    [[ -e "$src" ]] || return 0
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst" 2>/dev/null || true
    mv "$src" "$dst"
    log "movido: $src -> $dst"
}

link_bin() {
    local name="$1" target="$2"
    [[ -e "$target" ]] || return 1
    local rel
    rel=$(python3 -c "import os,sys;print(os.path.relpath(sys.argv[1],os.path.dirname(sys.argv[2])))" \
              "$target" "$OFFICEAI_ROOT/bin/$name" 2>/dev/null || echo "$target")
    mkdir -p "$OFFICEAI_ROOT/bin"
    rm -f "$OFFICEAI_ROOT/bin/$name"
    ln -sfn "$rel" "$OFFICEAI_ROOT/bin/$name"
    log "  linked bin/$name -> $rel"
}

link_bin_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    local f
    for f in "$dir"/*; do
        [[ -f "$f" && -x "$f" ]] || continue
        # Nunca expor auxiliares de venv (python, pip, libs) no bin/ global
        case "$(basename "$f")" in
            python|python[0-9]*|pip|pip[0-9]*|activate*|pybabel|pygmentize|tqdm|typer|uvicorn|watchfiles|websockets|httpx|idna|jsonschema|keyring|markdown-it|mcp|normalizer|openai|distro|dotenv|fastapi|fastmcp|dateparser*|courlan|cyclopts|cffi*|email_validator|htmldate|update-tld-names|trafilatura)
                continue ;;
        esac
        link_bin "$(basename "$f")" "$f" || true
    done
}

# ----------------------------------------------------------------------------
main() {
    echo "=== OfficeAI migrate_layout: modules/ -> lib/ + bin/ ==="
    [[ -d "$MODULES_DIR" ]] || { warn "modules/ nao existe; nada a migrar"; exit 0; }

    # ---- Linguagens ---------------------------------------------------------
    move_into "$MODULES_DIR/languages/rust"   "$OFFICEAI_ROOT/lib/rust/home"
    move_into "$MODULES_DIR/languages/zig"    "$OFFICEAI_ROOT/lib/zig"
    move_into "$MODULES_DIR/languages/go"     "$OFFICEAI_ROOT/lib/go"
    move_into "$MODULES_DIR/languages/uv"     "$OFFICEAI_ROOT/lib/languages/uv"

    # ---- CLIs (cada modules/XX -> lib/XX) -----------------------------------
    if [[ -d "$MODULES_DIR/clis" ]]; then
        for d in "$MODULES_DIR"/clis/*; do
            [[ -d "$d" ]] || continue
            move_into "$d" "$OFFICEAI_ROOT/lib/$(basename "$d")"
        done
    fi

    # ---- LLM servers --------------------------------------------------------
    if [[ -d "$MODULES_DIR/llm-servers" ]]; then
        for d in "$MODULES_DIR"/llm-servers/*; do
            [[ -d "$d" ]] || continue
            move_into "$d" "$OFFICEAI_ROOT/lib/$(basename "$d")"
        done
    fi

    # ---- Outros (deixe modules/ ser preservado se houver residuos) ----------

    echo ""
    echo "=== Regenerando symlinks de bin/ ==="

    # Rust migrado (home contem cargo+rustup juntos)
    link_bin_dir "$OFFICEAI_ROOT/lib/rust/home/bin"
    # Rust instalado pelo novo instalador (cargo/rustup separados)
    link_bin_dir "$OFFICEAI_ROOT/lib/rust/cargo/bin"
    for tc in "$OFFICEAI_ROOT"/lib/rust/rustup/toolchains/*/bin; do
        link_bin_dir "$tc"
    done

    link_bin zig  "$OFFICEAI_ROOT/lib/zig/zig"
    link_bin_dir "$OFFICEAI_ROOT/lib/zig/bin"
    link_bin_dir "$OFFICEAI_ROOT/lib/go/bin"
    link_bin uv   "$OFFICEAI_ROOT/lib/languages/uv/uv"
    link_bin uvx  "$OFFICEAI_ROOT/lib/languages/uv/uvx"

    # lib/<tool>/bin de CLIs e servidores
    for tool_dir in "$OFFICEAI_ROOT"/lib/*/bin; do
        [[ -d "$tool_dir" ]] || continue
        link_bin_dir "$tool_dir"
    done

    # venvs Python locais
    for venv in "$OFFICEAI_ROOT"/lib/*/venv; do
        [[ -d "$venv" ]] || continue
        link_bin_dir "$venv/bin"
    done

    # npm per-tool
    for npm_dir in "$OFFICEAI_ROOT"/lib/npm/*/bin; do
        [[ -d "$npm_dir" ]] || continue
        link_bin_dir "$npm_dir"
    done

    # AppImages
    for app in "$OFFICEAI_ROOT"/lib/jan/*.AppImage "$OFFICEAI_ROOT"/lib/lmstudio/*.AppImage \
               "$OFFICEAI_ROOT"/lib/cursor/*.AppImage; do
        [[ -f "$app" ]] || continue
        link_bin "$(basename "$app" .AppImage)" "$app"
    done

    # Symlink de HOME (portabilidade)
    if [[ -L "$HOME/.officeai" ]] || [[ -e "$HOME/.officeai" ]]; then
        rm -f "$HOME/.officeai"
    fi
    [[ -d "$HOME" ]] && ln -sfn "$OFFICEAI_ROOT" "$HOME/.officeai"

    echo ""
    echo "=== Migracao concluida ==="
    echo "Arrase: modules/ -> lib/. Symlinks em bin/ prontos."
    echo "Ative:  source $OFFICEAI_ROOT/etc/00_envGeneral.sh"
}

main "$@"