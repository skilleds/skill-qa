---
name: schematize-qa
metadata:
  version: 0.7.0
description: >-
  Q.A. agnóstica de linguagem: pirâmide de testes, smoke com conteúdo, a11y, contrato, flaky, cobertura. Use ao planejar ou auditar teste. Teste nunca dispara efeito externo real.
---

# Q.A. / Quality Assurance da Casa (schematize-qa)

Disciplina normativa, **agnóstica de linguagem**, que responde a uma pergunta só: **o software faz o
que diz — e como você PROVA?** A casa não aceita "verde" por fé. Um teste só vale quando **testa
comportamento** (o que o sistema faz), foi visto **falhar no vermelho** quando o invariante quebra, e
o runner **o enxerga**. Tudo o mais — cobertura de linha, "renderizou", snapshot que ninguém lê — é
decoração até que o teste prove que reprova o caso ruim.

Esta skill foi **extraída da `schematize-engineering`** (as antigas references *testes* e *testes-execucao*
e o comando `eng-qa`, hoje removido) pra rodar solta e agnóstica de linguagem. A engineering mantém só o **piso
mínimo** — "a DoD exige testes verdes" — e delega o **COMO** pra cá. Onde a engenharia diz *que* tem
que ter teste, esta skill diz *como* o teste é escrito, rodado, medido e gated.

**Versão:** skill `schematize-qa` v0.7.0. Changelog em `CHANGELOG.md`.

## Comandos (Claude Code)

Digite `/qa-help` pra ver todos. Em resumo:

| Comando | O que faz |
|---|---|
| `/qa-help` | lista todos os comandos do schematize-qa |
| `/qa-plan` | **plan-first**: levanta o escopo (camadas/modos, ambiente, rotas/personas, destrutivos, riscos), gera o MD de passo a passo em `<projeto>_archive/qa/` e **pede aprovação ANTES de rodar** — nada às cegas |
| `/qa-run` | executa o Q.A. **do plano aprovado**: faseado/assistido (pausa entre fases) ou de uma vez (multiagentes + watchdog que retoma de checkpoint, sem retry infinito); passo destrutivo só com gate; coleta o `summary.json` e os gates de teste/a11y/CWV |
| `/qa-load` | carrega à força TODO o corpo normativo (estratégia/pirâmide, categorias, flaky, execução) e passa a aplicá-lo |
| `/qa-claude` | cria ou mescla o `CLAUDE.md` sempre-on de Q.A. na raiz do repo (não sobrescreve blocos de outras skills) |
| `/qa-cc` | context compact: gera handoff no archive e roda `/compact` |
| `/qa-handoff` | gera o handoff (context.md + checklist.md) **sem** compactar — pra fim de sessão |

Os comandos ficam em `assets/commands/` e são instalados em `.claude/commands/`.

## Precedência e herança (leia antes de divergir)

<!-- herdado:engineering/precedencia:dominio intro="Esta skill é o recorte **Q.A. (teste e prova)**, agnóstico de linguagem: **disciplina de domínio**, não linguagem — ela diz como o teste é escrito, rodado e gated; a base diz que ele tem de existir." cmd="qa" -->Esta skill é o recorte **Q.A. (teste e prova)**, agnóstico de linguagem: **disciplina de domínio**, não linguagem — ela diz como o teste é escrito, rodado e gated; a base diz que ele tem de existir.

1. **Onde esta skill divergir da base, a BASE MANDA.** Aqui mora a especialização do domínio ou da
   ferramenta — o como, o padrão, o gate. Divergência de *piso* é defeito desta skill, não variante local.
