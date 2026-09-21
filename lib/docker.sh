#!/usr/bin/env bash
# OfficeAI Suite - Docker
# Funcoes para gerenciamento Docker

# Verificar se Docker esta disponivel
docker_available() {
    command_exists docker && docker info &>/dev/null
}

# Verificar se Docker Compose esta disponivel
docker_compose_available() {
    if docker compose version &>/dev/null 2>&1; then
        return 0
    elif command_exists docker-compose; then
        return 0
    fi
    return 1
}

# Comando docker-compose
dc() {
    if docker compose version &>/dev/null 2>&1; then
        docker compose "$@"
    elif command_exists docker-compose; then
        docker-compose "$@"
    else
        log_error "Docker Compose nao encontrado"
        return 1
    fi
}

# Criar rede OfficeAI
docker_create_network() {
    local network="${OFFICEAI_NETWORK:-officeai-net}"
    
    if ! docker network ls | grep -q "$network"; then
        log_step "Criando rede: $network"
        docker network create "$network"
    fi
}

# Verificar se container esta rodando
docker_is_running() {
    local container="$1"
    docker ps --format "{{.Names}}" | grep -q "^${container}$"
}

# Obter status do container
docker_status() {
    local container="$1"
    docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null
}

# Logs do container
docker_logs() {
    local container="$1"
    local lines="${2:-100}"
    
    docker logs --tail "$lines" "$container" 2>&1
}

# Parar e remover container
docker_cleanup() {
    local container="$1"
    
    if docker_is_running "$container"; then
        log_step "Parando container: $container"
        docker stop "$container"
    fi
    
    if docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
        log_step "Removendo container: $container"
        docker rm "$container"
    fi
}

# Executar comando no container
docker_exec() {
    local container="$1"
    shift
    
    if docker_is_running "$container"; then
        docker exec -it "$container" "$@"
    else
        log_error "Container nao esta rodando: $container"
        return 1
    fi
}

# Obter IP do container
docker_get_ip() {
    local container="$1"
    local network="${2:-officeai-net}"
    
    docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" "$container" 2>/dev/null
}

# Verificar saude do container
docker_health() {
    local container="$1"
    
    docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' "$container" 2>/dev/null
}

# Listar containers OfficeAI
docker_list_officeai() {
    docker ps -a --filter "label=officeai" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Backup de volume
docker_backup_volume() {
    local volume="$1"
    local output="$2"
    
    log_step "Fazendo backup do volume: $volume"
    
    docker run --rm \
        -v "$volume":/source:ro \
        -v "$(dirname "$output")":/backup \
        alpine tar czf "/backup/$(basename "$output")" -C /source .
    
    log_success "Backup salvo em: $output"
}

# Restaurar volume
docker_restore_volume() {
    local volume="$1"
    local input="$2"
    
    log_step "Restaurando volume: $volume"
    
    docker run --rm \
        -v "$volume":/target \
        -v "$(dirname "$input")":/backup:ro \
        alpine tar xzf "/backup/$(basename "$input")" -C /target
    
    log_success "Volume restaurado"
}
