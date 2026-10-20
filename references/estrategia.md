# Estratégia de Teste, Pirâmide, Cobertura Útil e DoD

> Parte da skill **schematize-qa**. A **estratégia**: por que se testa, em que proporção, o que conta
> como teste de verdade, quanto cobrir, e como o Q.A. entra na Definition of Done e nos gates de CI.
> Detalhe por categoria em `categorias.md`; flaky em `flaky.md`; execução/plan-first em `execucao.md`.

## Índice
- 1. A pirâmide de testes (e as camadas transversais)
- 2. O que é um teste de verdade (comportamento, não "renderizou")
- 3. Cobertura útil, não vaidade
- 4. Q.A. como parte da Definition of Done
- 5. Gates de CI que travam o merge

---

## 1. A pirâmide de testes (e as camadas transversais)

Testar não é "escrever muitos testes"; é **distribuir** o esforço onde ele paga. A pirâmide é a forma
da casa:

```
              ╱╲        e2e / jornada      — poucos, caros, lentos, alto valor de confiança
             ╱  ╲       (Playwright/Cypress)
            ╱────╲      integração         — fluxos ponta-a-ponta com credenciais/DB reais
           ╱      ╲     (login real + CRUD)
          ╱────────╲    componente         — 1 unidade de UI/serviço + suas dependências próximas
         ╱          ╲   (render + interação real)
        ╱────────────╲  unit               — muitos, rápidos, isolados; o grosso da malha
       ╱______________╲ (domínio, validadores, parsers)
```

**Regra de proporção (heurística, não dogma):** a base (unit) é a maior fatia; sobe-se de camada
**só quando a de baixo não consegue provar o invariante**. Testar no e2e o que um unit provaria é
lento e frágil; testar no unit o que só a integração revela (o SQL real, o contrato do broker) é
ilusão de cobertura. **Teste no nível mais baixo que ainda enxerga o bug.**

**Camadas transversais** (cortam a pirâmide inteira, não são um "andar"):

| Camada | O que prova | Nível onde roda |
|---|---|---|
| **smoke** | o sistema **sobe e responde com conteúdo certo** (não só 200) | pós-deploy, todo ambiente |
| **a11y** | acessibilidade WCAG 2.2 AA (teclado, foco, contraste, nome acessível) | componente + e2e |
| **regressão visual** | a UI não mudou de aparência sem intenção | componente + e2e |
| **contrato** | produtor e consumidor concordam no shape (consumer-driven) | integração |
| **dados** | o dado que entra/sai satisfaz expectations; dado ruim é quarentenado | integração + pipeline |
| **property-based** | invariantes valem pra **todo** input, não só os do exemplo (procedimento e limiar: `categorias.md` §11) | unit + domínio |
| **mutation** | os testes **pegam** um bug injetado (mede o que verificam; score ≥ 80% no domínio crítico — `categorias.md` §12) | domínio crítico |
| **carga/perf** | o SLO se sustenta na carga real, e a cauda (p95/p99) não estourou (`categorias.md` §13) | integração + e2e |

Detalhe de cada uma em `categorias.md`.

> A pirâmide diz **onde** testar. As camadas transversais dizem **o que mais** provar além do caminho
> feliz. Um sistema "coberto" só no unit e sem smoke/a11y/contrato está cego pra classes inteiras de
> falha.

---

## 2. O que é um teste de verdade (comportamento, não "renderizou")

Um teste vale quando prova **comportamento** — o que o sistema **faz** diante de uma entrada — e foi
visto **falhar** quando esse comportamento quebra. Fora disso é decoração.

**MUST — testa comportamento, não estrutura**
- **Assere o efeito observável**, não o detalhe de implementação. "O botão dispara o checkout e o
  carrinho zera" é comportamento; "o componente montou" / "renderizou sem erro" / "o método foi
  chamado" quase nunca é. Teste de UI que só confere que o markup existe passa com a feature quebrada.
- **Snapshot não é asserção.** Snapshot cego (aceito com `-u` sem ninguém ler o diff) vira ruído que
  se atualiza sozinho. Se usar snapshot, é de **saída semântica pequena e revisada**, não da árvore
  DOM inteira.
