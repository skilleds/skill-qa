# Changelog — schematize-qa

Todas as mudanças relevantes deste pacote, no formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento [SemVer](https://semver.org/lang/pt-BR/).
## [0.8.0] — 2026-10-20
### Adicionado
- Categoria 14 em `categorias.md`: **matriz de acesso por rota** (anônimo, autenticado sem privilégio, privilegiado e burlas), inventário derivado, deny-by-default, allowlist de públicas com dono, anti-enumeração e red-first.
- Gate `scripts/check-route-authz.sh` (+ teste): falha se rota sem as 4 personas, órfã, sem política ou pública fora da allowlist (M == N).
- Piso 10 em `assets/CLAUDE.md` e item de DoD em `estrategia.md`.
- Porquê: rota entregando dado sem autenticação era bug recorrente; só teste permanente por rota, no PR, o impede.


## [0.7.0] — 2026-10-15
### Alterado
- Aponta para `schematize-regression` onde a fronteira corta: regressão visual (piso 5 e `categorias.md` §7
  mantêm o gate; o ciclo do baseline vai para `regression/visual.md`), regressão de perf (§13) e a
  seção de relação com as outras skills (bug nunca volta, caracterização, bisect).
- Porquê: a regression foi criada como dona do ciclo "o bug não volta"; sem ponteiro, o QA e ela divergiriam.

## [0.6.0] — 2026-10-14
Gate da skill-dev verde, bloco herdado de precedência e fronteiras com as skills novas.

### Corrigido

- `test-skeleton.test.sh`/`smoke-selfcheck.test.sh`: o `trap` de limpeza vira função com `p` local (fim do SC2154); scripts no piso de shell.

### Adicionado
- `scripts/smoke-selfcheck.test.sh` e `test-skeleton.test.sh` com vermelho e verde plantados (servidor HTTP de brinquedo, runner cego): um gate sem vermelho plantado é decoração.
- Bloco herdado `engineering/precedencia:dominio` no `SKILL.md` (faltava; o gate reprovava `herdado-ausente`).
- `SKILL.md` e `references/categorias.md` §8: `schematize-api` é a dona do contrato de API (aqui só o teste que prova que é cumprido) e `schematize-analytics` é a dona do tracking plan (teste de tracking segue o mesmo padrão de contrato).

### Alterado
- Description 232 -> 177 chars (orçamento de listagem).

## [0.5.1] — 2026-10-14
Ressincronização dos blocos herdados com a engineering v0.27.0; sem mudança de piso próprio.

### Alterado
- Description reduzida (≤235 chars) para caber no orçamento de listagem de skills (soma ≤8300); mesmo território, fronteiras com as irmãs preservadas.
- Blocos herdados ressincronizados com a `schematize-engineering` v0.27.0 (`tools/sync-herdados.mjs`): orquestração com a regra de imagem (nunca pelo Claude; detecta Codex/Gemini e pergunta ao usuário qual usar, Codex como sugestão) e `schematize overdev delegar` (comando do app) no lugar do falso nome de skill `schematize-overdev`.

## [0.5.0] — 2026-10-14
Fronteira qa x pentest e corte de duplicação com a base.

### Corrigido
- **`categorias.md` §10 dizia que a pentest "não tem script nenhum"** — falso (`pentest-gate.mjs`, `pentest-report.mjs`, `contar-rotas.sh`). A passagem foi reescrita sem a afirmação.
- **Oráculo de rejeição com dono único.** A matriz de SQLi/XSS/authz/hardening é de `schematize-pentest → references/appsec-rejeicao.md`; o qa virou ponteiro e mantém só a execução/integração no `simulated`. Referência sem prefixo foi prefixada.
- **§9 (efeito externo) enxugada** de ~100 para ~60 linhas: piso, guard e matriz ficam em `schematize-engineering → references/efeitos-externos.md`; aqui resta como provar o sink e o vermelho do guard. Removida citação a ADR que o leitor não consegue ler (`execucao.md`).
- Description ≤350 em YAML válido (`>-`); o escalar anterior era inválido.
- **Description** reduzida (~270 chars) para caber no orçamento de listagem (soma das 31 skills ≤ 8500; o Claude Code corta a listagem acima disso).

### Alterado
- `scripts/check-external-effects{,.test}.sh` viram arquivos herdados da engineering (cabeçalho "herdado de schematize-engineering — não edite aqui"); conteúdo inalterado.

## [0.4.2] — 2026-09-30
O piso de orquestração passa a ser **herdado** da base em vez de copiado à mão: uma mudança na engineering não exige mais editar 38 arquivos.

### Alterado
- Piso "Orquestrador não desenvolve; subagent barato executa" em `assets/CLAUDE.md` e `SKILL.md` agora é um bloco `<!-- herdado:engineering/orquestracao:… -->`, sincronizado de `schematize-engineering/assets/herdados/orquestracao.md` por `tools/sync-herdados.mjs` (checado no CI). Redação normalizada; conteúdo inalterado.

### Mantido (piso inalterado)
- Sonnet por default, escada até opus, sem frota ociosa (engineering `references/orquestracao.md` §9/§9.6).

## [0.4.1] — 2026-09-30
Pedido do dono: agents idle poluem a tela e seguram recurso.

### Adicionado
- Piso de orquestração ganha a regra de frota ociosa (idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata); detalhe na `schematize-engineering` §9.6.

## [0.4.0] — 2026-09-30
Pedido do dono, por **custo**: o agent principal não desenvolve — planeja e despacha; subagents
executam em `sonnet` por padrão e `opus` só após falha. Regra canônica em `schematize-engineering`
→ `references/orquestracao.md` §9.

### Adicionado
- **Modo autônomo com executores baratos** (`references/execucao.md`, `assets/commands/qa-run.md`):
  subagents/workers em `sonnet` por default; principal só planeja/revisa; escada mesmo subagent
  (≤2 rodadas) → re-decompor → `opus` com motivo registrado.
- Piso "Orquestrador não desenvolve; subagent barato executa" em `SKILL.md` e `assets/CLAUDE.md`.

### Mantido (piso inalterado)
- Plan-first com aprovação, gates que travam, passo destrutivo só no plano aprovado + gate de
  ambiente, watchdog sem retry infinito, efeito externo em sink, archive.

## [0.3.0] — 2026-08-21
As três técnicas que a description prometia e o corpo não entregava. A vistoria de 2026-08-21: `load` **não existia no contrato do CLI** (enquanto `execucao.md` já falava do modo como se existisse), `grep 'k6|Locust|benchmark|fuzz|testcontainers'` = **0**, e mutation tinha **nome de ferramenta e nenhum procedimento nem threshold**.

### Adicionado
- **`categorias.md` §11 — Property-based:** as **4 formas** de enunciar a propriedade (ida-e-volta, invariante, oráculo alternativo, metamórfica), as entradas que doem, **semente fixa e logada** (sem ela a técnica vira flaky irreproduzível) e a regra que faz a suíte crescer por descoberta: **todo contraexemplo vira teste de exemplo versionado**. Limiar: 100% dos módulos de domínio crítico com ao menos uma propriedade (lista nominal — módulo sem propriedade sai no relatório como **descoberto**, não como "não aplicável"), ≥1000 casos no nightly, ≥100 no PR, contraexemplo **reprova**.
- **`categorias.md` §12 — Mutation:** o porquê antes do número (linha coberta prova que o código **executou**; mutante morto prova que alguém **verificou o resultado** — teste sem asserção dá 100% de linha e 0% de mutation), a **triage do sobrevivente em três caixas** (teste faltando · equivalente com justificativa escrita · código morto, que se apaga em vez de testar) e os limiares: **≥ 80%** no domínio crítico com queda > **2pp** reprovando, **≥ 70%** nos arquivos alterados do PR com **mutante sobrevivente novo** reprovando, resto do repo medido e nunca gate. Equivalentes fora do denominador, e lista de equivalentes acima de 10% é cheiro. Baixar o piso é **ADR**.
- **`categorias.md` §13 — Carga e performance:** o vocabulário separado (smoke de carga · stress · **soak** · spike · benchmark), o procedimento com **SLO escrito antes** (os mesmos números do SLO de produção, não os que fazem o teste passar), carga modelada do usuário real (ramp-up gradual — subida instantânea mede o autoscaler), ambiente declarado, **p95 e p99** (a média esconde a cauda) e o fechamento com perfil, porque "ficou lento" não gera correção. Limiares: endpoint crítico sem cenário é **cobertura faltante**; p95 **+10%** contra o baseline reprova; erro acima do SLO reprova **sempre**; soak ≥1h com memória estável; spike volta ao normal em ≤2min. E o aviso na frente: **carga é o maior multiplicador de efeito externo que existe** — só roda com sink, guard verificado e cap.
- **`execucao.md`** — o contrato do CLI ganhou `test property`, `test mutation` e `test load`, e o `full` passou a incluir `property`. A promessa da description e o contrato voltaram a falar a mesma língua.

## [0.2.0] — 2026-08-20

Propagação do piso **"efeito externo NUNCA sai de não-produção"** (normativa na
`schematize-engineering` → `references/efeitos-externos.md`) no recorte de Q.A. — a disciplina que mais
dispara efeito externo por acidente. Origem: incidente real de **>5.000 e-mails** disparados por um
laço de teste para endereços sintéticos, com reputação de IP e domínio queimada e utilidade zero.

### Adicionado
- **SKILL.md — piso inegociável 10: "Teste NUNCA dispara efeito externo real."** Endereço sintético só
  no **domínio de teste em ROTA NULA** (`<papel>+<run-id>-<n>@test.<domain>`; VETADO `@gmail.com`,
  caixa real, domínio de terceiro, e-mail de pessoa real — inclusive o seu — e o domínio de produção);
  provider = **SINK**; **guard DENTRO do provider** fail-closed; **cap por execução**
  (`MAIL_MAX_PER_RUN`); o **corolário de Q.A.** (conferir caixa em teste é **ler do sink por API**,
  nunca de caixa real); e a exigência de que o **guard tenha teste que vê o VERMELHO** (tenta
  `@gmail.com` com `env=hml` e **espera a recusa** — assertion negativa, red-first do piso 1). Registra
  que **carga/seed em massa multiplicam o efeito**: cap + sink separam "1.000 contas" de "1.000
  e-mails".
- **`references/execucao.md` §5 — "Efeito externo em teste — endereço, sink e cap"** (procedimento
  completo): endereçamento de seeds/personas/fixtures com tabela por papel e a lista de vetados; setup
  do **sink Mailpit** (SMTP 1025 + API HTTP 8025: `GET /api/v1/messages`, `GET /api/v1/message/{ID}`,
  `DELETE /api/v1/messages`) e o fake em memória pro unit; tabela de **variáveis do test kit**
  (`APP_ENV`, `MAIL_PROVIDER=sink`, `MAIL_SINK_API`, `MAIL_SINK_SMTP`, `TEST_MAIL_DOMAIN`,
  `MAIL_MAX_PER_RUN`, `TEST_RUN_ID`); **pré-flight fail-closed do runner** (6 verificações que abortam
  o run antes do 1º teste, incluindo o grep de caixa real em seeds/fixtures); regra de **carga/seed em
  massa** com cap coerente com o N; e o bloco **`external_effects` no `summary.json`** (`real_sent`,
  `blocked_by_guard`, provider, cap) que o gate confere.
- **`references/categorias.md` §9 — "Efeito externo: assertar e-mail/notificação SEM enviar de
  verdade"**: o ciclo da asserção (limpa o sink → dispara → espera por **condição**, nunca `sleep` →
  busca **por destinatário** → asserta), contagem exata (1, não "≥1"), OTP do e2e vindo do sink (e o
  veto a expor OTP na resposta da API), tabela de **asserção de conteúdo do template** (destinatário,
  remetente, assunto, dado, link, texto+HTML) com **assertion negativa** (`{{`/`${`/`undefined`, stack,
  segredo/PII, link pro host errado), o **teste NEGATIVO do guard** com a matriz mínima de 5 casos
  (feliz, guard, fail-closed, sem bypass por parâmetro, cap) e a extensão pra **SMS/push/webhook**.
