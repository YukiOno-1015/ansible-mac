.PHONY: all init dev personal check homebrew mas xcode pleiades macos git dotfiles import-settings npm uv help

PLAYBOOK = ansible-playbook site.yml
PLAYBOOK_BECOME = ansible-playbook --ask-become-pass site.yml

# npm global packages
NPM_PACKAGES = \
	@github/copilot \
	@redocly/cli \
	mcp-proxy \
	multi-file-swagger \
	pnpm \
	yarn

# uv tools
UV_TOOLS = \
	serena-agent

all: help

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  init       前提条件（Homebrew / Ansible）をセットアップ"
	@echo "  dev        開発用セットアップ（コミュニケーションツールなし）"
	@echo "  personal   普段使い用セットアップ（全部入り）"
	@echo "  check-dev      開発用 ドライラン"
	@echo "  check-personal 普段使い用 ドライラン"
	@echo ""
	@echo "  homebrew   Homebrew パッケージのみ"
	@echo "  mas        App Store アプリのみ"
	@echo "  xcode      Xcode 依存 Homebrew パッケージのみ"
	@echo "  pleiades   Pleiades All in One DMG の取得のみ"
	@echo "  macos      macOS 設定のみ"
	@echo "  git        Git 設定のみ"
	@echo "  dotfiles   dotfiles の clone/update と install"
	@echo "  import-settings 現環境のアプリ設定を dotfiles に取り込み"
	@echo "  npm        npm グローバルパッケージのみ"
	@echo "  uv         uv ツールのみ"

init:
	@echo "==> Checking macOS..."
	@if [ "$$(uname -s)" != "Darwin" ]; then \
		echo "This setup supports macOS only."; \
		exit 1; \
	fi
	@echo "==> Checking Homebrew..."
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "  already installed: brew"; \
	fi
	@echo "==> Checking Ansible..."
	@BREW_BIN="$$(command -v brew || true)"; \
	if [ -z "$$BREW_BIN" ] && [ -x /opt/homebrew/bin/brew ]; then BREW_BIN=/opt/homebrew/bin/brew; fi; \
	if [ -z "$$BREW_BIN" ] && [ -x /usr/local/bin/brew ]; then BREW_BIN=/usr/local/bin/brew; fi; \
	if [ -z "$$BREW_BIN" ]; then \
		echo "Homebrew command was not found after installation."; \
		exit 1; \
	fi; \
	if "$$BREW_BIN" list ansible >/dev/null 2>&1; then \
		echo "  already installed: ansible"; \
	else \
		"$$BREW_BIN" install ansible; \
	fi
	@echo "==> Checking Ansible collections..."
	@BREW_BIN="$$(command -v brew || true)"; \
	if [ -z "$$BREW_BIN" ] && [ -x /opt/homebrew/bin/brew ]; then BREW_BIN=/opt/homebrew/bin/brew; fi; \
	if [ -z "$$BREW_BIN" ] && [ -x /usr/local/bin/brew ]; then BREW_BIN=/usr/local/bin/brew; fi; \
	ANSIBLE_GALAXY_BIN="$$(command -v ansible-galaxy || true)"; \
	if [ -z "$$ANSIBLE_GALAXY_BIN" ]; then \
		ANSIBLE_GALAXY_BIN="$$("$$BREW_BIN" --prefix)/bin/ansible-galaxy"; \
	fi; \
	"$$ANSIBLE_GALAXY_BIN" collection install -r requirements.yml
	@echo "==> init complete"

dev:
	@$(MAKE) ensure-not-root
	$(PLAYBOOK_BECOME) -e @vars/dev.yml
	$(MAKE) npm
	$(MAKE) uv

personal:
	@$(MAKE) ensure-not-root
	$(PLAYBOOK_BECOME) -e @vars/personal.yml
	$(MAKE) npm
	$(MAKE) uv

check-dev:
	$(PLAYBOOK) -e @vars/dev.yml --check

check-personal:
	$(PLAYBOOK) -e @vars/personal.yml --check

homebrew:
	@$(MAKE) ensure-not-root
	$(PLAYBOOK) --tags homebrew

mas:
	@$(MAKE) ensure-not-root
	$(PLAYBOOK) --tags mas

pleiades:
	$(PLAYBOOK) --tags pleiades

macos:
	$(PLAYBOOK) --tags macos

git:
	$(PLAYBOOK) --tags git

dotfiles:
	$(PLAYBOOK) --tags dotfiles

import-settings:
	scripts/import-app-settings.sh

npm:
	@echo "==> Installing npm global packages..."
	@for pkg in $(NPM_PACKAGES); do \
		npm list -g --depth=0 $$pkg > /dev/null 2>&1 \
			&& echo "  already installed: $$pkg" \
			|| npm install -g $$pkg; \
	done

uv:
	@echo "==> Installing uv tools..."
	@for tool in $(UV_TOOLS); do \
		uv tool list 2>/dev/null | grep -q $$tool \
			&& echo "  already installed: $$tool" \
			|| uv tool install $$tool; \
	done

ensure-not-root:
	@if [ "$$(id -u)" = "0" ]; then \
		echo "Do not run this Makefile with sudo. Homebrew must run as your normal user."; \
		exit 1; \
	fi
