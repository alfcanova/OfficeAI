# Padrões de Código - OfficeAI Suite

## 1. Estrutura Básica de Scripts

### 1.1 Cabeçalho Padrão
```bash
#!/usr/bin/env bash
set -euo pipefail

# Carregar bibliotecas
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "$0")/.." && pwd)}"
source "$OFFICEAI_ROOT/lib/colors.sh"
source "$OFFICEAI_ROOT/lib/log.sh"
source "$OFFICEAI_ROOT/lib/system.sh"
source "$OFFICEAI_ROOT/lib/utils.sh"
source "$OFFICEAI_ROOT/lib/loader.sh"

# Inicialização padrão
SCRIPT_NAME="$(basename "$0" .sh)"
script_init "$SCRIPT_NAME"
```

### 1.2 Função Principal
```bash
main() {
    # 1. Verificar pré-requisitos
    check_prerequisites
    
    # 2. Executar instalação
    if install_tool; then
        log_success "Instalação concluída com sucesso"
        generate_setenv
        return 0
    else
        log_error "Falha na instalação"
        return 1
    fi
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## 2. Padrões de Instalação

### 2.1 Fallback em Cascata
```bash
install_tool() {
    log_info "Iniciando instalação de $TOOL_NAME"
    
    # Método 1: Script oficial (preferido)
    if command_exists "curl" && install_via_official; then
        log_info "Método: Script oficial"
        return 0
    fi
    
    # Método 2: Gerenciador de pacotes
    if has_package_manager && install_via_package_manager; then
        log_info "Método: Gerenciador de pacotes ($PKG_MGR)"
        return 0
    fi
    
    # Método 3: Download direto
    if command_exists "curl" && install_via_binary; then
        log_info "Método: Download direto"
        return 0
    fi
    
    # Método 4: Compilação from source (último recurso)
    if has_build_tools && install_via_source; then
        log_info "Método: Compilação from source"
        return 0
    fi
    
    log_error "Todos os métodos de instalação falharam para $TOOL_NAME"
    return 1
}
```

### 2.2 Verificação de Pré-requisitos
```bash
check_prerequisites() {
    local missing=()
    
    # Verificar comandos essenciais
    for cmd in curl git make; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    # Verificar espaço em disco
    local available=$(df -BM "$INSTALL_DIR" | awk 'NR==2 {print $4}' | tr -d 'M')
    if [[ $available -lt 100 ]]; then
        log_error "Espaço insuficiente: ${available}MB disponível, 100MB necessário"
        return 1
    fi
    
    # Verificar permissões
    if [[ ! -w "$INSTALL_DIR" ]]; then
        log_error "Sem permissão de escrita em $INSTALL_DIR"
        return 1
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Comandos faltando: ${missing[*]}"
        log_warn "Instale manualmente ou use a Fase 0 (SystemBase)"
    fi
    
    return 0
}
```

## 3. Geração de setenv/unsetenv

### 3.1 Template Padrão
```bash
generate_setenv() {
    local tool_name="$1"
    local install_path="$2"
    local env_vars=("${@:3}")
    
    # Gerar setenv
    cat > "$OFFICEAI_ROOT/bin/${SCRIPT_NAME}_setenv_${tool_name}.sh" << EOF
#!/usr/bin/env bash
# Auto-gerado por OfficeAI - $(date)
# Ferramenta: $tool_name

export ${install_path:+PATH="$install_path:\$PATH"}
$(for var in "${env_vars[@]}"; do echo "export $var"; done)
EOF
    
    # Gerar unsetenv com remoção segura
    cat > "$OFFICEAI_ROOT/bin/${SCRIPT_NAME}_unsetenv_${tool_name}.sh" << EOF
#!/usr/bin/env bash
# Auto-gerado por OfficeAI - $(date)
# Ferramenta: $tool_name

$(for var in "${env_vars[@]}"; do
    var_name="${var%%=*}"
    echo "unset $var_name"
done)

# Remover do PATH de forma segura
if [[ -n "\$PATH" ]]; then
    IFS=':' read -ra PATH_ARRAY <<< "\$PATH"
    NEW_PATH=()
    for p in "\${PATH_ARRAY[@]}"; do
        if [[ "$p" != "$install_path" ]]; then
            NEW_PATH+=("$p")
        fi
    done
    export PATH="\$(IFS=':'; echo "\${NEW_PATH[*]}")"
fi
EOF
    
    chmod +x "$OFFICEAI_ROOT/bin/${SCRIPT_NAME}"_*_${tool_name}.sh
}
```

## 4. Tratamento de Erros

### 4.1 Função de Retry
```bash
retry() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local cmd=("$@")
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "${cmd[@]}"; then
            return 0
        fi
        
        log_warn "Tentativa $attempt/$max_attempts falhou"
        if [[ $attempt -lt $max_attempts ]]; then
            log_info "Aguardando ${delay}s antes da próxima tentativa..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    log_error "Todas as $max_attempts tentativas falharam"
    return 1
}

