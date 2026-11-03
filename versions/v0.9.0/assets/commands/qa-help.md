---
description: schematize-qa — lista todos os comandos disponíveis e o que cada um faz
---

Liste os comandos do **schematize-qa** instalados (`/qa-*`), com 1 linha cada:

- `/qa-help` — esta lista.
- `/qa-plan` — **plan-first**: levanta o escopo (camadas/modos, ambiente, rotas/personas, passos destrutivos, riscos), gera o MD de passo a passo em `<projeto>_archive/qa/` e **pede aprovação ANTES de rodar**. Nada de Q.A. às cegas.
- `/qa-run` — executa o Q.A. **do plano aprovado**: faseado/assistido (pausa entre fases) ou de uma vez (multiagentes + watchdog que retoma de checkpoint, sem retry infinito); passo destrutivo só com gate; coleta `summary.json` e os gates de teste/a11y/CWV.
- `/qa-load` — carrega à força TODO o corpo normativo (estratégia/pirâmide, categorias, flaky, execução) e passa a aplicá-lo.
- `/qa-claude` — cria ou mescla o `CLAUDE.md` sempre-on de Q.A. na raiz do repo.
- `/qa-cc` — context compact: gera handoff no archive e roda `/compact`.
- `/qa-handoff` — gera o handoff (context.md + checklist.md) sem compactar.

Depois da lista, lembre a **regra de ouro**: *se você não viu o teste falhar de propósito, você não
sabe se ele funciona.* Teste testa **comportamento**, não "renderizou"; cobertura é **contrato** (não
se baixa a régua); smoke prova **conteúdo**, não status; a11y e flaky **travam**; Q.A. é **plan-first**
e roda com aprovação. Detalhe normativo em `references/` da skill `schematize-qa`; a base (DoD/archive/
índice) é a `schematize-engineering`; segurança ofensiva é a `schematize-pentest`.
