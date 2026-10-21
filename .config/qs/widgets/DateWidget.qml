import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import QtQuick.Effects

import "../" as RootDir

Item {
  id: dateWidget

  property real bodyWidth: 140
  readonly property real cornerRadius: height / 2

  implicitHeight: 32
  implicitWidth: bodyWidth + cornerRadius * 2

  Rectangle {
    id: bg
    x: dateWidget.cornerRadius
    width: dateWidget.bodyWidth
    height: parent.height

    color: RootDir.Theme.bg

    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: dateWidget.cornerRadius
    bottomRightRadius: dateWidget.cornerRadius

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
      color: RootDir.Theme.fg

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

  RootDir.ConcaveCorner {
    radius: dateWidget.cornerRadius
    color: bg.color
    mirrored: true
    x: 0
    y: 0
  }

  RootDir.ConcaveCorner {
    radius: dateWidget.cornerRadius
    color: bg.color
    x: dateWidget.width - dateWidget.cornerRadius
    y: 0
  }
}
