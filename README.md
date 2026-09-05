# diegeltheme.bar.control — widget container

Groups any number of bar widgets into one shared pill. Usable more than once —
for instance one on the left for now-playing and one on the right for system icons.

## Install

```bash
omarchy plugin add https://github.com/lukasdiegelmann/omarchy-diegeltheme-control.git
```

## Usage

```jsonc
{ "id": "diegeltheme.bar.control",
  "items": ["omarchy.menu", "omarchy.bluetooth", "omarchy.network"],
  "widgetSettings": { "omarchy.power": { "showPercentage": true } } }
```

`items` are widget ids from the registry. `widgetSettings` forwards the options an
embedded widget would otherwise read from its own layout entry.

**Registry widgets only.** Command modules (`type: "command"`) will not work: the bar
renders those through an inline component bound to its own instance, which reaches
nothing outside a bar slot. Turn such a module into a real widget instead.

Third-party widgets must also be listed in `plugins[]` of `shell.json`, otherwise the
host never registers them.
