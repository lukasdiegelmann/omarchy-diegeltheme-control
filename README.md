# diegel.control — Widget-Container

Fasst beliebige Bar-Widgets in EINER gemeinsamen Pille zusammen. Mehrfach
einsetzbar — etwa einmal links fuer die Medienanzeige und einmal rechts fuer die
Systemsymbole.

## Installation

```bash
omarchy plugin add https://github.com/lukasdiegelmann/omarchy-diegeltheme-control.git
```

## Verwendung

```jsonc
{ "id": "diegel.control",
  "items": ["omarchy.menu", "omarchy.bluetooth", "omarchy.network"],
  "widgetSettings": { "omarchy.power": { "showPercentage": true } } }
```

`items` sind Widget-Ids aus der Registry; `widgetSettings` reicht die Einstellungen
durch, die die eingebetteten Widgets sonst aus ihrem eigenen Layout-Eintrag lesen
wuerden.

**Nur Registry-Widgets.** Kommando-Module (`type: "command"`) gehen nicht: die rendert
die Bar ueber eine an ihre eigene Instanz gebundene Inline-Komponente. Wer so etwas
einbetten will, macht daraus ein richtiges Widget (siehe `diegel.cpu`).

Third-Party-Widgets muessen zusaetzlich in `plugins[]` der `shell.json` stehen, sonst
registriert der Host sie nicht.
