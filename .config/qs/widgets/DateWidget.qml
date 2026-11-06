import QtQuick
import Quickshell

import "../" as RootDir

Item {
  id: dateWidget

  property real bodyWidth: 140
  readonly property real cornerRadius: height / 2

  implicitHeight: 32
  implicitWidth: bodyWidth + cornerRadius * 2

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

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

    Text {
      anchors.centerIn: parent
      font.family: RootDir.Fonts.text
      font.pixelSize: 15
      font.bold: true
      color: RootDir.Theme.fg
      text: Qt.formatDateTime(clock.date, "dd MMM HH:mm")
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