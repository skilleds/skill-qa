# Categorias de Teste (em detalhe)

> Parte da skill **schematize-qa**. Cada camada da pirâmide e cada camada transversal, com o que a
> torna uma guarda de verdade. Estratégia/proporção em `estrategia.md`; execução/test-kit em
> `execucao.md`. A matriz **adversarial** de ataque (injeção, IDOR, cross-tenant) é da
> **schematize-pentest** — aqui o `simulated` cobre **acessibilidade/cobertura de rota**.

## Índice
- 1. Unit — agressivo, não decorativo
- 2. Componente — comportamento, não markup
- 3. Integração — fluxos reais com credenciais/DB
- 4. e2e — jornada do usuário
- 5. Smoke — "verde de verdade"
- 6. Acessibilidade (a11y)
- 7. Regressão visual
- 8. Contrato e dados
- 9. Efeito externo — assertar e-mail/notificação SEM enviar de verdade
- 10. `simulated` — cobertura total de rota
- 11. Property-based — invariante, não exemplo
- 12. Mutation — o teste do teste
- 13. Carga e performance — número com condição, não adjetivo
- 14. Matriz de acesso por rota (authz de endpoint)

---

## 1. Unit — agressivo, não decorativo

O grosso da malha. Rápido, isolado, sem rede/DB real. Delega ao runner nativo: Go `go test -race
-cover ./...`; TS `vitest run`/`jest`; Rust `cargo test`; etc.

**MUST**
- **`-race` sempre** (Go) / detector de concorrência ligado. Teste flaky por corrida = bug, não
  "re-roda" (`flaky.md`).
- **Caminho de erro obrigatório:** pra cada função, sucesso **e** falha (input inválido, dependência
  que erra, timeout, nil/null, vazio, divisão por zero, overflow).
- **Tabela de casos hostis por validador/parser:** tipo errado, fora do range, string gigante, vazia,
  unicode/RTL/null byte, número como string e vice-versa. Bug de sanitização morre no unit, antes de
  qualquer pentest achar.
- **Boundary obrigatório:** `0`, `-1`, `1`, `MAX`, `MAX+1`, vazio, um, muitos. O bug mora na borda.
- **Property-based** (SHOULD → MUST em domínio crítico): `fast-check` (TS), `gopter`/`rapid` (Go),
  `proptest` (Rust). Idempotência, round-trip (encode→decode), invariantes de agregado — acha o edge
  case que você não imaginou.
- **Mutation testing no domínio crítico** (`estrategia.md` §3): se o teste não pega a mutação, é
  decorativo.
- **Proibido teste que não pode falhar:** assert ausente, `expect(true)`, mock que devolve o próprio
  input esperado.

---

## 2. Componente — comportamento, não markup

Uma unidade de UI (ou um serviço + suas dependências próximas, mockadas na borda) exercitada como o
usuário/consumidor a usa. Ferramentas: Testing Library (React/Vue/Svelte), `@testing-library/user-event`.

**MUST**
- **Teste o COMPORTAMENTO observável, não a estrutura.** "Digitar e submeter mostra a mensagem de
  sucesso e limpa o campo" — não "o `<form>` existe" nem "o componente montou".
- **Consulte por papel/nome acessível** (`getByRole`, `getByLabelText`), **não** por classe CSS ou
  `test-id` frágil quando houver alternativa acessível. Isso faz o teste **também** exercitar a11y.
- **Interação real** (`user-event`, não só `fireEvent`): foco, tab, teclado, digitação — como um humano.
- **Sem snapshot cego** da árvore inteira. Snapshot, se usado, é de saída semântica pequena e revisada
  no diff.
- **Estados: loading, erro, vazio, sucesso.** Componente que só testa o estado feliz esconde o spinner
  eterno e o "erro" invisível.

---

## 3. Integração — fluxos reais com credenciais/DB

Fluxos ponta-a-ponta **dentro do serviço** com dependências reais (DB, cache, broker) — sem mock do
que se quer provar. Alvo: < 3min.

**MUST**
- **Credenciais reais + seed reproduzível:** login do superadmin com cookie real, CRUD ponta-a-ponta
  via API, upload, reset de senha completo. Usa `tests/seeds/*.sql` (idempotente — `execucao.md`).
- **O SQL/queries de verdade rodam** — é aqui que morre o bug que o mock esconde (coerção de tipo do
  driver, migration esquecida, índice ausente que só aparece com dado).
