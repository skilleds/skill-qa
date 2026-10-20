#!/usr/bin/env bash
# check-route-authz.test.sh — o VERMELHO VISTO do gate da matriz de acesso por rota.
# Planta cada violação e exige exit 1; o caso verde exige exit 0.
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md` secao 1):
# harness roda sem `-e` de propósito — precisa continuar após um caso vermelho e reportar TODOS.
set -uo pipefail
G="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-route-authz.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
rc=0
mk() { # mk <dir>: base verde (2 rotas, 1 pública justificada)
  mkdir -p "$1"
  printf 'GET /health\nGET /orders/{id}\n' > "$1/routes"
  { for p in anonimo nao-privilegiado privilegiado burla; do
      case "$p" in privilegiado) a=allow ;; *) a=deny ;; esac
      echo "GET /orders/{id} $p $a"; done
    echo "GET /health anonimo allow"; echo "GET /health nao-privilegiado allow"
    echo "GET /health privilegiado allow"; echo "GET /health burla deny"; } > "$1/matrix"
  printf 'GET /health | probe do balanceador, sem dado | time-plataforma\n' > "$1/pub"
}
run() { bash "$G" --routes "$1/routes" --matrix "$1/matrix" --public-allowlist "$1/pub" 2>&1; }
expect() { # expect <nome> <exit esperado> <dir> [texto]
  OUT=$(run "$3"); z=$?
  if [ "$z" -eq "$2" ] && { [ -z "${4:-}" ] || grep -q "$4" <<<"$OUT"; }; then echo "  ✔ $1"
  else echo "  ✖ $1 (exit $z): $OUT"; rc=1; fi
}

echo "── verde"; mk "$W/ok"; expect "matriz completa passa" 0 "$W/ok"
echo "── vermelho: rota sem linha (rota nova esquecida)"; mk "$W/a"; echo 'POST /orders' >> "$W/a/routes"
expect "exit 1" 1 "$W/a" 'SEM linha'
echo "── vermelho: persona faltando"; mk "$W/b"; sed -i '/orders.*burla/d' "$W/b/matrix"
expect "exit 1" 1 "$W/b" 'persona ausente'
echo "── vermelho: rota órfã"; mk "$W/c"; echo 'GET /fantasma anonimo deny' >> "$W/c/matrix"
expect "exit 1" 1 "$W/c" 'ÓRFÃ'
echo "── vermelho: sem política"; mk "$W/d"; sed -i 's|^GET /orders/{id} nao-privilegiado deny|GET /orders/{id} nao-privilegiado none|' "$W/d/matrix"
expect "exit 1" 1 "$W/d" 'sem política'
echo "── vermelho: pública fora da allowlist"; mk "$W/e"; : > "$W/e/pub"
expect "exit 1" 1 "$W/e" 'fora da allowlist'
echo "── vermelho: allowlist sem dono"; mk "$W/f"; printf 'GET /health | probe |\n' > "$W/f/pub"
expect "exit 1" 1 "$W/f" 'sem justificativa/dono'
echo "── vermelho: burla passou"; mk "$W/g"; sed -i 's|^GET /orders/{id} burla deny|GET /orders/{id} burla allow|' "$W/g/matrix"
expect "exit 1" 1 "$W/g" 'burla PASSOU'
exit $rc
