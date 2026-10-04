# Spec: the plugin manager menu, redesigned

Status: designed, not built (2026-10-04). Settled in a grill-design session with Will, with feedback from AnythingGoes,
CryT4x and low5ive, over three rounds of prototypes and three design reviews. The winner is variant **10 reviewed** on
the prototype branch `claude/prototype-plugin-manager-ui` of `will-ness-ai/ballest-plugin-manager` (kept as the
primary source, never merged); run it with `tools/preview.sh plugins/plugin-manager ../ballest-grind-stats`, open
the menu from the footer, and the pink picker switches to variant 10.

## Problem Statement

The plugin manager's menu works, but it looks like a developer tool rather than part of Ballest: Roboto everywhere,
white-outlined default buttons, cards with a row of five small buttons each, and nothing of the game's lowercase
Cocogoose headings, lime selection and dark panels. It is also hard to use as the registry grows: 24 plugins in one
long "browse" list with no grouping, library plugins (Cosmetic Kit) listed like anything else, an update shown only as
small yellow text on a card, and a plugin's settings reachable only through a "settings" button among four others.

## Solution

The menu keeps its place (the footer's **plugins** button, over the screen) and becomes:

- **A side column** in the game's style: the title, then **installed**, **updates** (only while there are any, in
  lime) and **get more**, each with its count; the open one is a lime block. Under them **back** (the game's blue), then
  quiet **plugins folder** and **console** links for plugin authors.
- **A header row** over the list: the column's heading, a search box, and the **kinds** (all, cosmetics, practice,
  editor, look, other) as chips beside it, each with how many plugins of that kind the current view has; a kind with
  none is hidden. **update all** sits at the right while updates wait. Search and kind filter together.
- **installed** as rows, for managing: icon, name, a line of description (or "0.2.0 to 0.3.0" while an update
  waits), then on the right, always in this order, **update** (only when one waits), **on / off** (or "built in"),
  **settings** (only when the plugin has settings). Rows are tinted a dark blue so installed always reads as yours.
- **get more** as tiles four wide, for shopping: a large icon, the name, and **install**. With no kind picked, the
  tiles are grouped by kind under small headings with counts. Library plugins are left out unless searched for.
- **A plugin's page**, from a row's **settings** button, a row's name, or a tile: a header card with the large icon,
  name, author and version, its on / off (or install), remove and github, the update on its own line ("update to 0.3.0,
  you have 0.2.0"), the description at a readable width, and what it needs ("needs Cosmetic Kit: installed", or an
  **install it** button). Its settings follow, labels in one column and controls lined up in the next. A crumb at the
  top goes back to where it was opened from.
- **Lime means "on, or needs you"**: on, update, update all and the open tab. Install is a grey button with lime text
  on a tile, lime on a plugin's own page. Off and secondary actions are grey.
- **Smaller type** everywhere except the tile and row names, after low5ive's advice.
- **The footer button** reads "plugins  2 new" while updates wait.
- **Dark only.** A light theme was tried and dropped.

## User Stories

1. As a player, I want the plugin menu to look like the game's own menus, so that it feels like part of Ballest.
2. As a player, I want to see the plugins I have in one list, so that I can manage them without searching.
3. As a player, I want each installed plugin's on / off switch in its row, so that I can turn one off in one click.
4. As a player, I want a settings button on every plugin that has settings, so that I find them without guessing.
5. As a player, I want plugins without settings to show no settings button, so that I don't open an empty page.
6. As a player, I want to see at a glance that an update is waiting, from the footer and from the side column, so that
   I don't miss one.
7. As a player, I want to update everything at once, so that I don't click through each plugin.
8. As a player, I want to see which version I'm on and which I'd get, so that I know what an update changes.
9. As a player, I want the plugin manager's own update shown like any other, with "restart to finish" when it needs a
   restart, so that there is one way to update everything.
10. As a player, I want to browse new plugins as pictures, so that I can pick balls by how they look.
11. As a player, I want new plugins grouped by kind, so that cosmetics don't bury the practice tools.
12. As a player, I want to filter by kind next to the search, so that I can narrow the list without leaving it.
13. As a player, I want to see how many plugins each kind has before I pick it, so that I don't open an empty list.
14. As a player, I want search and the kind filter to work together, so that "ball" in cosmetics finds what I mean.
15. As a player, I want a clear way out of a search that found nothing, so that I'm not stuck on an empty page.
16. As a player, I want Escape to clear the search, then leave a plugin's page, then close the menu, so that one key
    always goes back one step.
17. As a player, I want library plugins like Cosmetic Kit kept out of the shop, so that I only see things that do
    something on their own.
18. As a player, I want a plugin's page to say what it needs and whether I have it, so that an install doesn't surprise
    me.
19. As a player, I want a plugin's page to show its picture, author, version and description, so that I can decide
    before installing.
