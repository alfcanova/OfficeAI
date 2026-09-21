# Especificação da Fase 4 - OfficeAI Suite

## Visão Geral

A Fase 4 foca em **refatoração, padronização e melhorias de qualidade** do código existente, preparando o projeto para escalabilidade e manutenção a longo prazo. Esta fase não adiciona novas funcionalidades, mas corrige inconsistências e elimina duplicação.

## Objetivos

1. Eliminar código duplicado entre scripts
2. Padronizar padrões de instalação e fallback
3. Melhorar tratamento de erros e logging
4. Unificar funções utilitárias nas bibliotecas existentes
5. Adicionar recursos de segurança e integridade

## Componentes

### 1. Refatoração de Bibliotecas (`lib/`)

#### 1.1 `lib/utils.sh` - Funções Utilitárias
- Adicionar `command_exists()` (atualmente duplicado em 6+ arquivos)
- Adicionar `remove_from_path()` para unsetenv seguro
- Adicionar `calculate_checksum()` para verificação de integridade

#### 1.2 `lib/system.sh` - Detecção de Sistema
- Consolidar `detect_arch()` (atualmente em 3+ arquivos)
- Adicionar `detect_os()` (atualmente apenas em OpenCode)
- Unificar `detect_pkg_mgr()` e `get_pkg_name()`
- Adicionar `detect_wsl()` e `detect_container()`

#### 1.3 `lib/loader.sh` - Carregamento e Execução
- Adicionar `run_and_capture()` (atualmente duplicado nos 3 hubs)
- Adicionar `script_init()` para inicialização padrão
- Adicionar `cleanup()` com trap para sinais

### 2. Padronização de Scripts de Instalação

#### 2.1 Padrão Obrigatório para Todos os Sub-scripts
```bash
#!/usr/bin/env bash
set -euo pipefail
source "$OFFICEAI_ROOT/lib/colors.sh"
source "$OFFICEAI_ROOT/lib/log.sh"
source "$OFFICEAI_ROOT/lib/system.sh"
source "$OFFICEAI_ROOT/lib/utils.sh"

# Inicialização padrão
script_init "$(basename "$0" .sh)"

# Função de instalação com fallback em cascata
install_tool() {
    local method=0
    local methods=("oficial" "package_manager" "binary")
    
    # Método 1: Script oficial
    if install_via_official; then
        log_info "Instalado via método oficial"
        return 0
    fi
    
    # Método 2: Gerenciador de pacotes
    if install_via_package_manager; then
        log_info "Instalado via gerenciador de pacotes"
        return 0
    fi
    
    # Método 3: Download direto
    if install_via_binary; then
        log_info "Instalado via download direto"
        return 0
    fi
    
    log_error "Todos os métodos de instalação falharam"
    return 1
}
```

#### 2.2 Geração Padrão de setenv/unsetenv
- Usar template em `lib/template.sh` (já existe)
- Verificar integridade com checksum
- Gerar scripts com `remove_from_path()` seguro

### 3. Melhorias de Segurança

#### 3.1 Verificação de Integridade
- Calcular SHA256 para todos os binários baixados
- Verificar checksums oficiais quando disponíveis
- Log de tentativas de verificação

#### 3.2 Tratamento de Sinais
- Adicionar `trap` para EXIT, INT, TERM
- Limpeza automática de arquivos temporários
- Rollback em caso de falha intermediária

#### 3.3 Validação de Entrada
- Verificar permissões antes de instalar
- Validar URLs e caminhos
- Proteção contra path traversal

### 4. Melhorias de Experiência do Usuário

#### 4.1 Modo Não-Interativo
- Flag `--non-interactive` para CI/CD
- Flag `--auto` para instalação automática
- Valores padrão configuráveis

#### 4.2 Status e Progresso
- Barra de progresso para downloads
- Resumo de instalação no final
- Sugestões pós-instalação

