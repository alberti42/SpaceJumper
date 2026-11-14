#import "SkyLightBridge.h"

#import <ColorSync/ColorSync.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <objc/message.h>
#import <string.h>

static NSString *const kSkyLightPath = @"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight";
// WMClientWindowManager lives here. Without it the fallback bridge's manager is
// nil and every bridged operation is dropped without an error.
static NSString *const kWindowManagementPath = @"/System/Library/PrivateFrameworks/WindowManagement.framework/Versions/A/WindowManagement";
// Static C++ function in SkyLight; it is in the symbol table but not exported.
static const char *const kPerformSymbol =
    "__ZL54SLSPerformAsynchronousBridgedWindowManagementOperationP47SLSAsynchronousBridgedWindowManagementOperation";

typedef int CGSConnectionID;

static CGSConnectionID (*sMainConnectionID)(void);
static CFArrayRef (*sCopyManagedDisplaySpaces)(CGSConnectionID);
static CFStringRef (*sCopyActiveMenuBarDisplayIdentifier)(CGSConnectionID);
static uint64_t (*sGetActiveSpace)(CGSConnectionID);
static bool (*sIsSymbolicHotKeyEnabled)(int);
static int (*sGetSymbolicHotKeyValue)(int, uint16_t *, uint16_t *, uint64_t *);
// Returns a pointer to a static buffer, overwritten by the next call.
static const char *(*sSymbolicHotKeyName)(int);
static bool (*sIsEventMatchingSymbolicHotKey)(CGSConnectionID, CGEventRef, int);
static CFArrayRef (*sCopySpacesForWindows)(CGSConnectionID, int, CFArrayRef);
static CFTypeRef (*sWindowQueryWindows)(CGSConnectionID, CFArrayRef, int);
static CFTypeRef (*sWindowQueryResultCopyWindows)(CFTypeRef);
static bool (*sWindowIteratorAdvance)(CFTypeRef);
static uint32_t (*sWindowIteratorGetWindowID)(CFTypeRef);
static uint64_t (*sWindowIteratorGetAttributes)(CFTypeRef);
static int (*sNewTransition)(CGSConnectionID, const void *, int *);
static int (*sInvokeTransition)(CGSConnectionID, int, float);
static int (*sReleaseTransition)(CGSConnectionID, int);
static void (*sPerform)(id);

/// Finds a symbol, including a local one, in the symbol table of a loaded image.
static void *FindSymbol(NSString *imagePath, const char *name)
{
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char *imageName = _dyld_get_image_name(i);
        if (!imageName || strcmp(imageName, imagePath.fileSystemRepresentation) != 0) continue;

        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        const struct segment_command_64 *linkedit = NULL;
        const struct symtab_command *symtab = NULL;

        const uint8_t *cursor = (const uint8_t *)(header + 1);
        for (uint32_t c = 0; c < header->ncmds; ++c) {
            const struct load_command *command = (const struct load_command *)cursor;
            if (command->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
                if (strcmp(segment->segname, SEG_LINKEDIT) == 0) linkedit = segment;
            } else if (command->cmd == LC_SYMTAB) {
                symtab = (const struct symtab_command *)command;
            }
            cursor += command->cmdsize;
        }
        if (!linkedit || !symtab) return NULL;

        uintptr_t base = linkedit->vmaddr - linkedit->fileoff + (uintptr_t)slide;
        const struct nlist_64 *symbols = (const struct nlist_64 *)(base + symtab->symoff);
        const char *strings = (const char *)(base + symtab->stroff);
        for (uint32_t s = 0; s < symtab->nsyms; ++s) {
            if (strcmp(strings + symbols[s].n_un.n_strx, name) == 0) {
                return (void *)(symbols[s].n_value + (uintptr_t)slide);
            }
        }
        return NULL;
    }
    return NULL;
}