- **Idempotência e reprocessamento** onde o domínio exige (`Idempotency-Key` 2× → mesmo efeito).
- **Pré-seed declarado:** rodar `<project> test seed-superadmin` na primeira vez no ambiente.
- **Fluxo que notifica (cadastro, OTP, reset de senha, recibo) asserta a notificação LENDO DO SINK**
  (§9) — nunca de uma caixa real, nunca "presumindo que enviou".

---

## 4. e2e — jornada do usuário

Poucos, caros, alto valor. O usuário real atravessando o sistema montado (front + back + DB).
Ferramentas: Playwright (preferido), Cypress.

**MUST**
- **Jornadas, não telas:** "cadastra → confirma email → faz login → compra → recebe recibo", não
  "a página /checkout abre". O "confirma email" da jornada busca o link/código **no sink** (§9); e2e
  **nunca** abre uma caixa real nem espera um humano conferir.
- **Seletores por papel/label acessível** (`getByRole`, `getByLabel`) — resistem a refactor de CSS e
  exercitam a11y. `test-id` só quando não há nome acessível estável.
- **Determinismo** (`flaky.md`): espera por **condição** (elemento visível, request concluída), nunca
  `sleep(N)`; relógio/rede controlados; dados isolados por teste (sem depender de estado deixado por
  outro).
- **Poucos e valiosos:** e2e cobre os caminhos que **valem** a lentidão; o resto desce pra
  componente/unit.

---

## 5. Smoke — "verde de verdade"

Saúde do sistema pós-deploy, < 2min. **Falha = bloqueio de deploy.** Roda **antes e depois** de cada
`update` em todo ambiente. Um smoke que só confere `200` é teatro.

**MUST — anti "verde mentiroso"**
- **Assertar CONTEÚDO, não só status.** Toda rota-chave valida o **shape do body** (`jq -e`), não só o
  HTTP. `200` com body vazio, `{}`, `null`, `[]` onde deveria haver dado, ou HTML de erro com status
  200 = **FALHA**.
- **Assertion negativa obrigatória.** Cada rota crítica testa que o que **não** deveria estar lá não
  está: sem stack trace, sem `error`/`exception` no body de sucesso, sem `"undefined"`/`"null"`/`"NaN"`
  serializado, sem placeholder não renderizado (`{{`, `${`, `%s`).
- **Self-test do próprio smoke (meta-teste).** O suite tem um caso que **força uma falha conhecida**
  (bater numa rota fake `/_smoke_canary_should_404` esperando 404, e uma asserção que deve falhar de
  propósito num modo `--self-check`) pra provar que o runner **consegue reportar FAIL**. Se o
  self-check "passa" quando deveria falhar, o smoke está cego → CI quebra. Pronto em
  `scripts/smoke-selfcheck.sh`.
- **Cobertura de rota verificada.** O smoke compara as rotas que testou contra o inventário do
  OpenAPI/dispatcher. **Rota em produção sem caso de smoke = FALHA**, não silêncio.
- **Sem `|| true`, sem swallow.** Proibido `curl ... || true`, `set +e` sem voltar, ou condição que
  transforma erro em pass. Timeout numa dependência **obrigatória** é FAIL (skip só pra dependência
  **opcional** declarada).
- **Latência e dado fresco.** `/ready` valida dependência **de verdade** (ping no DB/broker), não
  `200` cacheado; o smoke afere `response-time p95` contra o SLO. Lento demais = FALHA.
- **Fail loud.** Banner vermelho ENORME (`lib.sh` → `test_summary`) e `summary.json` com
  `totals.fail > 0` travando o deploy.

> Smoke que nunca falha não é smoke saudável — é smoke quebrado.

---

## 6. Acessibilidade (a11y)

WCAG 2.2 AA é **piso**, não enfeite. a11y é **gate** (trava o merge), não relatório opcional.

**MUST**
- **axe automatizado** em componente e e2e (`@axe-core/playwright`, `jest-axe`, `axe-core`): zero
  violações **sérias/críticas**. Violação séria trava o merge como qualquer teste vermelho.
- **Teclado:** toda ação alcançável e operável só por teclado; ordem de foco lógica; **foco visível**;
  sem armadilha de foco. Testado por interação real, não presumido.
- **Nome acessível** em todo controle (botão, link, campo): `getByRole(...).name` existe e faz sentido.
  Ícone-botão sem `aria-label` = falha.
- **Contraste** AA (texto 4.5:1, UI 3:1) verificado; **não depender só de cor** pra transmitir estado.
- **Landmarks/headings/idioma** corretos; `prefers-reduced-motion` respeitado.

**SHOULD**
- Passe manual assistido (leitor de tela: NVDA/VoiceOver) nos fluxos críticos — o axe pega ~30-40% das
  barreiras; o resto é humano. Casa com o piso de a11y da `schematize-web`.

