import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Rectangle {
    id: batteryWidget

    property int capacity: 0
    property string status: ""
    readonly property bool charging: status === "Charging"

    implicitWidth: 64
    implicitHeight: 28

    color: "#0b1b26"
    border.color: hoverHandler.hovered ? "#E3C9A3" : "#2a526e"
    border.width: 2
    radius: 16

    Behavior on border.color {
        ColorAnimation { duration: 100 }
      }


    HoverHandler {
        id: hoverHandler
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#99000000"
        shadowBlur: 0.8            // 0.0 to 1.0
        shadowVerticalOffset: 4
        shadowHorizontalOffset: 0
    }

    Text {
        anchors.centerIn: parent
        font.family: "monospace"
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

        command: ["sh", "-c", "cat /sys/class/power_supply/BAT1/capacity /sys/class/power_supply/BAT1/status"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                batteryWidget.capacity = parseInt(lines[0]);
                batteryWidget.status = lines[1];
            }
        }
    }
}
