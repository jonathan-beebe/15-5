# Entry points for 15-5. Each target wraps a script under scripts/, which holds the logic
# and the comments. `make` alone lists the targets.

.DEFAULT_GOAL := help

# Passed through to the scripts. Override on the command line:
#   make test SIMULATOR=iPad
#   make set-version VERSION=1.1.0 BUILD=42 TAG=1
export SIMULATOR

.PHONY: help setup build build-release run demo test test-macos test-ios check lint clean set-version release-dry-run release

help: ## List the targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN { FS = ":.*## " } { printf "  make %-18s %s\n", $$1, $$2 }'

setup: ## Check the toolchain and create Config/Local.xcconfig
	@scripts/setup.sh

build: ## Debug build of the macOS app into dist/15-5.app
	@scripts/build-app.sh

build-release: ## Release build of the macOS app into dist/15-5.app
	@scripts/build-app.sh --release

run: build ## Build, then launch dist/15-5.app, replacing a running copy
	@pkill -x 15-5 2>/dev/null || true
	@open dist/15-5.app

demo: build ## Build, then launch with a 6 s / 4 s cycle already running
	@pkill -x 15-5 2>/dev/null || true
	@open dist/15-5.app --args -demo

test: ## Run the tests on macOS and an iOS Simulator
	@scripts/test.sh

test-macos: ## Run the tests on macOS
	@scripts/test.sh --macos

test-ios: ## Run the tests on an iOS Simulator (SIMULATOR=<name or UDID>)
	@scripts/test.sh --ios

check: ## Every gate at once: shell lint, tests, Release builds for both platforms
	@scripts/check.sh

lint: ## shellcheck over scripts/
	@shellcheck -x scripts/*.sh scripts/lib/*.sh

clean: ## Remove build/, dist/, and this project's DerivedData (DRY_RUN=1 lists only)
	@scripts/clean.sh $(if $(DRY_RUN),--dry-run)

set-version: ## Write VERSION=X.Y.Z [BUILD=##] to Config/Base.xcconfig (TAG=1 also commits and tags)
	@test -n "$(VERSION)" || { echo "usage: make set-version VERSION=X.Y.Z [BUILD=##] [TAG=1]" >&2; exit 1; }
	@scripts/set-version.sh $(VERSION) $(BUILD) $(if $(TAG),--commit-and-tag)

release-dry-run: ## Everything in release except the upload
	@scripts/release-app.sh --dry-run

release: ## Preflight, archive, export, validate, and upload both platforms from the tag on HEAD
	@scripts/release-app.sh