> a11y automatizada é chão, não teto. Verde no axe **não** significa acessível; significa "sem as
> barreiras que a máquina enxerga".

---

## 7. Regressão visual

Prova que a UI **não mudou de aparência sem intenção**. Ferramentas: Playwright screenshots,
Percy/Chromatic/Loki.

**MUST**
- **Baseline versionado e revisado.** O baseline é aprovado por humano; a atualização (`-u`) passa por
  **revisão do diff visual no PR**, nunca aceite automático em massa.
- **Determinismo** (`flaky.md`): fontes carregadas, animações desligadas (`prefers-reduced-motion` /
  freeze), dados/relógio fixos, viewport fixo. Screenshot flaky = quarentena, não threshold frouxo pra
  esconder.
- **Threshold consciente:** um antialiasing de 1px não é regressão; um layout deslocado é. O threshold
  é escolhido, não "o default que para de reclamar".
- **Escopo por componente** (preferido) além de páginas inteiras — diff pequeno é revisável; página
  inteira vira ruído.

> O ciclo operacional do baseline (criar, `-u` com diff revisado, política de tolerância, gate no CI)
> está em `schematize-regression` → `references/visual.md`. Este §7 é o piso; não duplique lá o que está aqui.

---

## 8. Contrato e dados

**Testes de contrato (consumer-driven)**
- Onde serviços se integram, o **consumidor declara o contrato** que espera (Pact, ou schema/OpenAPI
  compartilhado) e o **produtor verifica** que o cumpre no seu CI. Muda o produtor, quebra o contrato,
  o pipeline do produtor falha — **antes** de quebrar o consumidor em produção.
- **Schema/OpenAPI como fonte:** validar request/response contra o schema; breaking change no shape
  exige **nova versão** (compat back/forward — casa com `schematize-data`).
- **Dona do contrato é a `schematize-api`** (OpenAPI 3.1 contract-first, erros, paginação, Sunset, gate
  `check-api.sh`): aqui só se testa que o contrato é cumprido; o desenho e o diff de breaking são de lá.
- **Teste de tracking (analytics)** é o mesmo padrão de contrato: o tracking plan é a fonte
  (`schematize-analytics`), e o teste assere evento, propriedades fechadas e ausência de disparo sem consentimento.

**MUST — o contrato quebra no CI de QUEM MUDOU, não em produção.** A verificação do produtor roda no
pipeline dele; publicar sem verificar é empurrar o defeito para o consumidor descobrir em runtime.
- **O contrato é versionado junto do código**, não num wiki: `pacts/` ou o `openapi.yaml` no repo,
  com o diff aparecendo no PR.
- **Consumidor novo = contrato novo**, não "a API já devolve isso". Campo que o produtor devolve mas
  ninguém declarou **não é contrato** — é acidente, e some no próximo refactor sem aviso.
- **Breaking change de shape exige NOVA VERSÃO** (compat back/forward — casa com `schematize-data`),
  nunca um campo que muda de tipo em silêncio.

**Testes de dados (expectations)**
- Todo dataset/pipeline valida **na borda**: tipos, ranges, obrigatoriedade, unicidade, integridade
  referencial, distribuição esperada (Great Expectations, `dbt test`, ou asserções próprias).
- **Dado ruim não contamina o downstream:** falha vira **quarentena/DLQ**, não silêncio nem crash.
  Idempotência e replay determinístico no reprocessamento.
- **A expectation roda ANTES do consumo, não depois** — validar no fim do pipeline é descobrir com o
  dashboard já errado. E ela **falha o pipeline**: expectation que só loga é decoração.
- **Cobertura mínima de expectation:** toda coluna que alguém *usa para decidir* (chave, valor
  monetário, status, timestamp de corte) tem pelo menos **nulidade + domínio**. Coluna sem
  expectation é coluna em que ninguém confia mas todo mundo usa.
- **Teste de dados tem oráculo, não "olhômetro":** o esperado é declarado (contagem, soma, taxa de
  nulos aceitável), e a comparação é do CI. "Parece certo" não é asserção.
- A disciplina de dados (contrato evolutivo, lineage, PII, retenção) é da **schematize-data**; a
  modelagem do schema é da **schematize-database**; aqui é o **teste** que prova as duas.

---

## 9. Efeito externo — assertar e-mail/notificação SEM enviar de verdade

Jornada real notifica (confirmação, OTP, recibo, push/SMS/webhook), e testar isso é **obrigatório**: o
bug do template quebrado (`{{nome}}` cru, link para `localhost`) só aparece aqui.

