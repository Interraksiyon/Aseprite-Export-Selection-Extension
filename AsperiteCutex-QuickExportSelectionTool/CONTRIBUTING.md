# Contributing

Thank you for contributing to Quick Export Selection, maintained by Interaksiyon.
Issues and pull requests are welcome. Keep changes focused and explain the
behavior that changes for someone using the extension.

## Project layout

```text
main.lua                 Aseprite command, dialog, and export logic
package.json             Extension metadata
LICENSE                  MIT license and copyright notice
build.ps1                Extension and clean source packages
test.ps1                 Local Aseprite test runner
scripts/check.ps1        Metadata, formatting, and package checks
scripts/source-files.ps1 Source distribution file list
tests/integration.lua    Tests using real Aseprite sprites and encoders
docs/                    Export details, banner, and versioned release notes
.github/                 CI, issue forms, and pull request template
```

Keep the extension self-contained in `main.lua`. Build and test tools belong
outside the installed extension. Use the formatting in [.editorconfig](.editorconfig):
UTF-8, LF line endings, two spaces for Lua, and four spaces for PowerShell.
When adding project files, update `scripts/source-files.ps1` to include them in
the source distribution.

## Validate and build

In a PowerShell terminal at the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1 -Packages
```

If Lua 5.4 is installed, check syntax with:

```text
luac -p main.lua
luac -p tests/integration.lua
```

GitHub Actions performs these syntax checks automatically, along with repository
and package validation. Validation jobs use read-only permissions. The release
job runs only after validation on `main` and uses contents-write permission to
publish a version that does not already have a release.

## Aseprite integration tests

Use your own Aseprite installation; Aseprite is not bundled or fetched by CI.
The Windows runner automatically checks PATH and common installation locations,
or accepts an explicit path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test.ps1 -AsepritePath 'C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe'
```

Normal exports use real sprites and encoders with simulated dialog input.
Failure conditions are injected to exercise write and replacement errors.
They cover frame selection, visibility, timing, color modes, cancellation,
validation, document preservation, and failed writes and file replacements.
They do not exercise the visual dialog or extension installation.

Successful runs clean up their generated configuration and output directories.
Failed runs keep their files for inspection. To retain a successful run, add
`-KeepArtifacts` to the command.

For GUI changes, also install the generated extension, open a sprite, make a
selection, and check the menu command, file picker, Save/Cancel buttons, and
keyboard shortcut in Aseprite. Report the operating system and Aseprite version
used for validation in your pull request.

## Report a problem

Include the extension and Aseprite versions, operating system, export format,
steps to reproduce, and the error message or unexpected output. Attach a small
sample sprite if it helps and you have permission to share it.

## Prepare a release

1. Update `version` in `package.json`, the package examples in README, and
   [CHANGELOG.md](CHANGELOG.md). Add `docs/releases/v<version>.md` with the release
   notes and include it in `scripts/source-files.ps1`.
2. Run the repository checks, integration tests, build, and package checks above.
3. Merge the source changes into `main`. After validation succeeds, the workflow
   creates the `v<version>` tag at that commit and publishes the extension,
   source archive, and checksums using the versioned release notes.
4. Check the release assets and installation instructions. Published versions
   are never overwritten automatically; fix a shipped version with a new version.

You can also run **Validate and package** manually from the repository's
[Actions page](https://github.com/Interraksiyon/Aseprite-Export-Selection-Extension/actions/workflows/ci.yml).
The release job only publishes when the selected branch is `main` and the
version has no release yet. Pushes to other branches and pull requests validate
and upload build artifacts without publishing.

Keep `dist/` and generated test directories out of the repository. The release
checksum file uses the standard `SHA256  filename` format. On Windows, compare
a downloaded file's hash using `Get-FileHash -Algorithm SHA256 <file>`.

## License

Contributions to this project are distributed under its [MIT License](LICENSE).
Retain the Interaksiyon copyright notice and add appropriate notices for any
new third-party code you introduce.

## Aseprite API references

- [Plugin registration](https://www.aseprite.org/api/plugin/)
- [Sprite API](https://www.aseprite.org/api/sprite/)
- [Dialog API](https://www.aseprite.org/api/dialog/)
- [Filesystem API](https://www.aseprite.org/api/app_fs/)
