// DashboardPanel.qml — the left-hand drawer: markets and headlines.
//
// Unlike the AI assistant, which is a Chromium window Hyprland animates, this
// is a native layer-shell surface — so the slide is ours to control and it
// genuinely comes in from the left edge.
//
// The window stays mapped for the length of the close animation, otherwise the
// card would vanish instead of sliding away.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
  id: root

  readonly property int cardWidth: 400

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

  Connections {
    target: Dashboard

    function onOpenChanged() {
      if (Dashboard.open) {
        unmount.stop();
        root.mounted = true;
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

    // Off-screen to the left when closed. This is the whole point: the drawer
    // enters from the edge it lives on.
    x: Dashboard.open ? Theme.margin : -(root.cardWidth + 12)
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

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "DASHBOARD"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        font.bold: true
        font.letterSpacing: 1
        color: Theme.fgDim
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 24
          height: 24
          radius: 12
          color: refreshHover.containsMouse ? Theme.hover : "transparent"

          Text {
            anchors.centerIn: parent
            text: Icons.refresh
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
            color: Dashboard.loadingStocks || Dashboard.loadingNews ? Theme.accent : Theme.fgDim

            RotationAnimation on rotation {
              running: Dashboard.loadingStocks || Dashboard.loadingNews
              loops: Animation.Infinite
              from: 0
              to: 360
              duration: 1100
            }
          }

          MouseArea {
            id: refreshHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Dashboard.refresh()
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
            onClicked: Dashboard.close()
          }
        }
      }
    }

    // ------------------------------------------------------------------ tabs
    Row {
      id: tabs

      anchors.top: header.bottom
      anchors.topMargin: 12
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 8

      Repeater {
        model: [
          {
            id: "stocks",
            label: "Markets",
            glyph: Icons.chart
          },
          {
            id: "news",
            label: "News",
            glyph: Icons.newspaper
          }
        ]

        delegate: Rectangle {
          id: tab

          required property var modelData
          readonly property bool current: Dashboard.tab === modelData.id

          width: (tabs.width - tabs.spacing) / 2
          height: 32
          radius: 9
          color: current ? Theme.accentSoft : tabHover.containsMouse ? Theme.hover : Theme.raised

          Behavior on color {
            ColorAnimation {
              duration: Theme.animFast
            }
          }

          Row {
            anchors.centerIn: parent
            spacing: 7

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: tab.modelData.glyph
              font.family: Theme.fontFamily
              font.pixelSize: Theme.iconSize
              color: tab.current ? Theme.accent : Theme.fgDim
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: tab.modelData.label
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              font.bold: tab.current
              color: tab.current ? Theme.accent : Theme.fgDim
            }
          }

          MouseArea {
            id: tabHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Dashboard.tab = tab.modelData.id
          }
        }
      }
    }

    // ----------------------------------------------------------------- body
    Item {
      anchors.top: tabs.bottom
      anchors.topMargin: 12
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      anchors.bottomMargin: 14

      // --------------------------------------------------------- markets
      Flickable {
        anchors.fill: parent
        visible: Dashboard.tab === "stocks"
        contentHeight: quoteList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: quoteList
          width: parent.width
          spacing: 4

          Repeater {
            model: Dashboard.stocks

            delegate: Rectangle {
              id: quote

              required property var modelData

              readonly property bool failed: modelData.error !== undefined
              readonly property real change: Dashboard.changePercent(modelData)
              readonly property color tone: change > 0 ? Theme.good : change < 0 ? Theme.crit : Theme.fgDim

              width: quoteList.width
              height: 54
              radius: 10
              color: quoteHover.containsMouse ? Theme.hover : Theme.raised

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animFast
                }
              }

              Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 112
                spacing: 2

                Text {
                  width: parent.width
                  text: quote.modelData.symbol
                  elide: Text.ElideRight
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize
                  font.bold: true
                  color: Theme.fg
                }

                Text {
                  width: parent.width
                  text: quote.failed ? "unavailable" : quote.modelData.name
                  elide: Text.ElideRight
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.smallSize - 1
                  color: Theme.fgDim
                }
              }

              Sparkline {
                anchors.centerIn: parent
                visible: !quote.failed && quote.modelData.spark !== undefined && quote.modelData.spark.length > 1
                width: 92
                height: 26
                points: quote.modelData.spark ?? []
                stroke: quote.tone
              }

              Column {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 92
                spacing: 2

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignRight
                  text: quote.failed ? "—" : Dashboard.formatPrice(quote.modelData.price)
                  elide: Text.ElideRight
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize
                  font.bold: true
                  color: Theme.fg
                }

                Row {
                  anchors.right: parent.right
                  spacing: 3
                  visible: !quote.failed

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: quote.change > 0 ? Icons.trendUp : quote.change < 0 ? Icons.trendDown : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallSize + 2
                    color: quote.tone
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (quote.change >= 0 ? "+" : "") + quote.change.toFixed(2) + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallSize
                    color: quote.tone
                  }
                }
              }

              MouseArea {
                id: quoteHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Dashboard.openLink("https://finance.yahoo.com/quote/" + quote.modelData.symbol)
              }
            }
          }

          Text {
            width: parent.width
            visible: Dashboard.stocks.length === 0
            text: Dashboard.loadingStocks ? "Fetching quotes…" : Dashboard.stocksError.length > 0 ? Dashboard.stocksError : "No symbols configured."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgDim
          }
        }
      }

      // ------------------------------------------------------------ news
      Flickable {
        anchors.fill: parent
        visible: Dashboard.tab === "news"
        contentHeight: storyList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: storyList
          width: parent.width
          spacing: 3

          Repeater {
            model: Dashboard.news

            delegate: Rectangle {
              id: story

              required property var modelData

              width: storyList.width
              implicitHeight: storyText.implicitHeight + 18
              height: implicitHeight
              radius: 10
              color: storyHover.containsMouse ? Theme.hover : "transparent"

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animFast
                }
              }

              Column {
                id: storyText

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 11
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                  width: parent.width
                  text: story.modelData.title
                  wrapMode: Text.WordWrap
                  maximumLineCount: 3
                  elide: Text.ElideRight
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize
                  color: Theme.fg
                }

                Row {
                  spacing: 6

                  Text {
                    text: story.modelData.source
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallSize
                    color: Theme.accent
                  }

                  Text {
                    visible: Dashboard.relativeDate(story.modelData.date).length > 0
                    text: "·  " + Dashboard.relativeDate(story.modelData.date)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallSize
                    color: Theme.fgDim
                  }
                }
              }

              MouseArea {
                id: storyHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Dashboard.openLink(story.modelData.link)
              }
            }
          }

          Text {
            width: parent.width
            visible: Dashboard.news.length === 0
            text: Dashboard.loadingNews ? "Fetching headlines…" : Dashboard.newsError.length > 0 ? Dashboard.newsError : "No feeds configured."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgDim
          }
        }
      }
    }
  }
}
