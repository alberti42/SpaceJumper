# Build SpaceJumper with Swift Package Manager and assemble the app bundle.
#
#   make            debug build, no bundle
#   make test       run the Swift tests and the tests of the scripts in bin/
#   make app        build/SpaceJumper.app with the login helper and Sparkle embedded
#   make run        make app, then open it
#   make clean
#
# SIGN_IDENTITY names a signing identity (see `security find-identity -v -p codesigning`).
# Without it the app is signed ad hoc, which is enough to run it on this Mac.
# ARCHS=universal builds arm64 and x86_64; the default is this Mac's architecture.

SIGN_IDENTITY ?= -
ARCHS ?= native

ifeq ($(ARCHS),universal)
ARCH_FLAGS := --arch arm64 --arch x86_64
endif

# Preserve the real linked SDK version with a macOS 15 deployment target.
# SwiftPM's clang --sysroot can record 15.0 instead, losing the modern UI on 26+.
SDK := $(shell xcrun --sdk macosx --show-sdk-path)
SDK_FLAGS := -Xswiftc -Xclang-linker -Xswiftc -isysroot -Xswiftc -Xclang-linker -Xswiftc "$(SDK)"

# A secure timestamp needs Apple's timestamp server; ad-hoc signatures cannot have one.
# Ad-hoc Sparkle and the app have no Team ID: hardened runtime library validation
# refuses to load the framework. Only Developer ID builds need the runtime.
ifeq ($(SIGN_IDENTITY),-)
TIMESTAMP := --timestamp=none
else
TIMESTAMP := --timestamp
RUNTIME := --options runtime
endif

APP := build/SpaceJumper.app
HELPER := $(APP)/Contents/Library/LoginItems/SpaceJumperLoginHelper.app
SPARKLE := $(APP)/Contents/Frameworks/Sparkle.framework
SIGN := codesign --force $(RUNTIME) $(TIMESTAMP) --sign "$(SIGN_IDENTITY)"

.PHONY: debug test app run clean

debug:
	swift build $(SDK_FLAGS)

test:
	swift test $(SDK_FLAGS)
	python3 -m unittest discover -s Tests/Scripts -p '*_test.py'

app:
	swift build -c release $(ARCH_FLAGS) $(SDK_FLAGS) --product SpaceJumper
	swift build -c release $(ARCH_FLAGS) $(SDK_FLAGS) --product LoginHelper
	# Stop if the binary would get the pre-26 look on modern macOS.
	@BIN="$$(swift build -c release $(ARCH_FLAGS) $(SDK_FLAGS) --show-bin-path)"; \
	for sdk in $$(vtool -show-build "$$BIN/SpaceJumper" | awk '$$1 == "sdk" { print $$2 }'); do \
	    if [ "$${sdk%%.*}" -lt 26 ]; then \
	        echo "error: $$BIN/SpaceJumper records SDK $$sdk; it must be 26 or later" >&2; \
	        exit 1; \
	    fi; \
	done
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources" "$(APP)/Contents/Frameworks" "$(HELPER)/Contents/MacOS"
	# ditto keeps the symbolic links inside the framework.
	BIN="$$(swift build -c release $(ARCH_FLAGS) $(SDK_FLAGS) --show-bin-path)"; \
	cp "$$BIN/SpaceJumper" "$(APP)/Contents/MacOS/SpaceJumper"; \
	cp "$$BIN/LoginHelper" "$(HELPER)/Contents/MacOS/SpaceJumperLoginHelper"; \
	ditto "$$BIN/Sparkle.framework" "$(SPARKLE)"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp Resources/LoginHelper-Info.plist "$(HELPER)/Contents/Info.plist"
	# Compile the Icon Composer file into Assets.car and AppIcon.icns. Info.plist
	# names the icon in CFBundleIconName and CFBundleIconFile, so the partial plist
	# that actool writes is not used.
	xcrun actool Resources/AppIcon.icon --compile "$(APP)/Contents/Resources" \
	    --platform macosx --minimum-deployment-target 15.0 --app-icon AppIcon \
	    --output-partial-info-plist build/AppIcon-partial.plist >/dev/null
	# Sign inside out: Sparkle's helpers, Sparkle, the login helper, then the app
	# that contains them. The order and the flags follow Sparkle's documentation
	# ("Code Signing", sparkle-project.org/documentation/sandboxing).
	$(SIGN) "$(SPARKLE)/Versions/B/XPCServices/Installer.xpc"
	$(SIGN) --preserve-metadata=entitlements "$(SPARKLE)/Versions/B/XPCServices/Downloader.xpc"
	$(SIGN) "$(SPARKLE)/Versions/B/Autoupdate"
	$(SIGN) "$(SPARKLE)/Versions/B/Updater.app"
	$(SIGN) "$(SPARKLE)"
	$(SIGN) "$(HELPER)"
	$(SIGN) "$(APP)"
	codesign --verify --strict --verbose=1 "$(APP)"
	@echo "Built $(APP) (signed with: $(SIGN_IDENTITY))"

run: app
	open "$(APP)"

clean:
	rm -rf .build build
