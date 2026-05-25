#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Security Scanner — entrypoint
#
# Usage:
#   docker run --rm -v $(pwd):/project security-scanner [flags]
#
# Scan types (combinable):
#   --secrets           Gitleaks secret scanning
#   --fs                Trivy filesystem / dependency scan
#   --python            Semgrep SAST for Python
#   --javascript        Semgrep SAST for JavaScript/TypeScript
#   --all               All scans + auto-detect stack
#
# Options:
#   --framework <name>  django|fastapi|flask|react|nextjs|express
#   --path <subpath>    Subpath inside /project (default: ".")
#   --severity <lvl>    CRITICAL,HIGH (default) | CRITICAL | MEDIUM | etc.
#   --exit-code <0|1>   0=warn only, 1=block on findings (default: 1)
#   --extra-rules <r>   Additional Semgrep rulesets (comma-separated)
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
RUN_SECRETS=false
RUN_FS=false
RUN_PYTHON=false
RUN_JAVASCRIPT=false
RUN_ALL=false
FRAMEWORK=""
SCAN_PATH="."
SEVERITY="CRITICAL,HIGH"
EXIT_CODE=1
EXTRA_RULES=""

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --secrets)     RUN_SECRETS=true ;;
    --fs)          RUN_FS=true ;;
    --python)      RUN_PYTHON=true ;;
    --javascript)  RUN_JAVASCRIPT=true ;;
    --all)         RUN_ALL=true ;;
    --framework)   FRAMEWORK="$2"; shift ;;
    --path)        SCAN_PATH="$2"; shift ;;
    --severity)    SEVERITY="$2"; shift ;;
    --exit-code)   EXIT_CODE="$2"; shift ;;
    --extra-rules) EXTRA_RULES="$2"; shift ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Run with --help or check the entrypoint header for usage." >&2
      exit 1
      ;;
  esac
  shift
done

# ── Resolve target path ───────────────────────────────────────────────────────
TARGET="/project/${SCAN_PATH}"
TARGET="${TARGET%/}"  # strip trailing slash

if [[ ! -d "$TARGET" ]]; then
  echo "Error: target path does not exist: $TARGET" >&2
  exit 1
fi

# ── Auto-detect for --all ─────────────────────────────────────────────────────
if [[ "$RUN_ALL" == "true" ]]; then
  RUN_SECRETS=true
  RUN_FS=true

  if [[ -f "$TARGET/requirements.txt" || -f "$TARGET/pyproject.toml" ]]; then
    RUN_PYTHON=true
  fi

  if [[ -f "$TARGET/package.json" ]]; then
    RUN_JAVASCRIPT=true
  fi
fi

# ── Validate at least one scan is selected ────────────────────────────────────
if [[ "$RUN_SECRETS" == "false" && "$RUN_FS" == "false" && \
      "$RUN_PYTHON" == "false" && "$RUN_JAVASCRIPT" == "false" ]]; then
  echo "Error: no scan type selected." >&2
  echo "Use --secrets, --fs, --python, --javascript, or --all." >&2
  exit 1
fi

# ── Framework auto-detect ─────────────────────────────────────────────────────
# Independent per language — --framework overrides both if set manually.
PYTHON_FRAMEWORK="$FRAMEWORK"
JS_FRAMEWORK="$FRAMEWORK"

if [[ "$RUN_PYTHON" == "true" && -z "$PYTHON_FRAMEWORK" ]]; then
  if [[ -f "$TARGET/manage.py" ]]; then
    PYTHON_FRAMEWORK="django"
  elif grep -qi "fastapi" "$TARGET/requirements.txt" 2>/dev/null || \
       grep -qi "fastapi" "$TARGET/pyproject.toml" 2>/dev/null; then
    PYTHON_FRAMEWORK="fastapi"
  elif grep -qi "flask" "$TARGET/requirements.txt" 2>/dev/null || \
       grep -qi "flask" "$TARGET/pyproject.toml" 2>/dev/null; then
    PYTHON_FRAMEWORK="flask"
  fi
fi

if [[ "$RUN_JAVASCRIPT" == "true" && -z "$JS_FRAMEWORK" ]]; then
  if grep -q '"next"' "$TARGET/package.json" 2>/dev/null; then
    JS_FRAMEWORK="nextjs"
  elif grep -q '"react"' "$TARGET/package.json" 2>/dev/null; then
    JS_FRAMEWORK="react"
  elif grep -q '"express"' "$TARGET/package.json" 2>/dev/null; then
    JS_FRAMEWORK="express"
  fi
