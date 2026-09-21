#!/usr/bin/env bash
# ============================================================================
# OfficeAI - 00_unenvGeneral.sh
# DESATIVACAO DO AMBIENTE AUTO-CONTIDO
#
# Restaura HOME, XDG, TMPDIR, PATH e variaveis de ferramentas para os
# valores originais do shell (salvos em var/env-backup.sh).
#
# Uso: source etc/00_unenvGeneral.sh
# ============================================================================

if [[ -z "${OFFICEAI_CONTAINED:-}" ]]; then
    echo "[OfficeAI] Ambiente contido nao esta ativo neste shell" >&2
    return 0 2>/dev/null || exit 0
fi

OFFICEAI_ENV_BACKUP="${OFFICEAI_ROOT%/}/var/env-backup.sh"

if [[ -f "$OFFICEAI_ENV_BACKUP" ]]; then
    # shellcheck source=/dev/null
    source "$OFFICEAI_ENV_BACKUP"
    rm -f "$OFFICEAI_ENV_BACKUP"
fi

unset OFFICEAI_CONTAINED OFFICEAI_HOME OFFICEAI_VAR_DIR OFFICEAI_ENV_BACKUP HOME_LOCAL_BIN

echo "[OfficeAI] Ambiente contido desativado" >&2