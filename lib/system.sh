#!/usr/bin/env bash
# OfficeAI Suite - System
# Funcoes de informacao do sistema

# Obter info do SO
get_os() {
    local os=""
    
    case "$OSTYPE" in
        linux-gnu*)
            if [[ -f /etc/os-release ]]; then
                os=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
            else
                os="linux"
            fi
            ;;
        darwin*)
            os="macos"
            ;;
        msys*|cygwin*)
            os="windows"
            ;;
        *)
            os="unknown"
            ;;
    esac
    
    echo "$os"
}

# Obter arquitetura
get_arch() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armhf)
            echo "armhf"
            ;;
        i686|i386)
            echo "i386"
            ;;
        *)
            echo "$arch"
            ;;
    esac
}

# Obter versao do kernel
get_kernel_version() {
    uname -r
}

# Obter memoria total (MB)
get_total_memory() {
    if [[ -f /proc/meminfo ]]; then
        awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
    elif command_exists sysctl; then
        sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024)}'
    else
        echo "0"
    fi
}

# Obter espaco livre em disco (GB)
get_disk_free() {
    local path="${1:-.}"
    df -BG "$path" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G'
}

# Obter numero de CPUs
get_cpu_count() {
    if [[ -f /proc/cpuinfo ]]; then
        grep -c "^processor" /proc/cpuinfo
    elif command_exists sysctl; then
        sysctl -n hw.ncpu
    else
        echo "1"
    fi
}

# Obter modelo da CPU
get_cpu_model() {
    if [[ -f /proc/cpuinfo ]]; then
        grep "^model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[[:space:]]*//'
    elif command_exists sysctl; then
        sysctl -n machdep.cpu.brand_string 2>/dev/null
    else
        echo "Unknown"
    fi
}

# Verificar se esta em container
is_container() {
    [[ -f /.dockerenv ]] || grep -q "docker\|lxc\|container" /proc/1/cgroup 2>/dev/null
}

# Verificar se esta em VM
is_vm() {
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        local product
        product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        [[ "$product" == *"Virtual"* ]] || [[ "$product" == *"VM"* ]]
    else
        return 1
    fi
}

# Verificar systemd
has_systemd() {
    command_exists systemctl && [[ -d /run/systemd/system ]]
}

# Verificar init system
get_init_system() {
    if has_systemd; then
        echo "systemd"
    elif [[ -f /sbin/openrc ]]; then
        echo "openrc"
    elif [[ -f /etc/init.d/cron ]]; then
        echo "sysvinit"
    elif command_exists launchctl; then
        echo "launchd"
    else
        echo "unknown"
    fi
}

# Relatorio completo do sistema
system_report() {
    echo "=== Relatorio do Sistema ==="
    echo ""
    echo "SO:              $(get_os)"
    echo "Arquitetura:     $(get_arch)"
    echo "Kernel:          $(get_kernel_version)"
    echo "CPU:             $(get_cpu_model)"
    echo "CPUs:            $(get_cpu_count)"
    echo "Memoria Total:   $(get_total_memory) MB"
    echo "Disco Livre:     $(get_disk_free) GB"
    echo "Container:       $(is_container && echo 'Sim' || echo 'Nao')"
    echo "VM:              $(is_vm && echo 'Sim' || echo 'Nao')"
    echo "Init System:     $(get_init_system)"
    echo ""
    
    # GPUs
    list_gpus
}

# Verificar requisitos minimos
check_system_requirements() {
    local issues=()
    
    # Memoria minima: 4GB
    local mem
    mem=$(get_total_memory)
    if [[ $mem -lt 4096 ]]; then
        issues+=("Memoria insuficiente: ${mem}MB (minimo: 4096MB)")
    fi
    
    # Disco minimo: 10GB
    local disk
    disk=$(get_disk_free)
    if [[ $disk -lt 10 ]]; then
        issues+=("Disco insuficiente: ${disk}GB (minimo: 10GB)")
    fi
    
    # Comandos essenciais
    local cmds=("git" "curl" "bash")
    for cmd in "${cmds[@]}"; do
        if ! command_exists "$cmd"; then
            issues+=("Comando nao encontrado: $cmd")
        fi
    done
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log_error "Requisitos nao atendidos:"
        printf '  - %s\n' "${issues[@]}" >&2
        return 1
    fi
    
    return 0
}

# ============================================================================
# FUNCOES UNIFICADAS PARA FASE 4
# ============================================================================

# Detectar sistema operacional (alias para get_os)
detect_os() {
    get_os
}

# Detectar arquitetura (alias para get_arch)
detect_arch() {
    get_arch
}

