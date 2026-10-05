# Quick Export Selection

[![Build](https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension/actions/workflows/ci.yml/badge.svg)](https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Interraksiyon/Aseprite-Export-Selection-Extension?color=62c7a8)](https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension/releases/latest)
[![MIT License](https://img.shields.io/badge/license-MIT-9580e4.svg)](LICENSE)
![Aseprite 1.3+](https://img.shields.io/badge/Aseprite-1.3%2B-f38b71.svg)

**Export a selected area without changing your sprite.** An open-source Aseprite
extension by [Interaksiyon](https://github.com/Interraksiyon), with English menus,
a save dialog, and support for your own keyboard shortcut.

**[Download the extension](https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension/releases/latest)**
&nbsp;&middot;&nbsp; [Installation](#install)
&nbsp;&middot;&nbsp; [How to use](#export-in-three-steps)
&nbsp;&middot;&nbsp; [Report a bug](https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension/issues/new?template=bug_report.yml)

## A small tool for everyday exports

- **PNG or JPEG:** export the active frame as a single image.
- **Animated GIF:** export the selected area across all frames, with frame timing.
- **Fewer clicks:** open the command from the menu or assign a keyboard shortcut.
- **Your work stays intact:** preserve the original sprite, selection, and undo history.
- **A useful save dialog:** remember the last export folder and confirm replacements.

The illustration above shows the crop workflow; it is not an Aseprite screenshot.

## Install

Requires **Aseprite 1.3 or later** with Lua scripting support.

1. Open the [latest release](https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension/releases/latest)
   and download **`quick-export-selection-1.1.0.aseprite-extension`** from **Assets**.
2. In Aseprite, choose **Edit > Preferences > Extensions > Add Extension** and
   select that file.
3. Confirm installation and check that the extension is enabled. Restart
   Aseprite if its command does not appear.

You can also double-click the package on Windows or macOS. Use the
`.aseprite-extension` asset for installation; GitHub's source archives are for
development. See [Aseprite's extension guide](https://www.aseprite.org/docs/extensions/)
for the application settings.

Updating keeps the command ID used by existing keyboard shortcuts.

## Export in three steps

| 1. Select | 2. Open the command | 3. Save |
| --- | --- | --- |
| Open a sprite and select an area with a selection tool. | Choose **File > Export > Export Selection**. | Pick a destination and file name, then click **Save**. |

A file name without an extension defaults to `.png`.

### Set up a keyboard shortcut

Open **Edit > Keyboard Shortcuts > Commands**, search for **Export Selection**,
and assign an available key combination. You can then select an area, press
your shortcut, and choose where to save it.

### Choose an output format

| Format | What is exported | Transparency |
| --- | --- | --- |
| **PNG** | Active frame | Preserved |
| **JPG / JPEG** | Active frame | Not supported by JPEG |
| **GIF** | All frames, with their durations | Subject to GIF's color and transparency limits |

The export includes **visible layers** inside the rectangle surrounding the
selection, clipped to the canvas. Lasso and magic-wand selections still produce
a rectangular crop, including unselected pixels inside that rectangle.
Read [export behavior](docs/EXPORT_BEHAVIOR.md) for frame, color, and file handling details.

## Troubleshooting

| Problem | Try this |
| --- | --- |
| Command is missing | Enable the extension in Preferences, then restart Aseprite. |
| Command is disabled | Open a sprite and select an area that overlaps its canvas. |
| Export fails | Choose an existing, writable folder and a `.png`, `.gif`, `.jpg`, or `.jpeg` file name. |
| Shortcut does not work | Check its assignment and conflicts in Keyboard Shortcuts. |
| JPEG loses transparency or GIF changes colors | Choose PNG when you need full-color transparency in a still image. |

Still stuck? [Open a bug report](https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension/issues/new?template=bug_report.yml)
with your Aseprite version, operating system, and export format.

## Build and contribute

Clone the repository, then build in PowerShell 5.1 or later:

```powershell
git clone https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension.git
cd Aseprite-Export-Selection-Extension
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

The build produces an installer, a source ZIP, and `SHA256SUMS.txt` in `dist/`.
No npm or Lua packages are needed to build. Source files are directly available
in the repository, and generated archives belong in Releases.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for validation, local Aseprite tests, and
release instructions. Browse the [changelog](CHANGELOG.md),
[suggest a feature](https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension/issues/new?template=feature_request.yml),
or [open a pull request](https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension/pulls).

GitHub Actions checks Lua syntax, validates the source, and verifies the built
packages. After a successful build on `main`, it publishes a release if the
version has not been released already. Existing releases are left intact.

The **21 local integration tests** use a real Aseprite installation and cover
exports, format conversion, document preservation, and failure recovery.
Tested on **Windows with Aseprite 1.3.18.6**. macOS and Linux GUI behavior has
not been verified; contributions from those platforms are welcome.

## Open source

**Copyright (c) 2026 Interaksiyon.** This project is available under the
[MIT License](LICENSE). You may use, modify, and redistribute it, including
commercially, while retaining the copyright and license notice.

Aseprite is a separate application and is not included in this project.
