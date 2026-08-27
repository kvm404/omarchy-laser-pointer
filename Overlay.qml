import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  readonly property string pluginId: "io.github.kvm404.laser-pointer"
  readonly property string layerRuleCommand:
    "hl.layer_rule({ name = \"omarchy-laser-pointer-above-widgets\", "
    + "match = { namespace = \"" + root.pluginId + "\" }, order = -1000 })"
  property bool opened: false

  function open(payloadJson) {
    root.opened = true
    root.setCursorHidden(true)
    if (root.service) {
      root.service.active = true
    }
  }

  function close() {
    root.opened = false
    root.setCursorHidden(false)
    if (root.service) {
      root.service.active = false
    }
  }

  function setCursorHidden(hidden) {
    if (cursorVisibilityProcess.running) cursorVisibilityProcess.running = false

    cursorVisibilityProcess.command = [
      "hyprctl",
      "eval",
      "hl.config({ cursor = { invisible = " + (hidden ? "true" : "false") + " } })"
    ]
    cursorVisibilityProcess.running = true
  }

  // One passive layer-shell surface per output. The empty input region keeps
  // the pointer usable while the compositor hides the real cursor.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: pointerWindow
      required property var modelData
      screen: modelData
      visible: root.opened
      color: "transparent"
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      WlrLayershell.namespace: "io.github.kvm404.laser-pointer"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      readonly property var monitor: Hyprland.monitorFor(modelData)
      readonly property bool cursorOnMonitor: root.service && monitor
        && root.service.cursorX >= monitor.x
        && root.service.cursorX < monitor.x + pointerWindow.width
        && root.service.cursorY >= monitor.y
        && root.service.cursorY < monitor.y + pointerWindow.height

      Canvas {
        id: trailCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        function pointOnMonitor(point) {
          return pointerWindow.monitor && point.x >= pointerWindow.monitor.x
            && point.x < pointerWindow.monitor.x + pointerWindow.width
            && point.y >= pointerWindow.monitor.y
            && point.y < pointerWindow.monitor.y + pointerWindow.height
        }

        onPaint: {
          var context = getContext("2d")
          context.clearRect(0, 0, width, height)

          if (!root.opened || !root.service || !pointerWindow.monitor) return

          var points = root.service.trailPoints
          var now = Date.now()
          var lifetime = root.service.trailLifetimeMs
          var strokeColor = root.service.color
          var monitorX = pointerWindow.monitor.x
          var monitorY = pointerWindow.monitor.y

          context.lineCap = "round"
          context.lineJoin = "round"

          // Stroke each on-screen run once. The popup contains only the head;
          // keeping the trail in one canvas prevents overlapping paths when
          // the pointer reaches an output edge.
          var runStart = -1
          for (var i = 0; i <= points.length; i++) {
            var inRun = i < points.length && pointOnMonitor(points[i])
            if (inRun) {
              if (runStart < 0) runStart = i
              continue
            }

            if (runStart < 0) continue

            var runEnd = i - 1
            if (runEnd >= runStart) {
              var newest = points[runEnd]
              var fade = Math.max(0, 1 - (now - newest.time) / lifetime)
              if (fade > 0) {
                var first = points[runStart]
                context.beginPath()
                context.moveTo(first.x - monitorX, first.y - monitorY)

                if (runEnd === runStart) {
                  context.lineTo(first.x - monitorX, first.y - monitorY)
                } else {
                  for (var j = runStart + 1; j <= runEnd; j++) {
                    var current = points[j]
                    var next = j < runEnd ? points[j + 1] : current
                    var endX = j < runEnd ? (current.x + next.x) / 2 : current.x
                    var endY = j < runEnd ? (current.y + next.y) / 2 : current.y

                    context.quadraticCurveTo(
                      current.x - monitorX,
                      current.y - monitorY,
                      endX - monitorX,
                      endY - monitorY)
                  }
                }

                context.strokeStyle = Qt.rgba(
                  strokeColor.r,
                  strokeColor.g,
                  strokeColor.b,
                  fade * 0.92)
                context.lineWidth = 2.6
                context.stroke()
              }
            }

            runStart = -1
          }
        }

        Timer {
          interval: 33
          repeat: true
          running: root.opened
          onTriggered: trailCanvas.requestPaint()
        }

        Connections {
          target: root.service
          function onTrailPointsChanged() { trailCanvas.requestPaint() }
        }
      }

      // A bounded XDG popup follows the hotspot so the laser head remains above
      // Omarchy PopupCard windows without covering the screen with input.
      PopupWindow {
        id: pointerPopup
        visible: root.opened && root.service && root.service.cursorReady
          && pointerWindow.cursorOnMonitor
        color: "transparent"
        implicitWidth: 320
        implicitHeight: 320
        mask: Region {}

        parentWindow: pointerWindow
        relativeX: root.service && pointerWindow.monitor
          ? Math.max(0, Math.min(
              root.service.cursorX - pointerWindow.monitor.x - pointerPopup.implicitWidth / 2,
              Math.max(0, pointerWindow.width - pointerPopup.implicitWidth)))
          : 0
        relativeY: root.service && pointerWindow.monitor
          ? Math.max(0, Math.min(
              root.service.cursorY - pointerWindow.monitor.y - pointerPopup.implicitHeight / 2,
              Math.max(0, pointerWindow.height - pointerPopup.implicitHeight)))
          : 0

        // Keep the laser head at the real cursor hotspot. Service.qml hides the
        // compositor cursor while active, so this is the only visible pointer.
        LaserIcon {
          id: pointerIcon
          x: root.service && pointerWindow.monitor
            ? root.service.cursorX - pointerWindow.monitor.x - pointerPopup.relativeX
            : 0
          y: root.service && pointerWindow.monitor
            ? root.service.cursorY - pointerWindow.monitor.y - pointerPopup.relativeY
            : 0
          iconSize: 20
          color: "#ffffff"
        }

        Rectangle {
          x: pointerIcon.x + 1
          y: pointerIcon.y + 1
          width: 4
          height: width
          radius: width / 2
          color: root.service ? root.service.color : "#ff3b30"
          z: 3
        }
      }
    }
  }

  Process {
    id: layerOrderProcess
    command: ["hyprctl", "eval", root.layerRuleCommand]
  }

  Component.onCompleted: layerOrderProcess.running = true

  Process {
    id: cursorVisibilityProcess
    command: [
      "hyprctl",
      "eval",
      "hl.config({ cursor = { invisible = false } })"
    ]
  }

  Component.onDestruction: if (root.opened) {
    Quickshell.execDetached([
      "hyprctl",
      "eval",
      "hl.config({ cursor = { invisible = false } })"
    ])
  }
}
