# Execução — Plan-First, Test Kit, CI e Makefile

> Parte da skill **schematize-qa**. O **como se roda**: o fluxo plan-first (planeja → MD → aprovação →
> executa), o test kit (CLI único + saída machine-readable), o padrão de script, seeds/personas, a
> integração com CI (gates de teste/a11y/CWV) e o Makefile. Estratégia em `estrategia.md`; categorias
> em `categorias.md`; flaky em `flaky.md`.

## Índice
- 1. Fluxo de Q.A. plan-first (aprovação obrigatória)
- 2. Test kit e saída machine-readable
- 3. Padrão de script
- 4. Seeds e personas
- 5. Efeito externo em teste — endereço, sink e cap (o incidente das 5.000 contas)
- 6. Integração com CI (os gates)
- 7. Makefile padrão

---

## 1. Fluxo de Q.A. plan-first (aprovação obrigatória)

A malha de Q.A. inclui passos potencialmente destrutivos (**chaos** — `service-kill`,
`db-disconnect` —, mutação, carga). **O modo `chaos` é da `schematize-infra`**
(`references/resiliencia.md` §7: definição, as 5 partes do experimento, o oráculo — inclusive
*"não aconteceu nada" REPROVA* — e o gate de segurança). Esta skill **invoca** e reporta; não
define. Por isso **nenhuma submissão de Q.A. roda às cegas**: toda submissão passa por
planejamento, aprovação humana e execução controlada. Comandos: `/qa-plan` (planeja) e `/qa-run`
(executa o aprovado).

**MUST — antes de executar qualquer coisa**
1. **Planejar tudo primeiro.** Ao receber a submissão, o agente **não executa nada ainda**. Levanta o
   escopo completo: quais camadas/modos vão rodar (unit/componente/integração/e2e/smoke/a11y/visual/
   contrato/dados/`simulated`, chaos — este último definido pela `schematize-infra`), ambiente alvo, rotas e personas afetadas, ordem de execução,
   dependências entre passos, o que é **destrutivo/gated**, e os riscos.
2. **Gerar um MD de passo a passo detalhado** em
   `<projeto>_archive/qa/<YYYY-MM-DD-HH-MM-SS>-<contexto>.md` (archive obrigatório — §28 da
   engineering). Cada passo declara: objetivo, comando exato, ambiente, resultado esperado, critério de
   pass/fail, e flag de **destrutivo** quando aplicável. O plano referencia o `summary.json` (§2) que
   será produzido.
3. **Pedir aprovação explícita do usuário.** Sem aprovação registrada, **nada roda**. O agente
   apresenta o plano e aguarda o "ok". **Aprovação parcial** (subconjunto de passos) é válida e vira o
   escopo efetivo.

**MUST — após aprovado**
4. **Oferecer a modalidade de execução:**
   - **Faseado e assistido** — executa por fase, **pausa entre fases** para revisão/confirmação, mostra
     resultado parcial e só segue com o "continuar". Default recomendado para staging sensível e para
     qualquer plano com passo destrutivo.
   - **De uma vez (autônomo)** — executa o plano inteiro sem parar.
5. **No modo "de uma vez":**
   - **Multiagentes para a execução** — paralelizar categorias independentes (ex.: unit, a11y,
     `simulated`, contrato em workers separados), respeitando dependências declaradas e limites de
     concorrência (backpressure).
   - **Quem executa (custo)** — piso "Orquestrador não desenvolve; subagent barato executa"
     (`schematize-engineering` → `references/orquestracao.md` §9). Cada worker/subagent executor
     roda em **`sonnet` por default**; o agent principal **só planeja, despacha, supervisiona e
     revisa** (lê o resultado/`summary.json`, confere o gate) — não roda a execução do Q.A. ele
     mesmo. Cada categoria/passo é uma **micro-task** com escopo, comando e critério de pronto no
     brief. Falhou → devolve ao **mesmo subagent** com o erro concreto (até 2 rodadas) →
     re-decompõe → só então **`opus`**, com o motivo da escalada no checkpoint (que ganha colunas
     modelo e rodadas de correção). Esgotou Opus → escala pro humano (a mesma parada explícita
     abaixo). Isto decide *quem executa*; não altera o plano aprovado, os gates nem o watchdog.
   - **Cron/watchdog de continuidade** — um agendador supervisiona e **retoma de checkpoint até
     concluir**, sem intervenção manual se um worker cair. "Conclusão" é condição de parada explícita:
     todos os passos aprovados terminaram, **ou** uma falha bloqueante escalou para o humano.
     Checkpoints são **idempotentes** e a retomada não reexecuta passo já concluído.