2. **O que não está repetido aqui é HERDADO, não dispensado.** Esta skill herda os pisos da base e
   os comandos dela cobrem o **domínio**, não o piso geral. Valem integralmente, sem cópia local:
   - **§28 Archive** — `<projeto>/<projeto>_archive/` é **repositório git próprio, PRIVADO e
     obrigatório**, criticidade 0 (`schematize-archive`).
   - **§35 Definition of Done** e a lista de anti-padrões (citada por **título**, nunca por número).
   - **§39 Índice/MAPA** — enumeração exaustiva (uma entrada por unidade chamável, `M == N`) e grafo
     com arestas em ASCII (`A -> B`), nunca a seta unicode.
   - **IAM** (`schematize-engineering` → `references/iam.md`): identidade ≠ email, ≥2 fatores, ReBAC
     multi-tenant, argon2id-only para senha nova, sessão longa e logout irreversível.
   - **Efeito externo** nunca sai de não-produção (`schematize-engineering` →
     `references/efeitos-externos.md`).
   - **Orquestração** (`schematize-engineering` → `references/orquestracao.md` §9): o principal não
     desenvolve (é Claude Opus); executor mais barato que resolve — `haiku`/`sonnet` → Codex Terra → Cursor → `opus` só após falha; visual direto ao Codex; imagem nunca pelo Claude: detecta Codex/Gemini e pergunta ao usuário qual usar (Codex é a sugestão, não automática), nunca API paga.
3. **QA, ops, IAM e índice não têm comando próprio aqui:** vêm da base `/eng-*`. Para trabalho
   contínuo use `/eng-overdev`; para planejar `/eng-plan`; para varrer a base `/eng-scan`; para
   revisão geral `/eng-review` (e `/eng-ops`, `/eng-iam`, `/eng-index`). Os comandos
   `/qa-*` cobrem o domínio desta skill; o piso geral é o da base.<!-- /herdado -->

## Como usar esta skill

1. **Plan-first sempre** (`/qa-plan`): a malha de Q.A. inclui passos potencialmente destrutivos
   (chaos, mutação, carga). **Nenhuma submissão de Q.A. roda às cegas** — planeja tudo, gera o MD,
   pede aprovação. Leia `references/execucao.md`.
2. **Escreva teste que testa COMPORTAMENTO** (`references/estrategia.md` + `references/categorias.md`):
   a pirâmide (unit → componente → integração → e2e) mais as camadas transversais (smoke, a11y,
   regressão visual, contrato, dados). Cada teste é visto **falhar no vermelho** (red-first) antes de
   valer como guarda.
3. **Toda rota exposta nasce com matriz de acesso** (`references/categorias.md` §14): 4 personas
   (anônimo, não privilegiado, privilegiado, burla) × cada rota do inventário derivado, status **e**
   corpo, deny-by-default, públicas só na allowlist com dono, M == N, visto vermelho. Gate:
   `scripts/check-route-authz.sh`. O pentest é complementar, não substituto.
4. **Meça o que o teste VERIFICA, não só o que executa** (`references/estrategia.md`): cobertura por
   camada é contrato (não se baixa a régua), line coverage é piso, mutation testing é a meta.
5. **Nada de efeito externo real em teste** (`references/execucao.md` §5 + `references/categorias.md`
   §9): provider = sink, endereço no domínio de teste, cap por execução — e a caixa se confere
   **lendo do sink por API**, com o guard provado por um teste que **espera a recusa**.
6. **Teste flaky é bug, não "re-roda"** (`references/flaky.md`): detecta, torna determinístico, ou
   coloca em quarentena **com prazo e dono** — nunca silencia pra sempre.
7. **Gate no CI trava o merge e NÃO se desliga "por enquanto"** (`references/execucao.md`): teste,
   a11y e CWV são bloqueantes; Q.A. é item da DoD.
8. **Não trabalhe de memória** — os limites por camada, o "verde de verdade" e o fluxo plan-first
   estão nos references. Aplique os pisos abaixo independentemente do reference carregado.

Mapa de references — leia o que casa com a tarefa:

