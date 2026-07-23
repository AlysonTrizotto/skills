# 🧠 Staff+ Skills

**Turn any AI coding agent into a Staff+ engineering peer — automatically.**

Drop this pack into a repository and your AI assistant (Claude Code, Cursor, Windsurf, Antigravity, Copilot, …) **detects the stack on its own** and adopts the right senior-engineer persona, rules, and review checklist for that exact project. No manual file-renaming, no picking a mode by hand — the pack maps itself to your codebase.

> Antes: você escolhia um `.rules` genérico, copiava e renomeava na mão.
> Agora: a IA lê o pacote, descobre a stack, e carrega regras arquiteturais profundas sozinha.

---

## ⚡ Por que "Staff+"? (A Filosofia)

A maioria das regras de sistema tentam transformar a IA em um *gerador de código educado*. O **Staff+ Skills** transforma a IA em um **Revisor Arquitetural Incisivo**. Nós abandonamos o "assistente obediente" em favor do "engenheiro sênior que te desafia".

### 1. Desafiar em vez de obedecer (*Challenge Triggers*)
Cada skill possui gatilhos de desafio estritos. Se você pedir para a IA fazer uma query que causa N+1, ou sugerir um I/O bloqueante na thread principal, a IA é instruída a **parar, recusar a implementação inicial e propor a solução arquiteturalmente correta**.

### 2. Evidence Tags
A IA é forçada a classificar e taggear suas deduções antes de escrever código. Usando tags de escopo global como `[FACT]` e `[ASSUMPTION]`, ou específicas da stack como `[N+1]`, `[CACHE_MISS]` e `[RACE_CONDITION]`, você sabe exatamente *por que* a IA tomou certa decisão.

### 3. Skills Transversais por Intenção (*Cross-cutting*)
Seu projeto pode usar Laravel, mas e se a tarefa atual for configurar um CI/CD ou otimizar o banco? O pacote carrega múltiplas skills: uma para a stack (`backend-laravel`) e outra injetada pela intenção da tarefa (`devops-lean` ou `qa-api-destroyer`). A IA muda a postura dinamicamente.

---

## 📦 O que vem no pacote

```text
staff-plus-skills/
├─ AGENTS.md              ← O ROUTER: detecta a stack e carrega as skills adequadas
├─ install.sh            ← Instala os adaptadores nativos por plataforma
├─ skills/
│  ├─ _TEMPLATE.md         Base para criar novas skills Staff+
│  ├─ architecture-staff/SKILL.md
│  ├─ backend-django/SKILL.md
│  ├─ backend-fastapi/SKILL.md
│  ├─ backend-flask/SKILL.md
│  ├─ backend-hyperf/SKILL.md
│  ├─ backend-laravel/SKILL.md
│  ├─ backend-node/SKILL.md
│  ├─ backend-rails/SKILL.md
│  ├─ code-review-backend/SKILL.md
│  ├─ code-review-frontend/SKILL.md
│  ├─ code-review-mobile/SKILL.md
│  ├─ devops-lean/SKILL.md
│  ├─ engineering-excellence/SKILL.md
│  ├─ frontend-performance/SKILL.md
│  ├─ mobile-resilience/SKILL.md
│  └─ qa-api-destroyer/SKILL.md
└─ adapters/             ← Notas de integração manual por plataforma
```

### Catálogo de Skills

