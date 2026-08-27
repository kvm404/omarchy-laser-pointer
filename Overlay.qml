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

          // Build one continuous path for each on-screen run. The previous
          // renderer stroked every curve section independently; at high
          // cursor speeds those differently-sized round caps could read as a
          // second line alongside the real trail.
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

      // The system cursor remains in control of the underlying application;
      // this vector head gives the active pointer the same visual language as
      // Excalidraw's laser cursor without stealing clicks from the presenter.
      LaserIcon {
        id: pointerIcon
        visible: root.opened && root.service && root.service.cursorReady
        x: root.service ? root.service.cursorX - pointerWindow.monitor.x : 0
        y: root.service ? root.service.cursorY - pointerWindow.monitor.y : 0
        iconSize: 20
        color: "#ffffff"
        z: 2
      }

      Rectangle {
        visible: pointerIcon.visible
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
