import { PopToRootType, Toast, closeMainWindow, getApplications, open, showToast } from "@raycast/api";

// The command hands off to the Clean Up Dock Mac app, which draws the selection overlay and does the quitting.
const APP_BUNDLE_ID = "com.alaramartin.clean-up-dock";
const DOWNLOAD_URL = "https://github.com/alaramartin/clean-up-dock/releases/latest";

export default async function Command() {
  const installed = (await getApplications()).some((app) => app.bundleId === APP_BUNDLE_ID);
  if (!installed) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Clean Up Dock isn't installed",
      message: "It's a free Mac app that this command opens.",
      primaryAction: { title: "Download Clean Up Dock", onAction: () => open(DOWNLOAD_URL) },
    });
    return;
  }
  // Close Raycast first so the overlay gets the mouse and keyboard.
  await closeMainWindow({ clearRootSearch: true, popToRootType: PopToRootType.Immediate });
  await open("cleanupdock://sweep");
}
