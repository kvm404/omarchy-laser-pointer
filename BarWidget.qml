import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.kvm404.laser-pointer"

  readonly property var laserService: bar?.shell?.serviceFor(root.moduleName)
  readonly property var palette: [
    "#ff3b30", // red
    "#ff9500", // orange
    "#ffd60a", // yellow
    "#30d158", // green
    "#0a84ff", // blue
    "#64d2ff", // cyan
    "#bf5af2", // purple
    "#ffffff"  // white
  ]
  readonly property color selectedColor: laserService
    ? laserService.color
    : setting("color", "#ff3b30")
  property bool popupOpen: false

  function syncSettings() {
    var configured = setting("color", "")
    if (laserService && configured !== "") laserService.color = configured
  }

  function persistColor(value) {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.color = value

    // Update the live service before writing shell.json so the overlay changes
    // on the same click as the swatch.
    if (laserService) laserService.color = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function togglePointer() {
    if (laserService) laserService.toggle()
  }

  function close() {
    root.popupOpen = false
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: syncSettings()
  onSettingsChanged: syncSettings()
  onLaserServiceChanged: syncSettings()

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedWidth: Style.bar.iconSlot
    fixedHeight: Style.bar.iconSlot
    active: root.laserService ? root.laserService.active : false
    useActiveColor: false
    tooltipText: "Laser pointer · " + (active ? "ON" : "OFF")

    onPressed: function(buttonId) {
      if (buttonId === Qt.RightButton) root.togglePointer()
      else if (buttonId === Qt.LeftButton) root.popupOpen = !root.popupOpen
    }

    Item {
      anchors.centerIn: parent
      width: Style.space(20)
      height: width

      LaserIcon {
        anchors.fill: parent
        color: button.foreground
        opacity: root.laserService && root.laserService.active ? 1 : 0.62
      }

      // The cursor has a small coloured laser head at the hotspot.
      Rectangle {
        x: Style.space(1)
        y: Style.space(1)
        width: Style.space(3)
        height: width
        radius: width / 2
        color: root.selectedColor
        opacity: root.laserService && root.laserService.active ? 1 : 0.85
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(236))
    contentHeight: popup.fittedContentHeight(panelColumn.implicitHeight)

    Column {
      id: panelColumn
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(10)
          height: width
          radius: width / 2
          color: root.selectedColor
          border.width: 1
          border.color: "#ffffff"
        }

        Column {
          width: parent.width - Style.space(18)
          spacing: Style.space(2)

          Text {
            text: "LASER POINTER"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      Button {
        width: parent.width
        text: root.laserService && root.laserService.active ? "Turn off pointer" : "Turn on pointer"
        foreground: root.bar.foreground
        accent: root.selectedColor
        bordered: true
        onClicked: root.togglePointer()
      }

      PanelSeparator { foreground: root.bar.foreground }

      Text {
        text: "COLOUR"
        color: root.bar.foreground
        opacity: 0.7
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(4 * 28 + 3 * 6)
        columns: 4
        spacing: Style.space(6)

        Repeater {
          model: root.palette

          Button {
            required property string modelData
            width: Style.space(28)
            height: width
            horizontalPadding: 0
            verticalPadding: 0
            foreground: modelData
            accent: modelData
            bordered: true
            selected: String(root.selectedColor).toLowerCase() === String(modelData).toLowerCase()
            tooltipText: modelData
            onClicked: root.persistColor(modelData)

            Rectangle {
              anchors.centerIn: parent
              width: Style.space(16)
              height: width
              radius: width / 2
              color: modelData
              border.width: modelData === "#ffffff" ? 1 : 0
              border.color: "#ffffff"
            }
          }
        }
      }
    }
  }
}
