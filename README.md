# Omarchy Laser Pointer

A laser pointer for presentations and screen sharing on Omarchy.

![Omarchy Laser Pointer preview](preview.png)

## Features

- Fading trail drawn only while the left mouse button is held
- Laser head positioned at the pointer hotspot
- Hides the normal cursor while laser mode is on
- Eight presentation-friendly colors
- Adjustable trail thickness
- Multi-monitor support
- Click-through overlay that does not block the screen

## Use

- Left-click the laser icon in the Omarchy bar to open the controls.
- Choose a color and click **Turn on pointer**.
- Adjust the trail thickness with the slider.
- Right-click the laser icon to toggle laser mode quickly.
- Click **Turn off pointer** to restore the normal cursor.

## Enable click-to-draw

The click-through overlay cannot receive global mouse events directly on
Wayland. To enable drawing while holding left-click, add these static bindings
to `~/.config/hypr/bindings.lua`:

```lua
o.bind(
  "mouse:272",
  "Laser pointer draw (press)",
  "omarchy-shell -q io.github.kvm404.laser-pointer mouseDown",
  { mouse = true, non_consuming = true }
)

o.bind(
  "mouse:272",
  "Laser pointer draw (release)",
  "omarchy-shell -q io.github.kvm404.laser-pointer mouseUp",
  { mouse = true, release = true, non_consuming = true }
)
```

Then reload and validate Hyprland:

```bash
hyprctl reload
hyprctl configerrors
```

These bindings are intentionally user-owned. The plugin does not edit
Hyprland configuration, run `hyprctl repl`, or install/remove bindings while
the shell is running. `non_consuming` keeps the original click available to
the application, including the laser popup controls.

Without these optional bindings, the laser head still works, but the trail
does not draw.

## Install

```bash
omarchy plugin add https://github.com/kvm404/omarchy-laser-pointer.git --enable
```

The plugin appears on the right side of the bar by default. To enable it in a
different section:

```bash
omarchy plugin enable io.github.kvm404.laser-pointer --section right
```

## Remove

```bash
omarchy plugin remove io.github.kvm404.laser-pointer
```

## License

MIT