| Tarefa | Reference |
|---|---|
| **Property-based** (invariante em 4 formas, semente logada, contraexemplo vira teste), **mutation** (triage do sobrevivente em 3 caixas, score ≥ 80% no domínio crítico, queda > 2pp reprova) e **carga/perf** (smoke/stress/soak/spike/benchmark, SLO escrito ANTES, p95 +10% reprova) | `references/categorias.md` §§11–13 |
| **Estratégia & pirâmide** (unit→componente→integração→e2e), teste testa **comportamento não "renderizou"**, guarda provada no vermelho (red-first), **cobertura útil não vaidade** (mínimos por camada + mutation), Q.A. como **DoD**, gates de CI que travam | `references/estrategia.md` |
| **Categorias em detalhe:** unit agressivo, componente, integração, e2e, **smoke "verde de verdade"** (conteúdo + assertion negativa + self-check), **a11y (axe/WCAG 2.2 AA)**, **regressão visual**, **contrato** (consumer-driven) e **dados** (expectations/quarentena), **efeito externo — assertar e-mail/notificação LENDO DO SINK** (+ teste negativo do guard), matriz `simulated` de acessibilidade de rota | `references/categorias.md` |
| **Matriz de acesso por rota (authz de endpoint):** 4 personas × cada rota do inventário derivado, status+corpo, tabela de burlas com oráculo, deny-by-default, allowlist de públicas, anti-enumeração, red-first; gate `scripts/check-route-authz.sh` (M == N) | `references/categorias.md` §14 |
| **Flaky tests:** por que é bug (não "re-roda"), detecção (rodar N×, ordem aleatória, seed, `-race`), causas (tempo/sleep, estado compartilhado, rede real, relógio), **quarentena disciplinada** (prazo+dono, issue rastreável), determinismo | `references/flaky.md` |
| **Execução & gates:** o **fluxo plan-first** (planejar→MD→aprovação→rodar faseado/de-uma-vez, watchdog, destrutivo gated, sem retry infinito), **test kit** + CLI único + saída machine-readable (`summary.json`), padrão de script, seeds/personas, **efeito externo em teste** (endereço `@test.<domain>`, sink Mailpit, `MAIL_MAX_PER_RUN`, pré-flight fail-closed), **integração com CI** (PR/pré-deploy/nightly, gate por `summary.json`, a11y/CWV), Makefile | `references/execucao.md` |

## Pisos inegociáveis (VETADO — sem ADR de exceção)

Independente do reference, estes limites nunca são cruzados:

1. **Teste testa COMPORTAMENTO — e é visto FALHAR no vermelho.** Um teste que verifica "renderizou/
   montou" ou que passa **sem nunca ter reprovado o caso ruim** não é guarda, é decoração. Escreva-o
   **red-first** (ou quebre o código de propósito uma vez) e confirme o vermelho. **Proibido teste que
   não pode falhar:** assert ausente, `expect(true)`, mock que devolve o próprio input esperado,
   snapshot cego. Revisão de PR rejeita teste tautológico.
2. **O runner tem que ENXERGAR o teste.** Confirme que os arquivos novos são **coletados** (globs de
   include cobrem `*.test.tsx`/`_test.go`/`tests/**`). Suíte verde que rodou **0** dos testes novos é
   falso-verde silencioso — falhe o CI em "no tests found" no caminho novo e/ou asserte a **contagem
   esperada** de casos.
3. **Cobertura é CONTRATO — não se baixa a régua pra passar CI.** Editar o threshold, pular teste
   (`.skip`), comentar assert ou baixar o mínimo de cobertura pra "passar o CI" é VETADO. Conserta o
   código, não o teste. Line coverage é **piso**, não meta; a meta é mutation score no domínio crítico.
4. **Smoke prova CONTEÚDO, não status.** `200` com body vazio/`{}`/`null`/erro-HTML = FALHA. Toda rota
   crítica valida o **shape do body**, tem **assertion negativa** (sem stack trace/placeholder), e o
   suite tem um **self-check que força uma falha conhecida** pra provar que o runner sabe reportar
   FAIL. Smoke que nunca falha está cego.
5. **Acessibilidade e regressão visual TRAVAM.** a11y (axe/WCAG 2.2 AA — teclado, foco, contraste,
   nome acessível) e regressão visual são gate, não relatório opcional. Violação de a11y bloqueia o
   merge como qualquer teste vermelho. O ciclo completo do baseline visual (criar, atualizar com diff
   revisado, tolerância, determinismo) é da `schematize-regression` → `references/visual.md`; o piso
   acima (trava o merge, `-u` nunca em massa) vale igual aqui.
6. **Teste flaky é BUG, não "re-roda".** Flaky por corrida/tempo/estado é defeito. Detecta, torna
   determinístico, ou coloca em **quarentena com prazo e dono** (issue rastreável) — **nunca** silencia
   pra sempre nem esconde com retry infinito no gate.
7. **Q.A. é PLAN-FIRST e roda com aprovação.** Toda submissão de Q.A. planeja tudo, gera o MD de passo
   a passo e **pede aprovação antes de executar**. Passo destrutivo só roda se constava no plano
   aprovado **e** com o gate de ambiente ligado; autônomo só em dev/staging por default. Q.A. sem plano
   aprovado registrado **não roda**.
