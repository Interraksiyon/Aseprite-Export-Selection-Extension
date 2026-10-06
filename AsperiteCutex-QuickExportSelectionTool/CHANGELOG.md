# Changelog

## Unreleased

- Make the project source directly browsable on GitHub.
- Add an illustrated README, direct download and support links, and a short usage guide.
- Document export behavior separately and provide versioned release notes.
- Publish new versions and their packages after successful validation on `main`.
- Validate local Markdown links relative to each document's folder.
- Keep all text files in LF form when checked out on Windows.

## 1.1.0 — 2026-10-05

### Added

- MIT license with copyright credited to Interaksiyon, included in the extension.
- Clean source distribution and SHA-256 checksums alongside the extension package.
- Repository and archive validation, Lua syntax CI, and reproducible package timestamps.
- Contribution and release documentation, GitHub issue forms, and a pull request template.
- Regression tests for silent and partial writes, backup and replacement failures,
  and files created while an export is running.

### Fixed

- Failed saves can no longer report success because an older output file exists.
- Outputs are read back before replacement to reject unreadable or partial files.
- Existing output is backed up during replacement and restored if replacement fails.
- Directory paths are rejected before a default `.png` extension is appended.
- The command is disabled for selections wholly outside the canvas.
- Test runs use isolated configuration and clean up successful runs by default.

### Changed

- Project author and copyright metadata now identify Interaksiyon.
- README separates installation, usage, format behavior, and development guidance.

## 1.0.1 — 2026-10-05

- Translated extension menus, dialogs, messages, and documentation into English.
- Retained the command ID and preference keys for compatibility with existing installs.

## 1.0.0 — 2026-10-05

- Initial PNG, JPEG, and animated GIF export from rectangular selection bounds.
- Preserved the original sprite and restored its active frame and layer.
- Added overwrite confirmation, path validation, and remembered export folders.
- Added Aseprite integration tests and a PowerShell package builder.
