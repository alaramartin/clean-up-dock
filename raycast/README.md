# Clean Up Dock

Type "Clean Up Dock" in Raycast and press Return. Your cursor turns into a crosshair: drag a box over some Dock icons and let go. A small panel lists the apps you caught, and when you confirm, they quit and are taken out of the Dock.

- Every app icon the box touches counts, including apps in the Dock's Recents section.
- Running apps quit the normal way, so an app with unsaved work can ask you to save first. Its icon is removed once it has quit.
- Folders, minimized windows, Finder and Trash are never touched.
- Escape cancels at any point.

## Setup

This command opens **Clean Up Dock**, a free menu bar app that draws the selection box and does the quitting and removing. Install it first:

1. Download `CleanUpDock.zip` from the [latest release](https://github.com/alaramartin/clean-up-dock/releases/latest), unzip it and move **Clean Up Dock.app** to Applications.
2. Open it. It isn't notarized, so macOS blocks the first launch: go to **System Settings → Privacy & Security** and click **Open Anyway**.
3. Allow it under **System Settings → Privacy & Security → Accessibility**. It needs this to find the icons in your Dock and remove them.

The app needs to be version 1.1.0 or later. If it isn't installed, the command shows a link to download it.

The app also has a menu bar icon and a Ctrl-Option-D shortcut that start the same sweep, plus a list of protected apps that a sweep never touches. Source: [github.com/alaramartin/clean-up-dock](https://github.com/alaramartin/clean-up-dock).
