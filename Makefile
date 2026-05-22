PRODUCT = MacDown
BUILD_DIR = .build/release
APP = $(PRODUCT).app
CONTENTS = $(APP)/Contents

.PHONY: build run clean test

build:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(CONTENTS)/MacOS
	mkdir -p $(CONTENTS)/Resources
	cp $(BUILD_DIR)/MacDown $(CONTENTS)/MacOS/MacDown
	cp Info.plist $(CONTENTS)/Info.plist
	cp -r $(BUILD_DIR)/MacDown_MacDown.bundle/Contents/Resources/. $(CONTENTS)/Resources/ 2>/dev/null || \
	  cp -r Sources/MacDown/Resources/. $(CONTENTS)/Resources/
	codesign --deep --force --sign - $(APP)
	@echo "Built: $(APP)"

run: build
	open $(APP)

clean:
	rm -rf .build $(APP)

test:
	swift test
