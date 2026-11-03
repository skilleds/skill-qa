#!/usr/bin/env bash
# herdado de schematize-engineering — não edite aqui (fonte: skill-engineering/scripts/check-resilience.test.sh; regenere: node tools/sync-herdados.mjs)
# check-resilience.test.sh — vermelho/verde do gate check-resilience.sh (piso 28).
# strict-ok: harness de teste — roda todos os casos e soma (`schematize-shell` -> `references/piso.md` secao 1)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; G="$HERE/check-resilience.sh"; rc=0
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
mkdir -p "$T/svc/tests"
printf 'service: ledger\ndependencies:\n  - core\n  - redis\n' > "$T/svc/resilience.yml"
bash "$G" "$T/svc" >/dev/null 2>&1 && { echo "FAIL: sem testes deveria reprovar"; rc=1; }
# suíte completa (nomes em estilos diferentes: snake, camel)
cat > "$T/svc/tests/resilience_test.go" <<'X'
func TestBootSemDependencias(t *testing.T) {}
func TestDependenciaIndisponivel_Core_Timeout(t *testing.T) {}
func TestDependenciaIndisponivel_Redis_ConexaoRecusada(t *testing.T) {}
func TestRestartFilaCheia_DrenaSemPerda(t *testing.T) {}
func TestReentregaIdempotente(t *testing.T) {}
func TestDlqEnvenenada_AposNTentativas(t *testing.T) {}
func TestShutdownGracioso_NaoPerdeEmVoo(t *testing.T) {}
func TestCrashEntrePersistirEConfirmar_SemPerda(t *testing.T) {}
X
bash "$G" "$T/svc" >/dev/null 2>&1 || { echo "FAIL: suíte completa deveria passar"; bash "$G" "$T/svc"; rc=1; }
# falta a dependência redis (M != N)
sed -i '/Redis_ConexaoRecusada/d' "$T/svc/tests/resilience_test.go"
out="$(bash "$G" "$T/svc" 2>&1)" && { echo "FAIL: dependência sem teste deveria reprovar"; rc=1; }
grep -q "'redis'" <<<"$out" || { echo "FAIL: mensagem deveria citar a dependência redis"; rc=1; }
grep -q "M != N" <<<"$out" || { echo "FAIL: matriz M != N ausente"; rc=1; }
# teste pulado não conta (piso 5)
printf 'it.skip("dependencia_indisponivel redis", () => {})\n' >> "$T/svc/tests/resilience_test.go"
bash "$G" "$T/svc" >/dev/null 2>&1 && { echo "FAIL: teste pulado não pode contar"; rc=1; }
# falta o caso 5
printf '\nit("dependencia_indisponivel redis", () => {})\n' >> "$T/svc/tests/resilience_test.go"
bash "$G" "$T/svc" >/dev/null 2>&1 || { echo "FAIL: redis restaurado deveria passar"; rc=1; }
sed -i '/Dlq/d' "$T/svc/tests/resilience_test.go"
out="$(bash "$G" "$T/svc" 2>&1)" && { echo "FAIL: sem DLQ deveria reprovar"; rc=1; }
grep -q "dlq_envenenada" <<<"$out" || { echo "FAIL: mensagem do caso 5"; rc=1; }
# sem dependências: casos 2-5 dispensados, 1/6/7 exigidos
mkdir -p "$T/solo/tests"; printf 'service: solo\ndependencies: []\n' > "$T/solo/resilience.yml"
printf 'def test_boot_sem_dependencias(): ...\ndef test_shutdown_gracioso(): ...\ndef test_crash_entre_persistir_e_confirmar(): ...\n' > "$T/solo/tests/a_test.py"
bash "$G" "$T/solo" >/dev/null 2>&1 || { echo "FAIL: serviço sem vizinhos deveria passar com 1/6/7"; rc=1; }
# consumidor de fila externa com dependencies: [] NÃO escapa de 3/4/5 (consumes_queue: true)
printf 'service: solo\ndependencies: []\nconsumes_queue: true\n' > "$T/solo/resilience.yml"
out="$(bash "$G" "$T/solo" 2>&1)" && { echo "FAIL: consumes_queue sem testes 3-5 deveria reprovar"; rc=1; }
grep -q 'dlq_envenenada' <<<"$out" || { echo "FAIL: consumes_queue deveria cobrar DLQ"; rc=1; }
printf 'def test_restart_fila_cheia(): ...\ndef test_reentrega_idempotente(): ...\ndef test_dlq_envenenada(): ...\n' >> "$T/solo/tests/a_test.py"
bash "$G" "$T/solo" >/dev/null 2>&1 || { echo "FAIL: consumes_queue com 3-5 deveria passar"; rc=1; }
# falso verde: tag só em comentário ou string não conta
mkdir -p "$T/fake/tests"; printf 'service: f\ndependencies: []\n' > "$T/fake/resilience.yml"
printf '# test_boot_sem_dependencias test_shutdown_gracioso test_crash_entre_persistir_e_confirmar\nx = "boot_sem_dependencias shutdown_gracioso crash_entre_persistir_e_confirmar"\n' > "$T/fake/tests/a_test.py"
bash "$G" "$T/fake" >/dev/null 2>&1 && { echo "FAIL: tag em comentário/string não pode dar verde"; rc=1; }
# resilience.yml ausente
mkdir -p "$T/nada"; bash "$G" "$T/nada" >/dev/null 2>&1 && { echo "FAIL: resilience.yml ausente deveria reprovar"; rc=1; }
[ "$rc" -eq 0 ] && echo "check-resilience.test: OK"
exit "$rc"