> **O piso e o desenho do sink não moram aqui.** Regra, domínio de teste em rota nula, guard
> fail-closed, cap e a matriz do guard: `schematize-engineering → references/efeitos-externos.md`.
> Ambiente e pré-flight: `references/execucao.md` §5. **Esta seção é só o específico de Q.A.: como
> PROVAR, no teste, que a mensagem certa saiu para o sink e que o guard realmente guarda.**

**Regra em uma linha:** o teste **lê a caixa do sink por API** (Mailpit `GET /api/v1/messages`) —
nunca uma caixa real, nunca "olha lá no Gmail se chegou".

### 9.1 O ciclo da asserção (integração e e2e)

1. **Limpar o sink** (`DELETE /api/v1/messages`) — isolamento por teste (`flaky.md` §3).
2. **Disparar a ação de domínio** pela API/UI.
3. **Esperar por CONDIÇÃO** (poll no sink, timeout curto, erro claro) — nunca `sleep(N)`.
4. **Buscar por destinatário** (`?query=to:user+<run-id>-1@test.<domain>`), nunca "a última mensagem"
   (quebra em paralelo).
5. **Assertar conteúdo** (§9.2) e seguir a jornada com o que veio do e-mail (token, link, código).

**MUST**
- **Contagem exata:** a ação gera **1** mensagem, não "≥1" (duplicata de retry só esta asserção pega).
- **O OTP/token do e2e vem do sink**, não de caixa real nem de "modo de teste que devolve o código na
  resposta da API" (buraco de segurança que vaza para prd — `schematize-pentest`).
- **VETADO assertar "não deu erro no envio"** (`expect(sendMail).not.toThrow()`): tautológico (§1).

### 9.2 Asserção de conteúdo do template

| Assere | Exemplo |
|---|---|
| **destinatário exato** | `to == "user+r7f3a-1@test.<domain>"` (domínio de teste) |
| **remetente e reply-to** | do subdomínio de envio do ambiente, não o de produção |
| **assunto** | bate com o template e com o **locale** da persona |
| **corpo — o dado que importa** | nome, valor do pedido, **OTP no formato certo** |
| **link** | host do ambiente sob teste, token presente, e o link **funciona** (segue e valida) |
| **texto E HTML** | as duas partes existem e contêm o mesmo dado |

**Assertion negativa obrigatória** — o e-mail **não** contém: placeholder não renderizado (`{{`, `${`,
`%s`, `<%=`, `undefined`, `null`, `NaN`); stack trace ou caminho de servidor; segredo ou PII além da
necessária; link para `localhost`/host errado fora de ambiente local.

### 9.3 O teste NEGATIVO do guard (o vermelho do guard)

Guarda só conta se foi **vista reprovar** (piso 1). O QA escreve o caso que prova que o guard recusa, e
roda a **matriz mínima** definida na engineering (feliz, destinatário externo, config ausente =
fail-closed, bypass por parâmetro, cap N+1):

```
teste "guard recusa destinatário externo fora de prd":
    dado  env = "hml", MAIL_PROVIDER = "sink", TEST_MAIL_DOMAIN = "test.<domain>"
    quando enviar(para: "alguem@gmail.com", template: "otp")
    então  ESPERA erro acionável (cita o domínio de teste)
      e    o SINK está VAZIO e o contador real_sent continua 0
```

- Roda no **unit** (provider isolado) **e** é reexercido na **integração** com o provider real da
  composição — o guard tem que valer no objeto que o app usa, não só no fake.
- Se o caso do guard passar a "passar" (envio aceito), **o CI quebra**.

### 9.4 SMS, push e webhook

Mesmo oráculo: sink (número mágico / projeto de push de teste / receptor HTTP local — **nunca**
`webhook.site`, **nunca** a URL do parceiro), leitura do sink, contagem exata, negativo do guard e cap.
SMS custa por unidade: o cap importa mais.

---

## 10. `simulated` — cobertura total de rota

> **De quem é a matriz.** O oráculo de **rejeição** (SQLi, XSS, path traversal, mass assignment,
> coerção de tipo, authz, hardening) tem **dono único: `schematize-pentest → references/appsec-rejeicao.md`**
> — é lá que a matriz canônica (o que testar, o critério PASS/FAIL, a severidade) vive. Esta skill
> **não a redefine**.
>
> O que é de Q.A. é a **execução e a integração no runner**: o `scripts/simulated/run.py` pode
> executar esses payloads no CI como **caso hostil de regressão** (oráculo binário: nunca 500, nunca eco
> sem escape, nunca vazamento cross-tenant), consumindo a matriz da pentest. Exploração (encadear
> achados, PoC, red-team) é da `schematize-pentest`, sob autorização, escopo e RoE, e **não** roda no
> CI: se um payload vira exploração, ele saiu do `simulated` e entrou no engajamento.

