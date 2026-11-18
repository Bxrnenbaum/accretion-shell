import "." as RootDir
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: launcher

    property bool isOpen: false
    property bool windowVisible: false
    property string mode: "apps"
    property var recentApplicationIds: []
    property var completionCandidates: []
    property string completedCompletionQuery: ""
    property string completedCompletionKind: ""
    property bool outputVisible: false
    property string outputText: ""
    property string outputStatus: ""
    readonly property string queryText: searchInput.text.trim()
    readonly property bool canCompleteCommand: mode === "bash" && searchInput.text.length > 0 && searchInput.text === queryText && !/[\s/;&|<>]/.test(searchInput.text) && !/['"`\\$]/.test(searchInput.text)
    readonly property bool canCompleteArguments: mode === "bash" && /\s/.test(searchInput.text) && !/[\n\r;&|<>]/.test(searchInput.text) && !/['"`\\$]/.test(searchInput.text)
    readonly property bool canComplete: canCompleteCommand || canCompleteArguments
    readonly property var matchingApplications: {
        const query = queryText.toLowerCase();
        const rank = (app) => {
            const index = recentApplicationIds.indexOf(appKey(app));
            return index < 0 ? recentApplicationIds.length : index;
        };
        return DesktopEntries.applications.values.filter((app) => {
            if (String(app.id).startsWith("steam_app_"))
                return false;

            const searchable = [app.name, app.genericName, app.comment, (app.keywords || []).join(" ")].join(" ").toLowerCase();
            return searchable.includes(query);
        }).sort((a, b) => {
            return rank(a) - rank(b) || String(a.name).localeCompare(String(b.name), undefined, { sensitivity: "base" });
        });
    }

    readonly property var matchingCompletions: canComplete && completedCompletionQuery === searchInput.text && completionCandidates.length > 0 && completionCandidates.length <= 12 ? completionCandidates : []

    function appKey(app) {
        return String(app.id || app.name);
    }

    function dismissOutput() {
        commandProcess.running = false;
        outputVisible = false;
    }

    function runCommand() {
        if (commandProcess.running)
            return;

        outputText = "";
        outputStatus = "Running…";
        outputVisible = true;

        commandProcess.command = ["bash", "-lc", "exec 2>&1\n" + queryText];
        commandProcess.running = true;
    }

    function show(nextMode) {
        dismissOutput();
        mode = nextMode;
        searchInput.text = "";
        isOpen = true;
        windowVisible = true;
        closeTimer.stop();
        focusTimer.start();
    }

    function close() {
        if (!isOpen)
            return;

        dismissOutput();
        isOpen = false;
        closeTimer.restart();
    }

    function launchApplication(application) {
        const key = appKey(application);
        recentApplicationIds = [key, ...recentApplicationIds.filter((id) => id !== key)];
        application.execute();
        close();
    }

    function accept() {
        if (mode === "apps") {
            if (appList.currentItem)
                launchApplication(appList.currentItem.application);
        } else if (queryText.length > 0) {
            runCommand();
        }
    }

    function applyCompletion(candidate) {
        if (completedCompletionKind === "command") {
            searchInput.text = candidate;
        } else {
            const input = searchInput.text;
            const wordStart = Math.max(input.lastIndexOf(" "), input.lastIndexOf("\t")) + 1;
            searchInput.text = input.slice(0, wordStart) + candidate;
        }
        searchInput.cursorPosition = searchInput.text.length;
        searchInput.forceActiveFocus();
    }

    IpcHandler {
        function showApplications() {
            launcher.show("apps");
        }

        function showCommands() {
            launcher.show("bash");
        }

        target: "appLauncher"
    }

    Timer {
        id: focusTimer

        interval: 0
        onTriggered: searchInput.forceActiveFocus()
    }

    Timer {
        id: closeTimer

        interval: 230
        onTriggered: launcher.windowVisible = false
    }

    Timer {
        id: commandCompletionTimer

        interval: 120
        onTriggered: {
            if (commandCompletionProcess.running)
                return;

            commandCompletionProcess.requestQuery = searchInput.text;
            commandCompletionProcess.requestKind = launcher.canCompleteCommand ? "command" : "argument";
            if (commandCompletionProcess.requestKind === "command") {
                commandCompletionProcess.command = ["bash", "-lc", "compgen -c -- \"$1\" | grep -Fvx -- \"$1\" | sort -u | head -n 13", "launcher", commandCompletionProcess.requestQuery];
            } else {
                const script = [
                    'if [[ -r /usr/share/bash-completion/bash_completion ]]; then source /usr/share/bash-completion/bash_completion >/dev/null 2>&1 || true; fi',
                    'line=$1',
                    'COMP_LINE=$line',
                    'COMP_POINT=${#COMP_LINE}',
                    'read -r -a COMP_WORDS <<< "$line"',
                    'if [[ $line =~ [[:space:]]$ ]]; then COMP_WORDS+=(""); fi',
                    'COMP_CWORD=$((${#COMP_WORDS[@]} - 1))',
                    'command_name=${COMP_WORDS[0]}',
                    'current=${COMP_WORDS[COMP_CWORD]}',
                    'previous=',
                    'if ((COMP_CWORD > 0)); then previous=${COMP_WORDS[COMP_CWORD - 1]}; fi',
                    'if ! complete -p -- "$command_name" >/dev/null 2>&1 && declare -F _completion_loader >/dev/null; then _completion_loader "$command_name" >/dev/null 2>&1 || true; fi',
                    'spec=$(complete -p -- "$command_name" 2>/dev/null || true)',
                    'COMPREPLY=()',
                    'if [[ $spec =~ -F[[:space:]]+([[:alnum:]_]+) ]]; then',
                    '    function_name=${BASH_REMATCH[1]}',
                    '    "$function_name" "$current" "$previous" "$command_name" >/dev/null 2>&1',
                    'elif [[ -z $spec || $spec == *"-o default"* || $spec == *"-o bashdefault"* ]]; then',
                    '    mapfile -t COMPREPLY < <(compgen -f -- "$current" | head -n 13)',
                    'else',
                    '    exit 0',
                    'fi',
                    'if ((${#COMPREPLY[@]} == 0)); then exit 0; fi',
                    'mapfile -t unique_replies < <(printf "%s\\n" "${COMPREPLY[@]}" | LC_ALL=C sort -u | head -n 13)',
                    'if ((${#unique_replies[@]} > 12)); then exit 0; fi',
                    'printf "%s\\n" "${unique_replies[@]}"'
                ].join("\n");
                commandCompletionProcess.command = ["timeout", "0.5s", "bash", "-lc", script, "launcher", commandCompletionProcess.requestQuery];
            }
            commandCompletionProcess.running = true;
        }
    }

    Process {
        id: commandCompletionProcess

        property string requestQuery: ""
        property string requestKind: ""

        stdout: StdioCollector {
            onStreamFinished: {
                launcher.completionCandidates = text.split("\n").filter((command) => command);
                launcher.completedCompletionQuery = commandCompletionProcess.requestQuery;
                launcher.completedCompletionKind = commandCompletionProcess.requestKind;
            }
        }

        onExited: {
            if (launcher.canComplete && searchInput.text !== requestQuery)
                commandCompletionTimer.restart();
        }
    }

    Process {
        id: commandProcess

        stdout: SplitParser {
            onRead: (line) => launcher.outputText = (launcher.outputText + line + "\n").slice(-50000)
        }
        onExited: (exitCode, exitStatus) => {
            launcher.outputStatus = exitCode === 0 ? "Finished" : `Exited with status ${exitCode}`;
        }
    }

    PanelWindow {
        visible: launcher.windowVisible
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: launcher.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.close()
        }

        Item {
            id: launcherPanel

            readonly property real cornerRadius: Math.min(height / 2, 16 * Math.pow(Math.max(height / 32, 1), 0.4))

            width: Math.min(parent.width - 24, Math.min(1000, Math.max(640, parent.width * 0.6)))
            height: contents.implicitHeight + 36
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            opacity: launcher.isOpen ? 1 : 0
            scale: launcher.isOpen ? 1 : 0.33

            Rectangle {
                id: panelBackground

                x: launcherPanel.cornerRadius
                width: launcherPanel.width - launcherPanel.cornerRadius * 2
                height: launcherPanel.height
                color: RootDir.Theme.bg
                topLeftRadius: launcherPanel.cornerRadius
                topRightRadius: launcherPanel.cornerRadius
            }

            RootDir.ConcaveCorner {
                radius: launcherPanel.cornerRadius
                color: panelBackground.color
                mirror.x: true
                mirror.y: true
                x: 1
                y: launcherPanel.height - radius
            }

            RootDir.ConcaveCorner {
                radius: launcherPanel.cornerRadius
                color: panelBackground.color
                mirror.x: false
                mirror.y: true
                x: launcherPanel.width - launcherPanel.cornerRadius
                y: launcherPanel.height - radius
            }

            Column {
                id: contents

                readonly property real rowWidth: Math.min(width * 0.82, width - launcherPanel.cornerRadius * 2)

                x: -10
                y: 36
                width: parent.width + 20
                spacing: 10

                Rectangle {
                    width: contents.rowWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 46
                    radius: 12
                    color: RootDir.Theme.bgSecondary
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: RootDir.Theme.accent

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            width: 34
                            height: parent.height
                            text: launcher.mode === "apps" ? "app" : "$"
                            color: RootDir.Theme.accent
                            font.family: RootDir.Fonts.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }

                        Item {
                            width: parent.width - 34 - parent.spacing
                            height: parent.height

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: launcher.mode === "apps" ? "Search applications" : "Run a Bash command"
                                color: RootDir.Theme.fgMuted
                                font.family: RootDir.Fonts.text
                                font.pixelSize: 13
                                visible: searchInput.text.length === 0
                            }

                            TextInput {
                                id: searchInput

                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: RootDir.Theme.fg
                                selectionColor: RootDir.Theme.accent
                                selectedTextColor: RootDir.Theme.bg
                                font.family: RootDir.Fonts.text
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onTextChanged: {
                                    appList.currentIndex = 0;
                                    if (launcher.canComplete)
                                        commandCompletionTimer.restart();
                                    else
                                        commandCompletionTimer.stop();
                                }
                                Keys.onPressed: (event) => {
                                    event.accepted = true;
                                    if (event.key === Qt.Key_Escape)
                                        launcher.outputVisible ? launcher.dismissOutput() : launcher.close();
                                    else if (event.key === Qt.Key_Tab) {
                                        if (launcher.matchingCompletions.length === 1)
                                            launcher.applyCompletion(launcher.matchingCompletions[0]);
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                        launcher.accept();
                                    else if (launcher.mode === "apps" && event.key === Qt.Key_Down)
                                        appList.incrementCurrentIndex();
                                    else if (launcher.mode === "apps" && event.key === Qt.Key_Up)
                                        appList.decrementCurrentIndex();
                                    else
                                        event.accepted = false;
                                }
                            }

                        }

                    }

                }

                ListView {
                    id: appList

                    width: contents.rowWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 400
                    visible: !launcher.outputVisible
                    clip: true
                    spacing: 3
                    model: launcher.mode === "apps" ? launcher.matchingApplications : launcher.matchingCompletions
                    currentIndex: count > 0 ? 0 : -1

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isApplication: launcher.mode === "apps"
                        readonly property var application: isApplication ? modelData : null
                        readonly property bool selected: ListView.isCurrentItem

                        width: ListView.view.width
                        height: 44
                        radius: 8
                        color: selected ? RootDir.Theme.fg : (index % 2 ? RootDir.Theme.bgSecondary : "transparent")

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            IconImage {
                                width: 26
                                height: 26
                                source: isApplication ? Quickshell.iconPath(application.icon || "application-x-executable", true) : ""
                                anchors.verticalCenter: parent.verticalCenter
                                visible: isApplication
                            }

                            Column {
                                width: parent.width - (isApplication ? 36 : 0)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: isApplication ? application.name : modelData
                                    color: selected ? RootDir.Theme.bg : RootDir.Theme.fg
                                    font.family: RootDir.Fonts.text
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: isApplication ? (application.genericName || application.comment) : (launcher.completedCompletionKind === "command" ? "Bash command" : "Bash argument")
                                    color: selected ? RootDir.Theme.bgSecondary : RootDir.Theme.fgMuted
                                    font.family: RootDir.Fonts.text
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: appList.currentIndex = index
                            onClicked: {
                                if (isApplication) {
                                    launcher.launchApplication(application);
                                } else {
                                    launcher.applyCompletion(modelData);
                                }
                            }
                        }

                    }

                }

                Rectangle {
                    id: outputPanel

                    width: contents.rowWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 400
                    radius: 12
                    color: RootDir.Theme.bgSecondary
                    visible: launcher.outputVisible

                    Item {
                        id: outputHeader

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 32

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: launcher.outputStatus + (commandProcess.running ? "  ·  Esc to stop" : "  ·  Esc to close")
                            color: RootDir.Theme.fgMuted
                            font.family: RootDir.Fonts.text
                            font.pixelSize: 11
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✕"
                            color: RootDir.Theme.fg
                            font.family: RootDir.Fonts.text
                            font.pixelSize: 13

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                onClicked: {
                                    launcher.dismissOutput();
                                    searchInput.forceActiveFocus();
                                }
                            }

                        }

                    }

                    Flickable {
                        id: outputFlick

                        anchors.top: outputHeader.bottom
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 10
                        clip: true
                        contentWidth: width
                        contentHeight: outputLabel.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                        Text {
                            id: outputLabel

                            width: outputFlick.width
                            text: launcher.outputText
                            textFormat: Text.PlainText
                            wrapMode: Text.WrapAnywhere
                            color: RootDir.Theme.fg
                            font.family: "monospace"
                            font.pixelSize: 12
                        }

                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 190
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

            transform: Translate {
                y: launcher.isOpen ? 0 : launcherPanel.height + 20

                Behavior on y {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

    }

}