#include "mac_overlay.h"

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <sys/sysctl.h>

#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

static NSWindow *window_from_handle(int64_t handle) {
	if (handle == 0) {
		return nil;
	}
	id obj = (__bridge id)(void *)(uintptr_t)handle;
	if ([obj isKindOfClass:[NSWindow class]]) {
		return (NSWindow *)obj;
	}
	if ([obj isKindOfClass:[NSView class]]) {
		return [(NSView *)obj window];
	}
	return nil;
}

static const NSWindowCollectionBehavior OVERLAY_BEHAVIOR =
		NSWindowCollectionBehaviorCanJoinAllSpaces |
		NSWindowCollectionBehaviorStationary |
		NSWindowCollectionBehaviorFullScreenAuxiliary |
		NSWindowCollectionBehaviorIgnoresCycle;

// Above normal and floating windows, so the buddies stay on top (overlay-window spike S3).
static const NSWindowLevel OVERLAY_LEVEL = NSStatusWindowLevel;

void MacOverlay::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure_window", "handle"), &MacOverlay::configure_window);
	ClassDB::bind_method(D_METHOD("get_window_level_of", "handle"), &MacOverlay::get_window_level_of);
	ClassDB::bind_method(D_METHOD("set_accessory_app"), &MacOverlay::set_accessory_app);
	ClassDB::bind_method(D_METHOD("remember_frontmost_app"), &MacOverlay::remember_frontmost_app);
	ClassDB::bind_method(D_METHOD("restore_frontmost_app"), &MacOverlay::restore_frontmost_app);
	ClassDB::bind_method(D_METHOD("activate_window", "handle"), &MacOverlay::activate_window);
	ClassDB::bind_method(D_METHOD("get_frontmost_app_bundle_id"), &MacOverlay::get_frontmost_app_bundle_id);
	ClassDB::bind_method(D_METHOD("is_app_active"), &MacOverlay::is_app_active);
	ClassDB::bind_method(D_METHOD("set_status_item_icons_template"), &MacOverlay::set_status_item_icons_template);
	ClassDB::bind_method(D_METHOD("get_displays"), &MacOverlay::get_displays);
	ClassDB::bind_method(D_METHOD("get_dock_prefs"), &MacOverlay::get_dock_prefs);
	ClassDB::bind_method(D_METHOD("is_accessibility_trusted", "prompt"), &MacOverlay::is_accessibility_trusted);
	ClassDB::bind_method(D_METHOD("get_dock_frame"), &MacOverlay::get_dock_frame);
	ClassDB::bind_method(D_METHOD("find_app_of", "pid"), &MacOverlay::find_app_of);
	ClassDB::bind_method(D_METHOD("activate_app_of", "pid"), &MacOverlay::activate_app_of);
	ClassDB::bind_method(D_METHOD("login_item_status"), &MacOverlay::login_item_status);
	ClassDB::bind_method(D_METHOD("set_login_item", "enabled"), &MacOverlay::set_login_item);
	ClassDB::bind_method(D_METHOD("open_login_items_settings"), &MacOverlay::open_login_items_settings);
	ClassDB::bind_method(D_METHOD("bundle_location"), &MacOverlay::bundle_location);
	ClassDB::bind_method(D_METHOD("bundle_path"), &MacOverlay::bundle_path);
	ClassDB::bind_method(D_METHOD("move_to_applications"), &MacOverlay::move_to_applications);
}

static NSButton *find_button(NSView *view) {
	if ([view isKindOfClass:[NSButton class]]) {
		return (NSButton *)view;
	}
	for (NSView *sub in view.subviews) {
		NSButton *found = find_button(sub);
		if (found) {
			return found;
		}
	}
	return nil;
}

int64_t MacOverlay::set_status_item_icons_template() {
	// Godot's StatusIndicator does not mark its icon as a template image, so a
	// monochrome icon is not tinted for light/dark menu bars. Status item buttons
	// live in this process's NSStatusBarWindow instances.
	int64_t count = 0;
	for (NSWindow *window in [NSApp windows]) {
		if (![NSStringFromClass([window class]) hasPrefix:@"NSStatusBarWindow"]) {
			continue;
		}
		NSButton *button = window.contentView ? find_button(window.contentView) : nil;
		NSImage *image = button.image;
		if (!image) {
			continue;
		}
		if (!image.isTemplate) {
			NSImage *copy = [image copy];
			[copy setTemplate:YES];
			button.image = copy;
		}
		count++;
	}
	return count;
}

MacOverlay::MacOverlay() {}

MacOverlay::~MacOverlay() {
	if (remembered_app) {
		CFRelease(remembered_app);
		remembered_app = nullptr;
	}
	forget_dock_list();
}

