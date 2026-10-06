# Export behavior

## Selection and layers

The output uses the **rectangle surrounding the selection**, intersected with
the canvas. A selection entirely outside the canvas disables the command.
Partially overlapping selections are clipped to the canvas.

This is a crop of the visible artwork. For lasso, magic-wand, or disconnected
selections, unselected pixels inside the surrounding rectangle are included.
The extension does not apply the selection as a pixel mask.

Visible layers are composited by Aseprite's exporter. Hidden layers do not
appear in the result. The extension exports the area across visible layers,
not just the active layer.

## Frames and formats

| Format | Frames | Color handling |
| --- | --- | --- |
| PNG | Active frame only | Preserves supported transparency and the sprite's color mode. |
| JPG / JPEG | Active frame only | Converts indexed sprites to RGB on the temporary copy. JPEG does not support alpha. |
| GIF | All frames | Keeps frame durations; converts grayscale copies to RGB. GIF has limited colors and transparency. |

PNG and JPEG produce a single image even when the source contains multiple
frames. GIF exports the full timeline, including frames outside any selected
tag or frame range.

## Original document

The extension creates a temporary copy, crops it, clears the copied selection,
and exports from that copy. It closes temporary documents and restores the
original active sprite, frame, and layer.

Your original dimensions, pixels, selection, color mode, saved state, and undo
history are preserved. The source file cannot be chosen as the export destination.

## Destination and replacement

A missing file extension becomes `.png`. The parent folder must already exist,
and the file type must be PNG, GIF, JPG, or JPEG. The last successfully used
folder is remembered between Aseprite sessions.

Before replacing an existing file, the extension asks for confirmation. It
writes a temporary file in the destination folder, then opens that file to
check that it is readable and has the expected dimensions.

During replacement, the old output is renamed to a temporary backup. If moving
the new output into place fails, the extension attempts to restore the old file.
If recovery fails too, its error message identifies the backup location.

Normal completion removes temporary files. If Aseprite or the computer stops
mid-export, a `.quick-export-*` file may remain in the destination folder. A
`.bak` file contains the previous output. Check it before removing it.

Return to the [installation and usage guide](../README.md).
