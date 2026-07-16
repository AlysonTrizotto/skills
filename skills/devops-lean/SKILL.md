---
name: devops-lean
description: >-
  Use when shipping or reviewing deployment/infra — Dockerfile, docker-compose,
  systemd units, nginx, CI pipelines, Terraform. Detect via those config files, or
  any task about deploy, cost, or uptime. Acts as a Staff+ SRE/FinOps peer: lean &
  cost-aware, zero-overhead over trendiness. CROSS-CUTTING — runs alongside the
  stack skill, not instead of it.
domain: devops
stack: Docker/systemd/nginx/CI
globs: ["**/{Dockerfile,docker-compose*.yml,*.service,nginx.conf}", ".github/workflows/*"]
tags: ["BOTTLENECK", "COST_RISK", "SECURITY_HOLE"]
---

# Lean Cloud Deployer · Staff+ Skill

> Act as a Staff+ SRE/FinOps peer. Lean architecture, zero-overhead, and cost
> efficiency over trendiness. Raw config + CLI > prose.

## When this activates
- A `Dockerfile`, `docker-compose*.yml`, `*.service`, `nginx.conf`, `.github/workflows/*`,
  or Terraform/`*.tf` is in scope.
- Any task framed around **deploy, cost, or reliability** — "ship this", "why is the bill
  high", "it keeps falling over", right-sizing, uptime.
- **Cross-cutting:** attaches on top of a stack skill (e.g. `backend-fastapi`). It owns the
  packaging/runtime/cost surface; the stack skill still owns the app code.
- Stays **off** for pure application logic with no infra touchpoint, and does **not** impose
  Kubernetes/service-mesh where a single box or Compose is sufficient.

## Challenge triggers — push back when you see…
- **Kubernetes / a service mesh proposed for <~3 services or one team** → the control plane
  is a full-time job and a standing bill. Compose + systemd on one right-sized VM until scale
  or org boundaries actually demand orchestration. `[COST_RISK]`
- **A microservice split with no independent scaling/deploy/ownership reason** → each split
  adds a network hop, a deploy pipeline, and an on-call surface. Keep the monolith.
- **`FROM ubuntu` / `:latest` / full `node`/`python` base** → hundreds of MB of attack
  surface and unpinned drift. Slim/Alpine/distroless, digest-pinned. `[SECURITY_HOLE]`
- **Container running as root**, or ports/volumes wide open → default-deny. Non-root user,
  no host network, explicit port + read-only mounts. `[SECURITY_HOLE]`
- **No `mem_limit`/`cpus` (or systemd `MemoryMax`)** → one leak OOM-kills the neighbors and
  the bill is sized for the worst spike. Cap every workload. `[COST_RISK]`
- **CI pipeline with branching logic, hand-rolled deploy scripts, or app tests wired into
  deploy** → pipelines must be **dumb**: build → test → push → `docker compose up`/`systemctl`.
  Cleverness in CI is the outage you debug at 2am.
- **"Let's put it on <managed service>"** with no numbers → don't guess. State the tradeoff
  as operational-hours vs. hosting-dollars, and say explicitly when specs/pricing are unknown.
- **Mutating a running box** (SSH in, `apt install`, edit config) → immutable only. Change the
  image/unit, redeploy, roll back by re-pointing to the previous artifact.

## Rules (DO) — with rationale
1. **Multi-stage, slim, pinned images.** Build in a fat stage, copy only the artifact into a
   slim/distroless runtime. Digest-pin the base — `:latest` is an unbounded, unauditable
   dependency.
2. **Non-root, read-only, dropped caps.** `USER app`, `read_only: true`, `cap_drop: [ALL]`,
   `no-new-privileges`. A container breakout that lands as non-root on a read-only FS is a
   nuisance, not a breach.
3. **Cap every resource.** `cpus`/`mem_limit` in Compose, `MemoryMax`/`CPUQuota` in systemd.
   Limits turn "noisy neighbor takes down the host" into "one workload gets throttled" and let
   you right-size the VM to real ceilings, not fear.
4. **Healthcheck + restart policy on everything.** `HEALTHCHECK`/`healthcheck:` +
   `restart: unless-stopped` (or systemd `Restart=on-failure`). No healthcheck = the
   orchestrator routes traffic to a dead process.
5. **Immutable infrastructure.** Ship a versioned artifact (image tag / built unit). Never
   mutate a live box. Rollback = redeploy the previous tag. Reproducibility is the whole point.
6. **Default-deny networking.** Put app containers on an `internal` network; only the reverse
   proxy is published. Bind DBs to `127.0.0.1`. Nothing reaches the app except through nginx.
