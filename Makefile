# Makefile for a standard golang repo with associated container

# Circleci doesn't seem to provide a decent way to add to path, just adding here, for case where
# linux build and linuxbrew is installed.
export PATH := $(EXTRA_PATH):$(PATH)

BUILD_BASE_DIR ?= $(PWD)

GOTMP=.gotmp
SHELL = /bin/bash
PWD = $(shell pwd)
GOFILES = $(shell find $(SRC_DIRS) -name "*.go" ! -path "*/testdata/*")
GORACE = "halt_on_error=1"
CGO_ENABLED = 0
.PHONY: darwin_amd64 darwin_arm64 darwin_amd64_notarized darwin_arm64_notarized darwin_arm64_signed darwin_amd64_signed linux_amd64 linux_arm64 linux_arm windows_amd64 windows_arm64 windows_install setup

# Expands SRC_DIRS into the common golang ./dir/... format for "all below"
SRC_AND_UNDER = $(patsubst %,./%/...,$(SRC_DIRS))

TESTTMP=/tmp/testresults

# This repo's root import path (under GOPATH).
PKG := github.com/ddev/ddev

# Top-level directories to build
SRC_DIRS := cmd pkg

# Version variables to replace in build
VERSION_VARIABLES ?= DdevVersion AmplitudeAPIKey

# These variables will be used as the default unless overridden by the make
DdevVersion ?= $(VERSION)
# WebTag ?= $(VERSION)  # WebTag is normally specified in version_constants.go, sometimes overridden (night-build.mak)
# DBTag ?=  $(VERSION)  # DBTag is normally specified in version_constants.go, sometimes overridden (night-build.mak)
# RouterTag ?= $(VERSION) #RouterTag is normally specified in version_constants.go, sometimes overridden (night-build.mak)
# DBATag ?= $(VERSION) #DBATag is normally specified in version_constants.go, sometimes overridden (night-build.mak)

# VERSION can be set by
  # Default: git tag
  # make command line: make VERSION=0.9.0
# It can also be explicitly set in the Makefile as commented out below.

# This version-strategy uses git tags to set the version string
# VERSION can be overridden on make commandline: make VERSION=0.9.1 push
VERSION := $(shell git describe --tags --always --dirty)
# Some things insist on having the version without the leading 'v', so provide a
# $(NO_V_VERSION) without it.
# no_v_version removes the front v, for Chocolatey mostly
NO_V_VERSION=$(shell echo $(VERSION) | awk -F"-" '{ OFS="-"; sub(/^./, "", $$1); printf $$0; }')
GITHUB_ORG := ddev

BUILD_OS = $(shell go env GOHOSTOS)
BUILD_ARCH = $(shell go env GOHOSTARCH)
VERSION_LDFLAGS=$(foreach v,$(VERSION_VARIABLES),-X '$(PKG)/pkg/versionconstants.$(v)=$($(v))')
# Static link, version variables, strip symbols and dwarf info
LDFLAGS=-extldflags -static $(VERSION_LDFLAGS) -s -w
DEFAULT_BUILD=$(shell go env GOHOSTOS)_$(shell go env GOHOSTARCH)

build: $(DEFAULT_BUILD)


# Provide shorthand targets
linux_amd64: $(GOTMP)/bin/linux_amd64/ddev $(GOTMP)/bin/linux_amd64/ddev-hostname
linux_arm64: $(GOTMP)/bin/linux_arm64/ddev $(GOTMP)/bin/linux_arm64/ddev-hostname
darwin_amd64: $(GOTMP)/bin/darwin_amd64/ddev $(GOTMP)/bin/darwin_amd64/ddev-hostname
darwin_arm64: $(GOTMP)/bin/darwin_arm64/ddev $(GOTMP)/bin/darwin_arm64/ddev-hostname
windows_amd64: windows_amd64_install
windows_arm64: windows_arm64_install
wsl_amd64: $(GOTMP)/bin/wsl_amd64/ddev-hostname.exe $(GOTMP)/bin/wsl_amd64/mkcert.exe
wsl_arm64: $(GOTMP)/bin/wsl_arm64/ddev-hostname.exe $(GOTMP)/bin/wsl_arm64/mkcert.exe

