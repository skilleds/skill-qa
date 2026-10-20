---
description: Gera o handoff de contexto (context.md + checklist.md) no archive, SEM compactar
---

Gere o handoff do Q.A. **sem** compactar — pra fim de sessão ou troca de tarefa:

1. `<projeto>_archive/context/<YYYY-MM-DD-HH-MM-SS>-context.md` — escopo aprovado, camadas/modos
   rodados e resultados (`summary.json`), falhas abertas por categoria, flaky detectado/em quarentena
   (com prazo+dono), gates que travaram, decisões, onde parou.
2. `<projeto>_archive/context/<YYYY-MM-DD-HH-MM-SS>-checklist.md` — **FEITO vs EM ABERTO** (camadas
   testadas vs faltantes; falhas por consertar; gates por passar; veredito parcial).

Não rode `/compact` — só arquiva.