8. **Gate de CI trava o merge e NÃO se desliga "temporariamente".** Fail no `summary.json`
   (`.totals.fail > 0`), a11y vermelho, ou CWV fora do orçamento **travam o merge**. Desligar o gate
   "só por enquanto" é macaquice — o gate desligado não volta.
9. **Q.A. é parte da DoD e mora no archive.** Toda entrega passa pelos itens de teste da Definition of
   Done (§35 da engineering); todo plano/relatório de Q.A. mora em `<projeto>_archive/qa/` (§28), nunca
   no root. Sem archive, o Q.A. não aconteceu.

10. **Teste NUNCA dispara efeito externo real.** Nenhuma execução de Q.A. — unit, componente,
    integração, e2e, `simulated`, seed, carga — faz e-mail, SMS/voz, push, webhook de terceiro ou
    cobrança **chegar em alguém**. Normativa: `schematize-engineering` → `references/efeitos-externos.md`.
    **(a) Endereço sintético só no domínio de teste, em ROTA NULA:** fixture, seed, persona, factory,
    demo e carga usam `<papel>+<run-id>-<n>@test.<domain>` (null MX RFC 7505 + SPF `-all` + DMARC
    `p=reject`) ou TLD reservado (`.test`/`.invalid`/`.example`). **VETADO** `@gmail.com`/qualquer
    caixa real, domínio de terceiro/cliente, e-mail de pessoa real **(inclusive o seu)** e o domínio
    de **produção**. **(b) Provider = SINK** (Mailpit/log) em todo ambiente de teste, com o **guard
    DENTRO do provider**: destinatário fora do domínio de teste com `env != prd` → **erro**,
    fail-closed (config ausente = assume não-prd). **(c) Cap por execução** (`MAIL_MAX_PER_RUN`,
    default 50) que **aborta** o run. **(d) Corolário de Q.A. — conferir caixa de e-mail em teste é
    LER DO SINK por API** (Mailpit `GET /api/v1/messages`), **nunca** de uma caixa real e nunca "olha
    lá se chegou". **(e) O guard tem que ter teste que vê o VERMELHO:** um caso que tenta
    `@gmail.com` com `env=hml` e **espera a recusa** — assertion negativa, exatamente a disciplina
    red-first do piso 1; guard sem teste vermelho é guard não provado (e o sink tem que ficar **vazio**
    nesse caso). **Teste de carga e seed em massa MULTIPLICAM o efeito** — cap + sink são o que separa
    "1.000 contas criadas" de "1.000 e-mails enviados"; o incidente das 5.000 contas foi exatamente um
    laço de teste sem cap contra um provider real. Procedimento em `references/execucao.md` §5;
    asserção em `references/categorias.md` §9.
11. <!-- herdado:engineering/orquestracao:bullet -->**Orquestrador não desenvolve; subagent barato executa** (`schematize-engineering` → `references/orquestracao.md` §9). O principal só planeja/decompõe/despacha/supervisiona/revisa; ação onerosa vira micro-tasks; principal = Claude Opus; executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código, até 2 rodadas de correção pelo mesmo subagent) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo no checkpoint) → `park`; **visual direto ao Codex; imagem nunca pelo Claude (pergunta ao usuário: Codex sugerido, ou Gemini), API de imagem paga PROIBIDA**; papéis configuráveis em `agentes.toml` (aba "Agentes" do overdev). No `overdev`, cada item do checklist é executado pelo papel adequado e revisado pelo principal (diff + gate) antes do `- [x]`. **Sem frota ociosa:** agent idle com pendência executável volta ao trabalho; pendência que depende de outro agent → mata e enfileira com gatilho de dependência; terminou → mata (§9.6).<!-- /herdado -->

> Regra de bolso: se você **não viu o teste falhar de propósito**, você não sabe se ele funciona.
> Cobertura mede o que o teste **executa**; só o vermelho prova o que ele **verifica**.

## Andaime pronto (scripts e templates)

Não escreva do zero o que já está bundlado (movido da engineering pra cá):

