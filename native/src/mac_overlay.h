// MacOverlay: the small amount of macOS window behaviour Godot cannot set
// itself (overlay-window D4). Registered as the engine singleton "MacOverlay".
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class MacOverlay : public Object {
	GDCLASS(MacOverlay, Object);

	// Opaque NSRunningApplication* kept alive with a manual CFRetain.
	void *remembered_app = nullptr;

protected:
	static void _bind_methods();

public:
	MacOverlay();
	~MacOverlay();

	// Collection behaviour (all Spaces, stationary, fullscreen auxiliary, ignores
	// cycle), window level and no shadow. `handle` is the NSWindow* from
	// DisplayServer.window_get_native_handle(WINDOW_HANDLE). Returns true when
	// something had to be changed (Godot may reset the level itself).
	bool configure_window(int64_t handle);
	// The window level of `handle` (for the start-up log).
	int64_t get_window_level_of(int64_t handle) const;

	// No Dock icon, no Cmd-Tab entry.
	void set_accessory_app();

	// Focus helpers (overlay-window D5).
	void remember_frontmost_app();
	bool restore_frontmost_app();
	void activate_window(int64_t handle);
	String get_frontmost_app_bundle_id() const;
	bool is_app_active() const;

	// Marks the icons of this app's menu bar status items as template images so
	// macOS tints them for light and dark menu bars. Returns how many were found.
	int64_t set_status_item_icons_template();

	// Connected displays (multi-display design D6): an Array of Dictionaries
	// {id: int (NSScreenNumber), name: String (localizedName), frame: Rect2 in
	// points with a top-left origin at the main display's top-left corner,
	// scale: float (backingScaleFactor), main: bool}.
	Array get_displays() const;

	// The Dock's preferences (dock-dodge design D2), re-read from disk on every
	// call: {autohide, orientation, tilesize, magnification, largesize,
	// show_delay_sec}. Numbers come back as floats; missing keys are left out.
	Dictionary get_dock_prefs() const;
	// Whether this app may use the Accessibility API; `prompt` asks macOS to
	// show its permission dialog when it may not (dock-dodge design D1).
	bool is_accessibility_trusted(bool prompt) const;
	// The Dock's icon area (its AXList) in points with a top-left origin at the
	// main display's top-left corner, like get_displays(). An auto-hidden Dock
	// reports its frame just below the screen. Empty Rect2 when unavailable
	// (no permission, Dock restarting).
	Rect2 get_dock_frame();

	// The macOS app that runs process `pid` (go-to-session D1): walks the parent
	// processes to the first regular app. {name, bundle_id, pid} or {} if none.
	// Not called by the app: for checking from game_eval which app a click on a
	// buddy would bring to the front.
	Dictionary find_app_of(int64_t pid) const;
	// Brings that app to the front like a Dock click (go-to-session D2): unhide,
	// activate and reopen through LaunchServices. Returns its name, or "".
	String activate_app_of(int64_t pid);

	// Login item (standalone-app design D7), through SMAppService.mainAppService:
	// "enabled", "not_registered", "requires_approval", "not_found", or
	// "unavailable" before macOS 13.
	String login_item_status() const;
	// Registers or unregisters this app as a login item. "" on success, else the
	// error's description.
	String set_login_item(bool enabled);
	// Opens System Settings at General > Login Items.
	void open_login_items_settings();

	// Where this process's app bundle is (standalone-app design D7):
	// "applications" (in /Applications or ~/Applications), "translocated" (moved
	// by macOS for safety), "disk_image" (a read-only volume) or "elsewhere". In
	// an editor run this describes Godot.app.
	String bundle_location() const;
	// The path of this process's app bundle.
	String bundle_path() const;
	// Copies this app bundle to /Applications/<name>.app, replacing an older copy
	// that is not running (it goes to the Trash). Returns the new path, or
	// "error: <reason>". The caller starts the copy and quits.
	String move_to_applications();

private:
	void *dock_list = nullptr; // AXUIElementRef of the Dock's AXList, retained
	int64_t dock_pid = 0;
	void forget_dock_list();
};

} // namespace godot