- **Sem teste tautológico:** assert ausente, `expect(true).toBe(true)`, mock que devolve exatamente o
  que o teste espera de volta, comparar um valor consigo mesmo. Revisão de PR **rejeita**.

**MUST — guarda provada no vermelho (anti "verde mentiroso")**
- **Todo teste/guarda tem que ser visto FALHAR** quando o invariante que ele protege quebra. Um teste
  que passa verde **sem nunca ter reprovado o caso ruim** não é guarda. Escreva-o **red-first** (ou
  quebre o código de propósito uma vez) e **confirme o vermelho**. Bug clássico: a asserção casa com o
  **vizinho** (o array/filtro errado, um regex que bate em outra coisa) e "passa" sem checar nada.
- **O runner tem que ENXERGAR o teste.** Confirme que os arquivos novos são **coletados** — os globs
  de `include` cobrem `*.test.tsx`/`*.test.ts`/`_test.go`/`tests/**`. Suíte verde que rodou **0** dos
  testes novos é falso-verde silencioso: falhe o CI em "no tests found" no caminho novo e/ou asserte a
  **contagem esperada** de casos.
- **Caminho de erro é obrigatório**, não opcional. Pra cada função, teste sucesso **e** falha: input
  inválido, dependência que retorna erro, timeout, nil/null, vazio, boundary, overflow. 80% de
  cobertura só de happy-path é cobertura mentirosa.

> Se você não viu o teste falhar de propósito, você não sabe se ele funciona. "Passou" sem ter podido
> reprovar é a assinatura do verde mentiroso.

---

## 3. Cobertura útil, não vaidade

Cobertura de linha mede o que o teste **executa** — não o que ele **verifica**. É **piso**, nunca meta.

**Cobertura mínima por camada (contrato — não se baixa a régua)**

| Camada | Mínimo |
|---|---|
| `domain` | 80% |
| `application` | 70% |
| `infrastructure` | 40% |
| Global | 60% |

- **O número é contrato.** Editar o threshold, pular teste (`.skip`), comentar um assert ou baixar o
  mínimo pra "passar o CI" é **VETADO**. Sobe-se a cobertura **escrevendo teste**, não mexendo na
  régua. Se o teste está atrapalhando, conserta-se o **código**, não o teste.
- **Caminhos críticos têm testes explícitos** cobrindo sucesso, falha e edge cases — auth, pagamento,
  autorização, billing, eventos de domínio, multi-tenancy — **independente** da cobertura agregada.
  Um caminho crítico com 100% de linha mas só happy-path continua descoberto.

