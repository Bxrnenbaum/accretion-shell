import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import "../" as RootDir

Item {
  id: batteryWidget

  property int capacity: 0
  property string status: ""
  readonly property bool charging: status === "Charging"

  property real bodyWidth: 80
  readonly property real cornerRadius: height / 2

  implicitHeight: 32
  implicitWidth: bodyWidth + cornerRadius * 2

  Rectangle {
    id: bg
    x: batteryWidget.cornerRadius
    width: batteryWidget.bodyWidth
    height: parent.height

    color: RootDir.Theme.bg

    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: batteryWidget.cornerRadius
    bottomRightRadius: batteryWidget.cornerRadius

    Text {
      anchors.centerIn: parent
      font.family: RootDir.Fonts.text
      font.pixelSize: 16
      color: RootDir.Theme.fg
      text: (batteryWidget.charging ? "⚡ " : "") + batteryWidget.capacity + "%"
    }
  }

  RootDir.ConcaveCorner {
    radius: batteryWidget.cornerRadius
    color: bg.color
    mirrored: true
    x: 0
    y: 0
  }

  RootDir.ConcaveCorner {
    radius: batteryWidget.cornerRadius
    color: bg.color
    x: batteryWidget.width - batteryWidget.cornerRadius
    y: 0
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
}