- **`references/estrategia.md`** — novo item na **Definition of Done** (`real_sent == 0`, guard com
  teste vermelho, notificação assertada pelo sink) e novo item nos **gates de CI que travam o merge**.
- **`references/execucao.md` §6** — o gate de CI passa a travar em efeito externo real fora de prd
  (`external_effects.*.real_sent > 0`, provider real em job de teste, grep de caixa real em
  `tests/`/`seeds/`/`fixtures/`/`factories/`).
- **`references/flaky.md`** — envio real como causa de flakiness (fila/throttle/greylisting do
  provedor) na tabela de causas, e o sink como determinismo por design.
- **`assets/CLAUDE.md`** — novo piso sempre-on (7) com o resumo do veto + o ciclo de asserção pelo sink
  e o `real_sent == 0` no que o gate lê.

### Mudado
- **`references/execucao.md`** renumerado: "Integração com CI" §5 → **§6** e "Makefile padrão" §6 →
  **§7** (a nova seção de efeito externo entrou como §5, ancorada logo após seeds/personas).
- **`references/categorias.md`** renumerado: "`simulated` — cobertura total de rota" §9 → **§10** (a
  nova seção de efeito externo entrou como §9, junto das demais categorias).
- **`references/categorias.md`** §3 (integração) e §4 (e2e) passam a exigir explicitamente que fluxo
  que notifica asserte a notificação **lendo do sink**; §4 (seeds/personas) da `execucao.md` ancora o
  endereço das personas no §5.

