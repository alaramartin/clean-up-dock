# Dock Cleanup

A menu bar app (and Raycast extension; see `raycast/`) for clearing out your Dock. Click the dashed-rectangle icon in the menu bar (or press **Ctrl-Option-D**), drag a rectangle over some Dock icons, and let go. A small panel lists the apps you caught. Press Return and they're quit and taken out of the Dock.

- Every app icon the rectangle touches counts, including apps in the Recents section. Only the icons you touch are affected.
- Running apps quit the normal way (like Cmd-Q), so an app with unsaved work can ask you to save first. Its icon is removed once it has quit. If you cancel the save dialog, the app keeps running and stays in the Dock.
- Closed apps in the Dock are just removed.
- Folders, minimized windows, Finder, Trash, and Protected Apps (chosen by the user) are never touched.
- Escape, right-click, or clicking outside the panel cancels.

#### Install from the [latest release](https://github.com/alaramartin/dock-cleanup/releases/latest) for the menu bar app.

## Accessibility permission

On first launch macOS asks for **Accessibility** access (System Settings → Privacy & Security → Accessibility). The app needs it to read where the Dock icons are and to remove them.

The app removes icons through each icon's own Dock menu (Options → Remove from Dock), so the Dock doesn't restart. If that menu item can't be found, for example when macOS is set to a language other than English, it edits the Dock's preferences and restarts the Dock instead, which makes the icons blink for a second.