completions: $(GOTMP)/bin/completions.tar.gz

TARGETS=$(GOTMP)/bin/linux_amd64/ddev $(GOTMP)/bin/linux_arm64/ddev $(GOTMP)/bin/linux_arm/ddev $(GOTMP)/bin/darwin_amd64/ddev $(GOTMP)/bin/darwin_arm64/ddev $(GOTMP)/bin/windows_amd64/ddev.exe $(GOTMP)/bin/windows_arm64/ddev.exe $(GOTMP)/bin/linux_amd64/ddev-hostname $(GOTMP)/bin/linux_arm64/ddev-hostname $(GOTMP)/bin/darwin_amd64/ddev-hostname $(GOTMP)/bin/darwin_arm64/ddev-hostname $(GOTMP)/bin/windows_amd64/ddev-hostname.exe $(GOTMP)/bin/windows_arm64/ddev-hostname.exe
$(TARGETS): mkcert $(GOFILES)
	@rm -f $@
	@export TARGET=$(word 3, $(subst /, ,$@)); \
	if [[ "$@" == *ddev-hostname.exe ]]; then \
		export BUILDARGS="" CGO_ENABLED=0 GORACE=""; \
	else \
		export CGO_ENABLED="$(CGO_ENABLED)" GORACE="$(GORACE)" BUILDARGS="$(BUILDARGS)" ; \
	fi; \
	echo "building $@ from $(SRC_AND_UNDER) GORACE=$$GORACE CGO_ENABLED=$$CGO_ENABLED BUILDARGS=$$BUILDARGS"; \
	export GOOS="$${TARGET%_*}" GOARCH="$${TARGET#*_}" GOPATH="$(PWD)/$(GOTMP)" GOCACHE="$(PWD)/$(GOTMP)/.cache"; \
	mkdir -p $(GOTMP)/{.cache,pkg,src,bin/$$TARGET}; \
	chmod 777 $(GOTMP)/{.cache,pkg,src,bin/$$TARGET}; \
	go build -o $(GOTMP)/bin/$$TARGET -installsuffix static $$BUILDARGS -ldflags " $(LDFLAGS) " $(SRC_AND_UNDER)
	$(shell if [ -d $(GOTMP) ]; then chmod -R u+w $(GOTMP); fi)
	@echo $(VERSION) >VERSION.txt


$(GOTMP)/bin/completions.tar.gz: build
	$(GOTMP)/bin/$(BUILD_OS)_$(BUILD_ARCH)/ddev_gen_autocomplete
	tar -C $(GOTMP)/bin/completions -czf $(GOTMP)/bin/completions.tar.gz .

# WSL2 build targets - copy Windows binaries to Linux-style directories for packaging
$(GOTMP)/bin/wsl_amd64/ddev-hostname.exe: $(GOTMP)/bin/windows_amd64/ddev-hostname.exe
	mkdir -p $(GOTMP)/bin/wsl_amd64
	cp $< $@

$(GOTMP)/bin/wsl_arm64/ddev-hostname.exe: $(GOTMP)/bin/windows_arm64/ddev-hostname.exe
	mkdir -p $(GOTMP)/bin/wsl_arm64
	cp $< $@

$(GOTMP)/bin/wsl_amd64/mkcert.exe: $(GOTMP)/bin/windows_amd64/mkcert.exe
	mkdir -p $(GOTMP)/bin/wsl_amd64
	cp $< $@

$(GOTMP)/bin/wsl_arm64/mkcert.exe: $(GOTMP)/bin/windows_arm64/mkcert.exe
	mkdir -p $(GOTMP)/bin/wsl_arm64
	cp $< $@

mkcert: $(GOTMP)/bin/darwin_arm64/mkcert $(GOTMP)/bin/darwin_amd64/mkcert $(GOTMP)/bin/linux_arm64/mkcert $(GOTMP)/bin/linux_amd64/mkcert

