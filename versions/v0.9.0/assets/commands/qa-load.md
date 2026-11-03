---
description: schematize-qa — carrega à força TODO o corpo normativo (estratégia/pirâmide, categorias, flaky, execução) e passa a aplicá-lo
---

Carregue **à força** e passe a aplicar **integralmente** os Padrões de Q.A. da Casa (skill
`schematize-qa`) neste projeto. A partir de agora, nesta sessão, isto **não é opcional**.

1. **Leia agora, na íntegra, TODOS os references** — não trabalhe de memória. Caminho:
   `.claude/skills/schematize-qa/references/*.md` (projeto) ou
   `~/.claude/skills/schematize-qa/references/*.md` (global):
   - `estrategia.md` — a **pirâmide** (unit→componente→integração→e2e) + camadas transversais; teste
     testa **comportamento não "renderizou"** (anti-tautológico, guarda provada no vermelho, runner
     enxerga); **cobertura útil não vaidade** (mínimos por camada + mutation); Q.A. como **DoD**; gates
     de CI que travam e não se desligam.
   - `categorias.md` — unit agressivo, componente (comportamento não markup), integração, e2e, **smoke
     "verde de verdade"** (conteúdo + assertion negativa + self-check), **a11y (axe/WCAG 2.2 AA)**,
     **regressão visual**, **contrato/dados**, `simulated` (cobertura total de rota) e a **fronteira**
     com a pentest.
   - `flaky.md` — flaky é **bug** (não "re-roda"); detecção (rodar N×, ordem aleatória, `-race`);
     causas + conserto; **quarentena disciplinada** (prazo+dono, issue, teto); determinismo por design.
   - `execucao.md` — o **fluxo plan-first** (planejar→MD→aprovação→rodar faseado/de-uma-vez, watchdog,
     destrutivo gated, sem retry infinito); **test kit** + CLI + `summary.json`; padrão de script;
     seeds/personas; **integração com CI** (gates de teste/a11y/CWV); Makefile.

2. **Confirme ao usuário** que leu (1 linha por arquivo).

3. Deste ponto, aplique como regra inegociável: **teste testa comportamento e é visto falhar no
   vermelho**, o **runner enxerga o teste**, **cobertura é contrato** (não se baixa a régua), **smoke
   prova conteúdo**, **a11y e regressão visual travam**, **flaky é bug** (quarentena com prazo+dono),
   **Q.A. é plan-first** (roda com aprovação), o **gate de CI não se desliga "por enquanto"**, e todo
   plano/resultado mora em `<projeto>_archive/qa/`.

4. **Atualize o `CLAUDE.md` da raiz** com `assets/CLAUDE.md` da skill (mescla se já houver de outra
   skill) — é o `/qa-claude`.
