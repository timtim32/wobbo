// The app bundle and its place in macOS (standalone-app design D7): the login
// item through SMAppService, where the bundle lives, and moving it to
// /Applications.
#include "mac_overlay.h"

#import <AppKit/AppKit.h>
#import <ServiceManagement/ServiceManagement.h>

using namespace godot;

static String to_godot(NSString *s) {
	return s ? String::utf8([s UTF8String]) : String();
}

String MacOverlay::login_item_status() const {
	if (@available(macOS 13.0, *)) {
		switch (SMAppService.mainAppService.status) {
			case SMAppServiceStatusEnabled:
				return "enabled";
			case SMAppServiceStatusRequiresApproval:
				return "requires_approval";
			case SMAppServiceStatusNotFound:
				return "not_found";
			case SMAppServiceStatusNotRegistered:
			default:
				return "not_registered";
		}
	}
	return "unavailable";
}

String MacOverlay::set_login_item(bool enabled) {
	if (@available(macOS 13.0, *)) {
		NSError *error = nil;
		BOOL ok = enabled ? [SMAppService.mainAppService registerAndReturnError:&error]
						  : [SMAppService.mainAppService unregisterAndReturnError:&error];
		if (ok) {
			return "";
		}
		return error ? to_godot(error.localizedDescription) : String("unknown error");
	}
	return "login items need macOS 13 or later";
}

void MacOverlay::open_login_items_settings() {
	if (@available(macOS 13.0, *)) {
		[SMAppService openSystemSettingsLoginItems];
	}
}

String MacOverlay::bundle_path() const {
	return to_godot(NSBundle.mainBundle.bundlePath);
}

String MacOverlay::bundle_location() const {
	NSString *path = NSBundle.mainBundle.bundlePath.stringByStandardizingPath;
	if ([path containsString:@"/AppTranslocation/"]) {
		return "translocated";
	}
	NSString *parent = path.stringByDeletingLastPathComponent;
	NSString *user_apps = [NSHomeDirectory() stringByAppendingPathComponent:@"Applications"];
	if ([parent isEqualToString:@"/Applications"] || [parent isEqualToString:user_apps]) {
		return "applications";
	}
	if ([path hasPrefix:@"/Volumes/"]) {
		NSNumber *read_only = nil;
		[[NSURL fileURLWithPath:path] getResourceValue:&read_only forKey:NSURLVolumeIsReadOnlyKey error:nil];
		if (read_only.boolValue) {
			return "disk_image";
		}
	}
	return "elsewhere";
}

String MacOverlay::move_to_applications() {
	NSFileManager *fm = NSFileManager.defaultManager;
	NSString *source = NSBundle.mainBundle.bundlePath;
	NSString *dest = [@"/Applications" stringByAppendingPathComponent:source.lastPathComponent];
	if ([source.stringByStandardizingPath isEqualToString:dest]) {
		return to_godot(dest);
	}
	NSURL *dest_url = [NSURL fileURLWithPath:dest];
	if ([fm fileExistsAtPath:dest]) {
		for (NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications) {
			if (app.processIdentifier != getpid() && [app.bundleURL.path.stringByStandardizingPath isEqualToString:dest]) {
				return "error: the copy in Applications is running";
			}
		}
		NSError *error = nil;
		if (![fm trashItemAtURL:dest_url resultingItemURL:nil error:&error]) {
			return "error: " + to_godot(error.localizedDescription);
		}
	}
	NSError *error = nil;
	if (![fm copyItemAtPath:source toPath:dest error:&error]) {
		return "error: " + to_godot(error.localizedDescription);
	}
	return to_godot(dest);
}
