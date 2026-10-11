pragma Singleton

import QtQuick

QtObject {
  readonly property FontLoader _text: FontLoader {
    source: Qt.resolvedUrl("fonts/MonaspaceArgon-Regular.otf")
  }
  readonly property FontLoader _icons: FontLoader {
    source: Qt.resolvedUrl("fonts/SymbolsNerdFont-Regular.ttf")
  }

  readonly property string text: _text.name
  readonly property string icons: _icons.name
}