- `scripts/lib.sh` — helpers de teste (`test_pass`, `test_fail`, `test_skip`, `test_section`,
  `test_summary`, `http_call`, `assert_http_in`, `api_base`). Todo script de teste usa estes.
- `scripts/test-skeleton.sh` — esqueleto obrigatório de `tests/<mode>/<name>.sh` (status + shape do
  body + assertion negativa).
- `scripts/smoke-selfcheck.sh` — o meta-teste anti "verde mentiroso": prova que o runner **consegue
  reportar FAIL** (normal=0; `--self-check`=0 **quando reportou o FAIL**, 1 quando NÃO reportou — smoke cego).
- `scripts/check-route-authz.sh` — gate da matriz de acesso por rota: `--routes` (inventário) × `--matrix`
  (4 personas por rota) + `--public-allowlist`; falha em rota sem linha, órfã, sem política ou pública sem dono.
- `scripts/simulated/run.py` — scaffold do engine `rotas × personas × injections` (cobertura total de
  rotas: acessível pra quem deve, bloqueada pra quem não deve). O detalhe **ofensivo** das injeções é
  governado pela `schematize-pentest`; aqui o foco é **acessibilidade/cobertura de rota**.

## Relação com as outras skills

- **schematize-engineering** — a **BASE**. Ela **exige** teste (DoD §35, archive §28, índice §39) e
  delega o **COMO** pra cá. O piso "a DoD exige testes verdes" fica lá; a estratégia, as categorias, o
  flaky, a cobertura e o fluxo plan-first ficam aqui. As skills de linguagem (`schematize-go`/`rust`/
  `elixir`/`csharp`/`zig`/`ruby`/`web`/`node`) especializam o *runner* e a sintaxe; o piso de Q.A. é o
  mesmo em todas.
- **schematize-pentest** — a **fronteira de segurança ofensiva**. Provar rejeição rota-por-rota
  (injeção/coerção de tipo, IDOR/BOLA, BFLA, cross-tenant, SSRF, XSS, SQLi, JWT), threat model,
  hardening e red-team autorizado é **lá**, não aqui. O `simulated` desta skill cobre
  **acessibilidade/cobertura de rota**; a matriz **adversarial** de ataque é da pentest. Q.A. prova que
  o sistema **faz o certo**; a pentest prova que ele **rejeita o errado**.
- **schematize-audit** — a **fronteira de histórico**. Auditar se os **checklists criados foram
  sanados** ("feito" exige prova, órfãos RED) é lá. Q.A. gera evidência (teste que passa hoje); a audit
  **consome** essa evidência pra promover um `- [x]` de suspeito a fato.
- **schematize-data** — parceira nos **testes de dados**: expectations, qualidade na borda, quarentena/
  DLQ e contrato de schema evolutivo. O *como testar dado* referencia a disciplina de dados dela.
- **schematize-api** — dona do **contrato de API**: o spec OpenAPI/proto, o diff de breaking change e a
  deprecação são dela (`schematize-api` → `references/`); aqui está o **teste** que prova que produtor e
  consumidor cumprem o contrato (consumer-driven, validação request/response contra o schema).
- **schematize-regression** — dona do ciclo **"bug corrigido nunca volta"**: teste vermelho antes do
  fix, teste de caracterização (golden master) antes de refatorar legado, baseline de perf e visual,
  `git bisect`. Aqui ficam a estratégia, a pirâmide e as categorias; lá, o que impede o MESMO defeito
  de retornar (`schematize-regression` → `references/`).
- **schematize-analytics** — dona do **tracking plan**: o evento é contrato e o gate é `check-tracking.sh`.
  O teste de tracking (evento certo, propriedades fechadas, nada disparado sem consentimento) segue o
  piso de Q.A. (vermelho plantado) mas a regra do evento mora lá.
- **schematize-web** — parceira nos testes de **frontend**: componente (comportamento, não markup),
  e2e por seletor acessível, a11y e regressão visual casam com o piso de a11y/CWV do frontend.

## Aplicação sempre-on

Esta skill é puxada quando a tarefa casa com a descrição. Para garantir o piso em **toda** interação
do repo, copie `assets/CLAUDE.md` para a raiz do projeto (`/qa-claude` mescla sem sobrescrever os
blocos das outras skills). O `CLAUDE.md` pina o resumo e aponta pra cá; a skill entrega o detalhe e o
andaime.
