
COMPOSE_FILE := docker-compose.yml
OPS := ./scripts/ops.sh

.PHONY: up down status logs smoke clear k8s k8s-down

up:
	$(OPS) up

down:
	$(OPS) down

status:
	$(OPS) status

logs:
	$(OPS) logs

smoke:
	$(OPS) smoke

clear:
	$(OPS) clear
KIND ?= $(shell command -v kind 2>/dev/null || echo $(CURDIR)/bin/kind)

k8s:
	@if [ ! -x "$(KIND)" ]; then \
		mkdir -p $(CURDIR)/bin; \
		case $$(uname -m) in \
			arm64|aarch64) KARCH=arm64 ;; \
			*) KARCH=amd64 ;; \
		esac; \
		docker run --rm -v "$(CURDIR)/bin:/out" curlimages/curl:latest \
			-fsSL -o /out/kind "https://kind.sigs.k8s.io/dl/latest/kind-darwin-$$KARCH"; \
		chmod +x "$(CURDIR)/bin/kind"; \
	fi
	KC=$(CURDIR)/.kubeconfig; \
	KUBECONFIG=$$KC $(KIND) create cluster --name devops-assignment 2>/dev/null || true; \
	docker build -t ghcr.io/alialjaffer/my-app:latest .; \
	KUBECONFIG=$$KC $(KIND) load docker-image ghcr.io/alialjaffer/my-app:latest --name devops-assignment; \
	KUBECONFIG=$$KC kubectl kustomize --load-restrictor LoadRestrictionsNone k8s/ | KUBECONFIG=$$KC kubectl apply -f -; \
	KUBECONFIG=$$KC kubectl rollout status deployment/postgres --timeout=120s; \
	KUBECONFIG=$$KC kubectl rollout status deployment/api --timeout=120s

k8s-down:
	KC=$(CURDIR)/.kubeconfig; \
	KUBECONFIG=$$KC $(KIND) delete cluster --name devops-assignment; \
	rm -f $$KC
