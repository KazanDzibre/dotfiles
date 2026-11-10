// DashboardPopup.qml — markets, news and dev headlines, as a panel that grows
// out of the status pill.
//
// It replaces the left-hand drawer. Reached from the control center's
// Dashboard tile: the control center slides away and this takes over its
// surface, with a back link at the top (see StatusCluster.openPanel).
//
// Dashboard.open still means "the dashboard is showing" — it is what triggers
// the first fetch and what the control center tile lights up for — so it is
// kept in step with this panel rather than driven by a separate drawer.
import QtQuick
import Quickshell
import qs

MorphPanel {
  id: root

  cardWidth: 400
  contentSpacing: 12
  align: "right"

  Connections {
    target: root

    function onOpenedChanged() {
      Dashboard.open = root.opened;
    }
  }

  // Something else (the AI button) closing the dashboard closes this too.
  Connections {
    target: Dashboard

    function onOpenChanged() {
      if (!Dashboard.open && root.opened)
        root.close();
    }
  }

  // ---------------------------------------------------------------- header
  Item {
    id: header

    width: parent.width
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

    }
  }

  // ------------------------------------------------------------------ tabs
  Row {
    id: tabs

    width: parent.width
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
        },
        {
          id: "dev",
          label: "Dev",
          glyph: Icons.devFeed
        }
      ]

      delegate: Rectangle {
        id: tab

        required property var modelData
        readonly property bool current: Dashboard.tab === modelData.id

        width: (tabs.width - tabs.spacing * 2) / 3
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
    id: pages
    width: parent.width
    height: 430

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

    // ------------------------------------------------------------- dev
    Item {
      anchors.fill: parent
      visible: Dashboard.tab === "dev"

      // Six sources publish AI daily and Flutter publishes weekly, so a plain
      // date sort reads as an AI feed. These narrow it to one stack.
      Flow {
        id: topicChips

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 5

        Repeater {
          model: Dashboard.devTopics

          delegate: Rectangle {
            id: chip

            required property var modelData
            readonly property bool current: Dashboard.devTopic === modelData.id

            height: 22
            width: chipLabel.implicitWidth + 18
            radius: 11
            color: current ? Theme.accent : chipHover.containsMouse ? Theme.hover : Theme.raised

            Behavior on color {
              ColorAnimation {
                duration: Theme.animFast
              }
            }

            Text {
              id: chipLabel
              anchors.centerIn: parent
              text: chip.modelData.label
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize
              font.bold: chip.current
              color: chip.current ? Theme.base : Theme.fgDim
            }

            MouseArea {
              id: chipHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Dashboard.devTopic = chip.modelData.id
            }
          }
        }
      }

      Flickable {
        anchors.top: topicChips.bottom
        anchors.topMargin: 9
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        contentHeight: devList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: devList
          width: parent.width
          spacing: 3

          Repeater {
            model: Dashboard.devFiltered

            delegate: Rectangle {
              id: post

              required property var modelData

              width: devList.width
              implicitHeight: postText.implicitHeight + 18
              height: implicitHeight
              radius: 10
              color: postHover.containsMouse ? Theme.hover : "transparent"

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animFast
                }
              }

              Column {
                id: postText

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 11
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                  width: parent.width
                  text: post.modelData.title
                  wrapMode: Text.WordWrap
                  maximumLineCount: 3
                  elide: Text.ElideRight
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize
                  color: Theme.fg
                }

                Row {
                  width: parent.width
                  spacing: 6

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: post.modelData.source
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallSize
                    color: Theme.accent
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Dashboard.relativeDate(post.modelData.date).length > 0
                    text: "·  " + Dashboard.relativeDate(post.modelData.date)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallSize
                    color: Theme.fgDim
                  }

                  // Which of your stacks this touches, at a glance.
                  Repeater {
                    model: post.modelData.topics ?? []

                    delegate: Rectangle {
                      required property var modelData

                      anchors.verticalCenter: parent.verticalCenter
                      height: 15
                      width: badge.implicitWidth + 12
                      radius: 7
                      color: Theme.accentSoft

                      Text {
                        id: badge
                        anchors.centerIn: parent
                        text: parent.modelData
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallSize - 2
                        color: Theme.accent
                      }
                    }
                  }
                }
              }

              MouseArea {
                id: postHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Dashboard.openLink(post.modelData.link)
              }
            }
          }

          Text {
            width: parent.width
            visible: Dashboard.devFiltered.length === 0
            text: Dashboard.loadingDev ? "Fetching tech headlines…" : Dashboard.devError.length > 0 ? Dashboard.devError : Dashboard.dev.length > 0 ? "Nothing tagged with that yet." : "No feeds configured."
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