## [0.1.0] — 2026-08-18

Primeira versão da skill de **Q.A. / Quality Assurance** da casa — a disciplina inteira de teste,
extraída da `schematize-engineering` (references `testes.md` + `testes-execucao.md` e o comando
`/eng-qa`) pra rodar solta e agnóstica de linguagem. A engineering passa a manter só o piso mínimo
("a DoD exige testes verdes") e delega o COMO pra cá.

### Adicionado
- **SKILL.md** com 9 pisos inegociáveis (teste testa comportamento e é visto falhar no vermelho; o
  runner enxerga o teste; cobertura é contrato — não se baixa a régua; smoke prova conteúdo; a11y e
  regressão visual travam; flaky é bug com quarentena; Q.A. é plan-first com aprovação; gate de CI não
  se desliga "por enquanto"; Q.A. é DoD e mora no archive) + mapa de references + fronteiras com
  pentest/audit/data/web.
- **references/**:
  - `estrategia.md` — a pirâmide (unit→componente→integração→e2e) + camadas transversais; teste testa
    **comportamento não "renderizou"** (anti-tautológico, guarda provada no vermelho, runner enxerga);
    **cobertura útil não vaidade** (mínimos por camada + mutation testing); Q.A. como **DoD**; gates de
    CI que travam e não se desligam.
  - `categorias.md` — unit agressivo, componente (comportamento não markup), integração, e2e, **smoke
    "verde de verdade"** (conteúdo + assertion negativa + self-check), **a11y (axe/WCAG 2.2 AA)**,
    **regressão visual**, **contrato** (consumer-driven) e **dados** (expectations/quarentena),
    `simulated` (cobertura total de rota) — com a fronteira explícita: matriz adversarial é da pentest.
  - `flaky.md` — flaky é bug (não "re-roda"); detecção (rodar N×, ordem aleatória, `-race`, CI que
    marca); causas + conserto; **quarentena disciplinada** (prazo+dono, issue, teto, saída provada);
    determinismo por design.
  - `execucao.md` — o **fluxo plan-first** (planejar→MD→aprovação→rodar faseado/de-uma-vez, watchdog,
    destrutivo gated, sem retry infinito); **test kit** + CLI único + saída machine-readable
    (`summary.json`); padrão de script; seeds/personas; **integração com CI** (matriz PR/pré-deploy/
    nightly, gates de teste/a11y/CWV que travam); Makefile.
- **assets/commands/**: `/qa-help`, `/qa-plan` (plan-first, o que era `/eng-qa`), `/qa-run` (executa o
  aprovado), `/qa-load`, `/qa-claude`, `/qa-cc`, `/qa-handoff`.
- **assets/CLAUDE.md** — regra sempre-on: teste testa comportamento e é visto falhar; cobertura é
  contrato; smoke prova conteúdo; a11y/flaky travam; Q.A. é plan-first e DoD.
- **scripts/** (movidos da engineering): `lib.sh`, `test-skeleton.sh`, `smoke-selfcheck.sh`,
  `simulated/run.py`.

### Contexto da extração
- A `schematize-engineering` teve as references `testes.md`/`testes-execucao.md` e o comando `/eng-qa`
  removidos; no lugar ficou um ponteiro curto pra cá + o piso mínimo na DoD. As referências cruzadas
  de teste (`§22.x`) na engineering foram repontadas: teste/cobertura/smoke → `schematize-qa`;
  hardening/pentest/injeção → `schematize-pentest`.
