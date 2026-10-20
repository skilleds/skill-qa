# CLAUDE.md — Q.A. / Quality Assurance da Casa (sempre on)

> Copie para a **raiz do repositório** e ajuste `<project>`. Fica pinado no contexto de toda tarefa e
> garante o piso mesmo quando a skill `schematize-qa` não dispara sozinha. Em repo multi-skill, use
> **junto** com os `CLAUDE.md` das skills de engenharia (rode `/qa-claude` que mescla, sem sobrescrever
> os outros blocos).

## Regra mestre

"Verde" não vale por fé. Um teste só conta quando **testa comportamento** (o que o sistema faz), foi
visto **falhar no vermelho** quando o invariante quebra, e o **runner o enxerga**. A skill
`schematize-qa` rege como se escreve, roda, mede e gateia o teste. Em conflito entre "passou, deixa
assim" e este piso, **o piso vence**. Consulte o reference antes de agir — não trabalhe de memória.

## Pisos inegociáveis (VETADO — sem exceção)

1. **Teste testa COMPORTAMENTO e é visto FALHAR.** "Renderizou/montou", snapshot cego, `expect(true)`,
   mock que devolve o próprio esperado = decoração. Red-first: prove o vermelho antes do verde. O
   runner tem que **coletar** o teste novo (falhe em "no tests found").
2. **Cobertura é CONTRATO.** Editar threshold, `.skip`, comentar assert ou baixar o mínimo pra passar
   o CI é VETADO — conserta o código, não o teste. Line coverage é piso; mutation score é a meta.
3. **Smoke prova CONTEÚDO, não status.** Shape do body + assertion negativa + **self-check que força
   uma falha conhecida**. Smoke que nunca falha está cego.
4. **a11y e regressão visual TRAVAM.** axe/WCAG 2.2 AA (teclado, foco, contraste, nome acessível) e
   diff visual não intencional bloqueiam o merge como qualquer teste vermelho.
5. **Flaky é BUG, não "re-roda".** Detecta, torna determinístico, ou **quarentena com prazo e dono**
   (issue rastreável). Sem retry infinito no gate, sem `.skip` permanente sem issue.
6. **Q.A. é PLAN-FIRST.** Planeja → gera o MD em `<project>_archive/qa/` → **pede aprovação** → só então
   roda (faseado ou de uma vez com watchdog). Passo destrutivo só no plano aprovado E com gate de
   ambiente. Q.A. sem plano aprovado **não roda**.
7. **Teste NUNCA dispara efeito externo real.** Nenhum teste, seed, fixture ou carga faz e-mail/SMS/
   push/webhook/cobrança **chegar em alguém**. Endereço sintético só no **domínio de teste em rota
   nula** (`<papel>+<run-id>-<n>@test.<domain>`, null MX + SPF `-all` + DMARC `p=reject`, ou
   `.test`/`.invalid`/`.example`) — **VETADO** `@gmail.com`/caixa real/domínio de terceiro/e-mail de
   pessoa real (inclusive o seu)/domínio de produção. Provider = **SINK** (Mailpit), **guard DENTRO do
   provider** (destinatário externo + `env != prd` → **erro**, fail-closed) e **cap por execução**
   (`MAIL_MAX_PER_RUN`). **Conferir caixa em teste = LER DO SINK por API**, nunca de caixa real. **O
   guard tem teste que vê o VERMELHO**: tenta `@gmail.com` em hml e **espera a recusa** (sink vazio).
   Carga/seed em massa multiplicam o efeito — cap + sink separam "1.000 contas" de "1.000 e-mails".
   Normativa: `schematize-engineering` → `references/efeitos-externos.md` (piso 18).
8. **Gate de CI trava o merge e NÃO se desliga "por enquanto".** Fail no `summary.json`, a11y vermelho
   ou CWV fora do orçamento travam. `continue-on-error`/`allow_failure`/`--no-verify` pra destravar é
   macaquice — o gate desligado não volta.
9. **Q.A. é parte da DoD e mora no archive.** Todo plano/resultado (`summary.json` + relatório) em
   `<project>_archive/qa/` (§28). Sem archive, o Q.A. não aconteceu.
10. **Toda rota exposta NASCE com matriz de acesso, no CI, em unit/componente.** Para CADA rota do
   inventário (derivado do router/OpenAPI, nunca à mão): 4 personas — anônimo, autenticado não
   privilegiado, privilegiado, tentativas de burla — afirmando status E corpo. Deny-by-default: rota sem
   política falha; pública só na allowlist versionada (justificativa+dono). M == N: rota nova sem linha
   quebra o CI (`scripts/check-route-authz.sh`). Negação não vaza dado (401/403/404; anti-enumeração =
   mesmo corpo de inexistente). Visto VERMELHO antes de valer (tire a checagem do handler). Pentest é
   complementar. Detalhe: `references/categorias.md` §14.
11. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

## Como se testa aqui

- **Pirâmide:** unit (o grosso, agressivo) → componente (comportamento, não markup) → integração (DB/
  credenciais reais) → e2e (jornada, seletor acessível). Teste no **nível mais baixo que ainda enxerga
  o bug**.
- **Camadas transversais:** smoke "verde de verdade", a11y (axe), regressão visual, contrato
  (consumer-driven), dados (expectations/quarentena), property-based, mutation.
- **Plan-first (`/qa-plan`) → executa (`/qa-run`):** faseado/assistido (pausa entre fases) ou de uma
  vez (multiagentes + watchdog que retoma de checkpoint, sem retry infinito).
- **Gates:** PR (smoke+unit+a11y+lint), pré-deploy (`all`+visual+contrato), nightly (`full`+chaos+
  mutation). `summary.json` é o que o gate lê — inclusive `external_effects.*.real_sent == 0`.
- **Notificação em teste:** limpa o sink → dispara a ação → espera por condição (nunca `sleep`) → lê a
  mensagem por destinatário na API do sink → asserta conteúdo do template + assertion negativa (sem
  `{{`/`${`/`undefined`, sem segredo, link do host certo).

## Relação com as outras skills

- **schematize-engineering** — a base: **exige** teste (DoD §35, archive §28) e delega o **COMO** pra
  esta skill. O piso "a DoD exige testes verdes" fica lá; a estratégia/categorias/flaky/cobertura/
  plan-first ficam aqui.
- **schematize-pentest** — **segurança ofensiva** (rejeição rota-por-rota, injeção/coerção, IDOR/BOLA,
  cross-tenant, red-team) é **lá**. Q.A. prova que o sistema faz o certo; a pentest, que rejeita o errado.
- **schematize-audit** — **auditoria de histórico** ("os checklists foram sanados?") é lá; ela consome a
  evidência que o Q.A. gera pra promover "feito" de suspeito a fato.
- **schematize-data / web** — testes de **dados** (expectations/quarentena) e de **frontend** (a11y,
  visual, componente) casam com o piso dessas skills.

## Gestão de contexto (sessões longas)

Ao se aproximar do teto de contexto: **PARE e** gere o handoff em `<project>_archive/context/` (estado
+ FEITO vs EM ABERTO do Q.A.) **antes** de compactar (`/qa-cc`).
