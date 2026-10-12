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
      implicitHeight: Math.max(38, leftRow.height)

      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.exclusiveZone: 32

      visible: true
      color: "transparent"

      anchors {
        top: true
        left: true
        right: true
        bottom: false
      }

      property bool hasBattery: false

      Process {
        running: true
        command: ["sh", "-c", `
        for d in /sys/class/power_supply/*; do
        [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] || continue
        [ "$(cat "$d/scope" 2>/dev/null)" = "Device" ] && continue
        exit 0
        done
        exit 1
        `]
        onExited: code => hasBattery = (code === 0)
      }

      mask: Region {
        Region { item: leftRow }
        Region { item: rightRow }
      }

      Row {
        id: rightRow
        anchors {
          top: parent.top
          right: parent.right
          rightMargin: 16
        }
        spacing: 60   // spacing > 2 * radius

        WeatherWidget {}
        DateWidget {}
      }

      Row {
        id: leftRow
        anchors {
          top: parent.top
          left: parent.left
          leftMargin: 16
        }
        spacing: 60

        BatteryWidget { visible: hasBattery }
        MusicWidget {

        }
      }
    }
  }
}
