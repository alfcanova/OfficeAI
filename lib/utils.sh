#!/usr/bin/env bash
# OfficeAI Suite - Utils
# Funcoes utilitarias gerais

# Obter diretorio do script atual
get_script_dir() {
    local source="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    local dir
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    echo "$dir"
}

# Obter diretorio raiz do OfficeAI
get_officeai_root() {
    # Variavel de ambiente tem prioridade
    if [[ -n "${OFFICEAI_ROOT:-}" ]]; then
        echo "$OFFICEAI_ROOT"
        return 0
    fi
    
    local script_dir
    script_dir="$(get_script_dir)"
    
    # Navegar para cima ate encontrar a estrutura (layout auto-contido)
    local current="$script_dir"
    while [[ "$current" != "/" ]]; do
        if [[ -d "$current/lib" ]] && [[ -d "$current/scripts" ]] && [[ -d "$current/bin" ]]; then
            echo "$current"
            return 0
        fi
        current="$(dirname "$current")"
    done
    
    # Se nao encontrar, usar padrao relativo ao script
    echo "${OFFICEAI_ROOT:-$(cd -P "${script_dir}/.." && pwd)}"
}

# Verificar se e root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Verificar se e macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Verificar se e Linux
is_linux() {
    [[ "$OSTYPE" == "linux-gnu"* ]]
}

# Verificar se e Windows (WSL)
is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

# Verificar se um comando existe
command_exists() {
    command -v "$1" &>/dev/null
}

# Verificar se um pacote esta instalado (systema)
package_installed() {
    local pkg="$1"
    if command_exists dpkg; then
        dpkg -l "$pkg" &>/dev/null
    elif command_exists rpm; then
        rpm -q "$pkg" &>/dev/null
    elif command_exists pacman; then
        pacman -Qi "$pkg" &>/dev/null
    elif command_exists brew; then
        brew list "$pkg" &>/dev/null
    else
        return 1
    fi
}

# Instalar pacote do sistema
install_system_package() {
    local pkg="$1"
    local sudo="${2:-true}"
    
    log_step "Instalando $pkg..."
    
    if command_exists apt-get; then
        if [[ "$sudo" == true ]] && ! is_root; then
            sudo apt-get update -qq && sudo apt-get install -y -qq "$pkg"
        else
            apt-get update -qq && apt-get install -y -qq "$pkg"
        fi
    elif command_exists dnf; then
        if [[ "$sudo" == true ]] && ! is_root; then
            sudo dnf install -y "$pkg"
        else
            dnf install -y "$pkg"
        fi
    elif command_exists pacman; then
        if [[ "$sudo" == true ]] && ! is_root; then
            sudo pacman -S --noconfirm "$pkg"
        else
            pacman -S --noconfirm "$pkg"
        fi
    elif command_exists brew; then
        brew install "$pkg"
    else
        log_error "Gerenciador de pacotes nao suportado"
        return 1
    fi
}

# Download de arquivo
download_file() {
    local url="$1"
    local output="$2"
    
    log_step "Baixando: $url"
    
    if command_exists curl; then
        curl -fSL "$url" -o "$output"
    elif command_exists wget; then
        wget -q "$url" -O "$output"
    else
        log_error "curl ou wget necessario"
        return 1
    fi
}

# Download e extrair
download_and_extract() {
    local url="$1"
    local dest="$2"
    local type="${3:-auto}"
    
    local tmp_file
    tmp_file=$(mktemp)
    
    download_file "$url" "$tmp_file"
    
    mkdir -p "$dest"
    
    case "$type" in
        tar.gz|tgz)
            tar -xzf "$tmp_file" -C "$dest"
            ;;
        tar.xz)
            tar -xJf "$tmp_file" -C "$dest"
            ;;
        tar.bz2)
            tar -xjf "$tmp_file" -C "$dest"
            ;;
        zip)
            unzip -q "$tmp_file" -d "$dest"
            ;;
        auto)
            if [[ "$url" == *.tar.gz ]] || [[ "$url" == *.tgz ]]; then
                tar -xzf "$tmp_file" -C "$dest"
            elif [[ "$url" == *.tar.xz ]]; then
                tar -xJf "$tmp_file" -C "$dest"
            elif [[ "$url" == *.zip ]]; then
                unzip -q "$tmp_file" -d "$dest"
            else
                cp "$tmp_file" "$dest/$(basename "$url")"
            fi
            ;;
        *)
            cp "$tmp_file" "$dest/$(basename "$url")"
            ;;
    esac
    
    rm -f "$tmp_file"
}

# Criar diretorio com permissao
safe_mkdir() {
    local dir="$1"
    local mode="${2:-755}"
    
    mkdir -p "$dir"
    chmod "$mode" "$dir"
}

# Criar backup de arquivo
backup_file() {
    local file="$1"
    local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
    
    if [[ -f "$file" ]]; then
        cp "$file" "$backup"
        log_debug "Backup criado: $backup"
        echo "$backup"
    fi
}

