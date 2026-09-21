#!/usr/bin/env bash
# ============================================================================
# OfficeAI Suite - prefix.sh
# Helpers do layout auto-contido: bin/ (executaveis), lib/ (runtimes),
# share/ (dados), var/home/ (HOME virtual).
#
# Regra de ouro: nenhum path hardcoded do host. Tudo deriva de $OFFICEAI_ROOT.
# ============================================================================

# Garantir raiz resolvida
prefix_root() {
    OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    export OFFICEAI_ROOT
}

# Diretorios estruturais do prefix
prefix_bin()   { echo "$OFFICEAI_ROOT/bin"; }
prefix_lib()   { echo "$OFFICEAI_ROOT/lib"; }
prefix_share() { echo "$OFFICEAI_ROOT/share"; }
prefix_var()   { echo "$OFFICEAI_ROOT/var"; }
prefix_home()  { echo "$OFFICEAI_ROOT/var/home"; }

# Garantir que a estrutura base existe
prefix_ensure_structure() {
    prefix_root
    mkdir -p "$(prefix_bin)" "$(prefix_lib)" "$(prefix_share)" "$(prefix_var)" \
             "$(prefix_home)/.config" "$(prefix_home)/.cache" \
             "$(prefix_home)/.local/share" "$(prefix_home)/.local/state" \
             "$(prefix_home)/.runtime" "$(prefix_home)/.tmp" \
             "$(prefix_home)/.local/bin"
}

# Diretorio de instalacao de uma ferramenta em lib/
# Uso: tool_lib_dir <categoria> <ferramenta>
#   tool_lib_dir languages rust   -> $OFFICEAI_ROOT/lib/languages/rust
tool_lib_dir() {
    prefix_root
    local category="${1:-tools}"
    local tool="${2:-}"
    local dir="$OFFICEAI_ROOT/lib/$category"
    [[ -n "$tool" ]] && dir="$dir/$tool"
    mkdir -p "$dir"
    echo "$dir"
}

# Criar symlink bin/<nome> -> alvo (relativo). Nao sobrescreve diretorios.
# Uso: link_bin <nome> <alvo_absoluto>
link_bin() {
    prefix_root
    local name="$1"
    local target="$2"
    local link_path="$OFFICEAI_ROOT/bin/$name"

    [[ -z "$name" || -z "$target" ]] && { log_error "link_bin: nome e alvo obrigatorios" >&2; return 1; }
    [[ ! -f "$target" && ! -d "$target" ]] && { log_error "link_bin: alvo inexistente: $target" >&2; return 1; }

    mkdir -p "$OFFICEAI_ROOT/bin"

    # Link relativo (portabilidade da pasta)
    local rel
    rel=$(python3 -c "import os,sys;print(os.path.relpath(sys.argv[1],os.path.dirname(sys.argv[2])))" \
              "$target" "$link_path" 2>/dev/null || echo "$target")

    if [[ -L "$link_path" ]]; then
        rm -f "$link_path"
    fi
    ln -sfn "$rel" "$link_path"
    log_info "linked: bin/$name -> $rel"
}