| Domínio | Skill | Foco |
|---|---|---|
| Backend | `backend-django` | The Django Way — ORM perf (select_related), Fat Models, Transações atômicas, DRF |
| Backend | `backend-fastapi` | APIs Python async — Pydantic, DI, cache, logs estruturados |
| Backend | `backend-flask` | Python Micro-services — Application Factory, Blueprints, Explicit Context |
| Backend | `backend-hyperf` | PHP/Swoole coroutine-safe — pooling, statelessness |
| Backend | `backend-laravel` | Laravel idiomático — sem legado/Lumen, cache-first |
| Backend | `backend-node` | Node.js — event loop, streams, async safety, graceful shutdown |
| Backend | `backend-rails` | The Rails Way — MVC, Sidekiq, cache |
| Frontend | `frontend-performance` | Web Vitals (LCP/CLS/INP), a11y, isolamento de render |
| Mobile | `mobile-resilience` | Offline-first, bateria/CPU, disciplina de main-thread |
| DevOps | `devops-lean` | SRE/FinOps — enxuto, imutável, consciente de custo |
| QA | `qa-api-destroyer` | Testes adversariais, carga, idempotência, edge cases (do seu próprio serviço) |
| Review | `code-review-backend` | Code Review Backend — N+1, SQL perf, idempotência, concorrência, contratos de API |
| Review | `code-review-frontend` | Code Review Web Frontend — Web Vitals, re-renders, DOM perf, a11y, bundle bloat |
| Review | `code-review-mobile` | Code Review Mobile — UI main-thread jank, native memory leaks, bateria, offline sync |
| Architecture | `architecture-staff` | Arquitetura de Sistemas — DDD, Event-Driven, Outbox pattern, escolha de DB, ADRs |
| Engineering | `engineering-excellence` | Engenharia & Craftsmanship — SOLID, OpenTelemetry, refatoração, deploys zero-downtime |

---

## 🧭 Como Navegar no Projeto

Se você é novo aqui, recomendamos esta ordem de leitura:
1. **Leia o `AGENTS.md` (A Raiz):** Entenda como a "Matriz de Ativação" descobre a stack e leia o **Contrato Global** que dita a postura fria e pragmática do agente.
2. **Leia a sua Skill (`skills/*/SKILL.md`):** Veja os *Challenge Triggers*, a tabela de Anti-padrões e os Gotchas específicos da sua linguagem.
3. **Leia o `skills/_TEMPLATE.md`:** Se quiser contribuir com uma nova stack, este é o guia de como estruturar o pensamento Staff+.

---

## 🚀 Instalação e Comandos CLI

**Instalação Automática:**

```bash
./install.sh            # Instala / Atualiza todas as regras e skills nas IDEs
./install.sh --update   # Sincroniza regras e limpa skills órfãs (.claude/skills/)
./install.sh --verify   # Valida esquemas YAML, seções obrigatórias e roteador AGENTS.md
./install.sh --git-hook # Instala o hook de pre-commit para validação automática
./install.sh --list     # Exibe o dry-run do que será instalado/atualizado
```

O instalador gera as ligações nativas sem sobrescrever seus arquivos vitais:
- `AGENTS.md` na raiz — router universal (lido pelo Antigravity nativamente e por outros agentes);
- `.cursor/rules/staff-plus.mdc` — Para Cursor;
- `.windsurfrules` — Para Windsurf;
- `.claude/skills/<id>/` — Para Claude Code (auto-invocação por tools).

**Opção B — Manual.** Veja [`adapters/README.md`](adapters/README.md) para colar cada formato à mão, ou caso use outra IDE não mapeada.

Depois de instalar, **recarregue o editor/agente** para ele reler o workspace.

---

## ✅ Anatomia de uma Skill

Cada `SKILL.md` é autossuficiente e inclui:
- **Persona & Escopo** — quando ativa e quando fica de fora;
- **Gatilhos de Desafio** — quando parar e questionar em vez de obedecer;
- **Regras (DO)** — com o *porquê* de forma incisiva;
- **Anti-padrões (DON'T)** → correção mapeada em tabela;
- **Exemplos ❌ → ✅** — com código idiomático real;
- **Checklist de Review** — pronto para PR;
- **Definition of Done**;
- **Armadilhas da Stack** + **Tags de Evidência**.

---

## 📄 Licença

**Licença Comercial Proprietária**

Este software é um produto comercial. É estritamente proibida a cópia, modificação, redistribuição, revenda ou sublicenciamento deste pacote, no todo ou em parte, sem a autorização prévia e por escrito do autor. A licença concedida no ato da compra é intransferível e destinada apenas para o uso da pessoa ou empresa compradora.