# Set CURL to the Homebrew-installed curl, fallback to default
CURL := $(shell command -v /opt/homebrew/opt/curl/bin/curl || command -v /usr/local/opt/curl/bin/curl || echo curl)

# Download mkcert to it can be added to tarball installations
$(GOTMP)/bin/darwin_arm64/mkcert $(GOTMP)/bin/darwin_amd64/mkcert $(GOTMP)/bin/linux_arm64/mkcert $(GOTMP)/bin/linux_amd64/mkcert:
	@export TARGET=$(word 3, $(subst /, ,$@)) && \
	export GOOS="$${TARGET%_*}" GOARCH="$${TARGET#*_}" MKCERT_VERSION=v1.4.4 && \
	mkdir -p $(GOTMP)/bin/$${GOOS}_$${GOARCH} && \
	$(CURL) --fail -JL -s -S --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors -o $(GOTMP)/bin/$${GOOS}_$${GOARCH}/mkcert "https://github.com/FiloSottile/mkcert/releases/download/$${MKCERT_VERSION}/mkcert-$${MKCERT_VERSION}-$${GOOS}-$${GOARCH}" && chmod +x $(GOTMP)/bin/$${GOOS}_$${GOARCH}/mkcert

TEST_TIMEOUT=4h
BUILD_ARCH = $(shell go env GOARCH)

DDEVNAME=ddev
SHASUM=shasum -a 256
ifeq ($(BUILD_OS),windows)
	DDEVNAME=ddev.exe
	SHASUM=sha256sum
	TEST_TIMEOUT=6h
endif

DDEV_PATH=$(PWD)/$(GOTMP)/bin/$(BUILD_OS)_$(BUILD_ARCH)
DDEV_BINARY_FULLPATH=$(DDEV_PATH)/$(DDEVNAME)

# Override test section with tests specific to ddev
test: testpkg testcmd

testcmd: $(DEFAULT_BUILD) setup
	@echo LDFLAGS=$(LDFLAGS)
	@echo DDEV_BINARY_FULLPATH=$(DDEV_BINARY_FULLPATH)
	export PATH="$(DDEV_PATH):$$PATH" DDEV_NO_INSTRUMENTATION=true CGO_ENABLED=$(CGO_ENABLED) DDEV_BINARY_FULLPATH=$(DDEV_BINARY_FULLPATH); go test $(USEMODVENDOR) -p 1 -timeout $(TEST_TIMEOUT) -v -installsuffix static -ldflags " $(LDFLAGS) " ./cmd/... $(TESTARGS)

testpkg: testnotddevapp testddevapp

testddevapp: $(DEFAULT_BUILD) setup
	export PATH="$(DDEV_PATH):$$PATH" DDEV_NO_INSTRUMENTATION=true CGO_ENABLED=$(CGO_ENABLED) DDEV_BINARY_FULLPATH=$(DDEV_BINARY_FULLPATH); go test $(USEMODVENDOR) -p 1 -timeout $(TEST_TIMEOUT) -v -installsuffix static -ldflags " $(LDFLAGS) " ./pkg/ddevapp $(TESTARGS)

testnotddevapp: $(DEFAULT_BUILD) setup
	export PATH="$(DDEV_PATH):$$PATH" DDEV_NO_INSTRUMENTATION=true CGO_ENABLED=$(CGO_ENABLED) DDEV_BINARY_FULLPATH=$(DDEV_BINARY_FULLPATH); go test $(USEMODVENDOR) -p 1 -timeout $(TEST_TIMEOUT) -v -installsuffix static -ldflags " $(LDFLAGS) " $(shell find ./pkg -maxdepth 1 -type d ! -name ddevapp ! -name pkg) $(TESTARGS)

