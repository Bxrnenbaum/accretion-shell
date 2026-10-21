import QtQuick
import QtQuick.Shapes
import "." as RootDir

Item {
  id: root
  required property int radius
  property color color: RootDir.Theme.bg
  property bool mirrored: false   // true for the right-hand side
  property real bleed: 1          // overlap into the attached object to hide seams

  width: radius
  height: radius
  antialiasing: true

  // mirror x coordinates instead of using a Scale transform
  function mx(x) { return mirrored ? radius - x : x }

  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    // fallback quality if the curve renderer isn't available
    layer.enabled: preferredRendererType !== Shape.CurveRenderer
    layer.samples: 8

    ShapePath {
      strokeWidth: 0
      fillColor: root.color
      joinStyle: ShapePath.RoundJoin

      startX: root.mx(-root.bleed); startY: -root.bleed
      PathLine { x: root.mx(root.radius); y: -root.bleed }
      PathLine { x: root.mx(root.radius); y: 0 }
      PathArc {
        x: root.mx(0); y: root.radius
        radiusX: root.radius; radiusY: root.radius
        direction: root.mirrored ? PathArc.Clockwise : PathArc.Counterclockwise
      }
      PathLine { x: root.mx(-root.bleed); y: root.radius }
      PathLine { x: root.mx(-root.bleed); y: -root.bleed }
    }
  }
}
