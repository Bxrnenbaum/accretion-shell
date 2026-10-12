import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import QtQuick.Effects

import "../" as RootDir

Item {
  id: dateWidget

  implicitHeight: 32
  implicitWidth: 140

  Rectangle {
    id: bg
    anchors.fill: parent

    color: "#0b1b26"

    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: height / 2
    bottomRightRadius: height / 2

    Behavior on border.color {
      ColorAnimation { duration: 100 }
    }

    HoverHandler { id: hoverHandler }

    Text {
      id: clock
      anchors.centerIn: parent
      font.family: RootDir.Fonts.text
      font.pixelSize: 15
      font.bold: true
      color: "#F2E8D5"
 
      Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: dateProcess.running = true
      }

      Process {
        id: dateProcess
        command: ["date", "+%d %b %H:%M"]
        running: false
        stdout: StdioCollector {
          onStreamFinished: clock.text = this.text.trim()
        }
      }
    }
  }

  // siblings of bg, so the shadow layer doesn't clip them
  RootDir.ConcaveCorner {
    radius: dateWidget.height / 2 + 1
    color: bg.color
    mirrored: true
    x: -width
    y: 0
  }

  RootDir.ConcaveCorner {
    radius: dateWidget.height / 2 + 1
    color: bg.color
    x: dateWidget.width
    y: 0
  }
}
