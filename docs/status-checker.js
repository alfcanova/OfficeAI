/**
 * OfficeAI - Status Checker
 * Verifica dinamicamente se as ferramentas estao instaladas
 * usando o endpoint /api/installed do servidor (layout auto-contido).
 */

const OFFICEAI_API = 'http://127.0.0.1:8765';

// Mapeamento: ferramenta -> candidatos (nome de symlink em bin/ ou dir em lib/)
const TOOLS_MAP = {
    // Linguagens
    'python': ['uv', 'languages'],
    'nodejs': ['node'],
    'rust': ['rustc', 'cargo'],
    'go': ['go'],
    'zig': ['zig'],
    // CLIs
    'opencode': ['opencode'],
    'freebuff': ['freebuff'],
    'aider': ['aider'],
    'codex': ['codex'],
    'antigravity': ['antigravity', 'agy'],
    'kimi': ['kimi'],
    'qwen': ['qwen'],
    'claude': ['claude'],
    'copilot': ['copilot'],
    'pi': ['pi'],
    'cline': ['cline'],
    'cursor': ['cursor'],
    // LLMs
    'vllm': ['vllm'],
    'ollama': ['ollama'],
    'llamacpp': ['llamacpp', 'llama-cli', 'llama-server'],
    'localai': ['local-ai'],
    'jan': ['jan'],
    'lmstudio': ['lmstudio'],
    'openwebui': ['open-webui'],
    'openclaw': ['openclaw']
};

/**
 * Verifica se uma ferramenta esta instalada
 */
async function checkToolStatus(toolName) {
    const candidates = TOOLS_MAP[toolName];
    if (!candidates) return null;
    
    try {
        const response = await fetch(`${OFFICEAI_API}/api/installed`);
        const data = await response.json();
        if (!data || !data.bin) return null;
        
        const binSet = new Set(data.bin);
        const libSet = new Set(data.lib || []);
        
        return candidates.some(c => binSet.has(c) || libSet.has(c));
    } catch (err) {
        // Se o servidor estiver offline, nao podemos verificar
        console.warn(`Servidor offline - nao foi possivel verificar ${toolName}`);
        return null;
    }
}