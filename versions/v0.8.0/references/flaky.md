# Flaky Tests — Detecção, Determinismo e Quarentena

> Parte da skill **schematize-qa**. Teste flaky (passa e falha sem o código mudar) é **bug**, não
> "re-roda". Aqui: por que trava a casa, como detectar, as causas, como tornar determinístico, e a
> quarentena disciplinada — com prazo e dono, nunca silêncio.

## Índice
- 1. Por que flaky é bug (não "re-roda")
- 2. Detecção
- 3. Causas comuns (e o conserto)
- 4. Quarentena disciplinada
- 5. Determinismo por design

---

## 1. Por que flaky é bug (não "re-roda")

Um teste flaky **destrói a confiança na suíte inteira**: se "às vezes falha" é normal, ninguém olha o
vermelho — e o dia em que o vermelho é **real**, ele passa batido. Flaky treina o time a clicar
"re-run" até ficar verde, que é o mesmo que **desligar o teste sem admitir**.

**MUST**
- **Flaky é defeito rastreável**, tratado como bug de prioridade — do **teste** (asserção que casa com
  o vizinho, espera por tempo em vez de condição) **ou** do **código** (corrida real, estado
  compartilhado, dependência de ordem). Corrida detectada por `-race`/flaky **é bug de concorrência**,
  não ruído.
- **VETADO "resolver" flaky com retry infinito** no gate (`jest --retries=99`, re-run automático até
  passar). Retry mascara o sinal e deixa a corrida real em produção. Retry limitado (1–2) só é aceito
  **com** o flaky já em quarentena e issue aberta — nunca como conserto.
- **VETADO** baixar threshold visual/latência "pra parar de piscar" — isso esconde a instabilidade,
  não a remove.

> Um verde que só é verde no terceiro re-run é um vermelho que você decidiu não ver.

---

## 2. Detecção

Não se conserta o que não se mede. A casa **caça** flaky ativamente, não espera ele incomodar.

**MUST**
- **Rodar N vezes** o teste/suíte suspeita (ex.: `--runInBand --repeat 50`, `go test -count=50 -race`,
  `pytest -p no:randomly` vs randomly) e medir a taxa de falha. Taxa > 0 sem causa determinística
  conhecida = flaky confirmado.
- **Ordem aleatória ligada** (`vitest --sequence.shuffle`, `go test -shuffle=on`, `pytest-randomly`):
  teste que só passa numa ordem depende de **estado compartilhado** — bug. A seed da ordem é logada pra
  reproduzir.
- **`-race`/detector de concorrência** sempre no unit/integração (Go `-race`, TS/Node sob carga, thread
  sanitizer onde houver).
- **CI marca e rastreia flaky:** um job que reroda a suíte e **anota** quais testes oscilaram (por
  histórico), abrindo/atualizando a issue. Flaky sem registro vira lenda; flaky rastreado vira dívida
  com dono.

**SHOULD**
- Guardar o **histórico de estabilidade** por teste (pass rate nos últimos N runs) no dashboard, junto
  com `tests_pass_total`/`tests_fail_total` (`execucao.md`). Queda de pass rate = alerta antes de virar
  epidemia.

---

## 3. Causas comuns (e o conserto)

| Causa | Sintoma | Conserto |
|---|---|---|
| **Tempo/`sleep`** | passa na máquina rápida, falha no CI lento | esperar por **condição** (elemento visível, request concluída), nunca `sleep(N)` |
| **Relógio real** | falha à meia-noite, em fuso, no fim do mês | **relógio injetável** (clock fake/`time.Now` mockável); nunca `new Date()` direto no domínio |
| **Ordem/estado compartilhado** | passa isolado, falha na suíte | isolar estado por teste; setup/teardown que **não vaza**; DB/tabela por worker |
| **Rede/serviço real** | falha quando a API externa oscila | mockar a borda; contrato (`categorias.md`) em vez de chamar o real no unit |
| **Envio real (e-mail/SMS/push)** | passa e falha conforme fila/throttle/greylisting do provedor | **sink local** (Mailpit) + asserção pela API do sink (`categorias.md` §9) — determinístico, e ainda cumpre o piso 10 |
| **Concorrência real (corrida)** | falha 1 em 20, sob `-race` sempre | **bug de código** — corrigir a sincronização, não o teste |
| **Aleatoriedade sem seed** | falha com certos dados gerados | **seed fixa e logada**; property-based com shrink pra achar o caso mínimo |
| **Recursos (porta/arquivo/tmp)** | "address in use", "file exists" | recurso único por worker (`nproc`), tmpdir isolado, cleanup idempotente |
| **Animação/fonte não carregada** (visual) | screenshot difere 1px/frame | desligar animação, esperar fontes, viewport/DPR fixos (`categorias.md` §7) |
| **Timezone/locale/encoding** | difere entre dev e CI | fixar `TZ`, `LANG`, locale nos testes |

