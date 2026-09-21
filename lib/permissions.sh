#!/usr/bin/env bash
# OfficeAI Suite - Permissions
# Gerenciamento de permissoes

# Modo de operacao
OFFICEAI_MODE="${OFFICEAI_MODE:-local}"

# Diretorio base do usuario
get_user_dir() {
    if [[ "$OFFICEAI_MODE" == "local" ]]; then
        echo "${OFFICEAI_ROOT:-$(get_officeai_root)}/var/home/.officeai"
    else
        echo "${OFFICEAI_ROOT:-$(get_officeai_root)}"
    fi
}

# Configurar permissoes padrao
setup_permissions() {
    local root="${OFFICEAI_ROOT:-$(get_officeai_root)}"
    local mode="${OFFICEAI_MODE:-local}"
    
    log_step "Configurando permissoes (modo: $mode)..."
    
    if [[ "$mode" == "local" ]]; then
        # Modo local: usuario atual
        chmod 700 "$root/etc"
        chmod 700 "$root/etc/providers.env" 2>/dev/null
        chmod 755 "$root/bin"
        chmod 755 "$root/scripts"
        chmod 755 "$root/lib"
        chmod 755 "$root/packages"
        chmod 755 "$root/modules"
        
        # Logs e temp
        chmod 750 "$root/logs" 2>/dev/null
        chmod 750 "$root/temp" 2>/dev/null
        
    elif [[ "$mode" == "global" ]]; then
        # Modo global: requer root
        if ! is_root; then
            log_error "Modo global requer permissoes de root"
            return 1
        fi
        
        chown -R root:root "$root"
        chmod 755 "$root"
        chmod 700 "$root/etc"
        chmod 700 "$root/etc/providers.env" 2>/dev/null
        chmod 755 "$root/bin"
        chmod 755 "$root/scripts"
        chmod 755 "$root/lib"
        chmod 755 "$root/packages"
        chmod 755 "$root/modules"
        
        # Criar grupo officeai
        if ! getent group officeai &>/dev/null; then
            groupadd officeai
        fi
        
        # Adicionar usuario ao grupo
        if [[ -n "${SUDO_USER:-}" ]]; then
            usermod -aG officeai "$SUDO_USER"
        fi
    fi
    
    log_success "Permissoes configuradas"
}

# Verificar permissao de escrita
can_write() {
    local path="$1"
    [[ -w "$path" ]] || [[ -w "$(dirname "$path")" ]]
}

# Verificar se pode instalar globalmente
can_install_global() {
    if is_root; then
        return 0
    elif command_exists sudo; then
        sudo -n true 2>/dev/null
    else
        return 1
    fi
}

# Obter permissao recomendada para arquivo
get_recommended_perm() {
    local file="$1"
    local type="${2:-config}"
    
    case "$type" in
        config)
            if [[ "$file" == *"providers.env"* ]] || [[ "$file" == *"secret"* ]]; then
                echo "600"
            else
                echo "644"
            fi
            ;;
        script)
            echo "755"
            ;;
        directory)
            echo "755"
            ;;
        *)
            echo "644"
            ;;
    esac
}

# Corrigir permissoes
fix_permissions() {
    local root="${OFFICEAI_ROOT:-$(get_officeai_root)}"
    
    log_step "Corrigindo permissoes..."
    
    # Arquivos sensiveis
    local sensitive_files=(
        "$root/etc/providers.env"
        "$root/etc/secrets.yaml"
    )
    
    for file in "${sensitive_files[@]}"; do
        if [[ -f "$file" ]]; then
            chmod 600 "$file"
            log_debug "Permissao corrigida: $file (600)"
        fi
    done
    
    # Scripts devem ser executaveis
    find "$root/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
    find "$root/bin" -type f -exec chmod +x {} \; 2>/dev/null
    
    log_success "Permissoes corrigidas"
}

# Verificar integridade
check_integrity() {
    local root="${OFFICEAI_ROOT:-$(get_officeai_root)}"
    local issues=()
    
    # Verificar arquivos sensiveis
    local providers="$root/etc/providers.env"
    if [[ -f "$providers" ]]; then
        local perm
        perm=$(stat -c %a "$providers" 2>/dev/null || stat -f %Lp "$providers" 2>/dev/null)
        if [[ "$perm" != "600" ]]; then
            issues+=("providers.env com permissao incorreta: $perm (deveria ser 600)")
        fi
    fi
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log_warn "Problemas de permissao encontrados:"
        printf '  - %s\n' "${issues[@]}"
        return 1
    fi
    
    return 0
}