**MUST — segurança do fluxo**
- Passo destrutivo (`service-kill`, `db-disconnect`, drop, mutação em massa) **só roda se constava no
  plano aprovado** e com o gate de ambiente ligado (ex.: `<PROJECT>_CHAOS_ALLOW=1`). Aprovação do plano
  **não dispensa** o gate.
- Modo autônomo "de uma vez" roda por default só em `dev`/`staging`. Produção exige confirmação
  adicional explícita no momento da execução.
- **Sem retry infinito** no watchdog: limite de tentativas por passo, backoff, e escala pro humano ao
  estourar. "Ininterrupto até finalizar" é **retomar até concluir**, não repetir pra sempre (`flaky.md`).

**VETADO**
- Pular o plano ou a aprovação "pra ir mais rápido" — é macaquice (linha da §37 da engineering). Q.A.
  sem plano aprovado registrado **não roda**.

> O plano aprovado é o **contrato** da execução. Multiagente e cron aceleram o *como*, nunca dispensam o
> *o quê foi autorizado*.

---

## 2. Test kit e saída machine-readable

Toda a malha de testes "do sistema vivo" mora num repo dedicado (`<project>_ops`), invocada por um CLI
único. O **harness** (CLI, saída, seeds) é da casa; o conteúdo **ofensivo** dos modos de segurança é da
`schematize-pentest` (`categorias.md` §10).

**Estrutura padrão**
```
<project>_ops/
├── bin/<project>-test          # CLI: run modes, agrega saída
├── tests/
│   ├── lib.sh                  # helpers (scripts/lib.sh desta skill)
│   ├── README.md               # tabela de modos × scripts × duração
│   ├── smoke/  integration/  unit/            # Q.A. funcional (esta skill)
│   ├── a11y/  visual/  contract/  data/       # camadas transversais (esta skill)
│   ├── simulated/              # cobertura total de rotas × personas
│   ├── security/  pentest/  authz/  hardening/          # segurança (schematize-pentest)
│   ├── chaos/                                          # resiliência (schematize-infra §7)
│   └── seeds/                  # SQL de setup (personas de teste, superadmin)
├── Makefile
└── README.md
```

**CLI padrão**
```bash
<project> test                  # default: smoke
<project> test unit | integration | e2e | smoke | a11y | visual | contract | data | simulated
<project> test property         # property-based no dominio critico (categorias.md secao 11)
<project> test mutation         # o teste do teste (categorias.md secao 12) — nightly, nao PR
<project> test load             # carga/perf (categorias.md secao 13) — SO com sink+guard+cap
<project> test all              # tudo exceto chaos+unit+load
<project> test full             # all + chaos + unit + mutation + property
<project> test seed-superadmin  # setup inicial (uma vez)
```

**Saída estruturada** — toda execução escreve em `/<project>/logs/test-<YYYY-MM-DD>-<HHMMSS-pid>/`:

| Arquivo | Conteúdo |
|---|---|
| `summary.txt` | PASS/FAIL por script, legível |
| `summary.json` | **fonte única pra dashboards/CI/gate** — schema fixo abaixo |
| `run-totals.txt` | mode, started, finished, duration, scripts, pass, fail, exit |
| `<mode>-<name>.log` | output completo de cada script |
| `coverage-summary.{txt,json}` | cobertura por serviço (só em `unit`) |

**Schema `summary.json`** (contrato — não quebre `mode`, `totals`, `scripts[]`):
```json
{
  "mode": "smoke",
  "started_at": "2026-05-11T11:35:50Z",
  "finished_at": "2026-05-11T11:35:57Z",
  "duration_seconds": 7,
  "log_dir": "/<project>/logs/test-2026-05-11-083550-448694",
  "scripts": [
    {"category": "smoke", "name": "auth-endpoints", "status": "pass"},
    {"category": "a11y",  "name": "checkout-axe",    "status": "fail"}
  ],
  "totals": {"pass": 23, "fail": 1, "scripts": 24, "exit_code": 1}
}
```

**MUST**
- Exit code 0 se tudo passou; 1 se qualquer caso falhou. `summary.json` é **o que o gate lê** (§6).
- Cada script é executável standalone (`bash tests/smoke/auth-endpoints.sh` sai `0/1`), declara
  `TEST_NAME`, usa `lib.sh`, e emite banner ENORME em vermelho quando falha.