# Linkar TUDO de um diretorio bin/ de ferramenta para bin/ do prefixo
# Uso: link_bin_dir <tool_name> <dir_com_os_binarios>
link_bin_dir() {
    local tool_name="$1"
    local dir="${2:-$tool_name}"
    [[ -d "$dir" ]] || return 0
    local f
    for f in "$dir"/*; do
        [[ -f "$f" && -x "$f" ]] || continue
        # Nunca expor auxiliares de venv (python, pip, libs) no bin/ global
        case "$(basename "$f")" in
            python|python[0-9]*|pip|pip[0-9]*|activate*|pybabel|pygmentize|tqdm|typer|uvicorn|watchfiles|websockets|httpx|idna|jsonschema|keyring|markdown-it|mcp|normalizer|openai|distro|dotenv|fastapi|fastmcp|dateparser*|courlan|cyclopts|cffi*|email_validator|htmldate|update-tld-names|trafilatura)
                continue ;;
        esac
        link_bin "$(basename "$f")" "$f"
    done
    # Evita conflito quando o tool_name difere do binario (ex: cline)
    if [[ -n "$tool_name" && ! -e "$OFFICEAI_ROOT/bin/$tool_name" ]]; then
        local candidates=("$dir"/"$tool_name"*)
        [[ -e "${candidates[0]}" ]] && link_bin "$tool_name" "${candidates[0]}"
    fi
}

# Instalar pacote npm como prefixo local
# Uso: npm_prefix_install <tool_name> <pacote> [versao]
# Instala em lib/npm/<tool> e linka o binario em bin/
npm_prefix_install() {
    prefix_root
    local tool="$1"
    local pkg="${2:-$1}"
    local ver="${3:-latest}"
    local npm_dir="$OFFICEAI_ROOT/lib/npm/$tool"

    command_exists npm || { log_error "npm_prefix_install: npm nao encontrado (instale Node.js 01.04)" >&2; return 1; }

    mkdir -p "$npm_dir"
    export NPM_CONFIG_PREFIX="$OFFICEAI_ROOT/lib/npm"

    log_step "npm: instalando $pkg@$ver em lib/npm/$tool..."
    if ! npm install -g "$pkg@$ver" --prefix "$npm_dir" --no-audit --no-fund 2>&1 | tail -3; then
        log_error "npm_prefix_install: falha ao instalar $pkg" >&2
        return 1
    fi

    link_bin_dir "" "$npm_dir/bin"
    # npm pode criar links com nomes diferentes; garante o nome da ferramenta
    if [[ ! -e "$OFFICEAI_ROOT/bin/$tool" ]]; then
        local cand
        for cand in "$npm_dir"/bin/"$tool"*; do
            [[ -e "$cand" ]] && link_bin "$tool" "$cand" && break
        done
    fi
    return 0
}

# Instalar ferramenta via `uv tool` com destino interno
# Uso: uv_tool_install <tool_name> <source_spec>
uv_tool_install() {
    prefix_root
    local tool="$1"
    local src="${2:-$1}"
    local uv_bin="$OFFICEAI_ROOT/lib/languages/uv/uv"

    if [[ ! -x "$uv_bin" ]]; then
        command_exists uv && uv_bin="$(command -v uv)" || { log_error "uv_tool_install: uv nao encontrado" >&2; return 1; }
    fi

    mkdir -p "$OFFICEAI_ROOT/lib/uv-tools" "$OFFICEAI_ROOT/bin"
    export UV_TOOL_DIR="$OFFICEAI_ROOT/lib/uv-tools"
    export UV_TOOL_BIN_DIR="$OFFICEAI_ROOT/bin"
    export UV_CACHE_DIR="$OFFICEAI_ROOT/var/home/.cache/uv"

    log_step "uv: instalando $src em lib/uv-tools (bin -> bin/...)"
    if ! "$uv_bin" tool install --force "$src" 2>&1 | tail -3; then
        log_error "uv_tool_install: falha ao instalar $src" >&2
        return 1
    fi
    return 0
}

# Criar venv Python local e linkar executavel
# Uso: python_venv_tool <tool_name> <dir_lib> [python_spec]
# Instala ferramenta pip numa venv em lib/<tool>/venv, linka bin/<tool>
python_venv_tool() {
    prefix_root
    local tool="$1"
    local lib_dir="${2:-$OFFICEAI_ROOT/lib/$tool}"
    local py_spec="${3:-python3}"
    local venv="$lib_dir/venv"

    mkdir -p "$lib_dir"
    log_step "venv: criando ambiente Python em $venv"
    if ! "$py_spec" -m venv "$venv"; then
        log_error "python_venv_tool: falha ao criar venv" >&2
        return 1
    fi

    # Acumula instalação: pacote(s) restantes via argv depois de $3
    local pkg
    shift 3 2>/dev/null || shift $#
    for pkg in "$@"; do
        log_step "venv: pip install $pkg"
        "$venv/bin/pip" install --quiet "$pkg" || { log_error "python_venv_tool: pip falhou em $pkg" >&2; return 1; }
    done

    link_bin "$tool" "$venv/bin/$tool"
    return 0
}

# Verificar se ferramenta esta instalada (bin/<tool> existe OU lib/<tool> tem binarios)
tool_installed() {
    prefix_root
    local tool="$1"
    [[ -e "$OFFICEAI_ROOT/bin/$tool" ]] && return 0
    [[ -d "$OFFICEAI_ROOT/lib/$tool" ]] && return 0
    return 1
}

# Listar ferramentas instaladas (binarios reais em bin/, ignorando setenv)
list_tools() {
    prefix_root
    local f
    for f in "$OFFICEAI_ROOT/bin"/*; do
        [[ -L "$f" ]] || continue
        basename "$f"
    done | sort -u
}