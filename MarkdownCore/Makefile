APP_NAME := MacDown
BUILD_DIR := .build/release
APP_DIR := ../$(APP_NAME).app
CONTENTS := $(APP_DIR)/Contents
INSTALL_DIR := /Applications
PREFIX ?= /usr/local

.PHONY: app plist test install clean

## Empacota o .app em release (janela na frente, ícone próprio, handler de .md)
app: plist
	swift build -c release
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(CONTENTS)/MacOS/$(APP_NAME)
	cp Resources/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns
	@# binário novo dentro de bundle já assinado → killed pelo macOS; limpar attrs + re-assinar sempre
	xattr -cr $(APP_DIR) 2>/dev/null || true
	codesign --force --deep -s - $(APP_DIR) 2>/dev/null || true

## Gera Info.plist dentro do bundle (caminho absoluto: plistgen não aceita relativo com ..)
plist:
	mkdir -p $(APP_DIR)/Contents
	.build/release/plistgen $(CURDIR)/../MacDown.app/Contents/Info.plist || \
	(swift build -c release --product plistgen && .build/release/plistgen $(CURDIR)/../MacDown.app/Contents/Info.plist)

## Instala o .app em /Applications + a CLI `macdown` em $(PREFIX)/bin
install: app
	@# rm antes do ditto garante que não restem arquivos órfãos de versões anteriores
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	ditto $(APP_DIR) $(INSTALL_DIR)/$(APP_NAME).app
	xattr -cr $(INSTALL_DIR)/$(APP_NAME).app 2>/dev/null || true
	codesign --force --deep -s - $(INSTALL_DIR)/$(APP_NAME).app 2>/dev/null || true
	@echo "Instalado em $(INSTALL_DIR)/$(APP_NAME).app"

test:
	swift test

clean:
	swift package clean
