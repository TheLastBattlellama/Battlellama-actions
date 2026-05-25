# ─────────────────────────────────────────────────────────────────────────────
# security-scanner — Gitleaks + Trivy + Semgrep, version-pinned
#
# Build:  docker build -t security-scanner .
# Run:    docker run --rm -v $(pwd):/project security-scanner --all
#
# Update versions below when new releases are available:
#   gitleaks → https://github.com/gitleaks/gitleaks/releases
#   trivy    → https://github.com/aquasecurity/trivy/releases
#   semgrep  → https://pypi.org/project/semgrep/#history
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:3.20

ARG GITLEAKS_VERSION=8.21.2
ARG TRIVY_VERSION=0.52.2
ARG SEMGREP_VERSION=1.78.0

# ── System dependencies ───────────────────────────────────────────────────────
RUN apk add --no-cache \
        bash \
        curl \
        git \
        python3 \
        py3-pip \
        ca-certificates

# ── Gitleaks ──────────────────────────────────────────────────────────────────
RUN ARCH="$(uname -m)" && \
    case "$ARCH" in \
        x86_64)  GL_ARCH="x64" ;; \
        aarch64) GL_ARCH="arm64" ;; \
        *) echo "Unsupported arch: $ARCH" >&2 && exit 1 ;; \
    esac && \
    curl -sSL \
        "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GL_ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin gitleaks && \
    chmod +x /usr/local/bin/gitleaks

# ── Trivy ─────────────────────────────────────────────────────────────────────
RUN ARCH="$(uname -m)" && \
    case "$ARCH" in \
        x86_64)  TV_ARCH="64bit" ;; \
        aarch64) TV_ARCH="ARM64" ;; \
        *) echo "Unsupported arch: $ARCH" >&2 && exit 1 ;; \
    esac && \
    curl -sSL \
        "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TV_ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin trivy && \
    chmod +x /usr/local/bin/trivy

# ── Semgrep (isolated venv to avoid PEP 668 conflicts) ───────────────────────
RUN python3 -m venv /opt/semgrep && \
    /opt/semgrep/bin/pip install --no-cache-dir "semgrep==${SEMGREP_VERSION}"

ENV PATH="/opt/semgrep/bin:$PATH"

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /project
ENTRYPOINT ["/entrypoint.sh"]
