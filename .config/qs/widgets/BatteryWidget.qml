import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import QtQuick.Effects

import "../" as RootDir

Item {
  id: batteryWidget

  property int capacity: 0
  property string status: ""
  readonly property bool charging: status === "Charging"

  implicitHeight: 32
  implicitWidth: 80

  Rectangle {
    id: bg
    anchors.fill: parent

    color: "#0b1b26"

    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: height / 2
    bottomRightRadius: height / 2

    Text {
      anchors.centerIn: parent
      font.family: RootDir.Fonts.text
      font.pixelSize: 16
      color: "#F2E8D5"
      text: (batteryWidget.charging ? "⚡ " : "") + batteryWidget.capacity + "%"
    }

    Timer {
      interval: 30000
      running: true
      repeat: true
      triggeredOnStart: true
      onTriggered: batteryProcess.running = true
    }

    Process {
      id: batteryProcess

      command: ["sh", "-c", `
      for d in /sys/class/power_supply/*; do
      [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] || continue
      [ "$(cat "$d/scope" 2>/dev/null)" = "Device" ] && continue
      cat "$d/capacity" "$d/status"
      exit 0
      done
      exit 1
      `]

      stdout: StdioCollector {
        onStreamFinished: {
          const lines = this.text.trim().split("\n");
          const cap = parseInt(lines[0]);
          if (!isNaN(cap)) {
            batteryWidget.capacity = cap;
            batteryWidget.status = lines[1] ?? "";
          }
        }
      }
    }

    RootDir.ConcaveCorner {
      radius: batteryWidget.height / 2
      color: bg.color
      mirrored: true
      x: -width
      y: 0
    }

    RootDir.ConcaveCorner {
      radius: batteryWidget.height / 2
      color: bg.color
      x: batteryWidget.width
      y: 0
    }
  }
}