**Mutation testing — a meta real (SHOULD → MUST em domínio crítico)**
- Ferramentas: Stryker (JS/TS), `go-mutesting` (Go), `cargo-mutants` (Rust), `mutant` (Ruby),
  Stryker.NET (C#). Elas **injetam bugs** (trocam `>` por `>=`, removem uma linha, invertem um bool) e
  medem se **algum teste pega**. Mutação que sobrevive = teste decorativo naquela linha.
- **Mutation score mínimo definido por serviço crítico**, não só line coverage. É a rede que pega a
  guarda que não guarda quando o red-first passou batido.

**Cobertura de rota e de endpoint (a vaidade que mais engana)**
- Line coverage alta com **rotas sem smoke/pentest/simulated** é vaidade: o código roda em teste mas
  a superfície de entrada não é exercida. O `simulated` (`categorias.md`) prova que **100% das rotas**
  do inventário respondem como deviam. Rota em produção sem caso = FALHA, não silêncio.

> Cobertura de linha responde "meu teste passou por aqui?". Mutation responde "meu teste **notaria** se
> isto estivesse errado?". Só a segunda pergunta importa.

---

## 4. Q.A. como parte da Definition of Done

Q.A. **não é etapa de fim de sprint** — é gate de entrega. Uma task só está pronta quando, no recorte
de teste, cumulativamente:

- [ ] **Testes passam** (unit + integração), **cobertura nos mínimos** por camada (§3) — sem baixar régua.
- [ ] **Caminhos críticos** (auth/pagamento/authz/billing/eventos/multi-tenancy) com testes explícitos
  de sucesso **e** falha **e** edge.
- [ ] **Teste emulado (`simulated`) executado** — 100% das rotas do inventário acessíveis pra quem deve
  e bloqueadas pra quem não deve; **rota fantasma/morta = bloqueio** (`categorias.md`).
- [ ] **Matriz de acesso por rota verde e completa (M == N)** — toda rota exposta com as 4 personas
  (anônimo, não privilegiado, privilegiado, burla), status **e** corpo, deny-by-default, públicas só na
  allowlist com dono; vista vermelha (`categorias.md` §14, `scripts/check-route-authz.sh`).
- [ ] **Smoke em staging com asserção de CONTEÚDO + self-check** anti verde-mentiroso (`categorias.md`).
- [ ] **a11y (axe/WCAG 2.2 AA) verde** e **regressão visual** sem diff não intencional (onde há UI).
- [ ] **Testes de contrato** verdes entre produtor/consumidor (onde há integração de serviços).
- [ ] **Nenhum teste flaky no gate bloqueante** — flaky está determinístico ou em quarentena com prazo
  e dono (`flaky.md`), nunca silenciado com retry infinito.
- [ ] **Nenhum efeito externo real disparado pelo Q.A.** — provider = sink, todo endereço no domínio de
  teste, cap por execução respeitado, `external_effects.*.real_sent == 0` no `summary.json`; e o
  **guard tem teste que vê o vermelho** (tenta `@gmail.com` em não-prd e **espera a recusa**), com o
  fluxo que notifica assertado **lendo do sink** (`categorias.md` §9, `execucao.md` §5).
- [ ] **Mutation score** no domínio crítico dentro do mínimo definido (serviços críticos).
- [ ] **Plano de Q.A. e resultado** (`summary.json` + relatório) arquivados em `<projeto>_archive/qa/`.

> A DoD completa da entrega (archive §28, anti-padrões §37, índice §39, pentest de rejeição) mora na
> `schematize-engineering` (§35) e na `schematize-pentest`. Esta lista é o **recorte de teste** dela —
> o COMO dos itens que a DoD apenas exige.

---

## 5. Gates de CI que travam o merge

O gate é o que dá **dente** à disciplina. Sem gate, teste é sugestão.

**MUST — o que trava o merge**
- **Fail no `summary.json`** (`.totals.fail > 0`) trava o merge (`execucao.md`).
- **a11y vermelho** (violação axe séria/crítica) trava o merge como qualquer teste.
- **Core Web Vitals (CWV) fora do orçamento** — LCP/INP/CLS acima do budget declarado — trava (onde há
  frontend; casa com o piso de performance da `schematize-web`).
- **Cobertura abaixo do mínimo** (§3) trava.
- **"No tests found"** no caminho novo trava (§2 — o runner tem que enxergar).
- **Efeito externo real fora de prd trava**: `external_effects.*.real_sent > 0` no `summary.json`,
  provider de envio real em job de teste, ou caixa real (`gmail|hotmail|outlook|yahoo|icloud`) em
  `tests/`/`seeds/`/`fixtures/`/`factories/` (`execucao.md` §5 e §6).

**VETADO — o gate NÃO se desliga "temporariamente"**
- Comentar o step de teste, marcar `continue-on-error: true`, `allow_failure`, `--no-verify`, baixar o
  threshold "só nesse PR", ou mover o gate pra nightly "por enquanto" pra destravar um merge é
  **macaquice** (linha da §37 da engineering). O gate desligado **não volta** — vira dívida silenciosa
  que só aparece no incidente.
- Exceção só existe com **ADR de aceite de risco** (dono + prazo de remediação datado) e **nunca** pra
  caminho crítico de segurança/auth/dados. "Depois eu religo" não é ADR.

**SHOULD — feedback rápido**
- PR check roda o rápido (smoke + unit afetado + a11y + lint) em minutos; pré-deploy roda o `all`;
  nightly roda o `full` (inclui **chaos** — definido pela `schematize-infra`, `references/resiliencia.md` §7 —, mutation e carga). Detalhe da matriz em `execucao.md`.
- Falha de smoke **pós-deploy** dispara rollback automático — o gate não é só pré-merge.

> Um gate que se desliga sob pressão nunca esteve ligado. Ou ele trava o merge de verdade, ou é teatro
> de compliance.
