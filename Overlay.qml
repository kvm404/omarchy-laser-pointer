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
      visible: root.opened && root.service && root.service.cursorReady
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
      readonly property bool cursorOnMonitor: monitor && root.service
        && root.service.cursorX >= monitor.x
        && root.service.cursorX < monitor.x + monitor.width
        && root.service.cursorY >= monitor.y
        && root.service.cursorY < monitor.y + monitor.height
      readonly property real localCursorX: root.service ? root.service.cursorX - (monitor ? monitor.x : 0) : 0
      readonly property real localCursorY: root.service ? root.service.cursorY - (monitor ? monitor.y : 0) : 0

      Item {
        id: pointer
        visible: pointerWindow.cursorOnMonitor
        x: pointerWindow.localCursorX - width / 2
        y: pointerWindow.localCursorY - height / 2
        width: 38
        height: 38

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: "transparent"
          border.width: 2
          border.color: "#ffffff"
          opacity: 0.92
        }

        Rectangle {
          anchors.fill: parent
          anchors.margins: 3
          radius: width / 2
          color: "transparent"
          border.width: 3
          border.color: root.service ? root.service.color : "#ff3b30"
          opacity: 0.98
        }

        Rectangle {
          anchors.centerIn: parent
          width: 10
          height: 10
          radius: width / 2
          color: root.service ? root.service.color : "#ff3b30"
          border.width: 1
          border.color: "#ffffff"
        }

        Rectangle {
          anchors.centerIn: parent
          width: 2
          height: 2
          radius: 1
          color: "#ffffff"
        }
      }
    }
  }
}
