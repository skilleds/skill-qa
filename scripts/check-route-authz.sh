#!/usr/bin/env bash
# check-route-authz.sh — gate da matriz de acesso por rota (categorias.md §14).
# Deny-by-default: toda rota do inventário tem as 4 personas na matriz (M == N), nenhuma linha órfã,
# nenhuma rota sem política, e rota pública só com justificativa+dono na allowlist versionada.
#
# Uso:  bash scripts/check-route-authz.sh --routes inventario.txt --matrix matriz.txt \
#                                         [--public-allowlist publicas.txt]
#   --routes     uma rota por linha: "MÉTODO /path" (DERIVADO do router/OpenAPI, nunca à mão)
#   --matrix     linhas "MÉTODO /path persona resultado"; persona ∈ anonimo|nao-privilegiado|
#                privilegiado|burla; resultado ∈ allow|deny|none (none = sem política declarada)
#   --public-allowlist  linhas "MÉTODO /path | justificativa | dono" (# comenta)
# Sai 1 se: persona faltando, rota órfã, rota sem política (none), anônimo=allow fora da allowlist,
# allowlist sem justificativa/dono, burla=allow (burla tem de ser negada).
set -uo pipefail
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$_DIR/lib.sh"

ROUTES=""; MATRIX=""; ALLOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --routes) ROUTES="${2:-}"; shift 2 ;;
    --matrix) MATRIX="${2:-}"; shift 2 ;;
    --public-allowlist) ALLOW="${2:-}"; shift 2 ;;
    *) echo "argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done
if [[ -z "$ROUTES" || -z "$MATRIX" || ! -f "$ROUTES" || ! -f "$MATRIX" ]]; then
  echo "uso: $0 --routes <arquivo> --matrix <arquivo> [--public-allowlist <arquivo>]" >&2; exit 2
fi
[[ -n "$ALLOW" && ! -f "$ALLOW" ]] && { echo "allowlist inexistente: $ALLOW" >&2; exit 2; }

PERSONAS=(anonimo nao-privilegiado privilegiado burla)
norm() { sed -e 's/#.*//' -e 's/[[:space:]]\+/ /g' -e 's/^ //;s/ $//' "$1" | grep -v '^$'; }

declare -A INV MAT PUB
while IFS= read -r l; do INV["$l"]=1; done < <(norm "$ROUTES")
while read -r m p persona res _; do
  [[ -z "${m:-}" ]] && continue
  MAT["$m $p|$persona"]="$res"; MAT["$m $p|*"]=1
done < <(norm "$MATRIX")

test_section "allowlist de rotas públicas"
if [[ -n "$ALLOW" ]]; then
  while IFS= read -r l; do
    IFS='|' read -r r just dono <<<"$l"
    r="$(echo "$r" | sed 's/^ *//;s/ *$//')"; just="${just//[[:space:]]/}"; dono="${dono//[[:space:]]/}"
    if [[ -z "$just" || -z "$dono" ]]; then test_fail "allowlist sem justificativa/dono: $r"; else PUB["$r"]=1; fi
  done < <(sed -e 's/^[[:space:]]*#.*//' "$ALLOW" | grep -v '^[[:space:]]*$')
fi
test_pass "allowlist lida (${#PUB[@]} pública(s))"

test_section "matriz × inventário (M == N)"
for r in "${!INV[@]}"; do
  if [[ -z "${MAT[$r|*]:-}" ]]; then test_fail "rota SEM linha na matriz: $r"; continue; fi
  for p in "${PERSONAS[@]}"; do
    res="${MAT[$r|$p]:-}"
    if [[ -z "$res" ]]; then test_fail "$r: persona ausente '$p'"
    elif [[ "$res" == "none" ]]; then test_fail "$r: sem política declarada ($p)"
    elif [[ "$p" == "burla" && "$res" == "allow" ]]; then test_fail "$r: tentativa de burla PASSOU"
    elif [[ "$p" == "anonimo" && "$res" == "allow" && -z "${PUB[$r]:-}" ]]; then
      test_fail "$r: pública fora da allowlist (anônimo=allow sem justificativa+dono)"
    fi
  done
done
for k in "${!MAT[@]}"; do
  [[ "$k" == *"|*" ]] || continue
  r="${k%|*}"; [[ -z "${INV[$r]:-}" ]] && test_fail "rota ÓRFÃ na matriz (fora do inventário): $r"
done
for r in "${!PUB[@]}"; do
  [[ -z "${INV[$r]:-}" ]] && test_fail "allowlist cita rota fora do inventário: $r"
done
[[ $_FAIL -eq 0 ]] && test_pass "${#INV[@]} rota(s), 4 personas cada, M == N"

echo; echo "rotas=${#INV[@]} falhas=$_FAIL"
exit $((_FAIL > 0 ? 1 : 0))
