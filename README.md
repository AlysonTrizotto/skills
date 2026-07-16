# 🧠 Staff+ Skills

**Turn any AI coding agent into a Staff+ engineering peer — automatically.**

Drop this pack into a repository and your AI assistant (Claude Code, Cursor, Windsurf,
Copilot, …) **detects the stack on its own** and adopts the right senior-engineer persona,
rules, and review checklist for that exact project. No manual file-renaming, no picking a
mode by hand — the pack maps itself to your codebase.

> Antes: você escolhia um `.rules`, copiava e renomeava na mão.
> Agora: a IA lê o pacote, descobre a stack e carrega a skill certa sozinha.

---

## ⚡ O que muda

| | Rules soltas (antes) | Staff+ Skills (agora) |
|---|---|---|
| Ativação | manual (renomear arquivo) | **automática** (a IA detecta a stack) |
| Profundidade | ~10 linhas de diretrizes | skills de **150-250 linhas**: gatilhos, anti-padrões, exemplos ❌→✅, checklist, DoD |
| Plataforma | 1 IDE por vez | **universal** + adaptadores nativos |
| Multi-stack | uma regra por vez | carrega **várias skills juntas** (ex: Laravel + front-end + DevOps) |
| Consistência | varia por arquivo | um **contrato global** aplicado sobre todas |

---

## 📦 O que vem no pacote

```
staff-plus-skills/
├─ AGENTS.md              ← o ROUTER: detecta a stack e carrega a skill certa
├─ install.sh            ← instala os adaptadores nativos por plataforma
├─ skills/
│  ├─ _TEMPLATE.md         base para criar novas skills
│  ├─ backend-fastapi/SKILL.md
│  ├─ backend-hyperf/SKILL.md
│  ├─ backend-laravel/SKILL.md
│  ├─ backend-rails/SKILL.md
│  ├─ backend-node/SKILL.md
│  ├─ frontend-performance/SKILL.md
│  ├─ mobile-resilience/SKILL.md
│  ├─ devops-lean/SKILL.md
│  └─ qa-api-destroyer/SKILL.md
└─ adapters/             ← notas de integração manual por plataforma
```

### Catálogo de skills

| Domínio | Skill | Foco |
|---|---|---|
| Backend | `backend-fastapi` | APIs Python async — Pydantic, DI, cache, logs estruturados |
| Backend | `backend-hyperf` | PHP/Swoole coroutine-safe — pooling, statelessness |
| Backend | `backend-laravel` | Laravel idiomático — sem legado/Lumen, cache-first |
| Backend | `backend-rails` | The Rails Way — MVC, Sidekiq, cache |
| Backend | `backend-node` | Node.js — event loop, streams, async safety, graceful shutdown |
| Frontend | `frontend-performance` | Web Vitals (LCP/CLS/INP), a11y, isolamento de render |
| Mobile | `mobile-resilience` | Offline-first, bateria/CPU, disciplina de main-thread |
| DevOps | `devops-lean` | SRE/FinOps — enxuto, imutável, consciente de custo |
| QA | `qa-api-destroyer` | Testes adversariais, carga, edge cases (do seu próprio serviço) |

---

## 🚀 Instalação (30 segundos)

**Opção A — automática (recomendada).** Copie a pasta do pacote para a raiz do seu
repositório e rode o instalador:

```bash
cp -r staff-plus-skills/ /caminho/do/seu/repo/
cd /caminho/do/seu/repo
./staff-plus-skills/install.sh
```

O instalador gera, sem sobrescrever seus arquivos:
- `AGENTS.md` na raiz — router universal (lido por qualquer agente de IA);
- `.cursor/rules/staff-plus.mdc` — Cursor;
- `.windsurfrules` — Windsurf;
- `.claude/skills/<id>/` — Claude Code (skills nativas, com auto-invocação).

**Opção B — manual.** Veja [`adapters/README.md`](adapters/README.md) para colar cada
formato à mão.

**Opção C — só o router.** Copie apenas `AGENTS.md` + a pasta `skills/` para a raiz.
Qualquer agente que leia `AGENTS.md` já passa a se auto-mapear.

Depois, **recarregue o editor/agente** para ele reler as regras.

---

## 🧭 Como o auto-mapeamento funciona

1. O agente lê o `AGENTS.md` (o router) ao abrir o repositório.
2. Ele inspeciona os manifestos (`package.json`, `composer.json`, `Gemfile`,
   `pyproject.toml`, `pubspec.yaml`, `Dockerfile`, CI…) e cruza com a **matriz de
   ativação**.
3. Carrega **todas** as skills que casam — inclusive as transversais (`devops-lean`,
   `qa-api-destroyer`), que ativam por intenção da tarefa.
4. Aplica o **Contrato Global** (verdade sobre fluência, terseness, "desafie, não obedeça
   cegamente") por cima de cada skill.

Nada disso pede confirmação: a IA se posiciona sozinha no melhor potencial para o projeto.

---

## 🧩 Estendendo o pacote

Copie [`skills/_TEMPLATE.md`](skills/_TEMPLATE.md), preencha as seções, salve em
`skills/<seu-id>/SKILL.md` e adicione uma linha na matriz de ativação do `AGENTS.md`.
Pronto — a nova skill entra no auto-mapeamento.

---

## ✅ Anatomia de uma skill

Cada `SKILL.md` é autossuficiente e inclui:
- **Persona & escopo** — quando ativa e quando fica de fora;
- **Gatilhos de desafio** — quando parar e questionar em vez de obedecer;
- **Regras (DO)** com o *porquê*;
- **Anti-padrões (DON'T)** → correção, em tabela;
- **Exemplos ❌ → ✅** com código real da stack;
- **Checklist de review** pronto para PR;
- **Definition of Done**;
- **Armadilhas específicas da stack** + **tags de evidência**.

---

## 📄 Licença

Uso comercial. Defina aqui os termos da sua distribuição (licença por equipe, por repo,
etc.). *(placeholder — ajuste antes de publicar.)*
