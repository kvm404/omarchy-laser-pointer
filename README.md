# Omarchy Laser Pointer

A presentation laser pointer for the Omarchy bar. It draws a visible,
click-through reticle at the current cursor position on every monitor, so it
can be used while screensharing or presenting without stealing input from the
application underneath.

## MVP controls

- Left-click the bar widget to open the controls.
- Choose red, orange, yellow, green, blue, purple, or white.
- Use **Turn on pointer** / **Turn off pointer** to control the overlay.
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

Copy the plugin directory into Omarchy's user plugin directory, then rescan:

```bash
mkdir -p ~/.config/omarchy/plugins/io.github.kvm404.laser-pointer
cp -a omarchy-laser-pointer/. ~/.config/omarchy/plugins/io.github.kvm404.laser-pointer/
omarchy plugin validate ~/.config/omarchy/plugins/io.github.kvm404.laser-pointer
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.kvm404.laser-pointer --section right
```

The plugin is unsandboxed, like all Omarchy shell plugins. This MVP only uses
the installed `hyprctl` command to read the pointer position and has no
additional runtime dependency.

## Development checks

```bash
omarchy plugin validate omarchy-laser-pointer
qmllint -I "$OMARCHY_PATH/shell" \
  omarchy-laser-pointer/Service.qml \
  omarchy-laser-pointer/Overlay.qml \
  omarchy-laser-pointer/BarWidget.qml
```

## Current scope

This first version intentionally keeps the interaction small: one reticle,
seven colors, a bar toggle, and multi-monitor placement. Keyboard shortcuts,
trails, custom sizes, and publishing artwork can follow after the local MVP is
proven in real presentations.
