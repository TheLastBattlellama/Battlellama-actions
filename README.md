# TheLastBattlellama SDK (Actions)

Welcome to the **Battlellama Platform SDK**. This repository hosts the central, enterprise-grade reusable GitHub Actions Workflows used across the entire ecosystem. 

By centralizing CI logic into reusable templates, we enforce a strict **Zero-Trust Security Model** across all multi-tenant applications deployed to our GitOps infrastructure (ArgoCD).

## Overview

This repository provides highly opinionated pipelines that standardize checking, building, and publishing containerized applications.

### 🛡️ 1. DevSecOps: Static Audit (`reusable-security-scan.yml`)
Runs robust security scanners natively within the pull request / commit timeline to prevent vulnerabilities from ever reaching infrastructure.
- **[Gitleaks]**: Deep history scans protecting against accidentally committed secrets, API keys, or infrastructure tokens.
- **[Trivy]**: Filesystem vulnerability scanner halting the build (`exit-code: 1`) if `CRITICAL` or `HIGH` vulnerabilities are found in the project's dependencies or base images.

### 📦 2. Cloud Builder (`reusable-docker-build-push.yml`)
An ephemeral OCI builder hooked natively to the GitHub Container Registry (GHCR). 
- Leverages native `gha` docker cache bindings to heavily compress build times.
- Establishes automated precise tagging (`sha...long`) mandatory for continuous delivery via ArgoCD Image Updater.
- Relies exclusively on short-lived, permission-bound GitHub tokens (`secrets: inherit`) rather than persistent service account passwords.

---

## 🚀 How to Use (For Tenant Apps)

To use the Battlellama SDK, applications simply need to create a workflow file (e.g. `.github/workflows/deploy.yml`) and reference these reusable actions. 

### Basic Usage Example (NodeJS/Python/etc Frontend & Backend)

```yaml
name: "🏗️ CI/CD: My Awesome App"

on:
  push:
    branches: [ "main" ]

jobs:
  # 1. Enforce Base Security Rules (Obligatory)
  security-check:
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/reusable-security-scan.yml@main

  # 2. Build & Deploy to Registry (Depends on security passing)
  build-and-publish:
    needs: security-check
    uses: TheLastBattlellama/Battlellama-actions/.github/workflows/reusable-docker-build-push.yml@main
    with:
      image-name: "my-awesome-app"       # Output image name required
      dockerfile-path: "./Dockerfile"    # (Optional) Defaults to "."
      build-context: "."                 # (Optional) Defaults to "."
    secrets: inherit                     # Passes temporary auth context to publish the image
```

*Note: For the build action to work correctly, ensure the calling repository configuration allows GitHub Actions to read and write to Packages (GHCR).*
