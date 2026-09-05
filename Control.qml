import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Sammel-Widget: haelt mehrere andere Bar-Widgets in EINER Pille, im selben
// Stil wie diegeltheme.bar.tasks und diegeltheme.bar.tray.
//
// Der Trick ist, dass die Bar ihre Widgets nicht ueber Dateipfade aufloest,
// sondern ueber die barWidgetRegistry — eine Abbildung id -> { component,
// metadata }, die der Host jeder Bar reicht. Wer an diese Registry kommt, kann
// dieselben Komponenten selbst instanziieren. `bar` wird von BarWidget
// injiziert, also fuehrt der Weg dorthin ueber root.bar.
BarWidget {
  id: root
  moduleName: "diegeltheme.bar.control"

  // Ein Eintrag ist eine Widget-Id aus der barWidgetRegistry. Kommando-Module
  // (`type: "command"`) gehen hier bewusst NICHT: die rendert die Bar ueber eine
  // an ihre eigene Instanz gebundene Inline-Komponente, die ausserhalb eines
  // Bar-Slots ins Leere greift. Die vier eigenen Skript-Module sind deshalb
  // echte Widgets (diegeltheme.bar.cpu/vpn/gpu/watts) auf Basis von lib/CommandWidget.qml.
  readonly property var fallbackItems: [
    "omarchy.agents", "omarchy.bluetooth", "omarchy.network", "omarchy.audio",
    "omarchy.monitor", "diegeltheme.bar.cpu", "diegeltheme.bar.gpu",
    "omarchy.power"
  ]

  readonly property var items: {
    var v = root.settings ? root.settings.items : undefined
    return (v instanceof Array && v.length > 0) ? v : root.fallbackItems
  }

  // Einstellungen der eingebetteten Widgets, nach Id verschachtelt:
  //   { "id": "diegeltheme.bar.control", "widgetSettings": { "omarchy.power": { "showPercentage": true } } }
  // Ohne das haetten die Kinder keinen Weg mehr an ihre eigenen Optionen, weil
  // sie in shell.json keinen eigenen Layout-Eintrag mehr haben.
  readonly property var widgetSettings: {
    var v = root.settings ? root.settings.widgetSettings : undefined
    return (v && typeof v === "object") ? v : ({})
  }

  readonly property int pillPadding: Style.space(6)

  function componentFor(id) {
    var registry = root.bar ? root.bar.barWidgetRegistry : null
    if (!registry || !registry.widgets) return null
    // registry.revision mitlesen, damit sich diese Bindung neu auswertet, wenn
    // sich der Katalog aendert (Plugin aktiviert, Shell-Reload).
    var revision = registry.revision
    var entry = registry.widgets[String(id)]
    return entry ? entry.component : null
  }

  // WICHTIG: die Sichtbarkeit darf NICHT von der Breite abhaengen. QML vererbt
  // `visible` nach unten — ein unsichtbarer Container macht seine Kinder
  // unsichtbar, deren Breite faellt damit auf 0, und der Container bliebe fuer
  // immer unsichtbar. Genau in diese Schleife bin ich zuerst gelaufen: alle
  // Kinder geladen, implicitWidth 27, aber visible=false. Der Bar-Host loest es
  // genauso: der Slot bleibt sichtbar, nur seine BREITE folgt dem Inhalt.
  visible: !vertical
  readonly property bool hasContent: row.implicitWidth > 0
  implicitWidth: vertical ? barSize : (hasContent ? row.implicitWidth + pillPadding : 0)
  implicitHeight: vertical ? (hasContent ? row.implicitHeight + pillPadding : 0) : barSize

  // Vor der Row deklariert, damit sie darunter liegt. Farbe aus der TRAGENDEN
  // Bar abgeleitet wie bei den anderen beiden Pillen: #4A4A4A -> #686868.
  Rectangle {
    id: pill
    // Die Pille ist ein Blatt: sie unsichtbar zu schalten zieht nichts mit
    // herunter, anders als beim Container weiter oben.
    visible: root.hasContent
    anchors.centerIn: parent
    // Gleiche Hoehe und damit gleicher Radius wie die aeussere Pille von
    // diegeltheme.bar.tasks. Sie sitzt am nachlaufenden Ende der Bar, aber nicht
    // buendig: die Bar rueckt sie um die halbe Hoehendifferenz ein
    // (barPillInset), sodass beide Kappen KONZENTRISCH liegen und ringsum ein
    // gleich breiter Spalt entlang der Rundung bleibt.
    width: root.vertical ? Math.max(1, root.barSize - Style.space(4)) : row.implicitWidth + root.pillPadding
    height: root.vertical ? row.implicitHeight + root.pillPadding : Math.max(1, root.barSize - Style.space(4))
    radius: (root.vertical ? width : height) / 2
    color: Qt.lighter(root.bar && root.bar.background ? root.bar.background : Color.bar.background, 1.4)
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 0

    Repeater {
      model: root.items

      Item {
        id: hostSlot
        required property string modelData

        readonly property var widgetComponent: root.componentFor(hostSlot.modelData)
        readonly property var activeItem: childLoader.item

        // Genau wie ein Bar-Slot: die Breite kommt vom Kind, nicht umgekehrt.
        // Ein unsichtbares Kind (z.B. Bluetooth ohne Adapter) faellt auf 0 und
        // die Pille schrumpft entsprechend.
        width: activeItem && activeItem.visible ? activeItem.implicitWidth : 0
        height: root.barSize

        // moduleName wird BEWUSST nicht gesetzt: jedes Widget setzt ihn selbst
        // (moduleName: "omarchy.network" usw.), und eine Zuweisung von aussen
        // wuerde diese Bindung nur ueberschreiben.
        // `root` kann hier undefiniert sein: injectProps laeuft auch verzoegert
        // ueber Qt.callLater, und bis dahin kann der Delegate abgebaut sein —
        // dann ist der aeussere Scope weg und jeder Zugriff wirft.
        function injectProps() {
          var target = childLoader.item
          if (!target || !root) return
          if ("bar" in target) target.bar = root.bar
          if ("settings" in target)
            target.settings = root.widgetSettings[hostSlot.modelData] || ({})
        }

        Loader {
          id: childLoader
          anchors.fill: parent
          sourceComponent: hostSlot.widgetComponent
          // Zweimal, wie im Bar-Host: onLoaded laeuft, bevor `bar` unten in der
          // Kette gesetzt sein kann, der callLater holt die Nachzuegler.
          onLoaded: {
            hostSlot.injectProps()
            Qt.callLater(hostSlot.injectProps)
          }
        }
      }
    }
  }
}
