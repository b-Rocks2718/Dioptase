# Subrepositories
CARGO_DIRS := ./Dioptase-Emulators/Dioptase-Emulator-Simple ./Dioptase-Emulators/Dioptase-Emulator-Full
MAKE_DIRS := ./Dioptase-Assembler ./Dioptase-CPUs/Dioptase-Pipe-Simple ./Dioptase-CPUs/Dioptase-Pipe-Full

.PHONY: all test

all: build-cargo-projects build-make-projects

test: test-cargo-projects test-make-projects

build-cargo-projects:
	@for dir in $(CARGO_DIRS); do \
		echo ">>> building $$dir"; \
		(cd $$dir && cargo build --release); \
		echo ; \
	done

build-make-projects:
	@for dir in $(MAKE_DIRS); do \
		echo ">>> building $$dir"; \
		(cd $$dir && make all); \
		echo ; \
	done

test-cargo-projects:
	@for dir in $(CARGO_DIRS); do \
		echo ">>> testing $$dir"; \
		(cd $$dir && cargo test); \
		echo ; \
	done

test-make-projects:
	@for dir in $(MAKE_DIRS); do \
		echo ">>> testing $$dir"; \
		(cd $$dir && make test); \
		echo ; \
	done