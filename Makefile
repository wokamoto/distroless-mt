# MT の ZIP から mt-static / plugins を www/movabletype/ に展開する
# docker build の前に make prepare-mt を実行するか、make build で一括実行する

-include .env

MT_SOURCE_ZIP ?= MT-8.8.2.zip
MT_ZIP ?= files/movabletype/$(MT_SOURCE_ZIP)
MT_EXTRACT_DIR := .mt-extract
MT_WWW_DIR := www/movabletype

.PHONY: prepare-mt build up down help

# MT ZIP から mt-static と plugins を www/movabletype/ にコピーする
prepare-mt:
	@test -f "$(MT_ZIP)" || (echo "Error: $(MT_ZIP) not found" && exit 1)
	@echo "Extracting mt-static and plugins from $(MT_ZIP)..."
	@rm -rf "$(MT_EXTRACT_DIR)" "$(MT_WWW_DIR)/mt-static" "$(MT_WWW_DIR)/plugins"
	@mkdir -p "$(MT_EXTRACT_DIR)" "$(MT_WWW_DIR)"
	@unzip -o -q "$(MT_ZIP)" -d "$(MT_EXTRACT_DIR)"
	@SUBDIR=$$(find "$(MT_EXTRACT_DIR)" -maxdepth 1 -mindepth 1 -type d | head -1); \
	if [ -z "$$SUBDIR" ]; then \
		echo "Error: no top-level directory in zip"; exit 1; \
	fi; \
	if [ -d "$$SUBDIR/mt-static" ]; then cp -a "$$SUBDIR/mt-static" "$(MT_WWW_DIR)/"; fi; \
	if [ -d "$$SUBDIR/plugins" ]; then cp -a "$$SUBDIR/plugins" "$(MT_WWW_DIR)/"; fi
	@rm -rf "$(MT_EXTRACT_DIR)"
	@echo "Done: $(MT_WWW_DIR)/mt-static and $(MT_WWW_DIR)/plugins"

# prepare-mt の後に docker compose build を実行
build: prepare-mt
	docker compose build

# よく使うターゲット
up: build
	docker compose up -d

down:
	docker compose down

help:
	@echo "Targets:"
	@echo "  prepare-mt  - Extract mt-static and plugins from MT zip to www/movabletype/"
	@echo "  build       - prepare-mt + docker compose build"
	@echo "  up          - build + docker compose up -d"
	@echo "  down        - docker compose down"
	@echo ""
	@echo "Set zip in .env:  MT_SOURCE_ZIP=MT-9.0.0.zip"
	@echo "Override once:    make MT_ZIP=path/to/MT-9.0.0.zip prepare-mt"