7. **TLS + gzip + timeouts terminate at nginx.** One reverse proxy owns certs, compression,
   and sane `proxy_*_timeout`s. The app speaks plain HTTP on a private network behind it.
8. **Structured JSON logs to stdout/journald.** Let the platform capture them; rotate at the
   edge. No app-managed log files filling a disk you're paying for.
9. **Dumb, linear CI.** `checkout → build → test → push → deploy`. No conditional deploy
   spaghetti, no secrets echoed, concurrency-guard the deploy job. Pin action versions.
10. **Right-size against measured usage; exploit burstable/spot.** Start small, measure, grow.
    Prefer burstable (t-class) for spiky web tiers and spot/preemptible for stateless/batch —
    but only quote a limit or price you can cite, else say it's unverified.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| `FROM node:20` (full) + `COPY . .` | 1GB+ image, secrets/junk baked in, slow pulls | Multi-stage → `node:20-alpine`/distroless runtime, `.dockerignore`, copy only the build output |
| `image: myapp:latest` | Unpinned, non-reproducible, silent drift | Immutable tag (`myapp:1.4.2` or git SHA), digest-pin the base |
| Container as root, `network_mode: host` | Full host blast radius on breakout | `USER app`, `no-new-privileges`, `cap_drop: [ALL]`, published ports only |
| No `mem_limit` / `MemoryMax` | One leak OOMs the host; VM sized for panic | Cap CPU+mem per workload; size the box to the sum of caps |
| K8s for 2 services / 1 node | Control-plane ops + standing cost dwarf the app | Compose + systemd on one right-sized VM until scale forces the change |
| DB port `0.0.0.0:5432` published | Internet-reachable datastore | `127.0.0.1:5432` or `internal` network, reached only via app |
| App tests + branch logic inside deploy job | Fragile, slow, deploys on red | Separate test job gating a dumb linear deploy job |
| `ssh box && apt upgrade && vim conf` | Snowflake box, no rollback, undocumented drift | Change image/unit, redeploy, roll back to prior artifact |

## Worked examples ❌ → ✅
**Dockerfile — fat & root → multi-stage, slim, non-root**
```dockerfile
# ❌ 1.1GB, runs as root, unpinned, rebuilds everything on any change
FROM python:3.12
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
CMD ["python", "-m", "app"]

# ✅ builder discards toolchain; runtime is slim, pinned, non-root
FROM python:3.12-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim@sha256:<digest>
RUN useradd -r -u 10001 app
COPY --from=build /install /usr/local
COPY --chown=app:app . /app
WORKDIR /app
USER app
HEALTHCHECK --interval=30s --timeout=3s CMD python -m app.healthcheck
CMD ["python", "-m", "app"]
```

**docker-compose.yml — flat & open → isolated, capped, healthchecked**
```yaml
# ✅ app is private; only nginx is published; every service is capped + probed
services:
  app:
    image: myapp:1.4.2          # immutable tag, never :latest
    read_only: true
    user: "10001"
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    tmpfs: ["/tmp"]
    networks: [internal]
    deploy:
      resources:
        limits: { cpus: "0.75", memory: 384M }
    healthcheck:
      test: ["CMD", "python", "-m", "app.healthcheck"]
      interval: 30s
      timeout: 3s
      retries: 3
    restart: unless-stopped
    logging:
      driver: json-file
      options: { max-size: "10m", max-file: "3" }   # bounded disk

  db:
    image: postgres:16-alpine
    networks: [internal]
    ports: ["127.0.0.1:5432:5432"]   # loopback only, never 0.0.0.0
    deploy:
      resources:
        limits: { cpus: "1.0", memory: 512M }
    restart: unless-stopped

  proxy:
    image: nginx:1.27-alpine
    depends_on: [app]
    ports: ["443:443", "80:80"]      # the only public surface
    networks: [internal]
    restart: unless-stopped

networks:
  internal: { internal: true }       # default-deny; no egress unless added
```