fi

# ── UI helpers ────────────────────────────────────────────────────────────────
FAILED=false
SCANS_RUN=0
SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

header() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# ── Gitleaks ──────────────────────────────────────────────────────────────────
if [[ "$RUN_SECRETS" == "true" ]]; then
  header "🔐 Secret Scanning (Gitleaks)"
  SCANS_RUN=$((SCANS_RUN + 1))

  GITLEAKS_ARGS=(detect --source="$TARGET" --exit-code="$EXIT_CODE" --redact --verbose)
  # Fall back to file scan if target is not a git repo (e.g. mounted subdirectory)
  if [[ ! -d "$TARGET/.git" ]]; then
    GITLEAKS_ARGS+=(--no-git)
  fi

  if ! gitleaks "${GITLEAKS_ARGS[@]}"; then
    FAILED=true
  fi
fi

# ── Trivy ─────────────────────────────────────────────────────────────────────
if [[ "$RUN_FS" == "true" ]]; then
  header "📦 Dependency Scan (Trivy FS)"
  SCANS_RUN=$((SCANS_RUN + 1))

  if ! trivy fs \
      --severity "$SEVERITY" \
      --ignore-unfixed \
      --exit-code "$EXIT_CODE" \
      "$TARGET"; then
    FAILED=true
  fi
fi

# ── Semgrep Python ────────────────────────────────────────────────────────────
if [[ "$RUN_PYTHON" == "true" ]]; then
  header "🐍 Python SAST (Semgrep — framework: ${PYTHON_FRAMEWORK:-generic})"
  SCANS_RUN=$((SCANS_RUN + 1))

  RULES="p/python"
  case "$PYTHON_FRAMEWORK" in
    django)  RULES="$RULES p/django" ;;
    fastapi) RULES="$RULES p/fastapi" ;;
    flask)   RULES="$RULES p/flask" ;;
  esac
  RULES="$RULES p/bandit p/security-audit"

  if [[ -n "$EXTRA_RULES" ]]; then
    IFS=',' read -ra EXTRA_ARRAY <<< "$EXTRA_RULES"
    for rule in "${EXTRA_ARRAY[@]}"; do
      RULES="$RULES $(echo "$rule" | xargs)"
    done
  fi

  SEMGREP_ARGS=()
  for config in $RULES; do
    SEMGREP_ARGS+=(--config "$config")
  done
  [[ "$EXIT_CODE" == "1" ]] && SEMGREP_ARGS+=(--error)

  if ! semgrep scan "${SEMGREP_ARGS[@]}" "$TARGET"; then
    FAILED=true
  fi
fi

# ── Semgrep JavaScript ────────────────────────────────────────────────────────
if [[ "$RUN_JAVASCRIPT" == "true" ]]; then
  header "⚛️  JavaScript/TypeScript SAST (Semgrep — framework: ${JS_FRAMEWORK:-generic})"
  SCANS_RUN=$((SCANS_RUN + 1))

  RULES="p/javascript p/typescript"
  case "$JS_FRAMEWORK" in
    react)   RULES="$RULES p/react" ;;
    nextjs)  RULES="$RULES p/react p/nextjs" ;;
    express) RULES="$RULES p/expressjs" ;;
  esac
  RULES="$RULES p/security-audit"

  if [[ -n "$EXTRA_RULES" ]]; then
    IFS=',' read -ra EXTRA_ARRAY <<< "$EXTRA_RULES"
    for rule in "${EXTRA_ARRAY[@]}"; do
      RULES="$RULES $(echo "$rule" | xargs)"
    done
  fi

  SEMGREP_ARGS=()
  for config in $RULES; do
    SEMGREP_ARGS+=(--config "$config")
  done
  [[ "$EXIT_CODE" == "1" ]] && SEMGREP_ARGS+=(--error)

  if ! semgrep scan "${SEMGREP_ARGS[@]}" "$TARGET"; then
    FAILED=true
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "$SEP"
if [[ "$FAILED" == "true" ]]; then
  echo "  ❌  Scan complete — findings detected  ($SCANS_RUN scan(s) run)"
  echo "$SEP"
  exit 1
else
  echo "  ✅  Scan complete — no issues found  ($SCANS_RUN scan(s) run)"
  echo "$SEP"
fi
