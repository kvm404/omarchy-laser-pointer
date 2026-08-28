# Omarchy Laser Pointer

An Excalidraw-style laser pointer for presentations and screen sharing on
Omarchy.

![Omarchy Laser Pointer preview](preview.png)

## Features

- Fading trail that follows pointer movement
- Excalidraw-style laser head
- Hides the normal cursor while laser mode is on
- Eight presentation-friendly colors
- Multi-monitor support
- Click-through overlay that does not block the screen

## Use

- Left-click the laser icon in the Omarchy bar to open the controls.
- Choose a color and click **Turn on pointer**.
- Right-click the laser icon to toggle laser mode quickly.
- Click **Turn off pointer** to restore the normal cursor.

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
