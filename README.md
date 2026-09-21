# OfficeAI Suite v2.1.0 — Auto-contido

Conjunto modular de scripts Bash para instalação e gerenciamento de ferramentas de desenvolvimento e CLIs de IA. **A pasta OfficeAI é auto-contida**: todas as ferramentas são instaladas, executadas e mantêm dados (config/cache/credenciais) **dentro da pasta** — nada vaza para o sistema host (sem `sudo`, sem `/usr/local`, sem `~/.local/bin`).

## Estrutura

```
OfficeAI/
├── bin/          # Executaveis (symlinks) + scripts setenv/unsetenv por ferramenta
├── lib/          # Runtimes instalados (lib/<tool>) + bibliotecas bash (.sh)
│   └── languages/# Rust, Go, Zig, Node, uv
├── share/        # Dados persistentes: modelos (share/ollama-models), docs
├── var/          # Estado: home virtual (var/home), backup de ambiente
│   └── home/     # HOME virtual: .config, .cache, .local, .runtime, .tmp
├── etc/          # 00_envGeneral.sh (ativar) / 00_unenvGeneral.sh (desativar)
├── scripts/      # Instaladores (fases 0-5) + hubs de menu + migracao
├── docs/         # Documentacao HTML + especificacoes SDD
├── ollama_models/# Definições de modelos
└── logs/         # Logs de instalação
```

## Fluxo de Instalação

```bash
bash scripts/00_SystemBase.sh       # Fase 0: Python + uv (100% local)
bash scripts/01.00_Languages.sh     # Fase 1: Rust, Go, Zig, Node.js
bash scripts/02.00_CLIs.sh          # Fase 2: OpenCode, Claude, Codex, Qwen, ...
bash scripts/03.00_LlmServers.sh    # Fase 3: Ollama, vLLM, llama.cpp, Jan, ...
bash scripts/04.00_SDDs.sh          # Fase 4: Kiro, OpenSpec, SpecKit
bash scripts/05.00_Visual.sh        # Fase 5: VS Code, VSCodium
```

Cada menu suporta: `[1-9]` instalar individual, `[A]` instalar todos, `[P]` fase anterior, `[N]` próxima fase, `[X]` sair.

> **Fase 0 é 100% local** (Python+uv via binário). Compiladores não são instalados;
> Node.js é instalado pela fase 1 via tarball.

## Ativação / Desativação de Ambiente

Qualquer shell:

```bash
# Ativar tudo (HOME, XDG, TMPDIR, caches e PATH -> dentro da pasta)
source etc/00_envGeneral.sh

# Desativar tudo (restaura HOME, XDG, PATH originais)
source etc/00_unenvGeneral.sh

# Ativar/desativar ferramenta individual
source bin/01.01_setenv_rust.sh    # Ativar Rust
source bin/01.01_unsetenv_rust.sh  # Desativar Rust
```

### Ativação automática (opcional)

`00_SystemBase.sh` (opção `[A]`) adiciona um **bloco condicional único** ao `~/.bashrc`
real, que ativa o ambiente só se `$HOME/.officeai/etc/00_envGeneral.sh` existir
(`$HOME/.officeai` é um symlink para a pasta OfficeAI).

## Portabilidade (mover a pasta)

Se mover a pasta OfficeAI para outro local:

```bash
bash scripts/link_local.sh          # regera symlinks de bin/ + $HOME/.officeai
```

Todos os scripts resolvem `OFFICEAI_ROOT` dinamicamente a partir do próprio caminho —
nenhum caminho absoluto é hardcoded.

## Migração de instalações antigas (`modules/`)

Instalações existentes em `modules/` (layout antigo) migram sem redownload:

```bash
bash scripts/10_migrate_layout.sh   # move modules/ -> lib/ (mv local) + cria bin/
```

## Documentação Web

```bash
python3 scripts/server.py          # Inicia servidor na porta 8765
python3 scripts/server.py 9000     # Porta personalizada
python3 -m py_compile scripts/server.py  # checar sintaxe
```

## Layout de instalação por ferramenta

| Categoria | Destino runtime | Executável | Dados |
|---|---|---|---|
| Rust | `lib/rust/cargo` + `lib/rust/rustup` | `bin/rustc`, `bin/cargo` | — |
| Go | `lib/go` | `bin/go`, `bin/gofmt` | `var/home/go` (GOPATH), GOBIN=`bin/` |
| Zig | `lib/zig` | `bin/zig` | — |
| Node.js | `lib/node` | `bin/node`, `bin/npm`, `bin/npx` | npm prefix `lib/npm`, bun `lib/bun` |
| uv | `lib/languages/uv` | `bin/uv`, `bin/uvx` | cache `var/home/.cache/uv` |
| CLIs npm | `lib/npm/<tool>` | `bin/<tool>` | — |
| CLIs uv tool | `lib/uv-tools/<tool>` | `bin/<tool>` | — |
| CLIs binário | `lib/<tool>/bin` | `bin/<tool>` | — |
| Python venv (vLLM, Open WebUI) | `lib/<tool>/venv` | `bin/<tool>` | — |
| Ollama | `lib/ollama/bin` | `bin/ollama` | `share/ollama-models` |
| llama.cpp | `lib/llamacpp/bin` | `bin/llama-*` | — |
| GUI (Jan, LM Studio, VS Code) | `lib/<tool>` | `bin/<tool>` (AppImage/tarball) | `var/home` |

## Tecnologias

| Categoria | Tecnologias |
|---|---|
| Linguagem principal | Bash |
| Servidor de docs | Python 3 |
| Frontend | HTML5, CSS3 (dark theme), JavaScript |
| Gerenciadores de pacote | npm (prefix local), uv tool (local), cargo, rustup |
| Linguagens gerenciadas | Python, Node.js, Rust, Go, Zig |
| CLIs de IA | OpenCode, Claude, Codex, Qwen, Kimi, FreeBuff, AntiGravity, Copilot, Pi, Cline, Cursor, Aider |
| Servidores LLM | vLLM, Ollama, llama.cpp, LocalAI, Jan, LM Studio, Open WebUI, OpenClaw |
| GUI | VS Code, VSCodium |
| Compatibilidade | Linux (Debian 13+), sem root, sem bwrap |

## Padrões Arquiteturais

- **Auto-contido** — instalações em `lib/`, executáveis linkados em `bin/`, HOME virtual em `var/home/`
- **Containment por variáveis de ambiente** — `etc/00_envGeneral.sh` redireciona HOME, XDG, TMPDIR, caches e PATH (sem bwrap/chroot)
- **Padrão setenv/unsetenv** — cada ferramenta gera scripts próprios de ativação/desativação
- **Auto-descoberta** — hubs detectam scripts por glob (`01.XX_Language*.sh`, `02.XX_CLI*.sh`, ...)
- **Portabilidade** — `OFFICEAI_ROOT` sempre resolvido dinamicamente; `link_local.sh` re-links após mover a pasta
- **Migração sem redownload** — `10_migrate_layout.sh` move `modules/` → `lib/`



## Licença
Este projeto é desenvolvido para fins de pesquisa e desenvolvimento de linguagens de programação. Consulte a documentação em docs/ para obter detalhes completos da especificação e licença.

               GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007 Copyright (C) 2007 Free Software
