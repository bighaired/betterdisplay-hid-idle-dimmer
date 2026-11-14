# Changelog

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