BOOL SLBLoad(NSString **error)
{
    void *skyLight = dlopen(kSkyLightPath.fileSystemRepresentation, RTLD_NOW);
    if (!skyLight) {
        if (error) *error = @"Cannot load SkyLight.framework.";
        return NO;
    }
    if (!dlopen(kWindowManagementPath.fileSystemRepresentation, RTLD_NOW) || !NSClassFromString(@"WMClientWindowManager")) {
        if (error) *error = @"Cannot load WindowManagement.framework (WMClientWindowManager).";
        return NO;
    }

    sMainConnectionID = dlsym(skyLight, "SLSMainConnectionID");
    sCopyManagedDisplaySpaces = dlsym(skyLight, "SLSCopyManagedDisplaySpaces");
    sCopyActiveMenuBarDisplayIdentifier = dlsym(skyLight, "SLSCopyActiveMenuBarDisplayIdentifier");
    sGetActiveSpace = dlsym(skyLight, "SLSGetActiveSpace");
    sIsSymbolicHotKeyEnabled = dlsym(skyLight, "SLSIsSymbolicHotKeyEnabled");
    sGetSymbolicHotKeyValue = dlsym(skyLight, "SLSGetSymbolicHotKeyValue");
    sSymbolicHotKeyName = dlsym(skyLight, "SLSSymbolicHotKeyName");
    sIsEventMatchingSymbolicHotKey = dlsym(skyLight, "SLSIsEventMatchingSymbolicHotKey");
    sCopySpacesForWindows = dlsym(skyLight, "SLSCopySpacesForWindows");
    sWindowQueryWindows = dlsym(skyLight, "SLSWindowQueryWindows");
    sWindowQueryResultCopyWindows = dlsym(skyLight, "SLSWindowQueryResultCopyWindows");
    sWindowIteratorAdvance = dlsym(skyLight, "SLSWindowIteratorAdvance");
    sWindowIteratorGetWindowID = dlsym(skyLight, "SLSWindowIteratorGetWindowID");
    sWindowIteratorGetAttributes = dlsym(skyLight, "SLSWindowIteratorGetAttributes");
    sNewTransition = dlsym(skyLight, "SLSNewTransition");
    sInvokeTransition = dlsym(skyLight, "SLSInvokeTransition");
    sReleaseTransition = dlsym(skyLight, "SLSReleaseTransition");
    sPerform = FindSymbol(kSkyLightPath, kPerformSymbol);

    NSMutableArray *missing = [NSMutableArray array];
    if (!sMainConnectionID) [missing addObject:@"SLSMainConnectionID"];
    if (!sCopyManagedDisplaySpaces) [missing addObject:@"SLSCopyManagedDisplaySpaces"];
    if (!sCopyActiveMenuBarDisplayIdentifier) [missing addObject:@"SLSCopyActiveMenuBarDisplayIdentifier"];
    if (!sGetActiveSpace) [missing addObject:@"SLSGetActiveSpace"];
    if (!sIsSymbolicHotKeyEnabled) [missing addObject:@"SLSIsSymbolicHotKeyEnabled"];
    if (!sGetSymbolicHotKeyValue) [missing addObject:@"SLSGetSymbolicHotKeyValue"];
    // Optional: older macOS versions lack this diagnostic name lookup.
    if (!sIsEventMatchingSymbolicHotKey) [missing addObject:@"SLSIsEventMatchingSymbolicHotKey"];
    if (!sCopySpacesForWindows) [missing addObject:@"SLSCopySpacesForWindows"];
    if (!sWindowQueryWindows) [missing addObject:@"SLSWindowQueryWindows"];
    if (!sWindowQueryResultCopyWindows) [missing addObject:@"SLSWindowQueryResultCopyWindows"];
    if (!sWindowIteratorAdvance) [missing addObject:@"SLSWindowIteratorAdvance"];
    if (!sWindowIteratorGetWindowID) [missing addObject:@"SLSWindowIteratorGetWindowID"];
    if (!sWindowIteratorGetAttributes) [missing addObject:@"SLSWindowIteratorGetAttributes"];
    if (!sNewTransition) [missing addObject:@"SLSNewTransition"];
    if (!sInvokeTransition) [missing addObject:@"SLSInvokeTransition"];
    if (!sReleaseTransition) [missing addObject:@"SLSReleaseTransition"];
    if (!sPerform) [missing addObject:@"SLSPerformAsynchronousBridgedWindowManagementOperation"];
    for (NSString *name in @[@"SLSBridgedShowSpacesOperation", @"SLSBridgedHideSpacesOperation",
                             @"SLSBridgedManagedDisplaySetCurrentSpaceOperation",
                             @"SLSBridgedSpaceSetTransformOperation"]) {
        if (!NSClassFromString(name)) [missing addObject:name];
    }
    if (missing.count > 0) {
        if (error) *error = [NSString stringWithFormat:@"Missing in SkyLight: %@.", [missing componentsJoinedByString:@", "]];
        return NO;
    }
    return YES;
}

NSArray<NSDictionary *> *SLBCopyManagedDisplaySpaces(void)
{
    return CFBridgingRelease(sCopyManagedDisplaySpaces(sMainConnectionID()));
}

NSString *SLBActiveMenuBarDisplay(void)
{
    return CFBridgingRelease(sCopyActiveMenuBarDisplayIdentifier(sMainConnectionID()));
}

uint64_t SLBActiveSpace(void)
{
    return sGetActiveSpace(sMainConnectionID());
}

// Mask 7 returns the Spaces of a window wherever they are; 5 returns only the
// current Space, 6 only the others (checked on macOS 27.0.1).
static const int kAllSpacesMask = 7;

