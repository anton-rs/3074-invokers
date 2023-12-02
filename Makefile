.PHONY: build-forge-patch
build-forge-patch:
	@echo "Building forge patch..."
	@cd forge-3074-patch && \
		cargo build --bin forge --release && \
		mkdir -p ../bin && \
		cp target/release/forge ../bin/forge
	@echo "Done, patched forge binary is located in `bin/forge` relative to the project root"

.PHONY: test
test:
	@[[ ! -a ./bin/forge ]] && make build-forge-patch || true
	@./bin/forge test -vvv

.PHONY: build
build:
	@[[ ! -a ./bin/forge ]] && make build-forge-patch || true
	@./bin/forge build

.PHONY: fmt
fmt:
	@[[ ! -a ./bin/forge ]] && make build-forge-patch || true
	@./bin/forge fmt