testfullsitesetup: $(DEFAULT_BUILD) setup
	export PATH="$(DDEV_PATH):$$PATH" DDEV_NO_INSTRUMENTATION=true CGO_ENABLED=$(CGO_ENABLED) DDEV_BINARY_FULLPATH=$(DDEV_BINARY_FULLPATH); go test $(USEMODVENDOR) -p 1 -timeout $(TEST_TIMEOUT) -v -installsuffix static -ldflags " $(LDFLAGS) " ./pkg/ddevapp -run TestDdevFullSiteSetup $(TESTARGS)

testwininstaller: windows_amd64_install
	@echo "Running Windows installer tests..."
	export DDEV_TEST_USE_REAL_INSTALLER=true; go test -p 1 -timeout 30m -v ./winpkg -run TestWindowsInstaller $(TESTARGS)

setup:
	@mkdir -p $(GOTMP)/{bin/linux_arm64,bin/linux_amd64,bin/darwin_arm64,bin/darwin_amd64,bin/windows_amd64,bin/windows_arm64,src,pkg/mod/cache,.cache}
	@mkdir -p $(TESTTMP)

# Required static analysis targets used in circleci - these cause fail if they don't work
staticrequired: setup golangci-lint markdownlint mkdocs pyspelling

# Best to install markdownlint-cli locally with "npm install -g markdownlint-cli"
markdownlint:
	@echo "markdownlint: "
	@CMD="markdownlint *.md docs/content 2>&1"; \
	set -eu -o pipefail; \
	if command -v markdownlint >/dev/null 2>&1 ; then \
		$$CMD; \
	else \
		echo "Skipping markdownlint as not installed (see .envrc file)"; \
	fi

# Install mkdocs locally using
# https://ddev.readthedocs.io/en/stable/developers/testing-docs/
mkdocs:
	@echo "mkdocs: "
	@CMD="mkdocs build -d /tmp/mkdocsbuild"; \
	if command -v mkdocs >/dev/null 2>&1; then \
		$$CMD ; \
	else \
		echo "Not running mkdocs because it's not installed (see .envrc file)"; \
	fi

# To see what the docs will look like, you can use `make mkdocs-serve`
# It does require installing mkdocs and its requirements
# See https://ddev.readthedocs.io/en/stable/developers/testing-docs/
mkdocs-serve:
	@if command -v mkdocs >/dev/null ; then \
		mkdocs serve; \
	else \
		echo "mkdocs is not installed (see .envrc file)" && exit 2; \
	fi; \

# Install linkspector locally with "sudo npm install -g @umbrelladocs/linkspector"
linkspector:
	@echo "linkspector: "
	@if command -v linkspector >/dev/null 2>&1; then \
		linkspector check; \
	else \
		echo "Not running linkspector because it's not installed (see .envrc file)"; \
	fi

# Best to install pyspelling locally with "sudo -H pip3 install pyspelling pymdown-extensions". Also requires aspell, `sudo apt-get install aspell"
pyspelling:
	@echo "pyspelling: "
	@CMD="pyspelling --config .spellcheck.yml"; \
	set -eu -o pipefail; \
	if command -v pyspelling >/dev/null 2>&1 ; then \
		$$CMD; \
	else \
		echo "Not running pyspelling because it's not installed (see .envrc file)"; \
	fi

# Install textlint locally with `npm install -g textlint textlint-filter-rule-comments textlint-rule-no-todo textlint-rule-stop-words textlint-rule-terminology`
textlint:
	@echo "textlint: "
	@CMD="textlint {README.md,version-history.md,docs/**}"; \
	set -eu -o pipefail; \
	if command -v textlint >/dev/null 2>&1 ; then \
		$$CMD; \
	else \
		echo "textlint is not installed (see .envrc file)"; \
	fi