NSArray<NSNumber *> *SLBCopySpacesForWindow(uint32_t window)
{
    CFArrayRef spaces = sCopySpacesForWindows(sMainConnectionID(), kAllSpacesMask, (__bridge CFArrayRef)@[@(window)]);
    return spaces ? CFBridgingRelease(spaces) : @[];
}

NSDictionary<NSNumber *, NSNumber *> *SLBCopyWindowAttributes(NSArray<NSNumber *> *windows)
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    if (windows.count == 0) return result;
    CFTypeRef query = sWindowQueryWindows(sMainConnectionID(), (__bridge CFArrayRef)windows, (int)windows.count);
    if (!query) return result;
    CFTypeRef iterator = sWindowQueryResultCopyWindows(query);
    CFRelease(query);
    if (!iterator) return result;
    while (sWindowIteratorAdvance(iterator)) {
        result[@(sWindowIteratorGetWindowID(iterator))] = @(sWindowIteratorGetAttributes(iterator));
    }
    CFRelease(iterator);
    return result;
}

static BOOL PerformSpacesOperation(NSString *className, NSArray<NSNumber *> *spaces)
{
    Class cls = NSClassFromString(className);
    if (!cls) return NO;
    id operation = ((id (*)(id, SEL, id))objc_msgSend)([cls alloc], sel_registerName("initWithSpaces:"), spaces);
    if (!operation) return NO;
    sPerform(operation);
    return YES;
}

BOOL SLBShowSpaces(NSArray<NSNumber *> *spaces)
{
    return PerformSpacesOperation(@"SLSBridgedShowSpacesOperation", spaces);
}

BOOL SLBHideSpaces(NSArray<NSNumber *> *spaces)
{
    return PerformSpacesOperation(@"SLSBridgedHideSpacesOperation", spaces);
}

BOOL SLBSetCurrentSpace(NSString *display, uint64_t space)
{
    Class cls = NSClassFromString(@"SLSBridgedManagedDisplaySetCurrentSpaceOperation");
    if (!cls) return NO;
    id operation = ((id (*)(id, SEL, id, uint64_t))objc_msgSend)(
        [cls alloc], sel_registerName("initWithDisplayIdentifier:spaceID:"), display, space);
    if (!operation) return NO;
    sPerform(operation);
    return YES;
}

BOOL SLBSetSpaceOffset(uint64_t space, double x)
{
    Class cls = NSClassFromString(@"SLSBridgedSpaceSetTransformOperation");
    if (!cls) return NO;
    id operation = ((id (*)(id, SEL, uint64_t, CGAffineTransform, unsigned))objc_msgSend)(
        [cls alloc], sel_registerName("initWithSpaceID:transform:options:"), space,
        CGAffineTransformMakeTranslation(-x, 0), 0);
    if (!operation) return NO;
    sPerform(operation);
    return YES;
}

// The transition spec of SLSNewTransition: type 1 is a fade; window 0 and
// no background colour cover the whole screen.
typedef struct {
    uint32_t unknown;
    uint32_t type;
    uint32_t option;
    uint32_t window;
    float *backgroundColor;
} SLBTransitionSpec;

int SLBFreezeScreenForFade(void)
{
    SLBTransitionSpec spec = {0, 1, 0, 0, NULL};
    int transition = 0;
    if (sNewTransition(sMainConnectionID(), &spec, &transition) != 0) return 0;
    return transition;
}

BOOL SLBDissolveScreen(int transition, double seconds)
{
    return sInvokeTransition(sMainConnectionID(), transition, (float)seconds) == 0;
}

void SLBReleaseTransition(int transition)
{
    sReleaseTransition(sMainConnectionID(), transition);
}

double SLBDisplayWidth(NSString *display)
{
    CGDirectDisplayID displays[16];
    uint32_t count = 0;
    if (CGGetActiveDisplayList(16, displays, &count) == kCGErrorSuccess) {
        for (uint32_t i = 0; i < count; ++i) {
            CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID(displays[i]);
            if (!uuid) continue;
            NSString *identifier = CFBridgingRelease(CFUUIDCreateString(NULL, uuid));
            CFRelease(uuid);
            if ([identifier caseInsensitiveCompare:display] == NSOrderedSame) {
                return CGDisplayBounds(displays[i]).size.width;
            }
        }
    }
    return CGDisplayBounds(CGMainDisplayID()).size.width;
}

NSArray<NSDictionary<NSString *, NSNumber *> *> *SLBCopyEnabledSymbolicHotKeys(void)
{
    NSMutableArray *result = [NSMutableArray array];
    for (int hotKey = 0; hotKey < 512; ++hotKey) {
        uint16_t character = 0, keyCode = 0;
        uint64_t flags = 0;
        // 0xFFFF marks a shortcut without a key.
        if (sGetSymbolicHotKeyValue(hotKey, &character, &keyCode, &flags) != 0 || keyCode == 0xFFFF) continue;
        if (!sIsSymbolicHotKeyEnabled(hotKey)) continue;
        [result addObject:@{@"id": @(hotKey), @"keyCode": @(keyCode), @"flags": @(flags)}];
    }
    return result;
}

