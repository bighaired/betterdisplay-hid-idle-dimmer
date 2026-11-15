# Changelog

## 2.3.0 — 2026-11-15

- **Software-only brightness:** dim using `softwareBrightness` instead of `combinedBrightness`; never write DDC/hardware brightness from the normal dimmer.
- Default to **600 seconds / 0% software brightness**, preserving and restoring each display's original software level.
- Keep physically shared monitors at their existing hardware brightness, avoiding unwanted dimming of a selected Windows input.
- Read-only hardware brightness diagnostics before and after dimming.
- New software-specific snapshot key and mode-tagged recovery snapshot, with backwards-compatible emergency restoration for legacy combined snapshots.
- Installer checks for an active snapshot before upgrading; existing disable, enable, uninstall and emergency shortcuts remain supported.
- Update English and Russian documentation, including Codex caveats and backlight glow behavior.

## 1.0.0 — 2026-11-14

First standalone public package, based on the previously iterated **v2.2** Hammerspoon module.

- Bundles CoreGraphics HID reader source and compiles it locally during installation (no binary distribution).
- Installs without requiring any earlier v2.x zip package; saves dated backups of changed Hammerspoon files.
- Keeps the v2.2 watchdog, safe polling, wake handlers, manual emergency recovery, and Screen Sharing detection.
- Adds a plain-text brightness snapshot for manual emergency restoration, and a persistent disable marker.
- Includes dedicated scripts to enable, disable, uninstall, and recover brightness.
- Defaults to a 15-second / 5%-brightness **first-run test**, not the black-screen production settings.
- Adds English and Russian documentation and a macOS CI syntax/compile check.

**Compatibility notice:** tested only by static review in this packaged form. Users must verify runtime behavior, input filtering, and remote desktop interaction on their own Mac before enabling 0%/10 minutes.