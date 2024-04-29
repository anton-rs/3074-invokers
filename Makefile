all: build-forge-patch build-solc-patch build-anvil-patch 

.PHONY: build-anvil-patch
build-anvil-patch:
	@echo "Building anvil patch..."
	@cd lib/foundry && \
		cargo build --bin anvil --release && \
		mkdir -p ../../bin && \
		cp target/release/anvil ../../bin/anvil
	@echo "Done, patched anvil binary is located at `bin/anvil` relative to the project root"

.PHONY: build-forge-patch
build-forge-patch:
	@echo "Building forge patch..."
	@cd lib/foundry && \
		cargo build --bin forge --release && \
		mkdir -p ../../bin && \
		cp target/release/forge ../../bin/forge
	@echo "Done, patched forge binary is located at `bin/forge` relative to the project root"

.PHONY: build-solc-patch
build-solc-patch:
	@echo "Building solc patch..."
	@cd lib/solidity && \
		mkdir -p build && \
		cd build && \
		cmake .. && \
		make && \
		mkdir -p ../../../bin && \
		cp solc/solc ../../../bin/solc
	@echo "Done, patched solc binary is located at `bin/solc` relative to the project root"

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

.PHONY: snapshot
snapshot:
	@[[ ! -a ./bin/forge ]] && make build-forge-patch || true
	@./bin/forge snapshot

.PHONY: anvil-prague
anvil-prague:
	@[[ ! -a ./bin/anvil ]] && make build-anvil-patch || true
	@./bin/anvil --hardfork prague