Engine (`scripts/simulated/run.py`) que cruza **rotas × personas × injections** e prova, por persona,
que **cada rota do inventário** responde como esperado — acessível pra quem deve, `403`/`401` pra quem
não deve.

**MUST — cobertura total (garantia de acessibilidade)**
- **Enumera 100% das rotas** do catalog (gerado do OpenAPI/dispatcher). **Rota no catalog sem resultado
  = FALHA** — não existe rota "não testada".
- **Reconciliação obrigatória:** rota servida em runtime mas ausente do catalog (fantasma) **e** rota
  no catalog que não responde (morta / `404` inesperado) **ambas** quebram o run. O nº de rotas
  testadas bate com o inventário.
- Toda rota é exercida com persona **autorizada e não autorizada** — acessibilidade e isolamento no
  mesmo passe.
- Saída: `raw.jsonl` (uma linha/request), `report.md` (seções **AUTO** e **REVIEW**), `summary.json`.
  Personas mínimas (`superadmin`, `tenant_admin`, `normal_user`) em `personas.json`.

> **Fronteira com a pentest:** o `simulated` garante **cobertura e acessibilidade** de rota ("cada
> rota faz o certo pra quem deve"). A matriz **adversarial** (cada campo **rejeita** injeção/coerção/
> cross-tenant) é da `schematize-pentest → references/appsec-rejeicao.md` (`/pentest-endpoints`,
> `/pentest-authz`). Reutilizam o mesmo catalog de rotas; mudam o oráculo.

**Modos de segurança no runner** (`security`, `pentest`, `authz`, `hardening`): o harness (CLI, saída,
seeds) é do test kit (`execucao.md`); o conteúdo ofensivo (payloads, critérios, severidade/gate) é
**governado pela `schematize-pentest`**. Q.A. roda e coleta; a pentest define PASS/FAIL de segurança.

---

## 11. Property-based — invariante, não exemplo

> A description desta skill promete property-based; até 2026-08-21 havia **uma linha de tabela**
> dizendo o que é, e nenhum procedimento. Sem procedimento e limiar, técnica citada é vocabulário.

**O que é:** em vez de escrever `soma(2,3) == 5`, você declara a **propriedade** que vale para todo
input (`soma(a,b) == soma(b,a)`), e a ferramenta gera centenas de casos tentando quebrá-la. Quando
quebra, ela **encolhe** (shrink) até o menor contraexemplo — que é o que você cola no teste de
regressão.

**Procedimento**

1. **Escolha o alvo.** Vale a pena onde há **invariante de domínio**, não em CRUD: cálculo de preço/
   imposto, parser/serializador, máquina de estados, ordenação, particionamento por tenant, merge de
   conflito. Se você não consegue enunciar a propriedade numa frase, ainda não é caso para isto.
2. **Enuncie a propriedade** numa das quatro formas que cobrem quase tudo:
   **ida-e-volta** (`decodificar(codificar(x)) == x`) · **invariante** (o total nunca fica negativo;
   a soma das partes é o todo) · **oráculo alternativo** (a implementação nova concorda com a antiga/
   ingênua) · **metamórfica** (dobrar a quantidade dobra o frete).
3. **Gere entradas que doem:** vazio, limite do tipo, unicode com combining/RTL, `NaN`/`-0`, data em
   fuso e horário de verão, string com `\0`, número no limite da precisão decimal.
4. **Fixe a semente e LOGUE.** Property-based sem semente logada vira flaky irreproduzível — e a
   `flaky.md` já trata *aleatoriedade sem semente* como defeito, não como azar.
5. **Todo contraexemplo vira teste de exemplo versionado.** O valor da técnica é achar o caso; o
   valor de manter é ele não voltar. A suíte cresce por descoberta.

**Limiar (o que fecha o gate)**

- **Cobertura:** 100% dos **módulos de domínio crítico** listados no plano de Q.A. têm ao menos
  **uma** propriedade. Não é métrica de linha: é lista nominal, e módulo sem propriedade aparece no
  relatório como **descoberto**, não como "não aplicável".
- **Volume:** ≥ **1000 casos** por propriedade no nightly; ≥ 100 no PR (para não custar minutos).
- **Falha = bloqueio.** Contraexemplo encontrado reprova o run; "roda de novo que passa" é o oposto
  da técnica.
