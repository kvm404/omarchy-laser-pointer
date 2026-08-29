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

  // One layer-shell surface per output. It becomes an input shield only while
  // laser mode is active, so left-clicks belong to the laser instead of the
  // application underneath. The bar remains outside the shield so its widget
  // and popup controls stay usable.
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

      readonly property bool captureInput: root.opened && root.service
        && root.service.active && !root.service.trailSuppressed
      readonly property string barPosition: root.shell && root.shell.bar
        ? String(root.shell.bar.position || "top") : "top"
      readonly property int barSize: root.shell && root.shell.bar
        && !root.shell.bar.barHidden
        ? Math.max(0, Number(root.shell.bar.barSize) || 0) : 0

      // Keep the Omarchy bar clickable. When the popup opens, BarWidget sets
      // trailSuppressed and this region collapses so PopupCard receives input.
      Item {
        id: inputRegion
        x: !pointerWindow.captureInput ? 0
          : pointerWindow.barPosition === "left" ? pointerWindow.barSize : 0
        y: !pointerWindow.captureInput ? 0
          : pointerWindow.barPosition === "top" ? pointerWindow.barSize : 0
        width: !pointerWindow.captureInput ? 0
          : pointerWindow.barPosition === "left" || pointerWindow.barPosition === "right"
            ? Math.max(0, pointerWindow.width - pointerWindow.barSize)
            : pointerWindow.width
        height: !pointerWindow.captureInput ? 0
          : pointerWindow.barPosition === "top" || pointerWindow.barPosition === "bottom"
            ? Math.max(0, pointerWindow.height - pointerWindow.barSize)
            : pointerWindow.height
      }

      mask: Region { item: inputRegion }

      readonly property var monitor: Hyprland.monitorFor(modelData)
      readonly property bool cursorOnMonitor: root.service && monitor
        && root.service.cursorX >= monitor.x
        && root.service.cursorX < monitor.x + pointerWindow.width
        && root.service.cursorY >= monitor.y
        && root.service.cursorY < monitor.y + pointerWindow.height

      MouseArea {
        anchors.fill: inputRegion
        enabled: pointerWindow.captureInput
        acceptedButtons: Qt.LeftButton
        onPressed: function(mouse) {
          if (mouse.button === Qt.LeftButton && root.service)
            root.service.beginMouseDraw()
        }
        onReleased: function(mouse) {
          if (mouse.button === Qt.LeftButton && root.service)
            root.service.endMouseDraw()
        }
        onCanceled: if (root.service) root.service.endMouseDraw()
      }

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
          context.globalCompositeOperation = "source-over"
          context.shadowBlur = 0
          context.shadowColor = Qt.rgba(0, 0, 0, 0)

          if (!root.opened || !root.service || !pointerWindow.monitor) return

          var strokes = root.service.trailStrokes.slice()
          if (root.service.mouseHeld && root.service.currentTrailPoints.length > 0) {
            strokes.push({
              points: root.service.currentTrailPoints,
              fadeStartMs: 0,
              active: true
            })
          }
          var now = Date.now()
          var lifetime = root.service.trailLifetimeMs
          var strokeColor = root.service.color
          var monitorX = pointerWindow.monitor.x
          var monitorY = pointerWindow.monitor.y
          var thickness = Math.max(1, Number(root.service.thickness) || 3)

          context.lineCap = "round"
          context.lineJoin = "round"

          // Stroke each released/active stroke independently. This keeps a
          // new hold from erasing a previous stroke or connecting two strokes.
          for (var strokeIndex = 0; strokeIndex < strokes.length; strokeIndex++) {
            var stroke = strokes[strokeIndex]
            var points = stroke && stroke.points ? stroke.points : []
            if (points.length === 0) continue

            var fadeStartMs = Number(stroke.fadeStartMs) || 0
            var fade = fadeStartMs > 0
              ? Math.max(0, 1 - (now - fadeStartMs) / lifetime)
              : stroke.active ? 1.0 : 0
            if (fade <= 0) continue

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

                // Reuse the same smooth path for a soft halo, a saturated
                // beam, and a subtle hot center. The blurred additive pass
                // gives the colored edge a light-like falloff instead of a
                // stack of solid translucent lines.
                context.globalCompositeOperation = "lighter"
                context.shadowBlur = Math.min(18, thickness + 10)
                context.shadowColor = Qt.rgba(
                  strokeColor.r,
                  strokeColor.g,
                  strokeColor.b,
                  fade * 0.42)
                context.strokeStyle = Qt.rgba(
                  strokeColor.r,
                  strokeColor.g,
                  strokeColor.b,
                  fade * 0.18)
                context.lineWidth = thickness + 6
                context.stroke()

                context.shadowBlur = 0
                context.shadowColor = Qt.rgba(0, 0, 0, 0)
                context.strokeStyle = Qt.rgba(
                  strokeColor.r,
                  strokeColor.g,
                  strokeColor.b,
                  fade * 0.34)
                context.lineWidth = thickness + 2
                context.stroke()

                context.globalCompositeOperation = "source-over"
                context.strokeStyle = Qt.rgba(
                  strokeColor.r,
                  strokeColor.g,
                  strokeColor.b,
                  fade * 0.98)
                context.lineWidth = thickness
                context.stroke()

                context.strokeStyle = Qt.rgba(1, 1, 1, fade * 0.68)
                context.lineWidth = Math.max(1, thickness * 0.32)
                context.stroke()
              }

              runStart = -1
            }
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
          function onTrailStrokesChanged() { trailCanvas.requestPaint() }
          function onCurrentTrailPointsChanged() { trailCanvas.requestPaint() }
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
          contrastOutline: true
        }

        Rectangle {
          x: pointerIcon.x
          y: pointerIcon.y
          width: 6
          height: width
          radius: width / 2
          color: root.service ? root.service.color : "#ff3b30"
          border.color: "#101817"
          border.width: 1
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