darwin_amd64_signed: $(GOTMP)/bin/darwin_amd64/ddev $(GOTMP)/bin/darwin_amd64/ddev-hostname
	@if [ -z "$(DDEV_MACOS_SIGNING_PASSWORD)" ]; then \
		echo "Skipping signing ddev for macOS, no DDEV_MACOS_SIGNING_PASSWORD provided"; \
	else \
		for bin in $^; do \
			set -o errexit -o pipefail; \
			codesign --remove-signature "$$bin" || true; \
			$(CURL) -s --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors https://raw.githubusercontent.com/ddev/signing_tools/master/macos_sign.sh | \
				bash -s - --signing-password="$(DDEV_MACOS_SIGNING_PASSWORD)" --cert-file=certfiles/ddev_developer_id_cert.p12 --cert-name="Developer ID Application: Localdev Foundation (9HQ298V2BW)" --target-binary="$$bin"; \
		done; \
	fi
darwin_arm64_signed: $(GOTMP)/bin/darwin_arm64/ddev $(GOTMP)/bin/darwin_arm64/ddev-hostname
	@if [ -z "$(DDEV_MACOS_SIGNING_PASSWORD)" ]; then \
		echo "Skipping signing ddev for macOS, no DDEV_MACOS_SIGNING_PASSWORD provided"; \
	else \
		for bin in $^; do \
			set -o errexit -o pipefail; \
			codesign --remove-signature "$$bin" || true; \
			$(CURL) -s --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors https://raw.githubusercontent.com/ddev/signing_tools/master/macos_sign.sh | \
				bash -s - --signing-password="$(DDEV_MACOS_SIGNING_PASSWORD)" --cert-file=certfiles/ddev_developer_id_cert.p12 --cert-name="Developer ID Application: Localdev Foundation (9HQ298V2BW)" --target-binary="$$bin"; \
		done; \
	fi
darwin_amd64_notarized: darwin_amd64_signed
	@if [ -z "$(DDEV_MACOS_APP_PASSWORD)" ]; then echo "Skipping notarizing ddev for macOS, no DDEV_MACOS_APP_PASSWORD provided"; else \
		set -o errexit -o pipefail; \
		echo "Notarizing $(GOTMP)/bin/darwin_amd64/ddev and ddev-hostname ..." ; \
		$(CURL) -sSL --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors -f https://raw.githubusercontent.com/ddev/signing_tools/master/macos_notarize.sh | bash -s -  --app-specific-password=$(DDEV_MACOS_APP_PASSWORD) --apple-id=notarizer@localdev.foundation --primary-bundle-id=com.ddev.ddev --target-binary="$(GOTMP)/bin/darwin_amd64/ddev" ; \
		$(CURL) -sSL --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors -f https://raw.githubusercontent.com/ddev/signing_tools/master/macos_notarize.sh | bash -s -  --app-specific-password=$(DDEV_MACOS_APP_PASSWORD) --apple-id=notarizer@localdev.foundation --primary-bundle-id=com.ddev.ddev --target-binary="$(GOTMP)/bin/darwin_amd64/ddev-hostname" ; \
	fi
darwin_arm64_notarized: darwin_arm64_signed
	@if [ -z "$(DDEV_MACOS_APP_PASSWORD)" ]; then echo "Skipping notarizing ddev for macOS, no DDEV_MACOS_APP_PASSWORD provided"; else \
		set -o errexit -o pipefail; \
		echo "Notarizing $(GOTMP)/bin/darwin_arm64/ddev and ddev-hostname ..." ; \
		$(CURL) -sSL --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors -f https://raw.githubusercontent.com/ddev/signing_tools/master/macos_notarize.sh | bash -s - --app-specific-password=$(DDEV_MACOS_APP_PASSWORD) --apple-id=notarizer@localdev.foundation --primary-bundle-id=com.ddev.ddev --target-binary="$(GOTMP)/bin/darwin_arm64/ddev" ; \
		$(CURL) -sSL --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors -f https://raw.githubusercontent.com/ddev/signing_tools/master/macos_notarize.sh | bash -s - --app-specific-password=$(DDEV_MACOS_APP_PASSWORD) --apple-id=notarizer@localdev.foundation --primary-bundle-id=com.ddev.ddev --target-binary="$(GOTMP)/bin/darwin_arm64/ddev-hostname" ; \
	fi

