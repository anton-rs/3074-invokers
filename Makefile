.DEFAULT_GOAL := foundry

.PHONY: install
install:
	git submodule update --init --recursive

.PHONY: foundry
foundry:
	@if [[ "$(cmd)" == anvil* ]]; then \
		extra_flags="-p 8545:8545"; \
	else \
		extra_flags=""; \
	fi; \
	docker run --rm \
    --env-file .env \
		-v "$$(pwd):/app/foundry" \
		-u "$$(id -u):$$(id -g)" \
		$$extra_flags \
		ghcr.io/paradigmxyz/foundry-alphanet:latest \
		--foundry-directory /app/foundry \
		--foundry-command "$(cmd)"