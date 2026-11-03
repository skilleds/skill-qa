---
description: schematize-qa — cria ou mescla o CLAUDE.md sempre-on de Q.A. na raiz do repo (não sobrescreve blocos de outras skills)
---

Instale/atualize a regra **sempre-on** de Q.A. na raiz do repositório.

1. Pegue `assets/CLAUDE.md` da skill `schematize-qa` (projeto ou `~/.claude/skills/...`).
2. Se **não existe** `CLAUDE.md` na raiz: crie com esse conteúdo.
3. Se **já existe** (de outra skill — engineering/go/rust/web/pentest/audit/...): **mescle** — adicione
   a seção de Q.A. **sem sobrescrever** os blocos das outras skills. Em repo multi-skill, cada bloco
   convive; o piso de Q.A. é aditivo.
4. Se houver customização local, salve `./CLAUDE.md.bak` e reaplique por cima.
5. Confirme a versão aplicada e destaque o **piso**: teste testa comportamento e é visto falhar;
   cobertura é contrato; smoke prova conteúdo; a11y/flaky travam; Q.A. é plan-first e DoD.