> Quase todo flaky é uma dependência escondida do teste em algo que **você não controla** — tempo,
> ordem, rede, relógio, sorte. Determinismo é remover essas dependências, não tolerá-las.

---

## 4. Quarentena disciplinada

Quando um flaky **não pode** ser consertado na hora (bug de terceiro, corrida complexa), ele vai pra
**quarentena** — que é dívida com prazo, não um cemitério.

**MUST**
- **Quarentena = isolado do gate BLOQUEANTE, mas ainda rodando.** O teste sai do caminho que trava o
  merge (pra não bloquear o time por um flaky) **mas continua executando** num job não-bloqueante, pra
  não morrer esquecido. Marcar com tag explícita (`@flaky`, `test.fixme`, `//go:build flaky`).
- **Issue rastreável com DONO e PRAZO.** Toda entrada em quarentena abre issue: qual teste, por que é
  flaky (hipótese), dono, prazo de saneamento. Sem dono e prazo, **não entra** — vira `skip`
  disfarçado.
- **Teto de quarentena.** Um limite de testes em quarentena por suíte (ex.: N); estourou = **para a
  linha** e sana antes de adicionar mais. Quarentena que só cresce é a suíte apodrecendo devagar.
- **Saída = conserto provado, não `-u`.** O teste sai da quarentena quando roda **estável N× seguidas**
  (mesma prova do red-first ao contrário: provar que **não** falha mais), não quando "parou de reclamar".

**VETADO**
- `.skip`/`xit`/`t.Skip` **permanente sem issue** — isso é apagar o teste com passo extra.
- Deixar em quarentena **caminho crítico** (auth/pagamento/authz/dados): flaky em caminho crítico é
  prioridade de conserto, não candidato a quarentena de longo prazo.

> Quarentena é a UTI do teste, não a cova. Entra com prontuário (issue + dono + prazo) e sai curado
> (estável, provado) — ou o médico (o dono) responde por que ainda está lá.

---

## 5. Determinismo por design

O melhor flaky é o que nunca existe. Escreva teste determinístico desde o início:

- **Sem `sleep`** — espere por condição/evento observável.
- **Relógio, aleatoriedade e IDs injetáveis** — o domínio recebe `clock`/`rng`/`idgen`; o teste passa
  fakes fixos. Nada de `Date.now()`/`rand()`/`uuid()` direto em código testável.
- **Estado isolado por teste** — cada teste cria e destrói o seu; sem "o teste A deixa o user que o
  teste B usa". DB/schema/tabela por worker; tmpdir por teste.
- **Rede mockada na borda** — o unit não fala com a internet; a integração fala com dependência
  **controlada** (container efêmero, seed conhecido). **Efeito externo (e-mail/SMS/push/webhook) vai
  pro sink**, nunca pro provedor real: além do piso 10 (reputação), o provedor real é rede alheia —
  fila, throttle, latência — e portanto flaky por construção; o sink responde por API e é determinístico.
- **Ambiente fixado** — `TZ`, `LANG`, locale, viewport, DPR, fontes: tudo declarado, nada herdado da
  máquina.
- **Ordem irrelevante por construção** — se embaralhar a ordem quebra, o acoplamento é o bug; conserte
  o acoplamento, não fixe a ordem.

> Determinismo não é sorte de máquina rápida; é design. Um teste que depende do relógio, da ordem ou da
> rede **vai** piscar — a única questão é em qual deploy.
