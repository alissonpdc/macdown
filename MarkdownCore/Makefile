APP_NAME := MacDown
BUILD_DIR := .build/release
APP_DIR := ../$(APP_NAME).app
CONTENTS := $(APP_DIR)/Contents

.PHONY: app plist test clean

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

test:
	swift test

clean:
	swift package clean
