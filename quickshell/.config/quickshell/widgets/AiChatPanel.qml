// AiChatPanel.qml — the assistant drawer.
//
// Same left-edge slide as the dashboard, and for the same reason: it's a native
// layer-shell surface, so the animation is ours rather than Hyprland's.
//
// It takes keyboard focus on demand — you have to be able to type in it — but
// only while it is actually open.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
  id: root

  readonly property int cardWidth: 420

  property bool mounted: false

  visible: mounted

  anchors {
    top: true
    bottom: true
    left: true
  }

  margins {
    top: Theme.barHeight
    bottom: Theme.margin
  }

  implicitWidth: cardWidth + Theme.margin * 2
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  focusable: AiChat.open
  WlrLayershell.keyboardFocus: AiChat.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  Connections {
    target: AiChat

    function onOpenChanged() {
      if (AiChat.open) {
        unmount.stop();
        root.mounted = true;
        input.forceActiveFocus();
      } else {
        unmount.restart();
      }
    }
  }

  Timer {
    id: unmount
    interval: Theme.animSlow + 60
    onTriggered: root.mounted = false
  }

  Rectangle {
    id: card

    x: AiChat.open ? Theme.margin : -(root.cardWidth + 12)
    width: root.cardWidth
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    radius: 16
    color: Theme.island
    border.width: 1
    border.color: Theme.border

    Behavior on x {
      NumberAnimation {
        duration: Theme.animSlow
        easing.type: Easing.OutQuint
      }
    }

    // ---------------------------------------------------------------- header
    Item {
      id: header

      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 14
      height: 26

      Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
          text: "ASSISTANT"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize
          font.bold: true
          font.letterSpacing: 1
          color: Theme.fgDim
        }

        Text {
          text: AiChat.provider.label + "  ·  " + AiChat.modelLabel
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize - 1
          color: Theme.accent
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        // New conversation
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 24
          height: 24
          radius: 12
          visible: AiChat.messages.length > 0
          color: newHover.containsMouse ? Theme.hover : "transparent"

          Text {
            anchors.centerIn: parent
            text: Icons.plus
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
            color: Theme.fgDim
          }

          MouseArea {
            id: newHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: AiChat.reset()
          }
        }

        // Fall back to the full web app for anything this can't do.
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 24
          height: 24
          radius: 12
          color: webHover.containsMouse ? Theme.hover : "transparent"

          Text {
            anchors.centerIn: parent
            text: Icons.web
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
            color: Theme.fgDim
          }

          MouseArea {
            id: webHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              AiChat.close();
              AiAssistant.toggle();
            }
          }
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 24
          height: 24
          radius: 12
          color: closeHover.containsMouse ? Theme.crit : "transparent"

          Text {
            anchors.centerIn: parent
            text: Icons.close
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
            color: closeHover.containsMouse ? Theme.base : Theme.fgDim
          }

          MouseArea {
            id: closeHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: AiChat.close()
          }
        }
      }
    }

    // ------------------------------------------------------------ transcript
    Flickable {
      id: transcript

      anchors.top: header.bottom
      anchors.topMargin: 10
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: composer.top
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      anchors.bottomMargin: 10

      contentHeight: thread.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      // Follow the reply as it streams, but only when already at the bottom, so
      // scrolling back to re-read something isn't yanked away.
      property bool pinned: true
      onContentHeightChanged: {
        if (pinned)
          contentY = Math.max(0, contentHeight - height);
      }
      onMovementEnded: pinned = contentY >= contentHeight - height - 24

      Column {
        id: thread
        width: parent.width
        spacing: 10

        Repeater {
          model: AiChat.messages

          delegate: Column {
            id: bubble

            required property var modelData
            readonly property bool mine: modelData.role === "user"

            width: thread.width
            spacing: 3

            Text {
              text: bubble.mine ? "You" : "Assistant"
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize - 1
              font.bold: true
              color: bubble.mine ? Theme.fgDim : Theme.accent
            }

            Rectangle {
              width: parent.width
              implicitHeight: body.implicitHeight + 18
              height: implicitHeight
              radius: 10
              color: bubble.mine ? Theme.raised : Theme.accentSoft

              Text {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 11
                anchors.verticalCenter: parent.verticalCenter
                text: bubble.modelData.content
                wrapMode: Text.Wrap
                // Replies are markdown; Qt renders it natively.
                textFormat: Text.MarkdownText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fg
                onLinkActivated: link => Dashboard.openLink(link)
              }
            }
          }
        }

        // The in-flight reply.
        Column {
          width: thread.width
          spacing: 3
          visible: AiChat.streaming

          Text {
            text: "Assistant"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize - 1
            font.bold: true
            color: Theme.accent
          }

          Rectangle {
            width: parent.width
            implicitHeight: streamBody.implicitHeight + 18
            height: implicitHeight
            radius: 10
            color: Theme.accentSoft

            Text {
              id: streamBody
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 11
              anchors.verticalCenter: parent.verticalCenter
              text: AiChat.partial.length > 0 ? AiChat.partial : "…"
              wrapMode: Text.Wrap
              textFormat: Text.MarkdownText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              color: Theme.fg
            }
          }
        }

        // ------------------------------------------------------ empty states
        Column {
          width: thread.width
          spacing: 8
          visible: AiChat.messages.length === 0 && !AiChat.streaming && AiChat.configured

          Text {
            width: parent.width
            text: "Ask anything."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgDim
          }
        }

        // Not configured — say exactly what to do about it.
        Column {
          width: thread.width
          spacing: 10
          visible: !AiChat.configured

          Row {
            spacing: 8

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: Icons.key
              font.family: Theme.fontFamily
              font.pixelSize: Theme.iconSize + 2
              color: Theme.warn
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Needs an API key"
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              font.bold: true
              color: Theme.fg
            }
          }

          Text {
            width: parent.width
            text: "Unlike the web app, a native chat has no browser session to borrow — it needs a key of its own.\n\nPick a provider and add it to your shell profile:"
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize + 1
            color: Theme.fgDim
          }

          Rectangle {
            width: parent.width
            implicitHeight: setup.implicitHeight + 18
            radius: 9
            color: Theme.raised

            Text {
              id: setup
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 10
              anchors.verticalCenter: parent.verticalCenter
              text: "set -gx QS_AI_PROVIDER " + AiChat.providerId + "\nset -gx QS_AI_API_KEY  …\n\n# providers: openrouter · groq · xai · gemini · ollama"
              wrapMode: Text.WrapAnywhere
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize
              color: Theme.accent
            }
          }

          Text {
            width: parent.width
            text: "Put it in ~/.config/fish/config.fish (not your dotfiles repo) and restart the shell. The web app still works from the globe button above."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize
            color: Theme.fgDim
          }
        }

        // Errors from the provider.
        Rectangle {
          width: thread.width
          implicitHeight: errorText.implicitHeight + 18
          radius: 9
          visible: AiChat.error.length > 0
          color: Qt.rgba(Theme.crit.r, Theme.crit.g, Theme.crit.b, 0.15)

          Text {
            id: errorText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.verticalCenter: parent.verticalCenter
            text: AiChat.error
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize
            color: Theme.crit
          }
        }
      }
    }

    // ------------------------------------------------------------- composer
    Rectangle {
      id: composer

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 14

      implicitHeight: Math.min(120, Math.max(38, input.implicitHeight + 18))
      height: implicitHeight
      radius: 10
      color: Theme.raised
      border.width: 1
      border.color: input.activeFocus ? Theme.accent : "transparent"
      enabled: AiChat.configured

      Behavior on border.color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }

      TextEdit {
        id: input

        anchors.left: parent.left
        anchors.right: sendButton.left
        anchors.leftMargin: 11
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter

        wrapMode: TextEdit.Wrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.base
        enabled: AiChat.configured

        // Enter sends, Shift+Enter makes a new line.
        Keys.onReturnPressed: event => {
          if (event.modifiers & Qt.ShiftModifier) {
            event.accepted = false;
            return;
          }
          AiChat.send(input.text);
          input.text = "";
        }
        Keys.onEscapePressed: AiChat.close()

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          visible: input.text.length === 0
          text: AiChat.configured ? "Message…" : "Set QS_AI_API_KEY to enable"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: Theme.fgDim
        }
      }

      Rectangle {
        id: sendButton

        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 14

        readonly property bool armed: AiChat.configured && (AiChat.streaming || input.text.trim().length > 0)

        color: armed ? sendHover.containsMouse ? Theme.accent : Theme.accentSoft : "transparent"

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        Text {
          anchors.centerIn: parent
          text: AiChat.streaming ? Icons.stop : Icons.send
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: sendButton.armed ? sendHover.containsMouse ? Theme.base : Theme.accent : Theme.fgDim
        }

        MouseArea {
          id: sendHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (AiChat.streaming) {
              AiChat.stop();
              return;
            }
            AiChat.send(input.text);
            input.text = "";
          }
        }
      }
    }
  }
}
