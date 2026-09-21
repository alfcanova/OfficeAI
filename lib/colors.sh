#!/usr/bin/env bash
# OfficeAI Suite - Cores
# Biblioteca de cores para o terminal

# Cores Basicas
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'

# Cores de fundo
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'

# Estilos
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
REVERSE='\033[7m'
RESET='\033[0m'

# Verificar suporte a cores
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
    USE_COLOR=true
else
    USE_COLOR=false
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
    GRAY=""
    BG_RED=""
    BG_GREEN=""
    BG_YELLOW=""
    BG_BLUE=""
    BOLD=""
    DIM=""
    UNDERLINE=""
    BLINK=""
    REVERSE=""
    RESET=""
fi

# Funcoes auxiliares de cor
colorize() {
    local color="$1"
    local text="$2"
    if [[ "$USE_COLOR" == true ]]; then
        echo -e "${color}${text}${RESET}"
    else
        echo "$text"
    fi
}

red() { colorize "$RED" "$*"; }
green() { colorize "$GREEN" "$*"; }
yellow() { colorize "$YELLOW" "$*"; }
blue() { colorize "$BLUE" "$*"; }
magenta() { colorize "$MAGENTA" "$*"; }
cyan() { colorize "$CYAN" "$*"; }
white() { colorize "$WHITE" "$*"; }
gray() { colorize "$GRAY" "$*"; }
bold() { colorize "$BOLD" "$*"; }

# Caixas decorativos
box() {
    local text="$1"
    local color="${2:-$CYAN}"
    local width=${#text}
    ((width += 4))
    local border=$(printf '%*s' "$width" '' | tr ' ' '─')
    
    echo ""
    if [[ "$USE_COLOR" == true ]]; then
        echo -e "${color}┌${border}┐${RESET}"
        echo -e "${color}│${RESET}  ${text}  ${color}│${RESET}"
        echo -e "${color}└${border}┘${RESET}"
    else
        echo "┌${border}┐"
        echo "│  ${text}  │"
        echo "└${border}┘"
    fi
    echo ""
}

# Icones simples (para terminais com suporte)
icon_check="✓"
icon_cross="✗"
icon_arrow="→"
icon_star="★"
icon_info="ℹ"
icon_warn="⚠"
icon_error="✕"