bool MacOverlay::configure_window(int64_t handle) {
	NSWindow *window = window_from_handle(handle);
	if (!window) {
		UtilityFunctions::push_warning("MacOverlay: configure_window got no NSWindow.");
		return false;
	}
	bool changed = false;
	if (window.collectionBehavior != OVERLAY_BEHAVIOR) {
		window.collectionBehavior = OVERLAY_BEHAVIOR;
		changed = true;
	}
	if (window.level != OVERLAY_LEVEL) {
		window.level = OVERLAY_LEVEL;
		changed = true;
	}
	if (window.hasShadow) {
		window.hasShadow = NO;
		changed = true;
	}
	return changed;
}

int64_t MacOverlay::get_window_level_of(int64_t handle) const {
	NSWindow *window = window_from_handle(handle);
	return window ? (int64_t)window.level : 0;
}

void MacOverlay::set_accessory_app() {
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

void MacOverlay::remember_frontmost_app() {
	NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
	if (!front || [front isEqual:[NSRunningApplication currentApplication]]) {
		return; // Keep the earlier remembered app; we never restore to ourselves.
	}
	if (remembered_app) {
		CFRelease(remembered_app);
	}
	remembered_app = (void *)CFBridgingRetain(front);
}

bool MacOverlay::restore_frontmost_app() {
	if (!remembered_app) {
		return false;
	}
	NSRunningApplication *app = (__bridge NSRunningApplication *)remembered_app;
	bool ok = false;
	if (!app.terminated) {
		if (@available(macOS 14.0, *)) {
			[NSApp yieldActivationToApplication:app];
			ok = [app activateWithOptions:0];
		} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			ok = [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
#pragma clang diagnostic pop
		}
	}
	// Keep the reference: a second click without leaving the region must restore
	// the same app again. It is replaced on the next remember_frontmost_app().
	return ok;
}

void MacOverlay::activate_window(int64_t handle) {
	if (@available(macOS 14.0, *)) {
		[NSApp activate];
	} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[NSApp activateIgnoringOtherApps:YES];
#pragma clang diagnostic pop
	}
	NSWindow *window = window_from_handle(handle);
	if (window) {
		[window makeKeyAndOrderFront:nil];
	}
}

String MacOverlay::get_frontmost_app_bundle_id() const {
	NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
	if (!front || !front.bundleIdentifier) {
		return String();
	}
	return String::utf8(front.bundleIdentifier.UTF8String);
}

bool MacOverlay::is_app_active() const {
	return [NSApp isActive];
}

Dictionary MacOverlay::get_dock_prefs() const {
	CFStringRef app = CFSTR("com.apple.dock");
	CFPreferencesAppSynchronize(app); // pick up changes the Dock wrote since the last call
	static NSDictionary<NSString *, NSString *> *const KEYS = @{
		@"autohide" : @"autohide",
		@"orientation" : @"orientation",
		@"tilesize" : @"tilesize",
		@"magnification" : @"magnification",
		@"largesize" : @"largesize",
		@"autohide-delay" : @"show_delay_sec",
	};
	Dictionary out;
	for (NSString *key in KEYS) {
		id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, app));
		String name = String::utf8(KEYS[key].UTF8String);
		if ([value isKindOfClass:[NSNumber class]]) {
			out[name] = [(NSNumber *)value doubleValue];
		} else if ([value isKindOfClass:[NSString class]]) {
			out[name] = String::utf8([(NSString *)value UTF8String]);
		}
	}
	return out;
}

bool MacOverlay::is_accessibility_trusted(bool prompt) const {
	NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt : @(prompt)};
	return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

void MacOverlay::forget_dock_list() {
	if (dock_list) {
		CFRelease((AXUIElementRef)dock_list);
		dock_list = nullptr;
	}
	dock_pid = 0;
}

static AXUIElementRef find_dock_list(pid_t pid) {
	AXUIElementRef app = AXUIElementCreateApplication(pid);
	AXUIElementSetMessagingTimeout(app, 0.05f); // never stall a frame on a busy Dock
	CFTypeRef children = nullptr;
	AXUIElementRef found = nullptr;
	if (AXUIElementCopyAttributeValue(app, kAXChildrenAttribute, &children) == kAXErrorSuccess) {
		for (id child in (__bridge NSArray *)children) {
			AXUIElementRef element = (__bridge AXUIElementRef)child;
			CFTypeRef role = nullptr;
			if (AXUIElementCopyAttributeValue(element, kAXRoleAttribute, &role) == kAXErrorSuccess) {
				bool is_list = [(__bridge NSString *)role isEqualToString:(__bridge NSString *)kAXListRole];
				CFRelease(role);
				if (is_list) {
					found = (AXUIElementRef)CFRetain(element);
					AXUIElementSetMessagingTimeout(found, 0.05f);
					break;
				}
			}
		}
		CFRelease(children);
	}
	CFRelease(app);
	return found;
}

