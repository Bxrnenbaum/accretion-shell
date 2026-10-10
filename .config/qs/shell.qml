import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "widgets"

ShellRoot {
  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      required property var modelData

      screen: modelData
      implicitHeight: 30

      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.exclusiveZone: 24

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
        left: 5
        right: 5
      }

      property bool hasBattery: false

      Process {
        running: true
        command: ["test", "-f", "/sys/class/power_supply/BAT1/capacity"]
        onExited: code => hasBattery = (code === 0)
      }


      BatteryWidget {
        visible: hasBattery

        anchors {
          left: parent.left
          top: parent.top
          leftMargin: 2
        }
      }
    }
  }
}
