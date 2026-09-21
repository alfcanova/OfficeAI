#!/usr/bin/env python3
"""
OfficeAI - Server de Documentacao
Controla estado dos ambientes e atualiza flags no HTML.
"""

import os
import re
import sys
import json
from pathlib import Path
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse

OFFICEAI_ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = OFFICEAI_ROOT / "docs"

# Estado dos ambientes
ENV_STATE = {
    "rust": False,
    "go": False,
    "zig": False,
    "uv": False,
    "node": False  # Node local em lib/node (01.04)
}

# Mapeamento de linguagens para arquivos HTML
LANG_FILES = {
    "rust": "rust.html",
    "go": "go.html",
    "zig": "zig.html",
    "uv": "python.html",
    "node": "nodejs.html"
}

# Mapa de comandos (setenv/unsetenv gerados em bin/) para linguagens
CMD_MAP = {
    "00_setenv_SystemBase.sh": "uv",
    "00_unsetenv_SystemBase.sh": "uv",
    "01.01_setenv_rust.sh": "rust",
    "01.01_unsetenv_rust.sh": "rust",
    "01.03_setenv_go.sh": "go",
    "01.03_unsetenv_go.sh": "go",
    "01.02_setenv_zig.sh": "zig",
    "01.02_unsetenv_zig.sh": "zig",
    "01.04_setenv_nodejs.sh": "node",
    "01.04_unsetenv_nodejs.sh": "node",
}


def collect_installed_bin():
    """Nomes dos symlinks em bin/ (executaveis do layout auto-contido)"""
    bin_dir = OFFICEAI_ROOT / "bin"
    if not bin_dir.exists():
        return []
    return sorted(p.name for p in bin_dir.iterdir() if p.is_symlink())


def collect_installed_lib():
    """Diretorios de ferramentas instaladas em lib/"""
    lib_dir = OFFICEAI_ROOT / "lib"
    if not lib_dir.exists():
        return []
    return sorted(p.name for p in lib_dir.iterdir() if p.is_dir())


def update_html_flag(lang, available):
    """Atualiza flag no HTML da linguagem"""
    html_file = DOCS_DIR / LANG_FILES.get(lang, "")
    if not html_file.exists():
        return
    
    content = html_file.read_text()
    
    if available:
        new_class = "flag available"
        new_text = "Disponivel"
    else:
        new_class = "flag unavailable"
        new_text = "Indisponivel"
    
    # Substituir flag (com ou sem id)
    if lang == "uv":
        pattern = r'class="flag [^"]*" id="py-flag">[^<]*</span>'
        replacement = f'class="{new_class}" id="py-flag">{new_text}</span>'
    else:
        pattern = r'class="flag [^"]*">[^<]*</span>'
        replacement = f'class="{new_class}">{new_text}</span>'
    
    new_content = re.sub(pattern, replacement, content, count=1)
    
    if new_content != content:
        html_file.write_text(new_content)


class OfficeAIHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DOCS_DIR), **kwargs)
    
    def do_GET(self):
        parsed = urlparse(self.path)
        
        if parsed.path == "/api/status":
            self.send_json({"state": ENV_STATE})
            return
        
        if parsed.path == "/api/installed":
            self.send_json({"bin": collect_installed_bin(), "lib": collect_installed_lib()})
            return
        
        super().do_GET()
    
    def do_POST(self):
        parsed = urlparse(self.path)
        
        if parsed.path == "/api/exec":
            self.handle_exec()
        elif parsed.path == "/api/toggle":
            self.handle_toggle()
        else:
            self.send_error(404)
    
    def handle_exec(self):
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body)
            
            command = data.get("command", "").strip()
            
            if not command:
                self.send_json({"error": "No command"}, 400)
                return
            
            # Identificar linguagem pelo nome do script
            script_name = os.path.basename(command.replace("source ", ""))
            lang = next((l for k, l in CMD_MAP.items() if k in script_name), None)
            
            if not lang:
                self.send_json({"error": "Unknown command"}, 400)
                return
            
            # Atualizar estado
            is_unenv = "unenv" in script_name
            ENV_STATE[lang] = not is_unenv
            
            # Atualizar HTML
            update_html_flag(lang, ENV_STATE[lang])
            
            # Scripts de ambiente vivem em bin/ (novo layout) - fallback etc/
            script_path = None
            for base in (OFFICEAI_ROOT / "bin", OFFICEAI_ROOT / "etc"):
                candidate = base / script_name
                if candidate.exists():
                    script_path = candidate
                    break
            if script_path is not None:
                self.execute_script(script_path, is_unenv)
            
            self.send_json({
                "status": "ok",
                "lang": lang,
                "active": ENV_STATE[lang]
            })
            
        except Exception as e:
            self.send_json({"error": str(e)}, 500)
    
    def handle_toggle(self):
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body)
            
            lang = data.get("lang", "")
            
            if lang not in ENV_STATE:
                self.send_json({"error": "Unknown lang"}, 400)
                return
            
            # Toggle estado
            ENV_STATE[lang] = not ENV_STATE[lang]
            
            # Atualizar HTML
            update_html_flag(lang, ENV_STATE[lang])
            
            self.send_json({
                "status": "ok",
                "lang": lang,
                "active": ENV_STATE[lang]
            })
            
        except Exception as e:
            self.send_json({"error": str(e)}, 500)
    
    def execute_script(self, script_path, is_unenv):
        """Executa o script real para criar/remover symlinks"""
        import subprocess
        
        # Ler e executar o script
        content = script_path.read_text()
        
        # Substituir variavel OFFICEAI_ROOT
        content = content.replace('${OFFICEAI_ROOT:-/mnt/AI/OfficeAI}', str(OFFICEAI_ROOT))
        content = content.replace('$OFFICEAI_ROOT', str(OFFICEAI_ROOT))
        
        # Executar via bash
        result = subprocess.run(
            ['bash', '-c', content],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            print(f"Erro ao executar {script_path}: {result.stderr}")
    
    def send_json(self, data, code=200):
        response = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(response))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(response)
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
    
    def log_message(self, format, *args):
        pass


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    
    # Detectar layout auto-contido: bin/<tool> -> lib/<tool>
    # Checamos os bins mapeados por linguagem
    lang_bins = {
        "rust": ("rustc", "cargo"),
        "go": ("go",),
        "zig": ("zig",),
        "uv": ("uv",),
        "node": ("node",),
    }
    bin_dir = OFFICEAI_ROOT / "bin"
    if bin_dir.exists():
        for lang, names in lang_bins.items():
            for name in names:
                link = bin_dir / name
                if link.is_symlink():
                    target = os.readlink(link)
                    if f"lib/" in target:
                        ENV_STATE[lang] = True
                        update_html_flag(lang, True)
                        break
    
    server = HTTPServer(("127.0.0.1", port), OfficeAIHandler)
    
    print(f"OfficeAI Server rodando em http://127.0.0.1:{port}")
    print(f"Documentacao: {DOCS_DIR}")
    print(f"Estado: {ENV_STATE}")
    print("")
    print("Pressione Ctrl+C para parar.")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nParando servidor...")


if __name__ == "__main__":
    main()