# Uso:
retry 3 5 curl -fsSL "https://example.com/script.sh" | bash
```

### 4.2 Cleanup com Trap
```bash
setup_cleanup() {
    local temp_files=()
    
    trap '
        log_info "Limpando arquivos temporários..."
        for f in "${temp_files[@]}"; do
            [[ -f "$f" ]] && rm -f "$f"
        done
    ' EXIT INT TERM
    
    # Função para adicionar arquivo temporário
    add_temp_file() {
        temp_files+=("$1")
    }
}

# Uso:
setup_cleanup
TEMP_FILE=$(mktemp)
add_temp_file "$TEMP_FILE"
```

## 5. Validação e Testes

### 5.1 Funções de Validação
```bash
# Validar URL
validate_url() {
    local url="$1"
    if curl -fsSL --head "$url" >/dev/null 2>&1; then
        return 0
    else
        log_error "URL inválida: $url"
        return 1
    fi
}

# Validar checksum
validate_checksum() {
    local file="$1"
    local expected="$2"
    local actual
    
    actual=$(sha256sum "$file" | awk '{print $1}')
    
    if [[ "$actual" == "$expected" ]]; then
        log_info "Checksum válido: $actual"
        return 0
    else
        log_error "Checksum inválido: esperado=$expected, atual=$actual"
        return 1
    fi
}

# Validar binário
validate_binary() {
    local binary="$1"
    
    if [[ ! -f "$binary" ]]; then
        log_error "Binário não encontrado: $binary"
        return 1
    fi
    
    if [[ ! -x "$binary" ]]; then
        log_error "Binário não executável: $binary"
        return 1
    fi
    
    # Testar execução
    if ! "$binary" --version >/dev/null 2>&1; then
        log_warn "Binário não respondeu a --version"
    fi
    
    return 0
}
```

## 6. Padrões de Logging

### 6.1 Níveis de Log
```bash
# Uso correto dos níveis
log_debug "Informação de depuração (só com DEBUG=1)"
log_info "Informação geral"
log_warn "Aviso (continua execução)"
log_error "Erro (pode continuar)"
log_fatal "Erro crítico (para execução)"
log_success "Operação bem-sucedida"
```

### 6.2 Contexto de Log
```bash
# Adicionar contexto ao log
log_with_context() {
    local level="$1"
    local message="$2"
    local context="${3:-}"
    
    if [[ -n "$context" ]]; then
        log "$level" "[$context] $message"
    else
        log "$level" "$message"
    fi
}

# Uso:
log_with_context "INFO" "Instalando Rust" "rust-install"
log_with_context "ERROR" "Falha no download" "rust-install"
```

## 7. Compatibilidade

### 7.1 Detecção de Sistema
```bash
# Usar funções centralizadas de lib/system.sh
detect_system() {
    OS=$(detect_os)
    ARCH=$(detect_arch)
    PKG_MGR=$(detect_pkg_mgr)
    
    log_info "Sistema detectado: $OS $ARCH ($PKG_MGR)"
    
    # Compatibilidade específica
    case "$OS" in
        ubuntu|debian)
            PKG_INSTALL="apt-get install -y"
            ;;
        fedora|rhel)
            PKG_INSTALL="dnf install -y"
            ;;
        macos)
            PKG_INSTALL="brew install"
            ;;
        *)
            log_warn "Sistema não totalmente suportado: $OS"
            ;;
    esac
}
```

### 7.2 Caminhos Cross-Platform
```bash
# Usar caminhos relativos ao projeto
INSTALL_DIR="$OFFICEAI_ROOT/modules/clis/$TOOL_NAME"
BIN_DIR="$OFFICEAI_ROOT/bin"
LOG_DIR="$OFFICEAI_ROOT/logs"

# Nunca usar caminhos absolutos hardcoded
# ERRADO: INSTALL_DIR="/opt/tools/$TOOL_NAME"
# CERTO: INSTALL_DIR="$OFFICEAI_ROOT/modules/tools/$TOOL_NAME"
```

## 8. Documentação

### 8.1 Comentários Obrigatórios
```bash
# Cabeçalho do arquivo
# Descrição: Instala o ferramenta X
# Autor: Nome
# Data: YYYY-MM-DD
# Versão: 1.0.0