- **Tempo:** propriedade que leva > 30s no PR sai para o nightly com nome — nunca é apagada em
  silêncio.

**Ferramentas** (por stack, no anexo volátil de versões da skill da linguagem correspondente): Hypothesis (Python),
fast-check (TS/JS), proptest/quickcheck (Rust), rapid/gopter (Go), StreamData (Elixir), FsCheck
(.NET), Rantly (Ruby).

---

## 12. Mutation — o teste do teste

> Aqui havia **nome de ferramenta e nenhum procedimento nem threshold** (vistoria de 2026-08-21).
> Mutation score sem limiar escrito é número de slide.

**O que é:** a ferramenta injeta um bug pequeno no **código de produção** (troca `>` por `>=`,
inverte um `if`, remove uma linha, muda `+` por `-`) e roda a suíte. Se a suíte continua verde, o
mutante **sobreviveu** — e você acabou de descobrir código que ninguém verifica. `mutation score =
mutantes mortos / mutantes válidos`.

**Por que isto e não cobertura de linha:** linha coberta prova que o código **executou**; mutante
morto prova que alguém **verificou o resultado**. Um teste sem asserção dá 100% de linha e 0% de
mutation. É por isso que a skill chama line coverage de **piso** e mutation de **meta**.

**Procedimento**

1. **Delimite o escopo.** Mutation no repo inteiro é caro e ninguém olha o relatório. Rode no
   **domínio crítico** — a lista nominal do plano de Q.A. (cálculo, authz, estado, dinheiro).
2. **Rode no nightly**, nunca no PR (é 10–50× a suíte). No PR, rode **só nos arquivos alterados**
   (`--since`/incremental), com limiar próprio.
3. **Triage do sobrevivente**, em três caixas: **(a) teste faltando** → escreva o teste (é o achado
   que interessa); **(b) mutante equivalente** — o mutante não muda o comportamento observável (ex.:
   otimização, log) → marque como equivalente **com justificativa escrita**; **(c) código morto** →
   apague o código, não escreva teste para ele.
4. **Baseline versionado.** O score entra no repo; a comparação é contra o último verde.

**Limiar (o que fecha o gate)**

| Alvo | Piso | Regra de regressão |
|---|---|---|
| Domínio crítico (a lista nominal) | **mutation score ≥ 80%** | queda > **2pp** contra o baseline reprova |
| Arquivos alterados no PR | **≥ 70%**, ou nenhum mutante sobrevivente novo | mutante sobrevivente **novo** reprova o PR |
| Resto do repo | sem piso | medido e reportado, nunca gate |

- **Equivalentes declarados não entram no denominador** — e uma lista de equivalentes que só cresce
  é cheiro: revise-a quando passar de 10% dos mutantes.
- **Nunca "ajuste o limiar para o verde".** Baixar o piso é decisão com **ADR**, como qualquer
  afrouxamento de gate (`estrategia.md`).

**Ferramentas:** Stryker (TS/JS/.NET/Scala), mutmut/cosmic-ray (Python), `go-mutesting`/`ooze` (Go),
`cargo-mutants` (Rust), PIT (JVM), Muzz/`mutant` (Ruby).

---

## 13. Carga e performance — número com condição, não adjetivo

> A description promete **carga/perf** e o contrato do CLI não tinha o modo `load` — enquanto
> `execucao.md` já falava dele como se existisse (vistoria de 2026-08-21). Agora existe:
> `<project> test load`.
>
> **Carga é o maior multiplicador de efeito externo que existe.** Cada conta criada vira um OTP,
> cada pedido vira uma confirmação. **Só roda com sink ligado, guard deny-by-default verificado e
> cap por execução** (§9 e `execucao.md`) — e o destinatário sempre em `@test.<domain>`. Sem os
> três, o que você tem não é teste de carga: é incidente de reputação com relatório bonito.

**Vocabulário, porque a confusão aqui custa caro**

| Tipo | Pergunta que responde |
|---|---|
| **smoke de carga** | o sistema aguenta a carga **normal** sem degradar? (roda a cada release) |
| **stress** | onde ele quebra, e **como** quebra (degrada ou cai?) |
| **soak** (resistência) | ele sobrevive a horas de carga constante — vazamento de memória, conexão que não volta, disco de log |
| **spike** | ele sobrevive a 10× em 30 segundos e **volta ao normal** depois |
| **benchmark** | uma função/endpoint isolado, com número comparável entre commits |

**Procedimento**

