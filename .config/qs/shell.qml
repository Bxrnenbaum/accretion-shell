import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      required property var modelData

      screen: modelData
      implicitHeight: 36

      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.exclusiveZone: 36

      visible: true
      color: "transparent"

      anchors {
        top: true
        left: true
        right: true
        bottom: false
      }

      margins {
        top: 4
        left: 8
        right: 8
      }

      property bool hasBattery: false

      Process {
        running: true
        command: ["test", "-f", "/sys/class/power_supply/BAT1/capacity"]
        onExited: code => hasBattery = (code === 0)
      }

      Rectangle {
        anchors.fill: parent
        color: "black"
        border.color: "#2a526e"
        radius: 12

      }
    }
  }
}
