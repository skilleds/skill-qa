---
description: schematize-qa — executa o Q.A. do plano aprovado (faseado/assistido ou de uma vez com watchdog); coleta summary.json e os gates de teste/a11y/CWV
argument-hint: "[caminho do plano aprovado em <projeto>_archive/qa/]"
---

Execute o Q.A. **do plano aprovado** (`references/execucao.md` §1). Se não houver plano aprovado, rode
o `/qa-plan` primeiro — **nada roda sem aprovação registrada**.

## 1. Confirme o contrato
Carregue o plano de `${ARGUMENTS:-<projeto>_archive/qa/<último>}`. Rode **só** os passos aprovados
(aprovação parcial = escopo efetivo). Reconfirme ambiente alvo e os passos marcados **destrutivos**.

## 2. Escolha a modalidade
- **Faseado e assistido** — executa por fase, **pausa entre fases**, mostra o parcial e só segue com o
  "continuar". Default pra staging sensível e qualquer passo destrutivo.
- **De uma vez (autônomo)** — paraleliza categorias independentes (unit/a11y/`simulated`/contrato em
  workers/subagents) respeitando dependências e backpressure; **os subagents executores rodam em `sonnet` por default** (o principal só planeja/revisa; falhou → mesmo subagent corrige ≤2 rodadas → re-decompõe → só então `opus`, com motivo registrado — `schematize-engineering` → `references/orquestracao.md` §9); um **watchdog** retoma de checkpoint
  **idempotente** até concluir. Parada explícita: tudo concluído **ou** falha bloqueante escala pro
  humano. **Sem retry infinito** (`references/flaky.md`).

## 3. Segurança do fluxo
Passo destrutivo (`service-kill`/`db-disconnect`/drop/mutação em massa) **só roda se constava no plano
aprovado** E com o gate de ambiente ligado (ex.: `<PROJECT>_CHAOS_ALLOW=1`) — a aprovação do plano não
dispensa o gate. Autônomo só em dev/staging por default; produção exige confirmação extra no momento.

## 4. Colete e gateie
Agregue o `summary.json` (`references/execucao.md` §2). Aplique os **gates** (`estrategia.md` §5): fail
(`.totals.fail > 0`), a11y vermelho, CWV fora do orçamento ou cobertura abaixo do mínimo **travam**.
Grave o resultado no archive (`<projeto>_archive/qa/`). **NÃO** desligue gate pra destravar — o gate
desligado não volta.
