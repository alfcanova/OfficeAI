#!/usr/bin/env bash
# OfficeAI Suite - GPU
# Funcoes para deteccao e gerenciamento de GPU

# Deteccao de GPU
detect_gpu() {
    local gpus=()
    
    # NVIDIA
    if command_exists nvidia-smi; then
        local nvidia_info
        nvidia_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null)
        while IFS= read -r line; do
            gpus+=("nvidia:$line")
        done <<< "$nvidia_info"
    fi
    
    # AMD (ROCm)
    if command_exists rocminfo; then
        local amd_info
        amd_info=$(rocminfo 2>/dev/null | grep "Marketing Name" | head -1 | sed 's/.*: //')
        if [[ -n "$amd_info" ]]; then
            gpus+=("amd:$amd_info")
        fi
    fi
    
    # Intel Arc
    if [[ -d /dev/dri ]]; then
        local intel_info
        intel_info=$(ls /dev/dri/ 2>/dev/null | grep render)
        if [[ -n "$intel_info" ]]; then
            gpus+=("intel:Arc GPU")
        fi
    fi
    
    # CPU fallback
    if [[ ${#gpus[@]} -eq 0 ]]; then
        gpus+=("cpu:CPU only")
    fi
    
    printf '%s\n' "${gpus[@]}"
}

# Verificar se GPU esta disponivel
has_gpu() {
    local gpu_type="${1:-nvidia}"
    
    case "$gpu_type" in
        nvidia)
            command_exists nvidia-smi && nvidia-smi &>/dev/null
            ;;
        amd)
            command_exists rocminfo
            ;;
        *)
            return 1
            ;;
    esac
}

# Obter informacoes da GPU
get_gpu_info() {
    local gpu_type="${1:-nvidia}"
    
    case "$gpu_type" in
        nvidia)
            if has_gpu nvidia; then
                nvidia-smi --query-gpu=name,memory.total,memory.used,temperature.gpu --format=csv,noheader
            fi
            ;;
        amd)
            if has_gpu amd; then
                rocminfo 2>/dev/null | grep -E "(Marketing Name|Memory)" | head -5
            fi
            ;;
    esac
}

# Configurar Ollama para GPU
configure_ollama_gpu() {
    local gpu_type="${1:-auto}"
    
    if [[ "$gpu_type" == "auto" ]]; then
        if has_gpu nvidia; then
            gpu_type="nvidia"
        elif has_gpu amd; then
            gpu_type="amd"
        else
            gpu_type="cpu"
        fi
    fi
    
    case "$gpu_type" in
        nvidia)
            export OLLAMA_GPU_LAYERS="999"
            export CUDA_VISIBLE_DEVICES="0"
            log_info "Ollama configurado para NVIDIA GPU"
            ;;
        amd)
            export OLLAMA_GPU_LAYERS="999"
            export HSA_OVERRIDE_GFX_VERSION="10.3.0"
            log_info "Ollama configurado para AMD GPU"
            ;;
        cpu)
            export OLLAMA_GPU_LAYERS="0"
            log_info "Ollama configurado para CPU"
            ;;
    esac
}

# Verificar VRAM disponivel
get_available_vram() {
    local gpu_type="${1:-nvidia}"
    
    case "$gpu_type" in
        nvidia)
            if has_gpu nvidia; then
                nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | head -1
            fi
            ;;
        *)
            echo "0"
            ;;
    esac
}

# Listar GPUs com detalhes
list_gpus() {
    echo "=== GPUs Detectadas ==="
    echo ""
    
    while IFS= read -r gpu; do
        local type="${gpu%%:*}"
        local info="${gpu#*:}"
        
        case "$type" in
            nvidia)
                echo "NVIDIA: $info"
                ;;
            amd)
                echo "AMD: $info"
                ;;
            intel)
                echo "Intel: $info"
                ;;
            cpu)
                echo "CPU: $info (fallback)"
                ;;
        esac
    done < <(detect_gpu)
    
    echo ""
}