- Skip **sem erro** só quando dependência **opcional** declarada falta. Logs zipados pra storage (≥ 90
  dias) após cada CI run.

---

## 3. Padrão de script (`tests/<mode>/<name>.sh`)

Skeleton obrigatório em `scripts/test-skeleton.sh` — status + shape do body + **assertion negativa**:

```bash
#!/usr/bin/env bash
# <Categoria> · <Nome curto> — o que cobre e o esperado.
set -uo pipefail
_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_DIR/lib.sh"

test_section "<Categoria> · <Nome>"
API="$(api_base)"

assert_http_in "<caso>" "200|401" GET "$API/v1/<rota>"        # status

http_call GET "$API/v1/<rota>"                                # shape do body
if [[ "$HTTP_CODE" == "200" ]]; then
  echo "$HTTP_BODY" | jq -e '.data | length > 0' >/dev/null \
    && test_pass "<rota> retorna dados" \
    || test_fail "<rota> sem 'data'" "$HTTP_BODY"
fi

if echo "$HTTP_BODY" | grep -qiE 'stacktrace|exception|undefined|\{\{|\$\{'; then
  test_fail "<rota> vazou stack/placeholder" "$HTTP_BODY"     # assertion negativa
fi

test_summary "<categoria>/<nome>"
exit $TEST_EXIT_CODE
```

**MUST**: banner do `test_section` na 1ª linha; cada caso vira `✓`/`✗`/`○ skip`; `test_summary` agrega
contadores; falhas incluem `HTTP_BODY` truncado em 2000 chars (sem PII).

---

## 4. Seeds e personas

**MUST**
- Personas em `tests/seeds/test-*.sql` (ou `tests/<mode>/*.json`) — **versionadas, reproduzíveis**.
- Senhas test-only **explicitamente flagadas** (prefixo `SimTest!`) e **rejeitadas em produção** pelo
  validador de senha fraca.
- Setup **idempotente** (`INSERT ... ON CONFLICT DO UPDATE` — re-rodar não duplica). Cleanup só por
  comando explícito (`<project> test clean-seeds`), não automático (deixa lixo pra inspeção).

**Personas mínimas (RBAC + multi-tenancy):** `superadmin` (vê tudo), `tenant_admin_A`, `tenant_admin_B`
(pra testar isolamento), `normal_user` (só dados próprios). Opcionais: `viewer`/`editor`/`support`.

**E-mail/telefone das personas:** o endereço de toda persona, seed, fixture e factory obedece ao §5 —
`<papel>+<run-id>-<n>@test.<domain>`, nunca uma caixa real. Seed com `@gmail.com` é bug bloqueante, não
detalhe de fixture.

---

## 5. Efeito externo em teste — endereço, sink e cap (o incidente das 5.000 contas)

> **A normativa do piso NÃO mora aqui.** Ela é da base: `schematize-engineering` →
> `references/efeitos-externos.md` (as 4 camadas: DNS em rota nula, provider sink por default,
> guard deny-by-default dentro do provider, cap por execução). Esta seção cobre **só o
> recorte de Q.A.**: como o *runner* e o *ambiente de teste* realizam esse piso.
>
> *(Este arquivo repetia a normativa inteira, e ela aparecia mais 3 vezes na skill — 22% das
> linhas para um tema, contra 18 linhas somadas para contrato e dados. Achado do inventário da
> vistoria de 2026-08-21.)*

**Por que a Q.A. é o lugar mais perigoso para isso:** é a disciplina que **mais** dispara efeito
externo por acidente. O laço que cria contas dispara um e-mail por conta; com Email OTP always-on,
"1.000 contas criadas" e "1.000 e-mails enviados" são a mesma coisa — e foi assim que o incidente
de referência da casa passou de **5.000 mensagens reais**.

**O recorte de Q.A., em três peças:**

1. **Ambiente:** o sink é serviço do compose de teste (§5.2), não algo que se lembra de ligar.
2. **Variáveis:** `MAIL_PROVIDER=sink`, `TEST_MAIL_DOMAIN`, `MAIL_MAX_PER_RUN`, `TEST_RUN_ID` (§5.3).
3. **Pré-flight fail-closed** do runner, **antes do 1º teste** (§5.4) — e ele **aborta**, não avisa.

**Como se assere** que a mensagem saiu (ler do sink, contagem exata, buscar por destinatário, nunca
`sleep`): `references/categorias.md` §9. Aqui é o *ambiente*; lá é a *asserção*.

