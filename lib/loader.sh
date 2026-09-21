#!/usr/bin/env bash
# OfficeAI Suite - Loader
# Carrega todas as bibliotecas da suite

# Obter diretorio raiz
OFFICEAI_ROOT="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export OFFICEAI_ROOT

# Carregar bibliotecas na ordem correta
_load_lib() {
    local lib="$1"
    local file="$OFFICEAI_ROOT/lib/$lib.sh"
    
    if [[ -f "$file" ]]; then
        source "$file"
    else
        echo "Erro: Biblioteca nao encontrada: $lib" >&2
        return 1
    fi
}

# Ordem de carregamento (dependencias)
_load_lib "colors"      # Cores (basico)
_load_lib "log"         # Logging (depende de colors)
_load_lib "system"      # Info do sistema
_load_lib "utils"       # Utilitarios gerais
_load_lib "yaml"        # Parsing YAML
_load_lib "gpu"         # Deteccao de GPU
_load_lib "checks"      # Verificacoes
_load_lib "docker"      # Gerenciamento Docker
_load_lib "permissions" # Gerenciamento de permissoes
_load_lib "template"    # Gerenciamento de templates

# Versao
OFFICEAI_VERSION="2.0.0"
export OFFICEAI_VERSION

# Carregar configuracoes
_load_config() {
    local config="$OFFICEAI_ROOT/etc/officeai.yaml"
    
    if [[ -f "$config" ]] && _has_yq; then
        OFFICEAI_CONFIG_FILE="$config"
        export OFFICEAI_CONFIG_FILE
    fi
}

_load_config

# Funcao de inicializacao
officeai_init() {
    log_debug "OfficeAI Suite v$OFFICEAI_VERSION inicializado"
    log_debug "Root: $OFFICEAI_ROOT"
}

# Auto-inicializar
officeai_init

# ============================================================================
# FUNCOES PARA FASE 4
# ============================================================================

# Inicialização padrão para scripts
script_init() {
    local script_name="$1"
    
    # Configurar log
    mkdir -p "$OFFICEAI_ROOT/logs"
    LOG_FILE_NAME="${script_name}.log"
    log_set_file "$OFFICEAI_ROOT/logs/$LOG_FILE_NAME"
    USE_COLOR=true
    
    # Acumulador de setenv para exportar ao pai
    ALL_SETENV="/tmp/officeai_all_setenv_$$.sh"
    : > "$ALL_SETENV"
    
    # Trap para cleanup
    trap 'rm -f /tmp/officeai_setenv_$$.sh /tmp/officeai_all_setenv_$$.sh' EXIT INT TERM
    
    log_debug "Script inicializado: $script_name"
}

# Executar sub-script e capturar setenv
run_and_capture() {
    local script="$1"
    local marker="/tmp/officeai_setenv_$$.sh"
    
    # Rodar sub-script
    bash "$script"
    local rc=$?
    
    # Capturar setenv se existe
    if [[ -f "$marker" ]]; then
        # Eval no contexto atual
        source "$marker"
        # Acumular para exportar ao pai
        cat "$marker" >> "$ALL_SETENV"
        rm -f "$marker"
    fi
    
    return $rc
}

# Executar sub-script com tratamento de erro
run_with_error_handling() {
    local script="$1"
    local description="${2:-$(basename "$script")}"
    
    log_info "Executando: $description"
    
    if run_and_capture "$script"; then
        log_success "$description concluído com sucesso"
        return 0
    else
        log_error "$description falhou"
        return 1
    fi
}

# Executar múltiplos scripts em sequência
run_scripts_sequential() {
    local scripts=("$@")
    local failed=0
    
    for script in "${scripts[@]}"; do
        if ! run_with_error_handling "$script"; then
            ((failed++))
        fi
    done
    
    if [[ $failed -gt 0 ]]; then
        log_error "$failed scripts falharam"
        return 1
    fi
    
    return 0
}

# Executar múltiplos scripts em paralelo
run_scripts_parallel() {
    local scripts=("$@")
    local pids=()
    
    for script in "${scripts[@]}"; do
        run_with_error_handling "$script" &
        pids+=($!)
    done
    
    # Aguardar todas as execuções
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
        fi
    done
    
    if [[ $failed -gt 0 ]]; then
        log_error "$failed scripts falharam"
        return 1
    fi
    
    return 0
}
