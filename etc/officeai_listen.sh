#!/usr/bin/env bash
# ============================================================================
# OfficeAI - Listener de Ambiente
# Escuta comandos via FIFO e executa no terminal atual
# Uso: source officeai_listen.sh
# ============================================================================

FIFO_PATH="/tmp/officeai_cmd_fifo"

# Coalias para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Funcao para processar comandos
officeai_listen() {
    # Criar FIFO se nao existir
    [[ -p "$FIFO_PATH" ]] || mkfifo "$FIFO_PATH"
    
    echo -e "${CYAN}OfficeAI Listener ativo${RESET}"
    echo -e "${CYAN}Aguardando comandos em:${RESET} $FIFO_PATH"
    echo -e "${YELLOW}Pressione Ctrl+C para parar${RESET}"
    echo ""
    
    while true; do
        if read -r cmd < "$FIFO_PATH"; then
            if [[ -n "$cmd" ]]; then
                # Extrair nome do script para display
                script_name=$(basename "$cmd" .sh)
                script_name=${script_name#env}
                script_name=${script_name#unenv}
                
                if [[ "$cmd" == "source "* ]]; then
                    file_path="${cmd#source }"
                    file_path=$(echo "$file_path" | xargs)  # trim
                    
                    if [[ "$file_path" == *unenv* ]]; then
                        echo -e "${YELLOW}[OfficeAI] Desativando: ${script_name}${RESET}"
                    else
                        echo -e "${GREEN}[OfficeAI] Ativando: ${script_name}${RESET}"
                    fi
                    
                    # Executar source no shell atual
                    source "$file_path"
                    
                    echo -e "${GREEN}[OfficeAI] Ambiente atualizado${RESET}"
                    echo ""
                fi
            fi
        fi
    done
}

# Verificar se esta sendo sourced (nao executado direto)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Este script deve ser sourcing, nao executado:"
    echo "  source $0"
    exit 1
fi

# Iniciar listener
officeai_listen
