# Subrepositories
CARGO_DIRS := ./Dioptase-Emulators/Dioptase-Emulator-Simple ./Dioptase-Emulators/Dioptase-Emulator-Full
MAKE_RELEASE_DIRS := ./Dioptase-Assembler ./Dioptase-Languages/Dioptase-C-Compiler
MAKE_DEFAULT_DIRS := ./Dioptase-CPUs/Dioptase-Pipe-Simple ./Dioptase-CPUs/Dioptase-Pipe-Full
MAKE_DIRS := ./Dioptase-Assembler $(MAKE_DEFAULT_DIRS) ./Dioptase-Languages/Dioptase-C-Compiler
MAKEFLAGS += --no-print-directory
SHELL := /bin/bash

.PHONY: all test release test-release build-cargo-projects build-make-projects build-release-make-projects test-cargo-projects test-make-projects

all: build-cargo-projects build-make-projects

release: build-cargo-projects build-release-make-projects

test:
	@set -o pipefail; \
	GREEN="\033[0;32m"; \
	RED="\033[0;31m"; \
	NC="\033[0m"; \
	passed=0; failed=0; total=0; passed_dirs=""; failed_dirs=""; \
	for dir in $(CARGO_DIRS); do \
		echo ">>> building $$dir"; \
		if (cd $$dir && cargo build --release); then build_ok=1; else build_ok=0; fi; \
		echo ; \
		echo ">>> testing $$dir"; \
		tmp=$$(mktemp); \
		if [ $$build_ok -eq 1 ]; then \
			(cd $$dir && cargo test) 2>&1 | tee $$tmp; test_status=$$?; \
		else \
			echo "Build failed; skipping tests." | tee $$tmp; test_status=1; \
		fi; \
		name=$${dir##*/}; \
		if [ $$test_status -eq 0 ] && grep -q "test result: ok" $$tmp; then \
			passed=$$((passed+1)); \
			passed_dirs="$$passed_dirs $$name"; \
		else \
			failed=$$((failed+1)); \
			failed_dirs="$$failed_dirs $$name"; \
		fi; \
		total=$$((total+1)); \
		rm -f $$tmp; \
		echo ; \
	done; \
	for dir in $(MAKE_DIRS); do \
		echo ">>> building $$dir"; \
		if (cd $$dir && make all); then build_ok=1; else build_ok=0; fi; \
		echo ; \
		echo ">>> testing $$dir"; \
		tmp=$$(mktemp); \
		if [ $$build_ok -eq 1 ]; then \
			(cd $$dir && make test) 2>&1 | tee $$tmp; test_status=$$?; \
		else \
			echo "Build failed; skipping tests." | tee $$tmp; test_status=1; \
		fi; \
		name=$${dir##*/}; \
		summary=$$(grep -E "Summary: [0-9]+ / [0-9]+ tests passed" $$tmp | tail -n 1); \
		if [ $$test_status -eq 0 ] && [ -n "$$summary" ]; then \
			passed_count=$$(printf "%s\n" "$$summary" | awk '{print $$2}'); \
			total_count=$$(printf "%s\n" "$$summary" | awk '{print $$4}'); \
			if [ "$$passed_count" = "$$total_count" ]; then \
				passed=$$((passed+1)); \
				passed_dirs="$$passed_dirs $$name"; \
			else \
				failed=$$((failed+1)); \
				failed_dirs="$$failed_dirs $$name"; \
			fi; \
		else \
			failed=$$((failed+1)); \
			failed_dirs="$$failed_dirs $$name"; \
		fi; \
		total=$$((total+1)); \
		rm -f $$tmp; \
		echo ; \
	done; \
	for name in $$passed_dirs; do printf "%-32s %b\n" "$$name" "$$GREEN PASS $$NC"; done; \
	for name in $$failed_dirs; do printf "%-32s %b\n" "$$name" "$$RED FAIL $$NC"; done; \
	echo "Overall Summary: $$passed/$$total dirs passed all tests."; \
	true

test-release:
	@set -o pipefail; \
	GREEN="\033[0;32m"; \
	RED="\033[0;31m"; \
	NC="\033[0m"; \
	passed=0; failed=0; total=0; passed_dirs=""; failed_dirs=""; \
	for dir in $(CARGO_DIRS); do \
		echo ">>> building $$dir"; \
		if (cd $$dir && cargo build --release); then build_ok=1; else build_ok=0; fi; \
		echo ; \
		echo ">>> testing $$dir"; \
		tmp=$$(mktemp); \
		if [ $$build_ok -eq 1 ]; then \
			(cd $$dir && cargo test --release) 2>&1 | tee $$tmp; test_status=$$?; \
		else \
			echo "Build failed; skipping tests." | tee $$tmp; test_status=1; \
		fi; \
		name=$${dir##*/}; \
		if [ $$test_status -eq 0 ] && grep -q "test result: ok" $$tmp; then \
			passed=$$((passed+1)); \
			passed_dirs="$$passed_dirs $$name"; \
		else \
			failed=$$((failed+1)); \
			failed_dirs="$$failed_dirs $$name"; \
		fi; \
		total=$$((total+1)); \
		rm -f $$tmp; \
		echo ; \
	done; \
	for dir in $(MAKE_RELEASE_DIRS); do \
		echo ">>> building $$dir"; \
		if (cd $$dir && make release); then build_ok=1; else build_ok=0; fi; \
		echo ; \
		echo ">>> testing $$dir"; \
		tmp=$$(mktemp); \
		if [ $$build_ok -eq 1 ]; then \
			(cd $$dir && make test-release) 2>&1 | tee $$tmp; test_status=$$?; \
		else \
			echo "Build failed; skipping tests." | tee $$tmp; test_status=1; \
		fi; \
		name=$${dir##*/}; \
		summary=$$(grep -E "Summary: [0-9]+ / [0-9]+ tests passed" $$tmp | tail -n 1); \
		if [ $$test_status -eq 0 ] && [ -n "$$summary" ]; then \
			passed_count=$$(printf "%s\n" "$$summary" | awk '{print $$2}'); \
			total_count=$$(printf "%s\n" "$$summary" | awk '{print $$4}'); \
			if [ "$$passed_count" = "$$total_count" ]; then \
				passed=$$((passed+1)); \
				passed_dirs="$$passed_dirs $$name"; \
			else \
				failed=$$((failed+1)); \
				failed_dirs="$$failed_dirs $$name"; \
			fi; \
		else \
			failed=$$((failed+1)); \
			failed_dirs="$$failed_dirs $$name"; \
		fi; \
		total=$$((total+1)); \
		rm -f $$tmp; \
		echo ; \
	done; \
	for dir in $(MAKE_DEFAULT_DIRS); do \
		echo ">>> building $$dir"; \
		if (cd $$dir && make all); then build_ok=1; else build_ok=0; fi; \
		echo ; \
		echo ">>> testing $$dir"; \
		tmp=$$(mktemp); \
		if [ $$build_ok -eq 1 ]; then \
			(cd $$dir && make test) 2>&1 | tee $$tmp; test_status=$$?; \
		else \
			echo "Build failed; skipping tests." | tee $$tmp; test_status=1; \
		fi; \
		name=$${dir##*/}; \
		summary=$$(grep -E "Summary: [0-9]+ / [0-9]+ tests passed" $$tmp | tail -n 1); \
		if [ $$test_status -eq 0 ] && [ -n "$$summary" ]; then \
			passed_count=$$(printf "%s\n" "$$summary" | awk '{print $$2}'); \
			total_count=$$(printf "%s\n" "$$summary" | awk '{print $$4}'); \
			if [ "$$passed_count" = "$$total_count" ]; then \
				passed=$$((passed+1)); \
				passed_dirs="$$passed_dirs $$name"; \
			else \
				failed=$$((failed+1)); \
				failed_dirs="$$failed_dirs $$name"; \
			fi; \
		else \
			failed=$$((failed+1)); \
			failed_dirs="$$failed_dirs $$name"; \
		fi; \
		total=$$((total+1)); \
		rm -f $$tmp; \
		echo ; \
	done; \
	for name in $$passed_dirs; do printf "%-32s %b\n" "$$name" "$$GREEN PASS $$NC"; done; \
	for name in $$failed_dirs; do printf "%-32s %b\n" "$$name" "$$RED FAIL $$NC"; done; \
	echo "Overall Summary: $$passed/$$total dirs passed all tests."; \
	true

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

build-release-make-projects:
	@for dir in $(MAKE_RELEASE_DIRS); do \
		echo ">>> building $$dir"; \
		(cd $$dir && make release); \
		echo ; \
	done; \
	for dir in $(MAKE_DEFAULT_DIRS); do \
		echo ">>> building $$dir"; \
		(cd $$dir && make all); \
		echo ; \
	done

test-cargo-projects:
	@for dir in $(CARGO_DIRS); do \
		echo ">>> building $$dir"; \
		(cd $$dir && cargo build --release); \
		echo ; \
		echo ">>> testing $$dir"; \
		(cd $$dir && cargo test); \
		echo ; \
	done

test-make-projects:
	@for dir in $(MAKE_DIRS); do \
		echo ">>> building $$dir"; \
		(cd $$dir && make all); \
		echo ; \
		echo ">>> testing $$dir"; \
		(cd $$dir && make test); \
		echo ; \
	done