1. **Escreva o SLO antes do teste.** "Rápido" não é critério. O alvo é `p95 ≤ Xms` e `taxa de erro ≤
   Y%` **na carga Z**, por endpoint crítico — os mesmos números do SLO de produção
   (`schematize-infra` → `references/observabilidade.md`), não números inventados para o teste passar.
2. **Modele a carga do usuário real**: mix de endpoints proporcional ao tráfego, think time,
   ramp-up gradual (subida instantânea mede o autoscaler, não o sistema), dados **variados** — mil
   requests no mesmo `id` medem o cache.
3. **Ambiente comparável e declarado.** Rodar em hardware diferente a cada vez produz gráfico, não
   dado. Registre CPU/RAM/versão junto do resultado; comparação só vale contra o mesmo perfil.
4. **Meça o que dói:** latência **p95 e p99** (média esconde a cauda), taxa de erro, throughput,
   saturação (CPU, conexões de banco, fila) — e **onde** o gargalo estava, não só que existiu.
5. **Feche com perfil.** Teste de carga que só diz "ficou lento" não gera correção: colete flame
   graph/traço da execução (`observabilidade`) e nomeie o gargalo.

**Limiar (o que fecha o gate)**

- **Todo endpoint crítico** tem SLO escrito **e** um cenário de carga que o exercita. Endpoint
  crítico sem cenário = **cobertura faltante**, não "sem problema".
- **Regressão** (baseline de perf versionado e comparação por release: `schematize-regression` →
  `references/desempenho.md`): p95 pior que **+10%** contra o baseline do último release reprova; taxa de erro
  acima do SLO reprova **sempre**, sem tolerância percentual.
- **Soak:** ≥ **1h** no nightly de release, com **memória estável** (crescimento < 5% após o
  aquecimento) — o vazamento só aparece no tempo.
- **Spike:** o sistema **volta** ao p95 normal em ≤ 2 minutos após o pico. Não voltar é achado.
- O resultado é **JSON versionado** ao lado do `summary.json`, como todo o resto — número em
  captura de tela não é baseline.

**Ferramentas:** k6, Gatling, Locust, Vegeta, `wrk`, JMeter; para benchmark de função, o do
ecossistema (`go test -bench`, `criterion` no Rust, `pytest-benchmark`, `Benchmark.NET`,
`hyperfine` para CLI). Para subir dependência real em integração/carga local: **Testcontainers**.

---

## 14. Matriz de acesso por rota (authz de endpoint)

> **Regra:** toda rota/endpoint/handler exposto **NASCE** com teste de matriz de acesso, no CI, no
> nível **unit/componente** (sem subir infra real — roda no PR, em segundos). Para **cada** rota do
> inventário o teste exercita 4 personas e afirma **status E corpo**. É diferente do `simulated` (§10,
> cobertura de rota) e do **pentest** (`schematize-pentest`): o pentest é o engajamento ofensivo
> periódico contra o sistema no ar; esta matriz é a guarda barata e contínua que impede a regressão
> entre um pentest e outro. **Complementar, não substituto.**

**Inventário derivado, nunca digitado.** A lista de rotas sai do código/spec (router, tabela de
rotas do framework, OpenAPI) por um extrator no próprio teste. Digitar a lista à mão garante que a
rota nova seja esquecida. O gate falha se existir rota sem linha na matriz (**M == N**): rota nova
esquecida quebra o CI. Gate pronto: `scripts/check-route-authz.sh` (rotas × personas, órfã, sem
política, pública fora da allowlist).

**Deny-by-default.** Rota sem política declarada **falha** o teste. Rota pública é **exceção
explícita** numa **allowlist versionada** com justificativa e dono por linha; a allowlist é revisada
no PR (diff nela é decisão de segurança, não detalhe).

**As 4 personas (por rota)**

| # | Persona | Credencial | Esperado |
|---|---|---|---|
| 1 | **Anônimo** | nenhuma | `401`, corpo sem dado (exceto rota da allowlist) |
| 2 | **Autenticado não privilegiado** | válida, sem a permissão/papel/tenant exigido | `403` (ou `404` se a política for não revelar), corpo sem dado |
| 3 | **Privilegiado** | o que deve passar | `2xx` com o corpo do contrato |
| 4 | **Tentativas de burla** | a tabela abaixo | sempre negado; nunca `2xx` nem dado |

**Burlas mínimas por rota, com o oráculo**