Rect2 MacOverlay::get_dock_frame() {
	if (!AXIsProcessTrusted()) {
		forget_dock_list();
		return Rect2();
	}
	if (!dock_list) {
		NSRunningApplication *dock = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.dock"].firstObject;
		if (!dock) {
			return Rect2();
		}
		dock_list = (void *)find_dock_list(dock.processIdentifier);
		dock_pid = dock.processIdentifier;
		if (!dock_list) {
			return Rect2();
		}
	}
	AXUIElementRef list = (AXUIElementRef)dock_list;
	CFTypeRef pos_value = nullptr;
	CFTypeRef size_value = nullptr;
	CGPoint pos = CGPointZero;
	CGSize size = CGSizeZero;
	bool ok = AXUIElementCopyAttributeValue(list, kAXPositionAttribute, &pos_value) == kAXErrorSuccess &&
			AXUIElementCopyAttributeValue(list, kAXSizeAttribute, &size_value) == kAXErrorSuccess &&
			AXValueGetValue((AXValueRef)pos_value, kAXValueTypeCGPoint, &pos) &&
			AXValueGetValue((AXValueRef)size_value, kAXValueTypeCGSize, &size);
	if (pos_value) {
		CFRelease(pos_value);
	}
	if (size_value) {
		CFRelease(size_value);
	}
	if (!ok) {
		forget_dock_list(); // the Dock restarted: look it up again next time
		return Rect2();
	}
	return Rect2(pos.x, pos.y, size.width, size.height);
}

Array MacOverlay::get_displays() const {
	Array result;
	NSArray<NSScreen *> *screens = [NSScreen screens];
	if (screens.count == 0) {
		return result;
	}
	// Cocoa frames have a bottom-left origin at the main display's bottom-left
	// corner; convert to a top-left origin at the main display's top-left.
	CGFloat main_height = screens[0].frame.size.height;
	for (NSScreen *screen in screens) {
		NSRect f = screen.frame;
		NSNumber *number = screen.deviceDescription[@"NSScreenNumber"];
		Dictionary d;
		d["id"] = (int64_t)number.unsignedIntValue;
		d["name"] = String::utf8(screen.localizedName.UTF8String);
		d["frame"] = Rect2(f.origin.x, main_height - (f.origin.y + f.size.height), f.size.width, f.size.height);
		d["scale"] = (double)screen.backingScaleFactor;
		d["main"] = (screen == screens[0]);
		result.append(d);
	}
	return result;
}


// --- go-to-session D1, D2 ---------------------------------------------------

static pid_t parent_of(pid_t pid) {
	struct kinfo_proc info;
	size_t size = sizeof(info);
	int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };
	if (sysctl(mib, 4, &info, &size, NULL, 0) != 0 || size == 0) {
		return 0;
	}
	return info.kp_eproc.e_ppid;
}

static NSRunningApplication *app_of(pid_t pid) {
	for (int i = 0; i < 32 && pid > 1; i++) {
		NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
		if (app && app.activationPolicy == NSApplicationActivationPolicyRegular) {
			return app;
		}
		pid = parent_of(pid);
	}
	return nil;
}

Dictionary MacOverlay::find_app_of(int64_t pid) const {
	Dictionary d;
	NSRunningApplication *app = app_of((pid_t)pid);
	if (app) {
		d["name"] = String(app.localizedName.UTF8String ?: "");
		d["bundle_id"] = String(app.bundleIdentifier.UTF8String ?: "");
		d["pid"] = (int64_t)app.processIdentifier;
	}
	return d;
}

String MacOverlay::activate_app_of(int64_t pid) {
	NSRunningApplication *app = app_of((pid_t)pid);
	if (!app) {
		return String();
	}
	// Like a click on the app's Dock icon: unhide, activate, and "reopen" through
	// LaunchServices, which restores a minimised or closed main window. Activation
	// alone left a minimised Claude window hidden (go-to-session spike S1).
	[app unhide];
	if (@available(macOS 14.0, *)) {
		[NSApp yieldActivationToApplication:app];
		[app activateWithOptions:NSApplicationActivateAllWindows];
	} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[app activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];
#pragma clang diagnostic pop
	}
	NSURL *url = app.bundleURL;
	if (url) {
		NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
		config.activates = YES;
		[[NSWorkspace sharedWorkspace] openApplicationAtURL:url configuration:config completionHandler:nil];
	}
	return String(app.localizedName.UTF8String ?: "");
}
