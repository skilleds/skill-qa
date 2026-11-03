#!/usr/bin/env bash
# herdado de schematize-engineering — não edite aqui (fonte: skill-engineering/scripts/check-ritmo.sh; regenere: node tools/sync-herdados.mjs)
# check-ritmo.sh — gate do piso 26 (relatório a cada 30 min, handoff a cada 6 h de trabalho ativo).
# O quê: lê `<archive>/.ritmo.json` ({ultimo_relatorio, ultimo_handoff}, ISO-8601) e falha se o
#   arquivo faltar, se um carimbo faltar/for inválido, se ultimo_relatorio tiver > 30 min ou
#   ultimo_handoff > 6 h em relação a --agora (default: agora). Vale durante sessão ativa.
# Uso: bash scripts/check-ritmo.sh [--agora ISO-8601] [--max-relatorio MIN] [--max-handoff MIN] <archive>
# Saída: exit 0 em dia, 1 vencido/ausente, 2 uso inválido. Ver `references/orquestracao.md` §9.8.
# strict-ok: gate acumula achados e sai no fim (`schematize-shell` -> `references/piso.md` secao 1)
set -uo pipefail
AGORA=""; MAXR=30; MAXH=360; ARC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --agora) AGORA="${2:?--agora exige ISO-8601}"; shift 2 ;;
    --max-relatorio) MAXR="${2:?}"; shift 2 ;;
    --max-handoff) MAXH="${2:?}"; shift 2 ;;
    -*) echo "uso: check-ritmo.sh [--agora ISO] <archive>" >&2; exit 2 ;;
    *) ARC="$1"; shift ;;
  esac
done
[ -n "$ARC" ] || { echo "uso: check-ritmo.sh [--agora ISO] <archive>" >&2; exit 2; }
F="$ARC/.ritmo.json"
[ -f "$F" ] || { echo "FAIL: $F ausente (piso 26) — crie com o relatório inicial"; exit 1; }
if [ -n "$AGORA" ]; then now=$(date -d "$AGORA" +%s 2>/dev/null) || { echo "--agora inválido" >&2; exit 2; }
else now=$(date +%s); fi
rc=0
# extrai o valor de uma chave string do JSON plano (sem depender de jq)
val() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$F" | head -1; }
chk() { # chave, limite em min, rótulo
  local v t age; v="$(val "$1")"
  [ -n "$v" ] || { echo "FAIL: $1 ausente em .ritmo.json (piso 26)"; rc=1; return; }
  t=$(date -d "$v" +%s 2>/dev/null) || { echo "FAIL: $1 inválido ($v)"; rc=1; return; }
  age=$(( (now - t) / 60 ))
  if [ "$age" -gt "$2" ]; then echo "FAIL: $3 vencido há ${age} min (limite $2) — gere antes da próxima entrega (piso 26)"; rc=1; fi
}
chk ultimo_relatorio "$MAXR" "relatório"
chk ultimo_handoff "$MAXH" "handoff"
[ "$rc" -eq 0 ] && echo "check-ritmo: OK"
exit "$rc"
