#!/usr/bin/env bash
# OfficeAI Suite - Checks
# Funcoes de verificacao e diagnostico

# Verificar se OfficeAI esta instalado
check_installed() {
    local root="${OFFICEAI_ROOT:-$(get_officeai_root)}"
    [[ -d "$root" ]] && [[ -f "$root/etc/officeai.yaml" ]]
}

# Verificar versao
check_version() {
    local root="${OFFICEAI_ROOT:-$(get_officeai_root)}"
    if [[ -f "$root/VERSION" ]]; then
        cat "$root/VERSION"
    else
        echo "unknown"
    fi
}

# Verificar se tool esta instalado via OfficeAI
check_tool_installed() {
    local tool="$1"
    local root="${OFFICEAI_ROOT:-$(get_officeai_root)}"
    
    # Layout auto-contido: bin/<tool> (symlink) ou lib/<tool>
    [[ -e "$root/bin/$tool" || -d "$root/lib/$tool" ]]
}

# Verificar servicos Docker
check_docker_services() {
    local services=()
    
    if command_exists docker; then
        while IFS= read -r line; do
            services+=("$line")
        done < <(docker ps --format "{{.Names}}" 2>/dev/null)
    fi
    
    printf '%s\n' "${services[@]}"
}

# Verificar portas em uso
check_port() {
    local port="$1"
    
    if command_exists ss; then
        ss -tlnp | grep -q ":$port "
    elif command_exists netstat; then
        netstat -tlnp | grep -q ":$port "
    elif command_exists lsof; then
        lsof -i :"$port" &>/dev/null
    else
        return 1
    fi
}

# Verificar conexao com internet
check_internet() {
    local timeout="${1:-5}"
    
    if command_exists curl; then
        curl -fsSL --max-time "$timeout" https://httpbin.org/ip &>/dev/null
    elif command_exists wget; then
        wget -q --timeout="$timeout" https://httpbin.org/ip -O /dev/null
    else
        return 1
    fi
}

# Verificar permissoes
check_permissions() {
    local path="$1"
    local required="${2:-read}"
    
    case "$required" in
        read)
            [[ -r "$path" ]]
            ;;
        write)
            [[ -w "$path" ]]
            ;;
        execute)
            [[ -x "$path" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Verificar dependencias
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Dependencias faltando: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Diagnostico completo
run_diagnostics() {
    local issues=()
    local warnings=()
    
    echo "=== Diagnostico OfficeAI ==="
    echo ""
    
    # 1. Estrutura de diretorios
    log_step "Verificando estrutura..."
    local root="${OFFICEAI_ROOT:-$(get_officeai_root)}"
    local required_dirs=("bin" "lib" "etc" "packages" "modules" "scripts")
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$root/$dir" ]]; then
            issues+=("Diretorio faltando: $dir")
        fi
    done
    
    # 2. Arquivos de configuracao
    log_step "Verificando configuracoes..."
    if [[ ! -f "$root/etc/officeai.yaml" ]]; then
        issues+=("Arquivo de configuracao principal faltando")
    fi
    
    if [[ ! -f "$root/etc/providers.env" ]]; then
        warnings+=("Arquivo de providers nao configurado (etc/providers.env)")
    fi
    
    # 3. Docker
    log_step "Verificando Docker..."
    if command_exists docker; then
        if docker info &>/dev/null; then
            log_success "Docker: OK"
        else
            warnings+=("Docker instalado mas nao acessivel")
        fi
    else
        warnings+=("Docker nao instalado")
    fi
    
    # 4. GPU
    log_step "Verificando GPU..."
    local gpus
    gpus=$(detect_gpu)
    if echo "$gpus" | grep -q "nvidia"; then
        log_success "GPU NVIDIA detectada"
    elif echo "$gpus" | grep -q "amd"; then
        log_success "GPU AMD detectada"
    else
        warnings+=("Nenhuma GPU dedicada detectada (usando CPU)")
    fi
    
    # 5. Internet
    log_step "Verificando conexao..."
    if check_internet; then
        log_success "Conexao com internet: OK"
    else
        issues+=("Sem conexao com internet")
    fi
    
    # 6. Modulos instalados
    log_step "Verificando modulos..."
    local modules_dir="$root/modules"
    if [[ -d "$modules_dir" ]]; then
        local count
        count=$(find "$modules_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        log_info "Modulos instalados: $count"
    fi
    
    # Resultado
    echo ""
    echo "=== Resultado ==="
    echo ""
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log_error "Problemas encontrados: ${#issues[@]}"
        printf '  - %s\n' "${issues[@]}"
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        log_warn "Avisos: ${#warnings[@]}"
        printf '  - %s\n' "${warnings[@]}"
    fi
    
    if [[ ${#issues[@]} -eq 0 ]] && [[ ${#warnings[@]} -eq 0 ]]; then
        log_success "Sistema OK!"
    fi
    
    echo ""
    [[ ${#issues[@]} -gt 0 ]]
}
