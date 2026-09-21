/**
 * OfficeAI - Env Executor
 * Controla ambientes via API do servidor
 */

const OFFICEAI_API = 'http://127.0.0.1:8765';

document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('.env-item').forEach(item => {
        item.addEventListener('click', function() {
            const cmd = this.getAttribute('data-cmd');
            const label = this.getAttribute('data-label') || '';
            if (!cmd) return;
            
            const hint = this.querySelector('.copy-hint');
            const originalText = hint ? hint.textContent : '';
            const self = this;
            
            // Feedback visual imediato
            if (hint) hint.textContent = 'Executando...';
            this.classList.add('copied');
            
            // Timeout
            const timeout = setTimeout(() => {
                if (hint) hint.textContent = 'Servidor offline';
                self.style.borderColor = 'var(--red)';
                setTimeout(() => {
                    if (hint) hint.textContent = 'Rode: python3 scripts/server.py';
                    setTimeout(() => {
                        if (hint) hint.textContent = originalText;
                        self.classList.remove('copied');
                        self.style.borderColor = '';
                    }, 2000);
                }, 1500);
            }, 3000);
            
            fetch(`${OFFICEAI_API}/api/exec`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ command: cmd, label: label })
            })
            .then(r => r.json())
            .then(data => {
                clearTimeout(timeout);
                if (data.status === 'ok') {
                    if (hint) hint.textContent = 'Executado!';
                    // Recarregar pagina para atualizar flags
                    setTimeout(() => {
                        location.reload();
                    }, 500);
                } else {
                    if (hint) hint.textContent = 'Erro: ' + (data.error || 'desconhecido');
                    self.style.borderColor = 'var(--red)';
                    setTimeout(() => {
                        if (hint) hint.textContent = originalText;
                        self.classList.remove('copied');
                        self.style.borderColor = '';
                    }, 3000);
                }
            })
            .catch(err => {
                clearTimeout(timeout);
                if (hint) hint.textContent = 'Servidor offline';
                self.style.borderColor = 'var(--red)';
                setTimeout(() => {
                    if (hint) hint.textContent = 'Rode: python3 scripts/server.py';
                    setTimeout(() => {
                        if (hint) hint.textContent = originalText;
                        self.classList.remove('copied');
                        self.style.borderColor = '';
                    }, 2000);
                }, 1000);
            });
        });
    });
});