# Detectar gerenciador de pacotes
detect_pkg_mgr() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists brew; then
        echo "brew"
    elif command_exists zypper; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Mapear nome do pacote para o gerenciador de pacotes
get_pkg_name() {
    local pkg="$1"
    local pkg_mgr="${2:-$(detect_pkg_mgr)}"
    
    case "$pkg_mgr" in
        apt)
            case "$pkg" in
                build-essential) echo "build-essential" ;;
                cmake) echo "cmake" ;;
                git) echo "git" ;;
                curl) echo "curl" ;;
                wget) echo "wget" ;;
                python3) echo "python3" ;;
                python3-pip) echo "python3-pip" ;;
                nodejs) echo "nodejs" ;;
                npm) echo "npm" ;;
                docker.io) echo "docker.io" ;;
                jq) echo "jq" ;;
                unzip) echo "unzip" ;;
                *) echo "$pkg" ;;
            esac
            ;;
        dnf|yum)
            case "$pkg" in
                build-essential) echo "gcc gcc-c++ make" ;;
                cmake) echo "cmake" ;;
                git) echo "git" ;;
                curl) echo "curl" ;;
                wget) echo "wget" ;;
                python3) echo "python3" ;;
                python3-pip) echo "python3-pip" ;;
                nodejs) echo "nodejs" ;;
                npm) echo "npm" ;;
                docker.io) echo "docker" ;;
                jq) echo "jq" ;;
                unzip) echo "unzip" ;;
                *) echo "$pkg" ;;
            esac
            ;;
        pacman)
            case "$pkg" in
                build-essential) echo "base-devel" ;;
                cmake) echo "cmake" ;;
                git) echo "git" ;;
                curl) echo "curl" ;;
                wget) echo "wget" ;;
                python3) echo "python" ;;
                python3-pip) echo "python-pip" ;;
                nodejs) echo "nodejs npm" ;;
                npm) echo "npm" ;;
                docker.io) echo "docker" ;;
                jq) echo "jq" ;;
                unzip) echo "unzip" ;;
                *) echo "$pkg" ;;
            esac
            ;;
        brew)
            case "$pkg" in
                build-essential) echo "gcc" ;;
                cmake) echo "cmake" ;;
                git) echo "git" ;;
                curl) echo "curl" ;;
                wget) echo "wget" ;;
                python3) echo "python3" ;;
                python3-pip) echo "pip" ;;
                nodejs) echo "node" ;;
                npm) echo "node" ;;
                docker.io) echo "docker" ;;
                jq) echo "jq" ;;
                unzip) echo "unzip" ;;
                *) echo "$pkg" ;;
            esac
            ;;
        *)
            echo "$pkg"
            ;;
    esac
}

# Verificar se está em WSL
detect_wsl() {
    if [[ -f /proc/version ]]; then
        grep -qi microsoft /proc/version 2>/dev/null
    else
        return 1
    fi
}

# Verificar se está em container
detect_container() {
    if [[ -f /.dockerenv ]]; then
        return 0
    fi
    
    if [[ -f /proc/1/cgroup ]]; then
        grep -q "docker\|lxc\|container" /proc/1/cgroup 2>/dev/null
    fi
    
    return 1
}

# Verificar se tem build tools
has_build_tools() {
    local missing=()
    
    for cmd in make gcc g++; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    [[ ${#missing[@]} -eq 0 ]]
}

# Verificar se tem gerenciador de pacotes
has_package_manager() {
    local pkg_mgr
    pkg_mgr=$(detect_pkg_mgr)
    [[ "$pkg_mgr" != "unknown" ]]
}

# Relatório de detecção completa
detect_system() {
    local os arch pkg_mgr
    
    os=$(detect_os)
    arch=$(detect_arch)
    pkg_mgr=$(detect_pkg_mgr)
    
    log_info "Sistema detectado:"
    log_info "  OS: $os"
    log_info "  Arquitetura: $arch"
    log_info "  Gerenciador de pacotes: $pkg_mgr"
    log_info "  WSL: $(detect_wsl && echo 'Sim' || echo 'Não')"
    log_info "  Container: $(detect_container && echo 'Sim' || echo 'Não')"
    log_info "  Build Tools: $(has_build_tools && echo 'Sim' || echo 'Não')"
    
    # Retornar dados como variáveis globais
    DETECTED_OS="$os"
    DETECTED_ARCH="$arch"
    DETECTED_PKG_MGR="$pkg_mgr"
    
    export DETECTED_OS DETECTED_ARCH DETECTED_PKG_MGR
}
