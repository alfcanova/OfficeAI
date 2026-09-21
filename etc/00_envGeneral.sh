#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 00_envGeneral.sh
# ATIVACAO DO AMBIENTE AUTO-CONTIDO
#
# Redireciona HOME, XDG, TMPDIR, PATH e variaveis especificas de ferramentas
# para dentro da pasta OfficeAI. Nenhum arquivo escapa para o sistema.
#
# Uso: source etc/00_envGeneral.sh
# Restaurar: source etc/00_unenvGeneral.sh
# ============================================================================

# Impedir ativacao dupla dentro do mesmo shell
if [[ -n "${OFFICEAI_CONTAINED:-}" ]]; then
    echo "[OfficeAI] Ambiente ja ativo neste shell" >&2
    return 0 2>/dev/null || exit 0
fi

# Raiz sempre resolvida dinamicamente (portabilidade da pasta)
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export OFFICEAI_ROOT

# ----------------------------------------------------------------------------
# BACKUP DO AMBIENTE ORIGINAL (para restore em 00_unenvGeneral.sh)
# ----------------------------------------------------------------------------
OFFICEAI_VAR_DIR="$OFFICEAI_ROOT/var"
OFFICEAI_ENV_BACKUP="$OFFICEAI_VAR_DIR/env-backup.sh"
mkdir -p "$OFFICEAI_VAR_DIR"

: > "$OFFICEAI_ENV_BACKUP"
for _v in HOME XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME \
          XDG_RUNTIME_DIR TMPDIR PATH CARGO_HOME RUSTUP_HOME GOPATH GOBIN \
          GOPROXY NODE_HOME NPM_CONFIG_PREFIX NPM_CONFIG_CACHE \
          BUN_INSTALL OLLAMA_MODELS UV_CACHE_DIR UV_TOOL_DIR UV_TOOL_BIN_DIR \
          PIP_CACHE_DIR PYTHONPYCACHEPREFIX GEM_HOME GEM_PATH HOME_LOCAL_BIN; do
    if [[ -n "${!_v:-}" ]]; then
        printf 'export %s=%q\n' "$_v" "${!_v}" >> "$OFFICEAI_ENV_BACKUP"
    else
        printf 'unset %s\n' "$_v" >> "$OFFICEAI_ENV_BACKUP"
    fi
done

# ----------------------------------------------------------------------------
# CAMADA 1 - HOME VIRTUAL E DIRETORIOS XDG
# ----------------------------------------------------------------------------
OFFICEAI_HOME="$OFFICEAI_ROOT/var/home"
export HOME="$OFFICEAI_HOME"

# Skeleton do home virtual
mkdir -p "$HOME/.config" "$HOME/.cache" "$HOME/.local/share" \
         "$HOME/.local/state" "$HOME/.runtime" "$HOME/.tmp"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_RUNTIME_DIR="$HOME/.runtime"
export TMPDIR="$HOME/.tmp"

# ----------------------------------------------------------------------------
# CAMADA 1 - LINGUAGENS
# ----------------------------------------------------------------------------
# Rust: suporta layout migrado (lib/rust/home) e novo (cargo+rustup)
if [[ -d "$OFFICEAI_ROOT/lib/rust/home" ]]; then
    export CARGO_HOME="$OFFICEAI_ROOT/lib/rust/home"
    export RUSTUP_HOME="$OFFICEAI_ROOT/lib/rust/home"
else
    export CARGO_HOME="$OFFICEAI_ROOT/lib/rust/cargo"
    export RUSTUP_HOME="$OFFICEAI_ROOT/lib/rust/rustup"
fi
export GOPATH="$HOME/go"
export GOBIN="$OFFICEAI_ROOT/bin"                       # go install -> bin/
export GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"
export NODE_HOME="$OFFICEAI_ROOT/lib/node"
export NPM_CONFIG_PREFIX="$OFFICEAI_ROOT/lib/npm"
export NPM_CONFIG_CACHE="$HOME/.cache/npm"
export BUN_INSTALL="$OFFICEAI_ROOT/lib/bun"
export UV_CACHE_DIR="$HOME/.cache/uv"
export UV_TOOL_DIR="$OFFICEAI_ROOT/lib/uv-tools"        # uv tool install -> lib/uv-tools
export UV_TOOL_BIN_DIR="$OFFICEAI_ROOT/bin"             # executaveis -> bin/
export PYTHONPYCACHEPREFIX="$HOME/.cache/pyc"

# ----------------------------------------------------------------------------
# CAMADA 1 - SERVICOS E DADOS
# ----------------------------------------------------------------------------
export OLLAMA_MODELS="$OFFICEAI_ROOT/share/ollama-models"
export PIP_CACHE_DIR="$HOME/.cache/pip"
export GEM_HOME="$OFFICEAI_ROOT/lib/ruby-gems"
export GEM_PATH="$GEM_HOME"

# ----------------------------------------------------------------------------
# CAMADA 1 - PATH (bin/ do OfficeAI como unica entrada de ferramentas)
# ----------------------------------------------------------------------------
# Prepend INCONDICIONAL e livre de duplicatas: garante que bin/ do OfficeAI
# venha sempre primeiro, mesmo que um PATH herdado ja contenha o caminho.
export PATH="$OFFICEAI_ROOT/bin:$(printf '%s' "$PATH" |
    tr ':' '\n' |
    grep -vx "$OFFICEAI_ROOT/bin" |
    paste -sd: -)"

# ----------------------------------------------------------------------------
# HOME/BIN per-tool dentro da pasta (evita $HOME/.local/bin do host)
# ----------------------------------------------------------------------------
export HOME_LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$HOME_LOCAL_BIN"

# ----------------------------------------------------------------------------
export OFFICEAI_CONTAINED=1

echo "[OfficeAI] Ambiente contido ativado" >&2
echo "[OfficeAI] HOME virtual : $HOME" >&2
echo "[OfficeAI] OFFICEAI_ROOT: $OFFICEAI_ROOT" >&2
echo "[OfficeAI] Saia com: source etc/00_unenvGeneral.sh" >&2

unset _v