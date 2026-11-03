#!/usr/bin/env bash
# herdado de schematize-engineering — não edite aqui (fonte: skill-engineering/scripts/check-resilience.sh; regenere: node tools/sync-herdados.mjs)
# check-resilience.sh — gate do piso 28 (microserviço autônomo: fila durável + 7 testes de resiliência).
# O quê: dado o diretório de um serviço com `resilience.yml` (service + dependencies), procura nos
#   arquivos de teste um teste NOMEADO para cada um dos 7 casos (tags abaixo) e, para o caso 2, UM POR
#   dependência declarada (matriz M == N: M dependências declaradas, N com teste de indisponibilidade).
#   Tag casa por nome, sem distinguir maiúscula/minúscula nem separadores (_ - . espaço).
#   1 boot_sem_dependencias   2 dependencia_indisponivel (+ nome da dep na mesma linha)
#   3 restart_fila_cheia      4 reentrega_idempotente     5 dlq_envenenada
#   6 shutdown_gracioso       7 crash_entre_persistir_e_confirmar
#   `dependencies: []` dispensa os casos 2-5 (sem vizinho, sem fila); 1, 6 e 7 continuam exigidos —
#   EXCETO se o serviço consome fila externa: `consumes_queue: true` no resilience.yml mantém 3, 4 e 5 (DLQ,
#   idempotência, restart com fila cheia). Só linha que DECLARA teste conta (fn/func/def/function/it/test/
#   describe/[Fact]/@Test/void/Task): comentário e string solta não.
# Formato de resilience.yml:  service: ledger \n dependencies: \n   - core \n   - redis
# Uso: bash scripts/check-resilience.sh <dir-do-servico>      Saída: 0 ok, 1 faltou teste, 2 uso inválido.
# LIMITAÇÃO: heurística por nome — prova que o teste EXISTE e não está pulado (.skip/ignore/xfail na linha
#   ou na anterior não conta, piso 5), NÃO que ele é bom nem que passa. A execução é do CI da stack.
# strict-ok: gate acumula achados e sai no fim (`schematize-shell` -> `references/piso.md` secao 1)
set -uo pipefail
D="${1:-}"; [ -d "$D" ] || { echo "uso: check-resilience.sh <dir-do-servico>" >&2; exit 2; }
Y="$D/resilience.yml"
[ -f "$Y" ] || { echo "FAIL: $Y ausente (piso 28) — declare as dependências do serviço"; exit 1; }
grep -Eq '^service:' "$Y" || { echo "FAIL: resilience.yml sem 'service:'"; exit 1; }
grep -Eq '^dependencies:' "$Y" || { echo "FAIL: resilience.yml sem 'dependencies:' (use [] se nenhuma)"; exit 1; }
mapfile -t DEPS < <(awk '/^dependencies:/{in_d=1; if ($0 ~ /\[[ ]*\]/) in_d=0; next} in_d && /^[^ #-]/{in_d=0} in_d && /^[ ]*-[ ]/{s=$0; sub(/^[ ]*-[ ]*/,"",s); sub(/[ ]*#.*$/,"",s); gsub(/["\047]/,"",s); if (s!="") print s}' "$Y")
# normaliza: minúsculas, sem separadores
norm() { tr '[:upper:]' '[:lower:]' | tr -d '_ .-'; }
# arquivos de teste (exclui build/deps) -> linhas "arquivo:linha:texto-normalizado" já sem testes pulados
LINES="$(mktemp)"; trap 'rm -f "${LINES:?}"' EXIT
while IFS= read -r f; do
  awk -v F="$f" '{
    raw=$0; n=tolower(raw); gsub(/[_ .-]/,"",n)
    skip = (raw ~ /\.skip|@skip|#\[ignore\]|xfail|t\.Skip|@Disabled|xit\(|xtest\(|pending/ || prev ~ /\.skip|@skip|#\[ignore\]|xfail|t\.Skip|@Disabled|@pytest\.mark\.skip|pending/)
    # só conta DECLARAÇÃO de teste (fn/func/def/function/it/test/describe/[Fact]/@Test/void/Task); comentário e string solta não
    decl = (raw ~ /(^|[^[:alnum:]_])(fn|func|def|function|it|test|describe|specify|scenario)[ (\t"\047]/ || raw ~ /\[(Fact|Theory|Test)|@Test|void [A-Za-z_]|Task [A-Za-z_]/) && raw !~ /^[ \t]*(\/\/|#|\*|\/\*|--)/
    if (!skip && decl) print F ":" NR ":" n
    prev=raw }' "$f"
done < <(find "$D" -type f \( -iname '*test*' -o -iname '*spec*' -o -path '*/tests/*' -o -path '*/test/*' -o -path '*/__tests__/*' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/target/*' -not -path '*/vendor/*' -not -name 'resilience.yml' -not -name '*.md' | sort) > "$LINES"
rc=0; M=${#DEPS[@]}; N=0
tem() { grep -q -- "$1" "$LINES"; }
exige() { # tag normalizada, rótulo
  tem "$1" || { echo "FAIL: falta teste '$2' (piso 28)"; rc=1; }
}
exige "bootsemdependencias" "1 boot_sem_dependencias (boot com todas as dependências indisponíveis)"
if [ "$M" -gt 0 ]; then
  for d in "${DEPS[@]}"; do
    dn="$(printf '%s' "$d" | norm)"
    if grep -- "dependenciaindisponivel" "$LINES" | grep -q -- "$dn"; then N=$((N+1))
    else echo "FAIL: falta teste '2 dependencia_indisponivel' para a dependência '$d' (timeout/5xx/recusada -> fila, serviço vivo)"; rc=1; fi
  done
fi
if [ "$M" -gt 0 ] || grep -Eq '^consumes_queue:[[:space:]]*true' "$Y"; then
  exige "restartfilacheia" "3 restart_fila_cheia (drena sem perda/duplicata)"
  exige "reentregaidempotente" "4 reentrega_idempotente"
  exige "dlqenvenenada" "5 dlq_envenenada (N tentativas, fila não trava)"
fi
exige "shutdowngracioso" "6 shutdown_gracioso (drena o em voo, persiste, sai)"
exige "crashentrepersistireconfirmar" "7 crash_entre_persistir_e_confirmar (sem perda)"
echo "matriz de resiliência: M=$M dependências declaradas, N=$N com teste de indisponibilidade"
[ "$M" -eq "$N" ] || { echo "FAIL: matriz M != N ($M != $N)"; rc=1; }
[ "$rc" -eq 0 ] && echo "check-resilience: OK ($(grep -c . "$Y") linhas em resilience.yml, M == N == $M)"
exit "$rc"