windows_amd64_install: $(GOTMP)/bin/windows_amd64/ddev_windows_amd64_installer.exe
windows_arm64_install: $(GOTMP)/bin/windows_arm64/ddev_windows_arm64_installer.exe
windows_install: windows_amd64_install windows_arm64_install

windows_amd64_sign_binaries: $(GOTMP)/bin/windows_amd64/ddev.exe $(GOTMP)/bin/windows_amd64/ddev-hostname.exe $(GOTMP)/bin/windows_amd64/mkcert.exe
	@if [ "$(DDEV_WINDOWS_SIGN)" != "true" ] ; then echo "Skipping signing amd64 ddev.exe, DDEV_WINDOWS_SIGN not set"; else echo "Signing windows amd64 binaries..." && signtool sign -fd SHA256 ".gotmp/bin/windows_amd64/ddev.exe" ".gotmp/bin/windows_amd64/ddev-hostname.exe" ".gotmp/bin/windows_amd64/mkcert.exe" ".gotmp/bin/windows_amd64/ddev_gen_autocomplete.exe"; fi

windows_arm64_sign_binaries: $(GOTMP)/bin/windows_arm64/ddev.exe $(GOTMP)/bin/windows_arm64/ddev-hostname.exe $(GOTMP)/bin/windows_arm64/mkcert.exe
	@if [ "$(DDEV_WINDOWS_SIGN)" != "true" ] ; then echo "Skipping signing arm64 ddev.exe, DDEV_WINDOWS_SIGN not set"; else echo "Signing windows arm64 binaries..." && signtool sign -fd SHA256 ".gotmp/bin/windows_arm64/ddev.exe" ".gotmp/bin/windows_arm64/ddev-hostname.exe" ".gotmp/bin/windows_arm64/mkcert.exe" ".gotmp/bin/windows_arm64/ddev_gen_autocomplete.exe"; fi

windows_sign_binaries: windows_amd64_sign_binaries windows_arm64_sign_binaries

$(GOTMP)/bin/windows_amd64/ddev_windows_amd64_installer.exe: windows_amd64_sign_binaries linux_amd64 $(GOTMP)/bin/windows_amd64/mkcert_license.txt winpkg/ddev_windows_installer.nsi
	@makensis -DTARGET_ARCH=amd64 -DVERSION=$(VERSION) winpkg/ddev_windows_installer.nsi  # brew install makensis, apt-get install nsis, or install on Windows
	@if [ "$(DDEV_WINDOWS_SIGN)" != "true" ] ; then echo "Skipping signing amd64 $@, DDEV_WINDOWS_SIGN not set"; else echo "Signing windows installer amd64 binary..." && signtool sign -fd SHA256 "$@"; fi
	$(SHASUM) $@ >$@.sha256.txt

$(GOTMP)/bin/windows_arm64/ddev_windows_arm64_installer.exe: windows_arm64_sign_binaries linux_arm64  $(GOTMP)/bin/windows_arm64/mkcert_license.txt winpkg/ddev_windows_installer.nsi
	@makensis -DTARGET_ARCH=arm64 -DVERSION=$(VERSION) winpkg/ddev_windows_installer.nsi  # brew install makensis, apt-get install nsis, or install on Windows
	@if [ "$(DDEV_WINDOWS_SIGN)" != "true" ] ; then echo "Skipping signing arm64 $@, DDEV_WINDOWS_SIGN not set"; else echo "Signing windows installer arm64 binary..." && signtool sign -fd SHA256 "$@"; fi
	$(SHASUM) $@ >$@.sha256.txt

no_v_version:
	@echo $(NO_V_VERSION)

