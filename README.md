# 🦙 Battlellama Actions

Modular, security-first GitHub Actions workflows for building, scanning, and shipping containerized applications.

**Pick the modules you need. Compose your pipeline. Ship with confidence.**

## Modules

### Core (language-agnostic)

| Module | File | Purpose |
|---|---|---|
| 🛡️ **Security Scan** | `security-scan.yml` | Gitleaks (secrets) + Trivy FS (dependencies) |
| 📦 **Docker Build** | `docker-build.yml` | Build, tag, push to GHCR + image CVE scan |
| 🛡️ **IaC Scan** | `iac-scan.yml` | Trivy Config for K8s/Terraform misconfigurations |

### SAST (language-specific)

| Module | File | Frameworks |
|---|---|---|
| 🐍 **SAST Python** | `sast-python.yml` | Django · FastAPI · Flask |
| ⚛️ **SAST JavaScript** | `sast-javascript.yml` | React · Next.js · Express |

> **Composable**: Each module is independent. Use only what you need.

---

## Quick Start

### Minimal — just secrets + dependencies

```yaml
jobs:
  security:
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/security-scan.yml@main
```

### React + Django fullstack

```yaml
jobs:
  security:
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/security-scan.yml@main

  sast-backend:
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/sast-python.yml@main
    with:
      framework: "django"

  sast-frontend:
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/sast-javascript.yml@main
    with:
      framework: "react"

  build:
    needs: [security, sast-backend, sast-frontend]
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/docker-build.yml@main
    with:
      image-name: "my-app"
    secrets: inherit
```

### React + FastAPI fullstack

```yaml
jobs:
  security:
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/security-scan.yml@main

  sast-backend:
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/sast-python.yml@main
    with:
      framework: "fastapi"

  sast-frontend:
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/sast-javascript.yml@main
    with:
      framework: "react"

  build:
    needs: [security, sast-backend, sast-frontend]
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/docker-build.yml@main
    with:
      image-name: "my-app"
    secrets: inherit
```

### GitOps repo (K8s manifests only)

```yaml
jobs:
  iac:
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/iac-scan.yml@main
    with:
      use-kustomize: "true"
```

---

## Module Reference

### 🛡️ Security Scan

Language-agnostic. Scans for leaked secrets and vulnerable dependencies.

| Input | Default | Description |
|---|---|---|
| `severity` | `CRITICAL,HIGH` | Severities to flag |
| `exit-code` | `1` | `1` = blocking, `0` = warning |
| `scan-path` | `.` | Path to scan |
| `gitleaks-enabled` | `true` | Toggle secret scanning |
| `trivy-fs-enabled` | `true` | Toggle dependency scanning |

---

### 📦 Docker Build & Push

Builds, tags, pushes to GHCR, and scans the image for CVEs.

| Input | Default | Description |
|---|---|---|
| `image-name` | **(required)** | Image name (`my-app` → `ghcr.io/<owner>/my-app`) |
| `dockerfile-path` | `./Dockerfile` | Path to Dockerfile |
| `build-context` | `.` | Docker build context |
| `build-args` | `""` | Build arguments (`KEY=VALUE`, one per line) |
| `platforms` | `linux/amd64` | Target platforms |
| `push` | `true` | `false` for dry-run builds |
| `scan-after-build` | `true` | Run Trivy CVE scan on built image |
| `scan-severity` | `CRITICAL,HIGH` | Image scan severity filter |
| `scan-exit-code` | `1` | `1` = fail on CVEs, `0` = warn |

**Auto-generated tags**: `<sha>` · `latest` · `<branch>` · `<semver>`

---

### 🛡️ IaC Scan

Scans Infrastructure as Code for misconfigurations. Supports Kustomize auto-rendering.

| Input | Default | Description |
|---|---|---|
| `scan-path` | `.` | Path to scan (when `use-kustomize` is `false`) |
| `exit-code` | `1` | `1` = blocking, `0` = warning |
| `severity` | `CRITICAL,HIGH` | Severities to flag |
| `skip-files` | `""` | Files to skip |
| `use-kustomize` | `false` | Auto-render `kustomization.yaml` files |
| `kustomize-exclude-dirs` | `""` | Dirs to exclude from rendering |
| `kustomize-mount-template` | `""` | Template dir to mount for path resolution |

---

### 🐍 SAST Python

Semgrep-powered SAST with framework-specific rulesets.

| Input | Default | Description |
|---|---|---|
| `framework` | `generic` | `django` · `fastapi` · `flask` · `generic` |
| `exit-code` | `1` | `1` = blocking, `0` = warning |
| `scan-path` | `.` | Path to scan |
| `extra-rules` | `""` | Additional Semgrep rulesets (comma-separated) |

**Included rulesets**: `p/python` + `p/bandit` + `p/security-audit` + framework-specific rules

---

### ⚛️ SAST JavaScript/TypeScript

Semgrep-powered SAST with framework-specific rulesets.

| Input | Default | Description |
|---|---|---|
| `framework` | `generic` | `react` · `nextjs` · `express` · `generic` |
| `exit-code` | `1` | `1` = blocking, `0` = warning |
| `scan-path` | `.` | Path to scan |
| `extra-rules` | `""` | Additional Semgrep rulesets (comma-separated) |

**Included rulesets**: `p/javascript` + `p/typescript` + `p/security-audit` + framework-specific rules

---

## Design Principles

- **Modular** — Each workflow is independent. Compose what you need.
- **Secure by default** — `exit-code: "1"` blocks the pipeline. Opt out with `"0"`.
- **Zero config** — Sensible defaults. Just call the workflow.
- **Configurable** — Every behavior can be overridden via inputs.
- **Least privilege** — Only `contents: read` + `packages: write` (when pushing).
- **Ephemeral auth** — No persistent tokens. Uses GitHub's OIDC `GITHUB_TOKEN`.
- **Pinned versions** — All third-party actions are version-locked.

## License

MIT
