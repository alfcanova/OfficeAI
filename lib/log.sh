#!/usr/bin/env bash
# OfficeAI Suite - Logging
# Sistema de logging centralizado

LOG_LEVELS=("DEBUG" "INFO" "WARN" "ERROR" "FATAL")
LOG_LEVEL_CURRENT="${LOG_LEVEL:-INFO}"
LOG_FILE="${OFFICEAI_LOG_FILE:-}"

# Mapear nivel para numero
_log_level_num() {
    case "$1" in
        DEBUG) echo 0 ;;
        INFO)  echo 1 ;;
        WARN)  echo 2 ;;
        ERROR) echo 3 ;;
        FATAL) echo 4 ;;
        *)     echo 1 ;;
    esac
}

# Obter timestamp
_log_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Funcao interna de log
_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(_log_timestamp)
    
    local current_num
    current_num=$(_log_level_num "$LOG_LEVEL_CURRENT")
    local message_num
    message_num=$(_log_level_num "$level")
    
    # Verificar se nivel e permitido
    if [[ $message_num -lt $current_num ]]; then
        return 0
    fi
    
    # Formatar saida
    local prefix=""
    local color=""
    
    case "$level" in
        DEBUG) prefix="[DEBUG]"; color="${GRAY}" ;;
        INFO)  prefix="[INFO] "; color="${GREEN}" ;;
        WARN)  prefix="[WARN] "; color="${YELLOW}" ;;
        ERROR) prefix="[ERROR]"; color="${RED}" ;;
        FATAL) prefix="[FATAL]"; color="${RED}${BOLD}" ;;
    esac
    
    local output="${timestamp} ${prefix} ${message}"
    
    # Saida para terminal
    if [[ -t 2 ]]; then
        if [[ "$USE_COLOR" == true ]]; then
            echo -e "${color}${output}${RESET}" >&2
        else
            echo "$output" >&2
        fi
    else
        echo "$output" >&2
    fi
    
    # Saida para arquivo
    if [[ -n "$LOG_FILE" ]] && [[ -w "$(dirname "$LOG_FILE")" ]]; then
        echo "$output" >> "$LOG_FILE"
    fi
    
    # Fatal encerra o programa
    if [[ "$level" == "FATAL" ]]; then
        exit 1
    fi
}

# Funcoes publicas
log_debug() { _log "DEBUG" "$@"; }
log_info()  { _log "INFO" "$@"; }
log_warn()  { _log "WARN" "$@"; }
log_error() { _log "ERROR" "$@"; }
log_fatal() { _log "FATAL" "$@"; }

# Funcoes com prefixo visual
log_success() {
    local msg="$*"
    if [[ "$USE_COLOR" == true ]]; then
        echo -e "${GREEN}${icon_check} ${msg}${RESET}" >&2
    else
        echo "${icon_check} ${msg}" >&2
    fi
}

log_fail() {
    local msg="$*"
    if [[ "$USE_COLOR" == true ]]; then
        echo -e "${RED}${icon_cross} ${msg}${RESET}" >&2
    else
        echo "${icon_cross} ${msg}" >&2
    fi
}

log_step() {
    local msg="$*"
    if [[ "$USE_COLOR" == true ]]; then
        echo -e "${CYAN}${icon_arrow} ${msg}${RESET}" >&2
    else
        echo "${icon_arrow} ${msg}" >&2
    fi
}

# Configurar nivel de log
log_set_level() {
    local level="${1^^}"  # Converter para maiusculo
    if [[ " ${LOG_LEVELS[*]} " =~ " ${level} " ]]; then
        LOG_LEVEL_CURRENT="$level"
        log_debug "Nivel de log alterado para: $level"
    else
        log_warn "Nivel de log invalido: $level"
    fi
}

# Configurar arquivo de log
log_set_file() {
    LOG_FILE="$1"
    mkdir -p "$(dirname "$LOG_FILE")"
    log_debug "Arquivo de log configurado: $LOG_FILE"
}
