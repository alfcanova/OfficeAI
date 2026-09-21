#!/usr/bin/env bash
# OfficeAI Suite - YAML
# Funcoes para parsing de YAML

# Verificar se yq esta disponivel
_has_yq() {
    command -v yq &>/dev/null
}

# Ler valor do YAML usando yq
yaml_get() {
    local file="$1"
    local path="$2"
    
    if _has_yq; then
        yq eval "$path" "$file" 2>/dev/null
    else
        # Fallback: parsing basico com grep/sed
        _yaml_get_simple "$file" "$path"
    fi
}

# Parser YAML simples (sem yq)
_yaml_get_simple() {
    local file="$1"
    local path="$2"
    
    # Remove prefixes como . ou ~
    local clean_path
    clean_path=$(echo "$path" | sed 's/^[.~]*//')
    
    # Converter notacao de ponto para hierarquia
    local keys
    IFS='.' read -ra keys <<< "$clean_path"
    
    local current=""
    local indent=0
    
    while IFS= read -r line; do
        # Ignorar linhas vazias e comentarios
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Calcular indentacao
        local spaces="${line%%[![:space:]]*}"
        local current_indent=${#spaces}
        
        # Converter linha para formato chave: valor
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*(.*) ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Verificar se e o nivel desejado
            if [[ "$current_indent" -eq $((indent * 2)) ]]; then
                if [[ "$key" == "${keys[$indent]}" ]]; then
                    if [[ $((indent + 1)) -eq ${#keys[@]} ]]; then
                        # Encontrou! Limpar valor
                        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        value=$(echo "$value" | sed 's/^["'"'"']//;s/["'"'"']$//')
                        echo "$value"
                        return 0
                    fi
                    ((indent++))
                fi
            fi
        fi
    done < "$file"
    
    return 1
}

# Converter YAML para variaveis de ambiente
yaml_to_env() {
    local file="$1"
    local prefix="${2:-}"
    
    if _has_yq; then
        yq eval -o=props "$file" 2>/dev/null | while IFS='=' read -r key value; do
            key=$(echo "$key" | tr '.' '_' | tr '[:lower:]' '[:upper:]')
            [[ -n "$prefix" ]] && key="${prefix}_${key}"
            export "$key"="$value"
        done
    else
        log_warn "yq necessario para yaml_to_env"
        return 1
    fi
}

# Verificar se arquivo YAML e valido
yaml_validate() {
    local file="$1"
    
    if ! [[ -f "$file" ]]; then
        log_error "Arquivo nao encontrado: $file"
        return 1
    fi
    
    if _has_yq; then
        yq eval '.' "$file" &>/dev/null
    else
        # Validacao basica de sintaxe
        local indent_prev=0
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            local spaces="${line%%[![:space:]]*}"
            local indent=${#spaces}
            
            # Indentacao deve ser multipla de 2
            if ((indent % 2 != 0)); then
                log_error "Indentacao invalida na linha: $line"
                return 1
            fi
        done < "$file"
    fi
    
    return 0
}

# Listar chaves de um nivel
yaml_keys() {
    local file="$1"
    local path="${2:-.}"
    
    if _has_yq; then
        yq eval "$path | keys | .[]" "$file" 2>/dev/null
    else
        log_warn "yq necessario para yaml_keys"
        return 1
    fi
}

# Mesclar dois arquivos YAML
yaml_merge() {
    local base="$1"
    local overlay="$2"
    
    if _has_yq; then
        yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$base" "$overlay"
    else
        log_warn "yq necessario para yaml_merge"
        return 1
    fi
}
