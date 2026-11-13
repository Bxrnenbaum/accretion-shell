import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "widgets"

ShellRoot {
    AppLauncher {
    }

    Variants {
        model: Quickshell.screens

        Background {
            required property var modelData

            modelData: parent.modelData
        }

    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: panelWindow

            required property var modelData
            property bool hasBattery: false

            screen: modelData
            implicitHeight: modelData.height
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
                onExited: (code) => {
                    return panelWindow.hasBattery = (code === 0);
                }
            }

            Row {
                id: rightRow

                spacing: 8

                anchors {
                    top: parent.top
                    right: parent.right
                    rightMargin: 0
                }

                WeatherWidget {
                    id: weather
                }

                DateWidget {
                    id: date
                }

                WifiWidget {
                    id: wifi
                }

            }

            Row {
                id: leftRow

                spacing: 8

                anchors {
                    top: parent.top
                    left: parent.left
                    leftMargin: 0
                }

                BatteryWidget {
                    id: battery

                    visible: panelWindow.hasBattery
                }

                MusicWidget {
                    id: music
                }

            }

            mask: Region {
                Region {
                    item: weather
                }

                Region {
                    item: date
                }

                Region {
                    item: wifi
                }

                Region {
                    item: battery
                }

                Region {
                    item: music
                }

                Region {
                    item: power
                }

            }

        }

    }

}
