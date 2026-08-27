import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // Injected by omarchy-shell when the service is created.
  property var shell: null
  property var manifest: null

  readonly property string pluginId: "io.github.kvm404.laser-pointer"
  readonly property string home: Quickshell.env("HOME")
  readonly property string cursorThemeName: "OmarchyLaserPointer"
  readonly property string cursorThemeDir: root.home + "/.local/share/icons/" + root.cursorThemeName
  readonly property string cursorSourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir) + "/cursor"
    : ""
  property bool active: false
  property color color: "#ff3b30"
  property int cursorX: 0
  property int cursorY: 0
  property bool cursorReady: false
  property bool nativeCursorReady: false
  property var trailPoints: []
  readonly property int trailLifetimeMs: 1000

  function toggle() {
    if (root.shell && typeof root.shell.toggle === "function") {
      root.shell.toggle(root.pluginId, "{}")
      return
    }

    // Makes the service harmless to instantiate outside the shell while
    // developing or linting the plugin.
    root.active = !root.active
  }

  function refreshCursor() {
    if (!cursorProcess.running) cursorProcess.running = true
  }

  function appendTrailPoint(x, y) {
    var now = Date.now()
    var next = root.trailPoints.slice()

    while (next.length > 0 && now - next[0].time > root.trailLifetimeMs)
      next.shift()

    next.push({ x: x, y: y, time: now })
    root.trailPoints = next
  }

  function clearTrail() {
    root.trailPoints = []
  }

  function enableNativeCursor() {
    if (!root.cursorSourceDir) {
      console.warn("laser pointer: plugin source directory is unavailable")
      return
    }

    root.nativeCursorReady = false
    cursorThemeInstallProcess.running = true
  }

  function restoreNativeCursor() {
    root.nativeCursorReady = false
    cursorRestoreProcess.running = true
  }

  function updateCursor(raw) {
    var output = String(raw || "").trim()
    if (!output) return

    try {
      var position = JSON.parse(output)
      if (position && isFinite(Number(position.x)) && isFinite(Number(position.y))) {
        var nextX = Math.round(Number(position.x))
        var nextY = Math.round(Number(position.y))
        var moved = root.cursorReady && (nextX !== root.cursorX || nextY !== root.cursorY)

        root.cursorX = nextX
        root.cursorY = nextY
        root.cursorReady = true

        // Excalidraw leaves ink only while the pointer is moving. The normal
        // system cursor remains visible at the current head position.
        if (root.active && moved) root.appendTrailPoint(nextX, nextY)
      }
    } catch (error) {
      // Keep the last valid position. A transient hyprctl failure should not
      // make the pointer disappear between two successful samples.
    }
  }

  Timer {
    interval: 33
    repeat: true
    running: root.active
    onTriggered: root.refreshCursor()
  }

  Process {
    id: cursorProcess
    command: ["hyprctl", "-j", "cursorpos"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateCursor(text)
    }

    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.cursorReady) root.cursorReady = false
    }
  }

  // Hyprcursor searches user icon directories, so install the bundled theme
  // into the user-owned icon directory before asking Hyprland to load it.
  Process {
    id: cursorThemeInstallProcess
    command: [
      "bash",
      "-c",
      "mkdir -p -- \"$1\" && cp -a -- \"$2/.\" \"$1/\"",
      "laser-pointer-theme-install",
      root.cursorThemeDir,
      root.cursorSourceDir
    ]

    onExited: function(exitCode) {
      if (exitCode !== 0 || !root.active) return
      cursorApplyProcess.running = true
    }
  }

  Process {
    id: cursorApplyProcess
    command: ["hyprctl", "setcursor", root.cursorThemeName, "24"]

    onExited: function(exitCode) {
      root.nativeCursorReady = exitCode === 0 && root.active
    }
  }

  // `setcursor` is a compositor-wide change. A config reload restores the
  // user’s configured cursor theme, including the normal XCursor fallback.
  Process {
    id: cursorRestoreProcess
    command: ["hyprctl", "reload"]

    onExited: function() {
      root.nativeCursorReady = false
    }
  }

  onActiveChanged: {
    if (root.active) {
      root.refreshCursor()
      root.enableNativeCursor()
    } else {
      root.clearTrail()
      root.restoreNativeCursor()
    }
  }

  Component.onDestruction: if (root.nativeCursorReady) Quickshell.execDetached(["hyprctl", "reload"])
}
