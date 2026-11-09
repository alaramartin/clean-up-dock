import { PopToRootType, Toast, closeMainWindow, getPreferenceValues, open, showHUD, showToast } from "@raycast/api";
import { hasAccessibility, sweepDock } from "swift:../swift";

const ACCESSIBILITY_SETTINGS = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";

export default async function Command() {
  if (!(await hasAccessibility())) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Raycast needs Accessibility access",
      message: "Clean Up Dock uses it to find and remove Dock icons.",
      primaryAction: { title: "Open Accessibility Settings", onAction: () => open(ACCESSIBILITY_SETTINGS) },
    });
    return;
  }

  const { protectedApps = "" } = getPreferenceValues<Preferences.CleanUpDock>();
  const protectedList = protectedApps
    .split(",")
    .map((name) => name.trim())
    .filter(Boolean);

  // Close Raycast first so the selection overlay gets the mouse and keyboard.
  await closeMainWindow({ clearRootSearch: true, popToRootType: PopToRootType.Immediate });
  const { removed } = await sweepDock(protectedList);
  if (removed.length > 0) {
    await showHUD(`Quit and removed ${formatList(removed)}`);
  }
}

function formatList(names: string[]) {
  if (names.length <= 2) return names.join(" and ");
  return `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
}