#### 4.3 Relatórios
- Relatório de compatibilidade do sistema
- Lista de ferramentas instaladas/pendentes
- Sugestões de próximos passos

### 5. Testes e Validação

#### 5.1 Testes Unitários
- Testar funções utilitárias isoladamente
- Testar detecção de sistema
- Testar geração de setenv/unsetenv

#### 5.2 Testes de Integração
- Testar fluxo completo de instalação
- Testar compatibilidade entre distros
- Testar rollback em falhas

#### 5.3 Validação Contínua
- Script de validação `scripts/validate.sh`
- Verificação automática de padrões
- Relatório de inconsistências

## Estrutura de Arquivos

```
OfficeAI/
├── lib/
│   ├── utils.sh          # Atualizado com funções novas
│   ├── system.sh         # Atualizado com detecções unificadas
│   ├── loader.sh         # Atualizado com run_and_capture
│   └── ...               # Outras libs existentes
├── scripts/
│   ├── 00_SystemBase.sh  # Refatorado para usar libs
│   ├── 01.00_Languages.sh # Atualizado com boilerplate padronizado
│   ├── 02.00_CLIs.sh     # Atualizado com boilerplate padronizado
│   ├── 03.00_LlmServers.sh # Atualizado com boilerplate padronizado
│   ├── validate.sh       # Novo: validação de padrões
│   └── ...               # Sub-scripts atualizados
├── specs/
│   ├── fase4-spec.md     # Este documento
│   ├── padrões.md        # Padrões de código
│   └── testes.md         # Estratégia de testes
└── ...
```

## Prioridades de Implementação

### Fase 4.1 - Fundamentos (Semana 1-2)
1. Atualizar `lib/utils.sh` com `command_exists()` e `remove_from_path()`
2. Atualizar `lib/system.sh` com detecções unificadas
3. Atualizar `lib/loader.sh` com `run_and_capture()` e `script_init()`
4. Criar `scripts/validate.sh` para verificação de padrões

### Fase 4.2 - Padronização (Semana 3-4)
1. Atualizar os 3 hubs (01.00, 02.00, 03.00) para usar boilerplate padronizado
2. Atualizar 3-5 sub-scripts de exemplo para usar novo padrão
3. Testar compatibilidade com Debian, Fedora e macOS

### Fase 4.3 - Segurança e UX (Semana 5-6)
1. Adicionar verificação de checksum em sub-scripts críticos
2. Implementar trap para cleanup
3. Adicionar modo não-interativo
4. Criar testes unitários básicos

### Fase 4.4 - Consolidação (Semana 7-8)
1. Atualizar todos os sub-scripts restantes
2. Rodar validação completa
3. Atualizar documentação
4. Criar release notes

## Métricas de Sucesso

- [ ] Redução de ≥50% no código duplicado
- [ ] Todos os sub-scripts usam boilerplate padronizado
- [ ] Funções utilitárias centralizadas em lib/
- [ ] Verificação de checksum em ≥80% dos downloads
- [ ] Testes passando em Debian, Fedora e macOS
- [ ] Documentação atualizada
- [ ] Zero warnings no `scripts/validate.sh`

## Riscos e Mitigações

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| Breaking changes em scripts existentes | Alto | Testar cada alteração individualmente |
| Incompatibilidade com distros específicas | Médio | Matriz de teste com 3+ distros |
| Performance de checksums | Baixo | Cache de checksums verificados |
| Complexidade adicional | Médio | Documentação clara e exemplos |

## Critérios de Aceitação

1. Todos os scripts existentes continuam funcionando
2. Código duplicado reduzido em ≥50%
3. Padrão de fallback em cascata implementado em ≥80% dos sub-scripts
4. Verificação de checksum funcionando
5. Testes unitários com ≥70% de cobertura das funções utilitárias
6. Documentação atualizada com novos padrões
7. Validação automática passando sem erros

## Contato

- Responsável: [A definir]
- Revisão: [Data]
- Aprovação: [Data]