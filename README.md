# TitanAddonMenu

A [Titan Panel](https://www.curseforge.com/wow/addons/titan-panel) plugin that gathers every addon's
"open my settings" entry point into **one** bar button.

Click the **Addons** button for a menu with three sections. Clicking a launcher entry sends
its left-click; **hover the entry for a submenu with explicit Left click / Right click** items
(Bartender4, for example, unlocks its bars on left-click and opens options on right-click).
The bar button has no tooltip of its own, so it never covers the menu.

| Section | Source | Examples |
|---|---|---|
| Launchers | LibDataBroker `launcher` objects (the minimap-button convention) | Bartender4, Masque, Plater, BugSack, Prat |
| Addon Compartment | addons that declare `## AddonCompartmentFunc` in their TOC and have no launcher | DialogueUI |
| Slash commands | a user-maintained list for addons that expose neither | Arc Auras (`/arcauras`), Shadowed Unit Frames (`/suf`) |

Once this is on your bar you can hide the individual launcher buttons from Titan
(Titan > Configuration > Plugins) and keep the bar clean.

## Slash commands

```
/addonmenu                  help
/addonmenu list             list slash entries
/addonmenu add /cmd Label   add or relabel an entry
/addonmenu remove /cmd      remove an entry
/addonmenu reset            restore the defaults
```

`/tam` is an alias for `/addonmenu`.

Slash entries are run by looking the command up in `SlashCmdList` and calling the handler
directly; if it is not registered the text is sent through the chat edit box instead.

## Install

Copy the `TitanAddonMenu` folder into `Interface/AddOns/`. Requires Titan Panel.

Tested on WoW: Forever (interface 16001) with Titan Panel 9.3.x. The TOC also lists the
current retail interface numbers; the code uses nothing version-specific beyond `MenuUtil`
and `C_AddOns`, both present on the modern client.

## How it works

It is written as an LDB launcher object rather than a native Titan plugin, which is the
integration path Titan's developer notes recommend (`Titan/_ATitanDoc.lua`, and the bundled
`TitanUI` plugin is the reference example). Titan wraps the object in its own button, handles
placement, the tooltip frame and click dispatch; this addon only supplies the data object,
the tooltip text and a `MenuUtil` context menu.

## License

MIT