| Burla | Como tentar | Oráculo esperado |
|---|---|---|
| Token ausente/vazio/malformado | `Authorization:` omitido, `Bearer `, `Bearer x.y` | `401`, corpo genérico |
| Expirado / assinatura inválida | JWT vencido; assinatura adulterada | `401` |
| `alg=none` | JWT com `alg: none` e sem assinatura | `401` |
| Outro audience/tenant | token válido emitido para outro `aud`/tenant | `401`/`403` |
| Header de identidade forjado | `X-User-Id`, `X-Forwarded-*`, `X-Original-URL` vindos do cliente | ignorado: resultado igual ao anônimo |
| Troca de método | `HEAD`, `OPTIONS`, `X-HTTP-Method-Override` | mesma política do método real; sem bypass |
| Variação de path | `/x/`, `//x`, `/X`, `%2e%2e`, `%2f`, `;param`, `.json` | mesma negação (normaliza antes de autorizar) |
| BOLA/IDOR | id de recurso de outro usuário/tenant | `403`/`404` conforme política, sem dado |
| Mass assignment | body com `role`, `is_admin`, `tenant_id` | campo ignorado ou `400`; papel não muda |
| Param sobrescrevendo identidade | `?user_id=`, `{"user_id":..}` | identidade vem do token, nunca do param |
| Rota alternativa/versão antiga | `/v1` vs `/v2`, `/internal`, `/admin`, `/debug`, `/metrics`, `/health` com dados | mesma política (ou inexistente); sem dado |
| Cache/CDN | resposta autenticada servida a anônimo | `Cache-Control: private/no-store`; `Vary: Authorization` |
| GraphQL/batch/WebSocket/SSE | operação em lote ou handshake sem credencial | auth checada no handshake e por operação |
| CORS permissivo | `Origin` hostil com credenciais | sem `Access-Control-Allow-Origin` refletido/`*` com credencial |

**Negação não vaza.** `401` (anônimo) / `403` (sem permissão) / `404` (recurso de outro tenant, se a
política for não revelar), com **corpo sem dado do recurso**. Quando a política é **anti-enumeração**,
o corpo (e o tempo, dentro de tolerância) de "existe mas é de outro" é **idêntico** ao de "não
existe" — afirme igualdade de corpo, não só de status.

**Red-first (mutação).** O teste só vale depois de visto **vermelho**: remova a checagem de authz de
um handler (ou troque `deny` por `allow` na política) e veja a matriz falhar naquela rota. Se nada
quebra, a matriz decora. Registre o vermelho no PR (ou rode mutation na camada de authz, §12).

**Esqueleto (agnóstico de linguagem, tabela-dirigido)**

```text
inventario   = extrair_rotas(router | openapi)            # derivado; nunca literal
publicas     = ler("publicas.allowlist")                  # rota | justificativa | dono
personas     = [anonimo, nao_privilegiado, privilegiado]
burlas       = catalogo_de_burlas()                       # tabela acima

assert nao_vazio(inventario)
for rota in inventario:
    politica = politica_declarada(rota)                   # ausente => FALHA (deny-by-default)
    assert politica existe or rota in publicas
    for persona in personas:
        resp = chamar_handler(rota, credencial(persona))  # unit/componente, sem infra real
        esperado = oraculo(rota, persona, politica)
        assert resp.status == esperado.status
        assert resp.corpo == esperado.corpo               # corpo, não só status
        if esperado.nega: assert sem_dado_do_recurso(resp.corpo)
    for burla in burlas.aplicaveis(rota):
        resp = chamar_handler(rota, burla.requisicao)
        assert resp.status in {401, 403, 404} and sem_dado_do_recurso(resp.corpo)
assert linhas_da_matriz == len(inventario) * len(personas)   # M == N
```

**Como fica na prática (sem ficar preso a uma)**
- **Go:** `httptest.NewRecorder` sobre o `http.Handler`/router; rotas via `chi.Walk`/`mux.Walk`;
  `t.Run(rota+persona)` em tabela.
- **Rust:** `tower::ServiceExt::oneshot` no `axum::Router` (sem socket); rotas da tabela do router ou
  do OpenAPI gerado; `rstest`/loop de casos.
- **TS:** `supertest`/`app.inject` (Fastify)/`fetch` sobre o handler com `vitest` `test.each`; rotas do
  OpenAPI ou do registro do framework.
- **Python:** `TestClient` (FastAPI/Starlette) ou `Client` do Django com `pytest.mark.parametrize`;
  rotas de `app.routes`/schema OpenAPI.

Em todas: sem rede, sem DB real (repositório fake ou in-memory), tokens assinados por chave de teste.
O contrato do `check-route-authz.sh` espera a matriz exportada como `MÉTODO /path persona resultado`
e roda no CI como segundo gate (primeiro o teste, depois a conferência M == N).