20. As a player, I want a plugin that failed to show "stopped" and its error, so that I know why it isn't working.
21. As a player, I want remove and github on a plugin's page rather than on every row, so that the list stays calm.
22. As a player, I want settings with their labels and controls lined up, so that a long settings page is easy to scan.
23. As a player, I want a setting changed from its default to offer "default", so that I can undo it.
24. As a player, I want text sized for a TV across the room, so that I can read it from the couch.
25. As a plugin author, I want the console and the plugins folder still one click away, so that debugging stays quick.
26. As a plugin author, I want my plugin's registry entry to say its kind, so that players find it in the right place.
27. As a plugin author of a library, I want to mark it as one, so that players get it with the plugins that need it.
28. As a maintainer, I want before and after screenshots of every screen in the pull request, so that I can review the
    change without building it.
29. As a maintainer, I want the redesign tested without the game, so that a change to the menu is checked in seconds.

## Implementation Decisions

- **Only the plugin manager plugin and the host's UI change**, plus two registry fields. The plugin's script is
  rewritten around the new layout; the console view stays as it is and opens from the column's **console** link.
- **Registry fields**, set by the maintainers in `registry.json` (and written by the registry tool): `category`, one of
  cosmetics, practice, editor, look, other; `library`, true for plugins that do nothing alone. The script API exposes
  both on `Registry::`, and an installed plugin's own `info.toml` may carry them too. The prototype stands in for them
  with a table by id.
- **Host UI additions** the design needs, each small, each found necessary by the prototypes (where the prototype
  marks them `PROTOTYPE`, they are rebuilt properly with docs and API tests):
  - buttons: a flat rounded style (corner radius, padding, no outline, lighter on hover, darker pressed), a label size,
    a label colour, and a label font (the game's Cocogoose);
  - cards side by side in one row (`StartCardRow` / `EndCardRow`), a card's own colour, and a card's share of its row's
    width;
  - a sidebar that can be cleared and filled again (or a sidebar per view);
  - text that wraps at the width it gets.
- **The header stays put while the list is rebuilt**: search and the kind chips live in the window's header, so typing
  is never interrupted; the chips and the column are recoloured and relabelled in place.
- **Colours** (sRGB, converted to linear for the API): panel #1b1b1d, card #252528, installed #1f2b3d, secondary
  button #3a3a3e, lime #c6f432 with #111 text, column text #b8b8bc, headings #8a8a90, meta text #a8a8ae, the game's
  blue #0a5ccc for back. Sizes (points): title 30, heading 24, column 18, row and tile names 18-19.5, buttons 14-15,
  body 12-15.
- **The plugin manager's own update** is a row like any other in installed and updates; while it waits for a restart
  its button reads "restart to finish" and does nothing else.
- **Copy** follows Will's plain-copy rule: short, lowercase labels like the game's, no explanatory hints.

The decision-rich part of the prototype, the row's action order:

```
if update waiting      [update]           lime
if built in             built in          grey text, in the on / off column
else if stopped         stopped           red text
else                   [on] / [off]       lime / grey
if it has settings     [settings]         grey
```

## Testing Decisions

- **The seam is the window model** (`ui.hpp`: what a window shows, and the input written back into it), through the
  preview (`tools/preview`, its own pull request first): the menu is tested by what it shows after a list of steps,
  never by its script's internals. Good tests read like a player: open the menu, type a search, pick a kind, open a
  plugin's settings, change one, press Escape.
- **Golden text tests** in `tools/preview/tests/` against the four-plugin test registry (extended with a `category`
  and a library): the installed list, an update waiting, get more grouped by kind, a kind picked, a search with no
  match and its clear, a plugin's page with settings, Escape's three steps. Prior art: `plugin-manager.steps`.
- **The host additions** get API tests in `tools/api-tests/` like the existing ones, and the regression suite
  (`tools/regression.py`) still passes in a test copy.
- **One look in the game** before the pull request: a test copy with the new host build, screenshotted (the font and
  sizes are the game's only there).

## Out of Scope

- Gathering other plugins' footer buttons into the menu (asked in grilling, not designed).
- A light theme (tried in round 2 and dropped).
- Plugin screenshots, ratings or download counts in the registry.
- Automatic updates.
- The console's own design.
- Sizing the scroll area to whole rows (the host cannot yet; lists end with space so the last row scrolls into view).

## Further Notes

- **The pull request must carry before and after screenshots of every screen** (Will): before, today's menu in the
  game (installed, browse, a plugin's settings, the console); after, the new menu in the game and in the preview
  (installed, updates waiting, get more, a kind picked, a plugin's page with settings, a plugin to get, nothing
  matches). Pictures are data and allowed in upstream pull requests; they go in the pull request's description.
- **Order of pull requests upstream**: the preview (`claude/ui-preview`) first, then the host UI additions, then the
  redesign, each one reviewable alone. Upstream picks version numbers.
- Grilling decisions this rests on: everything but the console in scope; host and registry changes allowed; players
  first, plugin authors' tools kept but out of the way; library plugins hidden from the shop; categories set in the
  registry; an update badge and update all, no automatic updates; the plugin manager's own update shown like any
  other; the pull request is where AnythingGoes weighs in.

## Screenshots

In `plugin-manager-redesign/` beside this spec, all 1280 x 720:

- before, in the game: `before-installed`, `before-browse`, `before-settings`, `before-console`
- after, in the game (test copy, prototype host): `after-game-installed`, `after-game-updates`, `after-game-page`
- after, in the preview (stand-in font): `after-preview-installed`, `-updates`, `-more`, `-practice`, `-settings`,
  `-empty`, `-toget`
