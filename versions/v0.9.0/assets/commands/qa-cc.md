---
description: Context Compact — gera handoff (context.md + checklist.md) no <projeto>_archive e compacta
---

Antes de compactar, **arquive o handoff** (não perca o estado do Q.A.):

1. `<projeto>_archive/context/<YYYY-MM-DD-HH-MM-SS>-context.md` — estado: plano de Q.A. em curso (qual
   escopo aprovado), camadas/modos já rodados e resultados (`summary.json`), falhas abertas (por
   categoria), flaky detectado/em quarentena, gates que travaram, onde parou.
2. `<projeto>_archive/context/<YYYY-MM-DD-HH-MM-SS>-checklist.md` — **FEITO vs EM ABERTO** (camadas
   testadas vs faltantes; falhas por consertar; gates por passar).
3. Só então rode `/compact` (foco na tarefa corrente).