NSString *SLBSymbolicHotKeyName(int hotKey)
{
    if (!sSymbolicHotKeyName) return nil;
    const char *name = sSymbolicHotKeyName(hotKey);
    return name && name[0] ? [NSString stringWithUTF8String:name] : nil;
}

BOOL SLBEventMatchesSymbolicHotKey(uint16_t keyCode, uint64_t flags, int hotKey)
{
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    if (!event) return NO;
    CGEventSetFlags(event, flags);
    BOOL matches = sIsEventMatchingSymbolicHotKey(sMainConnectionID(), event, hotKey);
    CFRelease(event);
    return matches;
}

BOOL SLBSetSwitchesOnAppActivation(BOOL on)
{
    // Resolved here, not in SLBLoad: without it only this setting is lost.
    void *skyLight = dlopen(kSkyLightPath.fileSystemRepresentation, RTLD_NOW);
    if (!skyLight || !sMainConnectionID) return NO;
    int (*setPreferences)(CGSConnectionID, CFDictionaryRef) =
        dlsym(skyLight, "SLSSessionSetCurrentSessionWorkspacePreferences");
    CFStringRef *key = dlsym(skyLight, "kCGSWorkspaceSwitchOnAppActivationKey");
    if (!setPreferences || !key) return NO;
    NSDictionary *preferences = @{(__bridge NSString *)*key: @(on)};
    return setPreferences(sMainConnectionID(), (__bridge CFDictionaryRef)preferences) == 0;
}

// The menu-bar calls are resolved when first used, as above: without them only
// the menu-bar settings are lost.
static void *MenuBarSymbol(const char *name)
{
    void *skyLight = dlopen(kSkyLightPath.fileSystemRepresentation, RTLD_NOW);
    return skyLight ? dlsym(skyLight, name) : NULL;
}

BOOL SLBSetMenuBarOverride(uint32_t display, BOOL on)
{
    static int (*setOverride)(CGSConnectionID, uint32_t, uint8_t);
    if (!setOverride) setOverride = MenuBarSymbol("SLSSetMenuBarVisibilityOverrideOnDisplay");
    if (!setOverride || !sMainConnectionID) return NO;
    return setOverride(sMainConnectionID(), display, on ? 1 : 0) == 0;
}

BOOL SLBMenuBarOverride(uint32_t display)
{
    static int (*getOverride)(CGSConnectionID, uint32_t);
    if (!getOverride) getOverride = MenuBarSymbol("SLSGetMenuBarVisibilityOverrideOnDisplay");
    if (!getOverride || !sMainConnectionID) return NO;
    return getOverride(sMainConnectionID(), display) != 0;
}

double SLBMenuBarReveal(void)
{
    static double (*getReveal)(uint64_t);
    if (!getReveal) getReveal = MenuBarSymbol("SLSGetSpaceMenuBarReveal");
    if (!getReveal || !sGetActiveSpace || !sMainConnectionID) return 0;
    return getReveal(sGetActiveSpace(sMainConnectionID()));
}

static void (^sMenuBarRevealHandler)(uint64_t);

// The record of 0x524 starts with the Space ID (then start time and duration).
static void MenuBarRevealed(uint32_t type, void *data, size_t length, void *context)
{
    if (!data || length < sizeof(uint64_t)) return;
    uint64_t space;
    memcpy(&space, data, sizeof space);
    void (^handler)(uint64_t) = sMenuBarRevealHandler;
    if (handler) dispatch_async(dispatch_get_main_queue(), ^{ handler(space); });
}

void SLBObserveMenuBarReveals(void (^handler)(uint64_t space))
{
    static int (*registerProc)(void (*)(uint32_t, void *, size_t, void *), uint32_t, void *);
    BOOL registered = sMenuBarRevealHandler != nil;
    sMenuBarRevealHandler = [handler copy];
    if (registered) return;
    if (!registerProc) registerProc = MenuBarSymbol("SLSRegisterNotifyProc");
    if (registerProc) registerProc(MenuBarRevealed, 0x524, NULL);
}

BOOL SLBSetMenuBarAutohide(BOOL on)
{
    static int (*setAutohide)(CGSConnectionID, bool);
    if (!setAutohide) setAutohide = MenuBarSymbol("SLSSetMenuBarAutohideEnabled");
    if (!setAutohide || !sMainConnectionID) return NO;
    return setAutohide(sMainConnectionID(), on) == 0;
}
