import QtQuick
import QtQuick.Shapes

// Keep the laser-pointer mark as a vector so the same shape can be used in
// the bar and at the live pointer head.
Item {
  id: root

  property color color: "#ffffff"
  property real iconSize: 20

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    rotation: 90
    transformOrigin: Item.Center

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: root.iconSize / 20 * 1.25
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      PathSvg {
        path: "m9.644 13.69 7.774-7.773a2.357 2.357 0 0 0-3.334-3.334l-7.773 7.774L8 12l1.643 1.69Z M13.25 3.417 16.583 6.75 M10 10 12 8 M5 15 8 12 M2.156 17.894 3.156 16.894 M5.453 19.029 5.309 17.622 M2.377 11.887 3.243 13.005 M8.354 17.273 7.16 16.515 M.953 14.652 2.361 14.782"
      }
    }
  }
}