### 5.2 Setup do sink (Mailpit)

O sink é um serviço do ambiente de teste, subido pelo mesmo compose do DB/broker — **não** é algo que
cada teste liga na mão.

```yaml
# docker-compose.test.yml
services:
  mailpit:
    image: axllent/mailpit
    ports: ["1025:1025", "8025:8025"]   # 1025 = SMTP (o app manda aqui) · 8025 = UI + API HTTP
    environment: { MP_MAX_MESSAGES: "5000" }
```

| Uso | Endpoint |
|---|---|
| o app **envia** | SMTP `mailpit:1025` (sem TLS, sem auth — é sink) |
| o teste **lê a caixa** | `GET  http://localhost:8025/api/v1/messages` (lista, `?limit=`, `?query=`) |
| o teste lê **um** e-mail | `GET  http://localhost:8025/api/v1/message/{ID}` (headers, texto, HTML, anexos) |
| o teste **limpa** a caixa | `DELETE http://localhost:8025/api/v1/messages` (setup de cada caso — isolamento) |

**MUST**
- O provider é escolhido **uma vez na composição, por ambiente** — nunca em cada chamador. Em teste:
  `MAIL_PROVIDER=sink`.
- **Limpar o sink no setup de cada teste** que asserta e-mail (não no teardown): teste que herda a
  caixa do vizinho é acoplamento por estado compartilhado (`flaky.md` §3).
- **Egress SMTP (25/465/587) bloqueado** no ambiente de teste, e **nenhuma chave de produção** no seed
  — o sink é o default, a rede é a rede de segurança.
- Alternativa mínima quando não há container (unit): provider **fake em memória** que acumula as
  mensagens numa lista assertável. Mesmo contrato, mesmo guard.

### 5.3 Variáveis do test kit

| Variável | Default em teste | O que faz |
|---|---|---|
| `APP_ENV` | `test` | **nunca** `prd`. Ausente/ilegível ⇒ o guard assume **não-prd** (fail-closed) |
| `MAIL_PROVIDER` | `sink` | `sink`\|`fake`\|`smtp`. `smtp` fora de prd só com a exceção por ADR (5 condições) |
| `MAIL_SINK_API` | `http://localhost:8025` | base da API HTTP que o teste consulta pra assertar |
| `MAIL_SINK_SMTP` | `localhost:1025` | pra onde o app aponta o transporte |
| `TEST_MAIL_DOMAIN` | `test.<domain>` | domínio aceito pelo guard; tudo fora dele + `env != prd` = **erro** |
| `MAIL_MAX_PER_RUN` | `50` | teto por execução; estourou, o run **aborta** (circuit breaker) |
| `TEST_RUN_ID` | id do log dir | entra no `+tag` do endereço e no log de auditoria de envio |

### 5.4 Pré-flight do runner (fail-closed, antes do 1º teste)

**MUST** — o CLI (`<project> test …`) verifica **antes de rodar qualquer modo** e **aborta** se faltar
qualquer item. Descobrir que o provider era o real **depois** do run é descobrir tarde demais:

1. `APP_ENV != prd` (ou confirmação explícita do §1 pra produção);
2. `MAIL_PROVIDER=sink` (ou `fake`) — provider real fora de prd **aborta**;
3. sink **alcançável** (`GET $MAIL_SINK_API/api/v1/messages` responde) — sink inalcançável é FAIL, não
   fallback pro SMTP real;
4. `TEST_MAIL_DOMAIN` setado e **não vazio**;
5. `MAIL_MAX_PER_RUN` setado (numérico, > 0);
6. **grep de segurança nos seeds/fixtures**: `gmail|hotmail|outlook|yahoo|icloud` em `tests/seeds/`,
   `fixtures/`, `factories/` → **aborta o run** (mesmo grep do gate — §6).

