# Omarchy Laser Pointer

A presentation laser pointer for the Omarchy bar. It draws a short-lived,
fading, click-through trail behind cursor movement on every monitor, matching
the laser tool behavior in Excalidraw. While laser mode is on, Hyprland hides
the real cursor and the overlay renders the Excalidraw-shaped laser head, so
only one pointer is visible. Turning laser mode off restores the normal cursor.

## MVP controls

- Left-click the bar widget to open the controls.
- Choose red, orange, yellow, green, blue, purple, or white.
- Use **Turn on pointer** / **Turn off pointer** to control laser mode.
- Right-click the bar widget for a quick toggle.

The selected color is persisted in Omarchy's `shell.json`. The pointer state is
session-only and starts off after a shell restart.

## Install from GitHub

Once this repository is published:

```bash
omarchy plugin add https://github.com/kvm404/omarchy-laser-pointer.git --enable
```

The plugin declares the right side as its default bar section. To move it
explicitly:

```bash
omarchy plugin enable io.github.kvm404.laser-pointer --section right
```

## Local development

Copy the plugin files into Omarchy's user plugin directory, then rescan:

```bash
mkdir -p ~/.config/omarchy/plugins/io.github.kvm404.laser-pointer
cp -a omarchy-laser-pointer/manifest.json \
  omarchy-laser-pointer/Service.qml \
  omarchy-laser-pointer/Overlay.qml \
  omarchy-laser-pointer/BarWidget.qml \
  omarchy-laser-pointer/LaserIcon.qml \
  omarchy-laser-pointer/README.md \
  omarchy-laser-pointer/LICENSE \
  ~/.config/omarchy/plugins/io.github.kvm404.laser-pointer/
omarchy plugin validate ~/.config/omarchy/plugins/io.github.kvm404.laser-pointer
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.kvm404.laser-pointer --section right
```

The plugin is unsandboxed, like all Omarchy shell plugins. It reads the pointer
position with `hyprctl` and uses Hyprland's [`cursor:invisible`](https://wiki.hypr.land/Configuring/Basics/Variables/#cursor)
option while laser mode is active. This hides cursor surfaces supplied by
Wayland clients without changing input routing; turning the mode off sets the
option back to `false`.

## Visual reference

The bar icon and on-screen pointer head use the vector geometry from
Excalidraw's [`laserPointerToolIcon`](https://github.com/excalidraw/excalidraw/blob/master/packages/excalidraw/components/icons.tsx).
The trail is rendered as one continuous smoothed path so fast movement does
not create adjacent-looking strokes.

Hyprland's compositor-level cursor visibility switch is important here:
changing only the compositor theme cannot suppress a cursor surface already
provided by a client such as Chromium or GTK.

## Development checks

```bash
omarchy plugin validate omarchy-laser-pointer
qmllint -I "$OMARCHY_PATH/shell" \
  omarchy-laser-pointer/Service.qml \
  omarchy-laser-pointer/Overlay.qml \
  omarchy-laser-pointer/BarWidget.qml
```

## Current scope

This first version intentionally keeps the interaction small: one fading trail,
seven colors, a bar toggle, and multi-monitor placement. Keyboard shortcuts,
custom trail sizes, pressure-sensitive tapering, and publishing artwork can
follow after the local MVP is proven in real presentations.