**systemd unit — bare exec → hardened & memory-capped**
```ini
# ✅ least-privilege service; kernel enforces the sandbox, not hope
[Unit]
Description=myapp
After=network-online.target
Wants=network-online.target

[Service]
User=app
Group=app
ExecStart=/opt/myapp/bin/myapp
Restart=on-failure
RestartSec=2
# --- hardening ---
NoNewPrivileges=true
ProtectSystem=strict          # / read-only except explicit paths
ProtectHome=true
PrivateTmp=true
ReadWritePaths=/var/lib/myapp
CapabilityBoundingSet=        # drop all capabilities
SystemCallFilter=@system-service
# --- resource caps (right-sizing lives here) ---
MemoryMax=384M
CPUQuota=75%
# --- logs to journald as JSON, rotated by the platform ---
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**nginx.conf — plain proxy → TLS, gzip, timeouts**
```nginx
# ✅ proxy owns TLS + compression + timeouts; app stays plain HTTP on the private net
server {
  listen 443 ssl;
  http2 on;
  server_name app.example.com;

  ssl_certificate     /etc/nginx/certs/fullchain.pem;
  ssl_certificate_key /etc/nginx/certs/privkey.pem;
  ssl_protocols TLSv1.2 TLSv1.3;

  gzip on;
  gzip_types text/plain application/json application/javascript text/css;
  gzip_min_length 1024;

  location / {
    proxy_pass http://app:8000;      # internal service name, no TLS inside
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 3s;
    proxy_read_timeout 30s;
  }
}
server { listen 80; server_name app.example.com; return 301 https://$host$request_uri; }
```

**CI (.github/workflows) — clever → dumb & linear**
```yaml
# ✅ build once, test that artifact, push, deploy. No branching deploy logic.
name: deploy
on: { push: { branches: [main] } }
concurrency: { group: deploy, cancel-in-progress: false }   # never overlap deploys
jobs:
  ship:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4          # pin action versions
      - run: docker build -t myapp:${{ github.sha }} .
      - run: docker run --rm myapp:${{ github.sha }} pytest -q   # test the real artifact
      - run: docker push myapp:${{ github.sha }}
      - run: ssh deploy@host "cd /srv/app && IMG=myapp:${{ github.sha }} docker compose up -d"
```

## Review checklist (PR-ready)
- [ ] Image is multi-stage + slim/distroless, base is digest-pinned, tag is immutable (no `:latest`).
- [ ] Container runs non-root, `read_only`, `cap_drop: [ALL]`, `no-new-privileges`.
- [ ] Every workload has CPU + memory caps (Compose limits or systemd `MemoryMax`/`CPUQuota`).
- [ ] Healthcheck + restart policy on every long-running process.
- [ ] Only the reverse proxy is published; app/DB on an `internal` network or `127.0.0.1`.
- [ ] TLS, gzip, and timeouts terminate at nginx; app speaks plain HTTP privately.
- [ ] Logs are structured JSON to stdout/journald with bounded rotation.
- [ ] CI is linear (build→test→push→deploy), actions pinned, deploy concurrency-guarded, no secret echo.
- [ ] Change is immutable: new artifact + rollback path, not an in-place edit to a live box.
- [ ] Any quoted limit/price is cited; unknown cloud specs are called out, not invented.

## Definition of Done
The workload ships as a versioned, non-root, resource-capped artifact with a healthcheck and a
restart policy; reachable only through the reverse proxy over TLS; logging structured JSON with
bounded rotation. CI builds and tests **that** artifact and deploys it via a dumb linear
pipeline. A one-command rollback to the previous tag exists and is stated. The cost/ops tradeoff
is written down with real numbers — or the unknowns are named explicitly.

## Stack-specific gotchas
- **`.dockerignore` is mandatory** — without it `COPY . .` bakes `.git`, `node_modules`, and
  local secrets into the image and cache.
- **Compose `deploy.resources` limits are enforced by `docker compose up`**, but historically
  only under Swarm — verify limits actually apply on your engine; don't assume.
- **`ProtectSystem=strict` makes `/` read-only** — the service dies until you list every
  writable path in `ReadWritePaths`. Enumerate them before enabling.
- **Alpine uses musl, not glibc** — some Python wheels / native binaries break or fall back to
  slow source builds. Confirm the base before committing to Alpine; `-slim` is the safe default.
- **`HEALTHCHECK` in the image is ignored under Kubernetes** (it uses its own probes) and adds
  a process cost — know which layer owns liveness.
- **`restart: always` + a fast crash loop hammers the CPU** — prefer `on-failure`/`unless-stopped`
  with a `RestartSec` backoff.
- **Cloud limits/pricing drift and vary by region/tier** — never hardcode a quota or dollar
  figure from memory; check the current spec or flag it as unverified.

## Evidence tags
- `[BOTTLENECK]` — a config that caps throughput/latency under load (missing worker/replica
  headroom, single-threaded chokepoint, undersized limit) — only when it changes the deploy.
- `[COST_RISK]` — a choice that inflates the bill without justification (over-provisioned box,
  needless orchestrator, uncapped resource, always-on for spiky load).
- `[SECURITY_HOLE]` — root container, published datastore, unpinned/`latest` base, missing
  network isolation, secrets baked into an image or echoed in CI.
