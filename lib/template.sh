#!/usr/bin/env bash
# OfficeAI Suite - Template
# Gerenciamento de templates de projeto

TEMPLATE_DIR="${OFFICEAI_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/templates"

# Listar templates disponiveis
list_templates() {
    local templates=()
    
    if [[ -d "$TEMPLATE_DIR" ]]; then
        while IFS= read -r dir; do
            local name
            name=$(basename "$dir")
            if [[ -f "$dir/template.yaml" ]]; then
                templates+=("$name")
            fi
        done < <(find "$TEMPLATE_DIR" -mindepth 1 -maxdepth 1 -type d)
    fi
    
    if [[ ${#templates[@]} -eq 0 ]]; then
        log_warn "Nenhum template encontrado"
        return 1
    fi
    
    printf '%s\n' "${templates[@]}"
}

# Obter info de um template
get_template_info() {
    local template="$1"
    local file="$TEMPLATE_DIR/$template/template.yaml"
    
    if [[ ! -f "$file" ]]; then
        log_error "Template nao encontrado: $template"
        return 1
    fi
    
    if _has_yq; then
        echo "Nome:        $(yaml_get "$file" ".name")"
        echo "Descricao:   $(yaml_get "$file" ".description")"
        echo "Autor:       $(yaml_get "$file" ".author")"
        echo "Versao:      $(yaml_get "$file" ".version")"
        echo "Dependencias: $(yaml_get "$file" ".dependencies | join(\", \")")"
    else
        cat "$file"
    fi
}

# Criar projeto a partir de template
create_from_template() {
    local template="$1"
    local project_name="$2"
    local project_dir="${3:-$(pwd)/$project_name}"
    
    local template_dir="$TEMPLATE_DIR/$template"
    
    if [[ ! -d "$template_dir" ]]; then
        log_error "Template nao encontrado: $template"
        return 1
    fi
    
    log_step "Criando projeto: $project_name"
    log_step "Template: $template"
    
    # Criar diretorio do projeto
    mkdir -p "$project_dir"
    
    # Copiar arquivos do template
    if [[ -d "$template_dir/files" ]]; then
        cp -r "$template_dir/files/"* "$project_dir/" 2>/dev/null
    fi
    
    # Processar variaveis no template
    local vars=(
        "PROJECT_NAME=$project_name"
        "PROJECT_DIR=$project_dir"
        "CREATED_AT=$(date -Iseconds)"
    )
    
    # Ler variaveis do template
    if [[ -f "$template_dir/variables.env" ]]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            vars+=("$key=$value")
        done < "$template_dir/variables.env"
    fi
    
    # Substituir em arquivos
    find "$project_dir" -type f -name "*.template" | while read -r file; do
        for var in "${vars[@]}"; do
            local key="${var%%=*}"
            local value="${var#*=}"
            sed -i "s|{{${key}}}|${value}|g" "$file"
        done
        # Renomear arquivo
        mv "$file" "${file%.template}"
    done
    
    # Executar script de inicializacao
    if [[ -f "$template_dir/setup.sh" ]]; then
        log_step "Executando setup do template..."
        (cd "$project_dir" && bash "$template_dir/setup.sh")
    fi
    
    log_success "Projeto criado: $project_dir"
}

# Criar template
create_template() {
    local name="$1"
    local description="$2"
    
    local template_dir="$TEMPLATE_DIR/$name"
    
    if [[ -d "$template_dir" ]]; then
        log_error "Template ja existe: $name"
        return 1
    fi
    
    mkdir -p "$template_dir/files"
    
    # Criar template.yaml
    cat > "$template_dir/template.yaml" << EOF
name: $name
description: $description
author: "$(git config user.name 2>/dev/null || echo "unknown")"
version: "1.0.0"
created_at: "$(date -Iseconds)"
dependencies: []
EOF
    
    log_success "Template criado: $template_dir"
    echo "Edite $template_dir/template.yaml para configurar"
}

# Listar templates como menu
template_menu() {
    echo ""
    echo "=== Templates Disponiveis ==="
    echo ""
    
    local i=1
    while IFS= read -r template; do
        local desc
        desc=$(yaml_get "$TEMPLATE_DIR/$template/template.yaml" ".description" 2>/dev/null || echo "")
        echo "  $i) $template - $desc"
        ((i++))
    done < <(list_templates)
    
    echo ""
    echo "  0) Voltar"
    echo ""
}
