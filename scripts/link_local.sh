#!/usr/bin/env bash
# ============================================================================
# OfficeAI - link_local.sh
# Regenera os symlinks de bin/ e o symlink $HOME/.officeai a partir do que
# esta instalado em lib/. Use depois de MOVER a pasta OfficeAI para outro
# local (portabilidade).
#
# Uso:  bash scripts/link_local.sh
# ============================================================================
set -euo pipefail

OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "$0")/.." && pwd)}"

# ----------------------------------------------------------------------------
# Dicionario: tool -> caminho do binario dentro de lib/ (ou lista de bins dirs)
# ----------------------------------------------------------------------------
link_bin() {
    local name="$1" target="$2"
    [[ ! -e "$target" ]] && return 1
    local rel
    rel=$(python3 -c "import os,sys;print(os.path.relpath(sys.argv[1],os.path.dirname(sys.argv[2])))" \
              "$target" "$OFFICEAI_ROOT/bin/$name" 2>/dev/null || echo "$target")
    mkdir -p "$OFFICEAI_ROOT/bin"
    rm -f "$OFFICEAI_ROOT/bin/$name"
    ln -sfn "$rel" "$OFFICEAI_ROOT/bin/$name"
    echo "  linked bin/$name -> $rel"
    return 0
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

echo "=== OfficeAI link_local: regenerando symlinks de bin/ ==="

# ---- Linguagens ------------------------------------------------------------
link_bin_dir "$OFFICEAI_ROOT/lib/rust/cargo/bin" 2>/dev/null || true
for tc in "$OFFICEAI_ROOT"/lib/rust/rustup/toolchains/*/bin; do
    link_bin_dir "$tc"
done
link_bin zig  "$OFFICEAI_ROOT/lib/zig/zig"
link_bin_dir "$OFFICEAI_ROOT/lib/go/bin"
mkdir -p "$OFFICEAI_ROOT/bin"        # GOBIN: go install grava direto em bin/
link_bin_dir "$OFFICEAI_ROOT/lib/node/bin"
link_bin_dir "$OFFICEAI_ROOT/lib/npm/bin"
link_bin_dir "$OFFICEAI_ROOT/lib/bun/bin"
link_bin uv   "$OFFICEAI_ROOT/lib/languages/uv/uv"
link_bin uvx  "$OFFICEAI_ROOT/lib/languages/uv/uvx"

# ---- uv-tools (aider, kimi, speckit, etc.) ---------------------------------
link_bin_dir "$OFFICEAI_ROOT/lib/uv-tools/bin"

# ---- Python venvs -----------------------------------------------------------
for venv in "$OFFICEAI_ROOT"/lib/*/venv; do
    [[ -d "$venv" ]] || continue
    link_bin_dir "$venv/bin"
done

# ---- CLIs e servidores (bin/ de cada lib/<tool>) ----------------------------
for tool_dir in "$OFFICEAI_ROOT"/lib/*/bin; do
    [[ -d "$tool_dir" ]] || continue
    link_bin_dir "$tool_dir"
done

# ---- npm per-tool ------------------------------------------------------------
for npm_dir in "$OFFICEAI_ROOT"/lib/npm/*/bin; do
    [[ -d "$npm_dir" ]] || continue
    link_bin_dir "$npm_dir"
done

# ---- AppImage (jan, lmstudio, etc.) -----------------------------------------
for app in "$OFFICEAI_ROOT"/lib/jan/*.AppImage "$OFFICEAI_ROOT"/lib/lmstudio/*.AppImage \
           "$OFFICEAI_ROOT"/lib/cursor/*.AppImage; do
    [[ -f "$app" ]] || continue
    link_bin "$(basename "$app" .AppImage)" "$app"
done

# ---- Symlink HOME -----------------------------------------------------------
if [[ -d "$HOME" && -e "$OFFICEAI_ROOT/etc/00_envGeneral.sh" ]]; then
    if [[ -L "$HOME/.officeai" ]] || [[ -e "$HOME/.officeai" ]]; then
        rm -f "$HOME/.officeai"
    fi
    ln -sfn "$OFFICEAI_ROOT" "$HOME/.officeai"
    echo "  linked \$HOME/.officeai -> $OFFICEAI_ROOT"
fi

echo "=== Pronto. Ative com: source $OFFICEAI_ROOT/etc/00_envGeneral.sh ==="