# Restaurar backup
restore_backup() {
    local backup="$1"
    local original="${backup%.bak.*}"
    
    if [[ -f "$backup" ]]; then
        cp "$backup" "$original"
        log_debug "Restaurado: $original"
    fi
}

# Esperar por um servico
wait_for_service() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    local interval="${4:-1}"
    
    local elapsed=0
    while ! nc -z "$host" "$port" 2>/dev/null; do
        if [[ $elapsed -ge $timeout ]]; then
            log_error "Timeout aguardando $host:$port"
            return 1
        fi
        sleep "$interval"
        ((elapsed += interval))
    done
    
    log_success "Servico pronto: $host:$port"
}

# Criar wrapper/link
create_wrapper() {
    local target="$1"
    local link="$2"
    
    mkdir -p "$(dirname "$link")"
    ln -sf "$target" "$link"
    chmod +x "$target"
}

# ============================================================================
# FUNCOES ADICIONAIS PARA FASE 4
# ============================================================================

# Remover caminho do PATH de forma segura
remove_from_path() {
    local path_to_remove="$1"
    local current_path="${2:-$PATH}"
    
    if [[ -z "$current_path" ]]; then
        echo "$current_path"
        return 0
    fi
    
    IFS=':' read -ra PATH_ARRAY <<< "$current_path"
    NEW_PATH=()
    
    for p in "${PATH_ARRAY[@]}"; do
        # Ignorar caminhos vazios e o caminho a ser removido
        if [[ -n "$p" ]] && [[ "$p" != "$path_to_remove" ]]; then
            NEW_PATH+=("$p")
        fi
    done
    
    # Reconstruir PATH
    local result=""
    for p in "${NEW_PATH[@]}"; do
        if [[ -n "$result" ]]; then
            result="$result:$p"
        else
            result="$p"
        fi
    done
    
    echo "$result"
}

# Calcular checksum SHA256
calculate_checksum() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "Arquivo não encontrado para checksum: $file"
        return 1
    fi
    
    if command_exists sha256sum; then
        sha256sum "$file" | awk '{print $1}'
    elif command_exists shasum; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        log_error "Nenhum utilitário de checksum disponível"
        return 1
    fi
}

# Verificar checksum
verify_checksum() {
    local file="$1"
    local expected="$2"
    
    if [[ ! -f "$file" ]]; then
        log_error "Arquivo não encontrado: $file"
        return 1
    fi
    
    local actual
    actual=$(calculate_checksum "$file")
    
    if [[ "$actual" == "$expected" ]]; then
        log_info "Checksum válido: $actual"
        return 0
    else
        log_error "Checksum inválido: esperado=$expected, atual=$actual"
        return 1
    fi
}

# Validar URL
validate_url() {
    local url="$1"
    
    if command_exists curl; then
        if curl -fsSL --head "$url" >/dev/null 2>&1; then
            return 0
        fi
    elif command_exists wget; then
        if wget -q --spider "$url" 2>/dev/null; then
            return 0
        fi
    fi
    
    log_error "URL inválida ou inacessível: $url"
    return 1
}

# Retry com exponential backoff
retry_with_backoff() {
    local max_attempts=$1
    local base_delay=$2
    shift 2
    local cmd=("$@")
    
    local attempt=1
    local delay=$base_delay
    
    while [[ $attempt -le $max_attempts ]]; do
        if "${cmd[@]}"; then
            return 0
        fi
        
        log_warn "Tentativa $attempt/$max_attempts falhou"
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_info "Aguardando ${delay}s antes da próxima tentativa..."
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi
        
        ((attempt++))
    done
    
    log_error "Todas as $max_attempts tentativas falharam"
    return 1
}

# Setup cleanup com trap
setup_cleanup() {
    local temp_files=()
    
    # Trap para limpeza
    trap '
        log_debug "Limpando arquivos temporários..."
        for f in "${temp_files[@]}"; do
            [[ -f "$f" ]] && rm -f "$f"
        done
    ' EXIT INT TERM
    
    # Função para adicionar arquivo temporário
    add_temp_file() {
        temp_files+=("$1")
    }
}

# Verificar espaço em disco
check_disk_space() {
    local required_mb=$1
    local path="${2:-.}"
    
    local available
    available=$(df -BM "$path" | awk 'NR==2 {print $4}' | tr -d 'M')
    
    if [[ $available -lt $required_mb ]]; then
        log_error "Espaço insuficiente: ${available}MB disponível, ${required_mb}MB necessário"
        return 1
    fi
    
    return 0
}

# Verificar permissões de escrita
check_write_permission() {
    local path="$1"
    
    if [[ ! -w "$path" ]]; then
        log_error "Sem permissão de escrita em: $path"
        return 1
    fi
    
    return 0
}
