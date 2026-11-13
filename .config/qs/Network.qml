pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: network

    property string connectionName: ""

    function refresh() {
        activeConnectionProcess.running = true;
    }

    function splitTerse(line) {
        let fields = [], current = "";
        for (let index = 0; index < line.length; index++) {
            const character = line[index];
            if (character === "\\" && index + 1 < line.length) {
                current += line[++index];
            } else if (character === ":") {
                fields.push(current);
                current = "";
            } else {
                current += character;
            }
        }
        fields.push(current);
        return fields;
    }

    property Process monitorProcess: Process {
        running: true
        command: ["nmcli", "monitor"]

        stdout: SplitParser {
            onRead: network.refreshTimer.restart()
        }
    }

    property Timer refreshTimer: Timer {
        interval: 400
        onTriggered: network.refresh()
    }

    property Process activeConnectionProcess: Process {
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;

                    const fields = network.splitTerse(line);
                    if (fields[1] === "802-11-wireless" || fields[1] === "802-3-ethernet") {
                        name = fields[0];
                        break;
                    }
                }
                network.connectionName = name;
            }
        }
    }

    property Timer pollingTimer: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: network.refresh()
    }
}