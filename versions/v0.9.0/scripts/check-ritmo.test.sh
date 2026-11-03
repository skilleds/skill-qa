#!/usr/bin/env bash
# herdado de schematize-engineering — não edite aqui (fonte: skill-engineering/scripts/check-ritmo.test.sh; regenere: node tools/sync-herdados.mjs)
# check-ritmo.test.sh — vermelho/verde do gate check-ritmo.sh (relógio injetado por --agora).
# strict-ok: harness de teste — roda todos os casos e soma (`schematize-shell` -> `references/piso.md` secao 1)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; G="$HERE/check-ritmo.sh"; rc=0
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
NOW="2026-10-31T15:00:00Z"
bash "$G" --agora "$NOW" "$T" >/dev/null 2>&1 && { echo "FAIL: .ritmo.json ausente deveria falhar"; rc=1; }
printf '{"ultimo_relatorio":"2026-10-31T14:40:00Z","ultimo_handoff":"2026-10-31T10:00:00Z"}\n' > "$T/.ritmo.json"
bash "$G" --agora "$NOW" "$T" >/dev/null || { echo "FAIL: em dia deveria passar"; rc=1; }
printf '{"ultimo_relatorio":"2026-10-31T14:20:00Z","ultimo_handoff":"2026-10-31T10:00:00Z"}\n' > "$T/.ritmo.json"
out="$(bash "$G" --agora "$NOW" "$T" 2>&1)" && { echo "FAIL: relatório > 30 min deveria falhar"; rc=1; }
grep -q 'relatório vencido' <<<"$out" || { echo "FAIL: mensagem de relatório"; rc=1; }
printf '{"ultimo_relatorio":"2026-10-31T14:50:00Z","ultimo_handoff":"2026-10-31T08:00:00Z"}\n' > "$T/.ritmo.json"
out="$(bash "$G" --agora "$NOW" "$T" 2>&1)" && { echo "FAIL: handoff > 6 h deveria falhar"; rc=1; }
grep -q 'handoff vencido' <<<"$out" || { echo "FAIL: mensagem de handoff"; rc=1; }
printf '{"ultimo_relatorio":"2026-10-31T14:50:00Z"}\n' > "$T/.ritmo.json"
bash "$G" --agora "$NOW" "$T" >/dev/null 2>&1 && { echo "FAIL: carimbo ausente deveria falhar"; rc=1; }
[ "$rc" -eq 0 ] && echo "check-ritmo.test: OK"
exit "$rc"