# Função principal
# Descrição: Instala a ferramenta via múltiplos métodos
# Parâmetros: Nenhum
# Retorna: 0=sucesso, 1=falha
install_tool() {
    # ...
}
```

### 8.2 Help das Funções
```bash
show_help() {
    cat << EOF
Uso: $(basename "$0") [OPÇÕES]

Instala $TOOL_NAME no ambiente OfficeAI.

OPÇÕES:
    -h, --help          Mostra esta ajuda
    -v, --verbose       Modo verboso
    -q, --quiet         Modo silencioso
    -n, --non-interactive  Não solicita entrada
    -d, --dry-run       Simula instalação sem alterar nada
    --prefix DIR        Diretório de instalação personalizado
    --force             Força reinstalação

EXEMPLOS:
    $(basename "$0")                    # Instalação interativa
    $(basename "$0") --non-interactive  # Instalação automática
    $(basename "$0") --dry-run          # Simula instalação

EOF
}
```

## 9. Performance

### 9.1 Cache de Downloads
```bash
download_with_cache() {
    local url="$1"
    local output="$2"
    local cache_dir="$OFFICEAI_ROOT/.cache/downloads"
    
    mkdir -p "$cache_dir"
    
    # Verificar cache
    local cache_file="$cache_dir/$(echo "$url" | md5sum | awk '{print $1}')"
    
    if [[ -f "$cache_file" ]]; then
        log_info "Usando cache: $url"
        cp "$cache_file" "$output"
        return 0
    fi
    
    # Baixar e cachear
    if curl -fsSL "$url" -o "$output"; then
        cp "$output" "$cache_file"
        return 0
    else
        return 1
    fi
}
```

### 9.2 Paralelização
```bash
# Instalar múltiplas ferramentas em paralelo
install_parallel() {
    local tools=("$@")
    local pids=()
    
    for tool in "${tools[@]}"; do
        install_single_tool "$tool" &
        pids+=($!)
    done
    
    # Aguardar todas as instalações
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
        fi
    done
    
    if [[ $failed -gt 0 ]]; then
        log_error "$failed instalações falharam"
        return 1
    fi
    
    return 0
}
```

## 10. Exemplos de Implementação

### 10.1 Sub-script Padronizado
```bash
#!/usr/bin/env bash
set -euo pipefail

OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "$0")/.." && pwd)}"
source "$OFFICEAI_ROOT/lib/colors.sh"
source "$OFFICEAI_ROOT/lib/log.sh"
source "$OFFICEAI_ROOT/lib/system.sh"
source "$OFFICEAI_ROOT/lib/utils.sh"
source "$OFFICEAI_ROOT/lib/loader.sh"

# Constantes
TOOL_NAME="example-tool"
TOOL_VERSION="1.0.0"
INSTALL_DIR="$OFFICEAI_ROOT/modules/clis/$TOOL_NAME"

# Inicialização
script_init "$(basename "$0" .sh)"

# Métodos de instalação
install_via_official() {
    curl -fsSL "https://example.com/install.sh" | bash
}

install_via_package_manager() {
    case "$PKG_MGR" in
        apt) apt-get install -y example-tool ;;
        dnf) dnf install -y example-tool ;;
        brew) brew install example-tool ;;
        *) return 1 ;;
    esac
}

install_via_binary() {
    local arch
    arch=$(detect_arch)
    
    local url="https://github.com/example/tool/releases/download/v${TOOL_VERSION}/tool-${arch}.tar.gz"
    
    download_with_cache "$url" "/tmp/tool.tar.gz"
    tar -xzf /tmp/tool.tar.gz -C "$INSTALL_DIR"
}

# Instalação principal
install_tool() {
    mkdir -p "$INSTALL_DIR"
    
    if install_via_official; then
        return 0
    elif install_via_package_manager; then
        return 0
    elif install_via_binary; then
        return 0
    fi
    
    return 1
}

# Geração de ambiente
generate_environment() {
    generate_setenv "$TOOL_NAME" "$INSTALL_DIR/bin" \
        "EXAMPLE_HOME=$INSTALL_DIR"
}

# Função principal
main() {
    if ! check_prerequisites; then
        return 1
    fi
    
    if install_tool; then
        generate_environment
        log_success "$TOOL_NAME instalado com sucesso"
        return 0
    else
        log_error "Falha na instalação de $TOOL_NAME"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

---

**Autor:** OfficeAI Team  
**Última atualização:** 2024  
**Versão:** 1.0.0