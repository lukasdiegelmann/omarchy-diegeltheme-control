import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Container widget: holds several other bar widgets inside ONE pill, styled
// like diegeltheme.bar.tasks and diegeltheme.bar.tray.
//
// What makes this possible is that the bar does not resolve its widgets through
// file paths but through the barWidgetRegistry — a map id -> { component,
// metadata } that the host hands to every bar. Anything that can reach this
// registry can instantiate the very same components. `bar` is injected by
// BarWidget, so the way in is root.bar.
BarWidget {
  id: root
  moduleName: "diegeltheme.bar.control"

  // An entry is a widget id from the barWidgetRegistry. Command modules
  // (`type: "command"`) deliberately do NOT work here: the bar renders those
  // through an inline component bound to its own instance, which reaches
  // nothing outside a bar slot. The script modules are therefore real widgets
  // (diegeltheme.bar.cpu and .gpu) built on a shared CommandWidget base.
  readonly property var fallbackItems: [
    "omarchy.agents", "omarchy.bluetooth", "omarchy.network", "omarchy.audio",
    "omarchy.monitor", "diegeltheme.bar.cpu", "diegeltheme.bar.gpu",
    "omarchy.power"
  ]

  readonly property var items: {
    var v = root.settings ? root.settings.items : undefined
    return (v instanceof Array && v.length > 0) ? v : root.fallbackItems
  }

  // Settings for the embedded widgets, nested by id:
  //   { "id": "diegeltheme.bar.control", "widgetSettings": { "omarchy.power": { "showPercentage": true } } }
  // Without this the children would have no way to reach their own options,
  // because they no longer have a layout entry of their own in shell.json.
  readonly property var widgetSettings: {
    var v = root.settings ? root.settings.widgetSettings : undefined
    return (v && typeof v === "object") ? v : ({})
  }

  readonly property int pillPadding: Style.space(6)

  function componentFor(id) {
    var registry = root.bar ? root.bar.barWidgetRegistry : null
    if (!registry || !registry.widgets) return null
    // Read registry.revision so this binding re-evaluates whenever the
    // catalogue changes (a plugin enabled, a shell reload).
    var revision = registry.revision
    var entry = registry.widgets[String(id)]
    return entry ? entry.component : null
  }

  // IMPORTANT: visibility must NOT depend on the width. QML propagates
  // `visible` downwards — an invisible container makes its children invisible,
  // their width therefore drops to 0, and the container would stay invisible
  // forever. That is a closed loop, and an easy one to walk into: every child
  // loaded, implicitWidth 27, yet visible=false everywhere. The bar host solves
  // it the same way: the slot stays visible, only its WIDTH follows the content.
  visible: !vertical
  readonly property bool hasContent: row.implicitWidth > 0
  implicitWidth: vertical ? barSize : (hasContent ? row.implicitWidth + pillPadding : 0)
  implicitHeight: vertical ? (hasContent ? row.implicitHeight + pillPadding : 0) : barSize

  // Declared before the Row so it paints underneath. The colour is derived
  // from the CARRYING bar, like the other two pills: #4A4A4A -> #686868.
  Rectangle {
    id: pill
    // The pill is a leaf: hiding it drags nothing down with it, unlike the
    // container above.
    visible: root.hasContent
    anchors.centerIn: parent
    // Same height, and therefore same radius, as the outer pill of
    // diegeltheme.bar.tasks. It sits at the trailing end of the bar but not
    // flush: the bar insets it by half the height difference (barPillInset), so
    // both caps are CONCENTRIC and an evenly wide gap follows the curve all the
    // way round.
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

        // Exactly like a bar slot: the width comes from the child, not the
        // other way round. An invisible child (Bluetooth without an adapter,
        // say) collapses to 0 and the pill shrinks accordingly.
        width: activeItem && activeItem.visible ? activeItem.implicitWidth : 0
        height: root.barSize

        // moduleName is DELIBERATELY not set: every widget sets it itself
        // (moduleName: "omarchy.network" and so on), and assigning it from the
        // outside would only overwrite that binding.
        // `root` can be undefined in here: injectProps also runs deferred via
        // Qt.callLater, and by then the delegate may already be torn down —
        // the outer scope is gone and any access throws.
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
          // Twice, as the bar host does it: onLoaded runs before `bar` can be
          // set further down the chain; the callLater catches the stragglers.
          onLoaded: {
            hostSlot.injectProps()
            Qt.callLater(hostSlot.injectProps)
          }
        }
      }
    }
  }
}
