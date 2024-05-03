.DEFAULT_GOAL := foundry

.PHONY: install
install:
	git submodule update --init --recursive

.PHONY: foundry
foundry:
	@extra_flags=""
	@if [ "$$(echo $(cmd) | cut -c 1-5)" = "anvil" ]; then \
		extra_flags="-p 8545:8545"; \
	fi;
	@docker run --rm \
		-v $$(pwd):/app/foundry \
		-u $$(id -u):$$(id -g) \
		$$extra_flags \
		ghcr.io/paradigmxyz/foundry-alphanet:latest \
		--foundry-directory /app/foundry \
		--foundry-command "$(cmd)"