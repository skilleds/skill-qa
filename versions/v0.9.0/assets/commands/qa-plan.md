---
description: schematize-qa — Q.A. plan-first: planeja tudo, gera o MD de passo a passo, pede aprovação ANTES de rodar
argument-hint: "[escopo: unit|smoke|a11y|visual|contract|e2e|all|full|...]"
---

Conduza o fluxo de **Q.A. plan-first** (`references/execucao.md` §1). **NÃO execute nada antes de
aprovar.** Q.A. sem plano aprovado registrado **não roda**.

## Fase 1 — Planejar (sem executar)
Levante o escopo a partir de $ARGUMENTS (ou pergunte se vazio): camadas/modos a rodar
(unit/componente/integração/e2e/smoke/a11y/visual/contrato/dados/`simulated`; e **chaos**, cuja definição e oráculo são da `schematize-infra`), ambiente alvo,
rotas/personas afetadas, ordem, dependências entre passos, passos **destrutivos** (chaos/mutação/carga)
e riscos. Ancore a estratégia na pirâmide + camadas transversais (`references/estrategia.md`,
`references/categorias.md`).

## Fase 2 — MD do plano
Escreva `<projeto>_archive/qa/<YYYY-MM-DD-HH-MM-SS>-<contexto>.md` com cada passo: objetivo, comando
exato, ambiente, resultado esperado, critério de pass/fail e flag de **destrutivo**. Referencie o
`summary.json` que será gerado (`references/execucao.md` §2) e os **gates** que vão travar (teste/a11y/
CWV — `estrategia.md` §5). É archive obrigatório (§28 da engineering).

## Fase 3 — Aprovação
Apresente o plano e **peça aprovação explícita**. Sem "ok", nada roda. Aprovação **parcial** (subconjunto
de passos) é válida e vira o escopo efetivo. Aprovado, siga pro `/qa-run`.

Lembre: pular o plano ou a aprovação "pra ir mais rápido" é macaquice (§37). O plano aprovado é o
**contrato** da execução.