chocolatey: $(GOTMP)/bin/windows_amd64/ddev_windows_amd64_installer.exe
	rm -rf $(GOTMP)/bin/windows_amd64/chocolatey && cp -r winpkg/chocolatey $(GOTMP)/bin/windows_amd64/chocolatey
	perl -pi -e 's/REPLACE_DDEV_VERSION/$(NO_V_VERSION)/g' $(GOTMP)/bin/windows_amd64/chocolatey/*.nuspec
	perl -pi -e 's/REPLACE_DDEV_VERSION/$(VERSION)/g' $(GOTMP)/bin/windows_amd64/chocolatey/tools/*.ps1
	perl -pi -e 's/REPLACE_GITHUB_ORG/$(REPOSITORY_OWNER)/g' $(GOTMP)/bin/windows_amd64/chocolatey/*.nuspec $(GOTMP)/bin/windows_amd64/chocolatey/tools/*.ps1 #GITHUB_ORG is for testing, for example when the binaries are on rfay acct
	perl -pi -e "s/REPLACE_INSTALLER_CHECKSUM/$$(cat $(GOTMP)/bin/windows_amd64/ddev_windows_amd64installer.exe.sha256.txt | awk '{ print $$1; }')/g" $(GOTMP)/bin/windows_amd64/chocolatey/tools/*
	if [[ "$(NO_V_VERSION)" =~ -g[0-9a-f]+ ]]; then \
		echo "Skipping chocolatey build on interim version"; \
	else \
		docker run --rm -v "/$(PWD)/$(GOTMP)/bin/windows_amd64/chocolatey:/tmp/chocolatey" -w "//tmp/chocolatey" linuturk/mono-choco pack ddev.nuspec; \
		echo "chocolatey package is in $(GOTMP)/bin/windows_amd64/chocolatey"; \
	fi

$(GOTMP)/bin/windows_amd64/mkcert.exe $(GOTMP)/bin/windows_amd64/mkcert_license.txt:
	$(CURL) --fail -S --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors -JL -s -o $(GOTMP)/bin/windows_amd64/mkcert.exe "https://dl.filippo.io/mkcert/latest?for=windows/amd64"
	$(CURL) --fail -sSL --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors -o $(GOTMP)/bin/windows_amd64/mkcert_license.txt -O https://raw.githubusercontent.com/FiloSottile/mkcert/master/LICENSE

$(GOTMP)/bin/windows_arm64/mkcert.exe $(GOTMP)/bin/windows_arm64/mkcert_license.txt:
	$(CURL) --fail -JL -S --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors -s -o $(GOTMP)/bin/windows_arm64/mkcert.exe "https://dl.filippo.io/mkcert/latest?for=windows/arm64"
	$(CURL) --fail -sSL --retry 5 --retry-delay 5 --retry-connrefused --retry-all-errors -o $(GOTMP)/bin/windows_arm64/mkcert_license.txt -O https://raw.githubusercontent.com/FiloSottile/mkcert/master/LICENSE

# Best to install golangci-lint locally with "curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/local/bin v1.31.0"
golangci-lint:
	@echo "golangci-lint: "
	@CMD="golangci-lint run $(SRC_AND_UNDER)"; \
	set -eu -o pipefail; \
	if command -v golangci-lint >/dev/null 2>&1; then \
		$$CMD; \
	else \
		echo "Skipping golangci-lint as not installed"; \
	fi

go-mod-update:
	@echo "bump golang dependencies: "
	go get -u ./...
	go mod tidy
	go mod vendor

quickstart-test: build
	@echo "quickstart-test:"
	@echo DDEV_BINARY_FULLPATH=$(DDEV_BINARY_FULLPATH)
	export PATH="$(DDEV_PATH):$$PATH" DDEV_NO_INSTRUMENTATION=true CGO_ENABLED=$(CGO_ENABLED) DDEV_BINARY_FULLPATH=$(DDEV_BINARY_FULLPATH); bats docs/tests

version:
	@echo VERSION:$(VERSION)

clean: bin-clean

bin-clean:
	@rm -rf bin .cache
	$(shell if [ -d $(GOTMP) ]; then chmod -R u+w $(GOTMP) && rm -rf $(GOTMP); fi )

# print-ANYVAR prints the expanded variable
print-%: ; @echo $* = $($*)