Falhou o pré-flight: o run termina com `exit 1` e mensagem **acionável** ("nada foi enviado; ajuste
`MAIL_PROVIDER=sink` / use `@$TEST_MAIL_DOMAIN`"), não com warning.

### 5.5 Carga, seed em massa e o cap

Teste de carga e seed em massa são **multiplicadores**: cada conta criada vira um OTP, cada pedido vira
um recibo. Aqui o cap não é conforto, é o freio.

**MUST**
- Todo modo que cria entidade em volume (`load`, `seed`, `simulated` com N personas) declara o **N
  esperado** e roda com `MAIL_MAX_PER_RUN` **coerente com o N** — não com um teto "grande o bastante
  pra não incomodar".
- Estourar o cap **aborta o run** e vira `fail` no `summary.json` (não é warning, não é skip). O único
  jeito de subir o teto é declarar no plano aprovado (§1) **por que** e o run continuar sinkado.
- Um caso de teste prova o abort: dispara `MAIL_MAX_PER_RUN + 1` envios e **espera o erro**
  (`categorias.md` §9).

> "1.000 contas criadas" e "1.000 e-mails enviados" só são a mesma coisa quando ninguém pôs sink e cap.
> Com os dois, o primeiro é um teste de carga; sem os dois, o segundo é um incidente de reputação.

### 5.6 O que o `summary.json` e o plano registram

**MUST** — o `summary.json` (§2) ganha um bloco `external_effects` (aditivo, não quebra o schema):

```json
"external_effects": {
  "env": "test",
  "mail": {"provider": "sink", "sink_url": "http://localhost:8025",
           "test_domain": "test.<domain>", "sent": 137, "max_per_run": 500,
           "real_sent": 0, "blocked_by_guard": 2},
  "sms": {"provider": "sink", "sent": 0, "real_sent": 0},
  "webhook": {"provider": "sink", "sent": 4, "real_sent": 0}
}
```

- **`real_sent` > 0 fora de prd = FAIL do run**, sem discussão (§6). É o número que prova o piso.
- `blocked_by_guard` > 0 é **saudável** quando vem do teste negativo do guard — e é **alerta** quando
  vem de outro caso: significa que algum código tentou mandar pra fora e o guard segurou.
- O **plano de Q.A.** (§1) declara, pra cada passo que dispara notificação: provider, domínio de
  destino, N esperado e cap. Passo que dispara efeito externo **sem** essas quatro linhas não é passo
  aprovado.

---

## 6. Integração com CI (os gates)

O gate dá dente à disciplina. Detalhe do que trava (e do que **não pode** desligar) em
`estrategia.md` §5.

**MUST — matriz de execução**
- **PR check** (rápido, ~3min): `smoke + unit afetado + a11y + lint`. Feedback em minutos.
- **Pré-deploy**: `<project> test all` (full minus chaos+unit, ~6min) + regressão visual + contrato.
- **Nightly**: `<project> test full` (inclui chaos + unit + **mutation** + carga).

**MUST — o que trava o merge**
- Fail no `summary.json` (`.totals.fail > 0`) **trava**.
- **a11y** (violação axe séria/crítica) **trava**.
- **CWV** fora do orçamento (LCP/INP/CLS acima do budget) **trava** (onde há frontend).
- Cobertura abaixo do mínimo (`estrategia.md` §3) **trava**. "No tests found" no caminho novo **trava**.
- **Efeito externo real fora de prd trava:** `external_effects.*.real_sent > 0` no `summary.json`
  (§5.6), provider de envio **real** em job de teste, ou o grep `gmail|hotmail|outlook|yahoo|icloud`
  batendo em `tests/`, `seeds/`, `fixtures/`, `factories/` **travam o merge**. O gate espelho da
  engineering é o `scripts/check-external-effects.sh`.
- Falha de smoke **pós-deploy** dispara **rollback automático**.

**VETADO**: `continue-on-error`, `allow_failure`, `--no-verify`, comentar o step, baixar threshold "só
nesse PR", ou mover o gate pra nightly "por enquanto" pra destravar um merge — o gate desligado não
volta (`estrategia.md` §5).

**Dashboards**: `summary.json` é parseado pra empurrar `tests_pass_total`, `tests_fail_total`,
`tests_duration_seconds_bucket`, e o **pass rate por teste** (detecção de flaky — `flaky.md` §2) pra
Prometheus.

---

## 7. Makefile padrão

```bash
make test             # unit + integration
make test-unit
make test-integration
make test-e2e
make test-a11y        # axe em componente + e2e
make test-visual      # regressão visual
make test-contract    # contratos consumer-driven
make smoketest        # smoke com self-check
make mutation         # mutation testing no domínio crítico
make coverage         # relatório de cobertura por camada
make ci               # tudo que o CI roda (gates inclusos)
```

> `make ci` é o que o gate roda — se passa local e passa no CI, é a **mesma** suíte. Divergência entre
> "verde na minha máquina" e "vermelho no CI" é ambiente não fixado (`flaky.md` §5), não azar.
