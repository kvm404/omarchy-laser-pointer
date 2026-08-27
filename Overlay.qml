import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  readonly property string pluginId: "io.github.kvm404.laser-pointer"
  property bool opened: false

  function open(payloadJson) {
    root.opened = true
    if (root.service) root.service.active = true
  }

  function close() {
    root.opened = false
    if (root.service) root.service.active = false
  }

  // One passive layer-shell surface per output. An empty input region is
  // essential: the pointer must remain usable while presenting.
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
      Canvas {
        id: trailCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        function pointOnMonitor(point) {
          return pointerWindow.monitor && point.x >= pointerWindow.monitor.x
            && point.x < pointerWindow.monitor.x + pointerWindow.monitor.width
            && point.y >= pointerWindow.monitor.y
            && point.y < pointerWindow.monitor.y + pointerWindow.monitor.height
        }

        function easeOut(value) {
          var clamped = Math.max(0, Math.min(1, value))
          return 1 - Math.pow(1 - clamped, 2)
        }

        onPaint: {
          var context = getContext("2d")
          context.clearRect(0, 0, width, height)

          if (!root.opened || !root.service || !pointerWindow.monitor) return

          var points = root.service.trailPoints
          var now = Date.now()
          var lifetime = root.service.trailLifetimeMs
          var strokeColor = root.service.color

          context.lineCap = "round"
          context.lineJoin = "round"

          for (var i = 1; i < points.length; i++) {
            var previous = points[i - 1]
            var control = points[i]
            if (!pointOnMonitor(previous) || !pointOnMonitor(control)) continue

            var age = Math.max(0, now - control.time)
            var fade = Math.max(0, 1 - age / lifetime)
            if (fade <= 0) continue

            // Excalidraw's trail tapers from the oldest point toward the
            // current cursor head. Midpoints plus quadratic curves keep the
            // result smooth even though cursorpos is sampled at 30 Hz.
            var startX = i === 1 ? previous.x : (points[i - 2].x + previous.x) / 2
            var startY = i === 1 ? previous.y : (points[i - 2].y + previous.y) / 2
            var endX = i === points.length - 1 ? control.x : (control.x + points[i + 1].x) / 2
            var endY = i === points.length - 1 ? control.y : (control.y + points[i + 1].y) / 2
            var lengthFade = easeOut(i / Math.max(1, points.length - 1))
            var strength = Math.min(fade, lengthFade)

            context.beginPath()
            context.moveTo(startX - pointerWindow.monitor.x, startY - pointerWindow.monitor.y)
            context.quadraticCurveTo(
              control.x - pointerWindow.monitor.x,
              control.y - pointerWindow.monitor.y,
              endX - pointerWindow.monitor.x,
              endY - pointerWindow.monitor.y)
            context.strokeStyle = Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, strength)
            context.lineWidth = 0.7 + strength * 2.4
            context.stroke()
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
    }
  }
}
