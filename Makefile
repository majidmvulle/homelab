.PHONY: help signoz-delete

SIGNOZ_APP_PATH ?= platform/observability/signoz/app.yaml
ARGOCD_NS ?= argocd
SIGNOZ_NS ?= observability

help:
	@echo "Available targets:"
	@echo "  make signoz-delete   Force-complete stuck Signoz deletion (after desired state removal)"

signoz-delete:
	@set -euo pipefail; \
	if [ -f "$(SIGNOZ_APP_PATH)" ] && [ "$${FORCE:-0}" != "1" ]; then \
		echo "ERROR: $(SIGNOZ_APP_PATH) still exists."; \
		echo "Remove Signoz from desired state first, or run FORCE=1 for emergency cleanup."; \
		exit 1; \
	fi; \
	echo "Clearing Signoz ClickHouseInstallation finalizer (if present)..."; \
	kubectl -n "$(SIGNOZ_NS)" patch clickhouseinstallation signoz-clickhouse --type merge -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true; \
	echo "Clearing ArgoCD Application finalizer (if present)..."; \
	kubectl -n "$(ARGOCD_NS)" patch application signoz --type merge -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true; \
	echo "Status:"; \
	kubectl -n "$(ARGOCD_NS)" get application signoz 2>/dev/null || echo "Application signoz not found in $(ARGOCD_NS)."; \
	kubectl -n "$(SIGNOZ_NS)" get clickhouseinstallation signoz-clickhouse 2>/dev/null || echo "ClickHouseInstallation signoz-clickhouse not found in $(SIGNOZ_NS)."
