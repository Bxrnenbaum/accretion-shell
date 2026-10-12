import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

PanelWindow {
  id: musicPlayer

  implicitWidth: 300
  implicitHeight: 300

  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    left: true
  }

  margins {
    top: 40
    left: 100
  }

  Rectangle {
    anchors.fill: parent.fill
    color: "white"
  }
}
