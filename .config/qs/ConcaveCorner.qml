import "." as RootDir
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property int radius
    property color color: RootDir.Theme.bg
    property RootDir.MirrorAxes mirror: RootDir.MirrorAxes {}
    property real bleed: 1 // overlap into the attached object to hide seams

    function mx(x) {
        return mirror.x ? radius - x : x;
    }

    function my(y) {
        return mirror.y ? radius - y : y;
    }

    width: radius
    height: radius
    antialiasing: true

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        // fallback quality if the curve renderer isnt available
        layer.enabled: preferredRendererType !== Shape.CurveRenderer
        layer.samples: 8

        ShapePath {
            strokeWidth: 0
            fillColor: root.color
            joinStyle: ShapePath.RoundJoin
            startX: root.mx(-root.bleed)
            startY: root.my(-root.bleed)

            PathLine {
                x: root.mx(root.radius)
                y: root.my(-root.bleed)
            }

            PathLine {
                x: root.mx(root.radius)
                y: root.my(0)
            }

            PathArc {
                x: root.mx(0)
                y: root.my(root.radius)
                radiusX: root.radius
                radiusY: root.radius
                direction: root.mirror.x !== root.mirror.y ? PathArc.Clockwise : PathArc.Counterclockwise
            }

            PathLine {
                x: root.mx(-root.bleed)
                y: root.my(root.radius)
            }

            PathLine {
                x: root.mx(-root.bleed)
                y: root.my(-root.bleed)
            }

        }

    }

}
