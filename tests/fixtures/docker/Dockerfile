# Minimal Dockerfile fixture — used by CI integration tests (docker-build.yml)
# Used with push: false and scan-after-build: false for dry-run smoke test
FROM alpine:3.22
RUN adduser -D appuser
USER appuser
CMD ["echo", "ok"]
