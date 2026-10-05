// Plugin Manager: a "plugins" entry in the game's footer (main menu, inside maps and in the track editor) that opens
// the plugin manager menu, and closes it again. The menu is drawn in the game's own style (docs/specs/
// plugin-manager-redesign.md has the design and its screenshots):
//   the column   installed, updates (only while there are any) and get more, each with its count; back; the plugins
//                folder and the console, for plugin authors.
//   the header   the open list's heading, a search box, and the kinds of plugin (all, cosmetics, practice, editor,
//                look, other) as chips with how many of each the list has; update all while updates wait.
//   installed    a row per plugin: update (when one waits), on / off, settings (when it has any). A plugin turned off
//                stays installed but doesn't run, also after a restart.
//   updates      the installed plugins with an update, the plugin manager itself included (it finishes on a restart).
//   get more     tiles of the registry's plugins that aren't installed, grouped by kind; library plugins (Cosmetic
//                Kit) only when searched for, since they come with the plugins that need them.
//   a plugin     from a row's settings or name, or a tile: what it is, what it needs, its buttons, then its settings.
//   console      the host log as it is written, and host commands (find, props, functions, ...; the full list is in
//                src/host/testchannel.hpp): type one and press Enter, or click run. "show" filters the log.
//   Search finds the plugins whose name has every word typed, anywhere in it; the best matches come first.
//   Escape goes back one step: a plugin's page to its list, a search to empty, then out of the menu.

UI::FooterButton@ button;

// Colours, as picked on screen (sRGB hex). The game's widget colours are linear, so they are converted (Lin).
const uint PANEL = 0x1b1b1d;        // the menu
const uint TILE = 0x252528;         // a plugin to get
const uint MINE = 0x1f2b3d;         // an installed plugin: a dark tint of the game's blue
const uint SECOND = 0x3a3a3e;       // secondary buttons, kind chips
const uint LIME = 0xc6f432;         // on, update, install on a plugin's page, the open tab
const uint INK = 0x111111;          // text on lime
const uint WHITE = 0xffffff;
const uint SOFT = 0xe8e8ea;         // text on secondary buttons
const uint COLUMN = 0xb8b8bc;       // the column's labels
const uint HEAD = 0x8a8a90;         // small headings, "built in"
const uint META = 0xa8a8ae;         // authors, versions
const uint MUTED = 0x9a9aa0;        // descriptions
const uint BLUE = 0x0a5ccc;         // back
const uint WARN = 0xf2c14e;
const uint BAD = 0xff736b;
const string FONT = "/Game/UI/Fonts/CocogoosePro.CocogoosePro";
const array<string> KINDS = {"cosmetics", "practice", "editor", "look", "other"};

float Lin(uint c)
{
    double v = c / 255.0;
    return float(v <= 0.04045 ? v / 12.92 : Math::pow((v + 0.055) / 1.055, 2.4));
}
float R(uint hex) { return Lin((hex >> 16) & 255); }
float G(uint hex) { return Lin((hex >> 8) & 255); }
float B(uint hex) { return Lin(hex & 255); }

UI::Text@ T(UI::Window@ w, const string &in s, float size, uint hex, bool display = false)
{
    UI::Text@ t = w.AddText(s, size);
    t.SetColor(R(hex), G(hex), B(hex), 1);
    if (display)
        t.SetFont(FONT);
    return t;
}

void Paint(UI::Button@ b, uint background, uint label)
{
    b.SetBackground(R(background), G(background), B(background), 1);
    b.SetColor(R(label), G(label), B(label), 1);
}

// A button in the game's style: flat, rounded, the game's font.
UI::Button@ Btn(UI::Window@ w, const string &in label, uint background, uint text, float size = 15, float padX = 24, float padY = 7)
{
    UI::Button@ b = w.AddButton(label);
    b.SetCornerRadius(8);
    b.SetPadding(padX, padY);
    b.SetFont(FONT);
    b.size = size;
    Paint(b, background, text);
    return b;
}
UI::Button@ Lime(UI::Window@ w, const string &in label, float size = 15) { return Btn(w, label, LIME, INK, size); }
UI::Button@ Grey(UI::Window@ w, const string &in label, float size = 15) { return Btn(w, label, SECOND, SOFT, size); }
UI::Button@ Install(UI::Window@ w, const string &in label, float size = 15) { return Btn(w, label, SECOND, LIME, size); }

// --- what the menu shows ----------------------------------------------------------------------------------------------

class Entry
{
    string id, name, version, author, description, icon, page, kind = "other", update, status, pending;
    bool installed = false, enabled = true, essential = false, library = false, hasSettings = false, broken = false;
    array<string> needs;
    array<string> neededBy;
}

array<Entry@> entries;
string entriesFrom;                 // what they were read from; read again when it changes

int RegistryIndex(const string &in id)
{
    for (uint i = 0; i < Registry::Count(); i++)
        if (Registry::Id(i) == id)
            return int(i);
    return -1;
}

int InstalledIndex(const string &in id)
{
    for (uint i = 0; i < Plugins::Count(); i++)
        if (Plugins::Id(i) == id)
            return int(i);
    return -1;
}

// A newer plugin manager in the registry than the one running, or "".
string HostUpdate()
{
    string latest = Registry::HostVersion();
    return latest != "" && CompareVersions(latest, Host::Version()) > 0 ? latest : "";
}

// "1.10.0" > "1.9.2"
int CompareVersions(const string &in a, const string &in b)
{
    array<string>@ x = a.split(".");
    array<string>@ y = b.split(".");
    for (uint i = 0; i < x.length() || i < y.length(); i++)
    {
        int64 nx = i < x.length() ? parseInt(x[i]) : 0;
        int64 ny = i < y.length() ? parseInt(y[i]) : 0;
        if (nx != ny)
            return nx < ny ? -1 : 1;
    }
    return 0;
}

// Whether a plugin has anything for its page's settings: settings, or windows that can be dragged.
bool HasSettings(const string &in id)
{
    if (UI::HasMovable(id))
        return true;
    for (uint i = 0; i < Settings::Count(); i++)
        if (Settings::Plugin(i) == id && !Settings::Hidden(i))
            return true;
    return false;
}

// Everything the menu shows, as one string: when it changes, the entries are read again and the list rebuilt.
string State()
{
    string state = Registry::State() + "|host:" + HostUpdate() + ":" + Plugins::HostUpdateState();
    for (uint i = 0; i < Registry::Count(); i++)
        state += "|r:" + Registry::Id(i) + ":" + Registry::Version(i) + ":" + Registry::Icon(i) + ":" + Plugins::Pending(Registry::Id(i));
    for (uint i = 0; i < Plugins::Count(); i++)
        state += "|p:" + Plugins::Id(i) + ":" + Plugins::Version(i) + ":" + Plugins::Status(i) + ":" + Plugins::Pending(Plugins::Id(i)) +
                 (Plugins::Enabled(i) ? "" : ":off") + (HasSettings(Plugins::Id(i)) ? ":s" : "");
    return state;
}

void ReadEntries()
{
    entries.resize(0);
    for (uint p = 0; p < Plugins::Count(); p++)
    {
        Entry e;
        e.id = Plugins::Id(p);
        e.name = Plugins::Name(p);
        e.version = Plugins::Version(p);
        e.author = Plugins::Author(p);
        e.description = Plugins::Description(p);
        e.icon = Plugins::Icon(p);
        e.installed = true;
        e.enabled = Plugins::Enabled(p);
        e.essential = Plugins::Essential(p);
        e.status = Plugins::Status(p);
        e.pending = Plugins::Pending(e.id);
        int r = RegistryIndex(e.id);
        if (r >= 0)
        {
            e.page = Registry::Page(r);
            e.kind = Registry::Category(r);
            e.library = Registry::Library(r);
            e.needs = Registry::Dependencies(r);
            if (Registry::Description(r) != "")
                e.description = Registry::Description(r);
            if (CompareVersions(Registry::Version(r), e.version) > 0)
                e.update = Registry::Version(r);
        }
        if (e.id == "plugin-manager")
            e.update = HostUpdate();
        e.broken = e.enabled && e.status != "running";
        e.hasSettings = HasSettings(e.id);
        entries.insertLast(e);
    }
    for (uint r = 0; r < Registry::Count(); r++)
    {
        if (InstalledIndex(Registry::Id(r)) >= 0)
            continue;
        Entry e;
        e.id = Registry::Id(r);
        e.name = Registry::Name(r);
        e.version = Registry::Version(r);
        e.author = Registry::Author(r);
        e.description = Registry::Description(r);
        e.icon = Registry::Icon(r);
        e.page = Registry::Page(r);
        e.kind = Registry::Category(r);
        e.library = Registry::Library(r);
        e.needs = Registry::Dependencies(r);
        e.pending = Plugins::Pending(e.id);
        entries.insertLast(e);
    }
    for (uint i = 0; i < entries.length(); i++)
        for (uint k = 0; k < entries[i].needs.length(); k++)
        {
            Entry@ needed = Find(entries[i].needs[k]);
            if (needed !is null && entries[i].installed)
                needed.neededBy.insertLast(entries[i].name);
        }
    entriesFrom = State();
}

Entry@ Find(const string &in id)
{
    for (uint i = 0; i < entries.length(); i++)
        if (entries[i].id == id)
            return entries[i];
    return null;
}

string IconOf(Entry@ e) { return e.icon == "" ? Plugins::DefaultIcon() : e.icon; }

// --- search -----------------------------------------------------------------------------------------------------------

string Lower(const string &in text)
{
    string t = text;
    for (uint i = 0; i < t.length(); i++)
        if (t[i] >= 65 && t[i] <= 90)
            t[i] = t[i] + 32;
    return t;
}

string WithoutSpaces(const string &in text)
{
    string t;
    for (uint i = 0; i < text.length(); i++)
        if (text[i] != 32 && text[i] != 45 && text[i] != 95)     // space, - and _
            t += text.substr(i, 1);
    return t;
}

// How well a name matches what's typed: -1 not at all, else higher first. Every word typed must be somewhere in the
// name (the middle of a word counts: "timer" and "rind" both find Grind Timer), or in it with its spaces left out
// ("grindtimer"). A word that starts one of the name's words scores more than one found in the middle.
int SearchScore(const string &in name, const string &in query)
{
    string n = Lower(name), bare = WithoutSpaces(n);
    array<string>@ words = Lower(query).split(" ");
    int score = 0, used = 0;
    for (uint w = 0; w < words.length(); w++)
    {
        string word = words[w];
        if (word == "")
            continue;
        used++;
        int at = n.findFirst(word);
        if (at < 0)
        {
            if (bare.findFirst(WithoutSpaces(word)) < 0)
                return -1;
            score += 1;
            continue;
        }
        bool starts = at == 0 || n[at - 1] == 32 || n[at - 1] == 45;
        score += starts ? (at == 0 ? 4 : 3) : 2;
    }
    return used == 0 ? 0 : score;
}

bool Searching() { return WithoutSpaces(search) != ""; }

bool InTab(Entry@ e, const string &in t)
{
    if (t == "installed")
        return e.installed;
    if (t == "updates")
        return e.installed && e.update != "";
    return !e.installed && (!e.library || Searching());
}

// The open list: in the tab, of the kind picked, matching the search (best first).
array<Entry@> Listed()
{
    array<Entry@> found;
    array<int> scores;
    for (uint i = 0; i < entries.length(); i++)
    {
        Entry@ e = entries[i];
        if (!InTab(e, tab) || (kind != "" && e.kind != kind))
            continue;
        int score = SearchScore(e.name, search);
        if (score < 0)
            continue;
        uint at = found.length();
        while (at > 0 && scores[at - 1] < score)
            at--;
        found.insertAt(at, e);
        scores.insertAt(at, score);
    }
    return found;
}

uint CountOf(const string &in t, const string &in k)
{
    uint n = 0;
    for (uint i = 0; i < entries.length(); i++)
        if (InTab(entries[i], t) && (k == "" || entries[i].kind == k) && SearchScore(entries[i].name, search) >= 0)
            n++;
    return n;
}

// --- the menu ---------------------------------------------------------------------------------------------------------

UI::Window@ menu;
int listView = -1, consoleView = -1;
string tab = "installed";           // installed, updates, more, console
string page;                        // the plugin whose page is open, or ""
string kind;                        // the kind picked, "" all
string search;                      // what the list was built for
array<UI::Button@> tabs;
const array<string> TABS = {"installed", "updates", "more"};
UI::Button@ backButton, folderButton, consoleButton;
UI::Text@ heading;
UI::TextInput@ searchBox;
array<UI::Button@> kindChips;       // all, then KINDS
UI::Button@ updateAll;

// the list's buttons and what each does: "install:<id>", "update:<id>", "remove:<id>", "on:<id>", "off:<id>",
// "open:<url>", "page:<id>", "back", "clear"
array<UI::Button@> listButtons;
array<string> listActions;

void Main()
{
    Log::Info("plugin manager started on host " + Host::Version());
    @button = UI::AddFooterButton("plugins");
    BuildMenu();
}

void BuildMenu()
{
    @menu = UI::CreateWindow();
    menu.SetScreenSize(0.86f, 0.84f);
    menu.SetBackground(R(PANEL), G(PANEL), B(PANEL), 1);
    menu.SetCardBackground(R(TILE), G(TILE), B(TILE), 1);
    menu.SetBlocksClicks(true);         // the game's menu underneath must not get clicks through it
    menu.zOrder = 500;                  // in front of every other plugin's windows (they default to 100)
    menu.visible = false;

    menu.StartSidebar(200);
    T(menu, "plugins", 30, WHITE, true);
    menu.AddSpace(8);
    for (uint t = 0; t < TABS.length(); t++)
        tabs.insertLast(Btn(menu, TABS[t], PANEL, COLUMN, 18, 16, 8));
    menu.AddSpace(16);
    @backButton = Btn(menu, "back", BLUE, WHITE, 18, 16, 8);
    menu.AddSpace(16);
    @folderButton = Btn(menu, "plugins folder", PANEL, HEAD, 12, 4, 2);
    @consoleButton = Btn(menu, "console", PANEL, HEAD, 12, 4, 2);
    menu.StartMain();

    menu.StartHeader();
    @heading = T(menu, "installed", 24, WHITE, true);
    menu.AddSpace(24);
    @searchBox = menu.AddTextInput(360, "search plugins", 16.5f);
    searchBox.clearOnSubmit = false;
    searchBox.clearButton = true;
    menu.AddSpace(12);
    for (uint k = 0; k <= KINDS.length(); k++)
    {
        UI::Button@ chip = Btn(menu, k == 0 ? "all" : KINDS[k - 1], SECOND, COLUMN, 15, 16, 7);
        if (k > 0)
            chip.SetGapBefore(8);
        kindChips.insertLast(chip);
    }
    menu.AddSpace(0);
    @updateAll = Lime(menu, "update all", 14);

    listView = menu.StartView();
    menu.SetScrolling(listView, true);
    consoleView = menu.StartView();
    BuildConsole();
    ReadEntries();
    Show();
}

void OpenMenu()
{
    menu.visible = true;
    UI::SetCursorVisible(true);
    shownLogLines = 0;              // show the log as it is now
    if (entriesFrom != State())
        ReadEntries();
    Show();
    Log::Info("menu opened");
}

void CloseMenu()
{
    menu.visible = false;
    UI::SetCursorVisible(false);
    Log::Info("menu closed");
}

// The column, the header and the open view, as they should be now: labels, counts and colours change in place; the
// list is built again.
void Show()
{
    bool console = tab == "console";
    menu.ShowView(console ? consoleView : listView);
    uint updates = CountOfAll("updates");
    array<string> labels = {"installed  " + CountOfAll("installed"), "updates  " + updates, "get more  " + CountOfAll("more")};
    for (uint t = 0; t < tabs.length(); t++)
    {
        bool open = TABS[t] == tab;
        tabs[t].label = labels[t];
        tabs[t].visible = TABS[t] != "updates" || updates > 0;
        Paint(tabs[t], open ? LIME : PANEL, open ? INK : TABS[t] == "updates" ? LIME : COLUMN);
    }
    Paint(consoleButton, console ? LIME : PANEL, console ? INK : HEAD);
    heading.text = console ? "console" : page != "" ? "" : tab == "more" ? "get more" : tab;
    bool filtering = !console && page == "";
    searchBox.visible = filtering;
    for (uint k = 0; k < kindChips.length(); k++)
    {
        string chipKind = k == 0 ? "" : KINDS[k - 1];
        uint n = k == 0 ? 0 : CountOf(tab, chipKind);
        if (k > 0)
            kindChips[k].label = chipKind + "  " + n;
        kindChips[k].visible = filtering && (k == 0 || n > 0 || chipKind == kind);
        Paint(kindChips[k], chipKind == kind ? LIME : SECOND, chipKind == kind ? INK : COLUMN);
    }
    updateAll.label = "update all  " + updates;
    updateAll.visible = filtering && updates > 0 && Plugins::HostUpdateState() != "downloading";
    button.label = updates > 0 ? "plugins " + updates : "plugins";
    if (!console)
        BuildList();
}

uint CountOfAll(const string &in t)
{
    uint n = 0;
    for (uint i = 0; i < entries.length(); i++)
        if (InTab(entries[i], t) && !(t == "more" && entries[i].library))
            n++;
    return n;
}

UI::Button@ ListButton(UI::Button@ b, const string &in action)
{
    listButtons.insertLast(b);
    listActions.insertLast(action);
    return b;
}

void BuildList()
{
    menu.ClearView(listView);
    listButtons.resize(0);
    listActions.resize(0);
    form.Clear();
    if (page != "")
    {
        Entry@ e = Find(page);
        if (e !is null)
        {
            BuildPage(e);
            return;
        }
        page = "";
    }
    search = searchBox.typed;
    string state = Registry::State();
    if (tab == "more" && state != "ready")
    {
        T(menu, state == "loading" || state == "" ? "Loading the registry..." : "The registry couldn't be loaded (" + state + ").", 16.5f, META);
        menu.NewRow();
        ListButton(Grey(menu, "try again"), "refresh");
        return;
    }
    array<Entry@> list = Listed();
    if (list.length() == 0)
    {
        T(menu, Searching() ? "Nothing matches \"" + search + "\"." : tab == "updates" ? "Everything is up to date." :
                tab == "more" ? "Every plugin in the registry is installed." : "No plugins installed.", 16.5f, META);
        if (Searching() || kind != "")
        {
            menu.NewRow();
            ListButton(Install(menu, "clear search"), "clear");
        }
        return;
    }
    if (tab == "more")
    {
        if (kind == "" && !Searching())
        {
            // every kind: one group each, so the list reads like a shelf
            for (uint k = 0; k < KINDS.length(); k++)
            {
                array<Entry@> group;
                for (uint i = 0; i < list.length(); i++)
                    if (list[i].kind == KINDS[k])
                        group.insertLast(list[i]);
                if (group.length() == 0)
                    continue;
                menu.NewRow();
                T(menu, KINDS[k] + "  " + group.length(), 16.5f, HEAD, true);
                Tiles(group);
            }
        }
        else
            Tiles(list);
    }
    else
    {
        for (uint i = 0; i < list.length(); i++)
            Row(list[i]);
    }
    // room under the last row, so it can scroll fully into view
    menu.NewRow();
    T(menu, " ", 90, PANEL);
}

// --- installed and updates: a row per plugin --------------------------------------------------------------------------

//   [icon] Grind Stats  0.2.0 to 0.3.0               [update] [on] [settings]
void Row(Entry@ e)
{
    menu.StartCard();
    menu.SetCardColor(R(MINE), G(MINE), B(MINE), 1);
    menu.AddImage(IconOf(e), 48, 48);
    ListButton(Btn(menu, e.name, MINE, WHITE, 18, 4, 2), "page:" + e.id);
    string line = e.update != "" ? e.version + " to " + e.update : e.pending != "" ? e.pending : e.broken ? e.status : e.description;
    UI::Text@ about = T(menu, Shorten(line, 90), 13.5f, e.broken || e.pending.findFirst("error") == 0 ? BAD : e.update != "" ? META : MUTED);
    about.SetFill(true);
    Actions(e);
    menu.EndCard();
}

// A row's buttons, always in this order: update (when one waits), on / off (or what it is instead), settings.
void Actions(Entry@ e)
{
    bool busy = e.pending == "installing" || e.pending == "removing";
    if (e.id == "plugin-manager")
    {
        string host = Plugins::HostUpdateState();
        if (host == "restart")
            T(menu, "restart to finish", 13.5f, WARN, true);
        else if (host == "downloading")
            T(menu, "updating...", 13.5f, META, true);
        else if (e.update != "")
            ListButton(Lime(menu, "update", 14), "update:" + e.id);
    }
    else if (e.update != "" && !busy)
        ListButton(Lime(menu, "update", 14), "update:" + e.id);
    if (e.essential)
        T(menu, "built in", 13.5f, HEAD, true).SetWidth(96);
    else if (busy)
        T(menu, e.pending + "...", 13.5f, META, true).SetWidth(96);
    else if (e.broken)
        T(menu, "stopped", 13.5f, BAD, true).SetWidth(96);
    else
        ListButton(e.enabled ? Lime(menu, "on", 14) : Btn(menu, "off", SECOND, 0xc8c8cc, 14), (e.enabled ? "off:" : "on:") + e.id);
    UI::Button@ settings = ListButton(Grey(menu, "settings", 14), "page:" + e.id);
    settings.visible = e.hasSettings;
}

string Shorten(const string &in text, int length)
{
    return int(text.length()) <= length ? text : text.substr(0, length - 3) + "...";
}

// --- get more: tiles, four a row --------------------------------------------------------------------------------------

void Tiles(array<Entry@> list)
{
    for (uint start = 0; start < list.length(); start += 4)
    {
        menu.StartCardRow();
        for (uint k = 0; k < 4; k++)
        {
            menu.StartCard();
            if (start + k >= list.length())
            {
                menu.SetCardColor(0, 0, 0, 0);      // keeps a short last row's tiles the same width
                menu.AddSpace(10);
                continue;
            }
            Tile(list[start + k]);
        }
        menu.EndCardRow();
    }
}

void Tile(Entry@ e)
{
    menu.AddSpace(0);
    menu.AddImage(IconOf(e), 112, 112);
    menu.AddSpace(0);
    menu.NewRow();
    menu.AddSpace(0);
    ListButton(Btn(menu, e.name, TILE, WHITE, 19.5f, 4, 2), "page:" + e.id);
    menu.AddSpace(0);
    menu.NewRow();
    menu.AddSpace(0);
    if (e.pending.findFirst("error") == 0)
        T(menu, e.pending, 13.5f, BAD);
    else if (e.pending == "installing")
        T(menu, "installing...", 13.5f, META, true);
    else
        ListButton(Install(menu, "install"), "install:" + e.id);
    menu.AddSpace(0);
}

// --- a plugin's page --------------------------------------------------------------------------------------------------

//   [< installed]
//   [icon]  Grind Stats  by AnythingGoes, Will  0.2.0                     [on] [remove] [github]
//           [update to 0.3.0]  you have 0.2.0
//           Played time, attempts and finishes on a card, ...
//           needs Cosmetic Kit: installed
//   settings
//   window position                                         [reset position]
void BuildPage(Entry@ e)
{
    ListButton(Btn(menu, "< " + (tab == "more" ? "get more" : tab), SECOND, SOFT, 16.5f, 16, 8), "back");
    menu.StartCard();
    if (e.installed)
        menu.SetCardColor(R(MINE), G(MINE), B(MINE), 1);
    menu.AddImage(IconOf(e), 128, 128);
    T(menu, e.name, 27, WHITE, true);
    T(menu, "by " + e.author + "   " + e.version, 13.5f, META);
    menu.AddSpace(0);
    bool busy = e.pending == "installing" || e.pending == "removing";
    if (busy)
        T(menu, e.pending + "...", 15, META, true);
    else if (!e.installed)
        ListButton(Lime(menu, "install", 18), "install:" + e.id);
    else if (e.essential)
        T(menu, "built in", 13.5f, HEAD, true);
    else if (e.broken)
        T(menu, "stopped", 13.5f, BAD, true);
    else
        ListButton(e.enabled ? Lime(menu, "on", 18) : Btn(menu, "off", SECOND, 0xc8c8cc, 18), (e.enabled ? "off:" : "on:") + e.id);
    if (e.installed && !e.essential && !busy)
        ListButton(Grey(menu, "remove", 13.5f), "remove:" + e.id);
    if (e.page != "")
        ListButton(Grey(menu, "github", 13.5f), "open:" + e.page);
    if (e.installed && e.update != "" && !busy)
    {
        menu.NewRow();
        menu.AddSpace(128);
        if (e.id == "plugin-manager" && Plugins::HostUpdateState() == "restart")
            T(menu, "Plugin manager " + e.update + " is installed: restart the game to finish.", 15, WARN);
        else if (e.id == "plugin-manager" && Plugins::HostUpdateState() == "downloading")
            T(menu, "Updating to " + e.update + "...", 15, META);
        else
        {
            ListButton(Lime(menu, "update to " + e.update, 16.5f), "update:" + e.id);
            T(menu, "you have " + e.version, 13.5f, META);
        }
    }
    menu.NewRow();
    menu.AddSpace(128);
    UI::Text@ about = T(menu, e.description == "" ? "No description." : e.description, 15, WHITE);
    about.SetWrap(true);
    about.SetWidth(900);
    if (e.broken || e.pending.findFirst("error") == 0 || (e.id == "plugin-manager" && Plugins::HostUpdateState().findFirst("error") == 0))
    {
        menu.NewRow();
        menu.AddSpace(128);
        string error = e.broken ? e.status : e.pending.findFirst("error") == 0 ? e.pending : Plugins::HostUpdateState();
        UI::Text@ problem = T(menu, error, 13.5f, BAD);
        problem.SetWrap(true);
        problem.SetWidth(900);
    }
    for (uint k = 0; k < e.needs.length(); k++)
    {
        menu.NewRow();
        menu.AddSpace(128);
        Entry@ need = Find(e.needs[k]);
        bool have = need !is null && need.installed;
        T(menu, "needs " + (need is null ? e.needs[k] : need.name) + (have ? ": installed" : ""), 13.5f, META);
        if (!have && e.installed)
            ListButton(Install(menu, "install it", 13.5f), "install:" + e.needs[k]);
        else if (!have)
            T(menu, "(installed with it)", 13.5f, HEAD);
    }
    if (e.neededBy.length() > 0)
    {
        menu.NewRow();
        menu.AddSpace(128);
        string names;
        for (uint k = 0; k < e.neededBy.length(); k++)
            names += (k > 0 ? ", " : "") + e.neededBy[k];
        T(menu, "needed by " + names, 13.5f, META);
    }
    menu.EndCard();
    if (e.installed && e.hasSettings)
    {
        menu.NewRow();
        T(menu, "settings", 18, HEAD, true);
        form.Build(e.id);
    }
    menu.NewRow();
    T(menu, " ", 60, PANEL);
}

// --- a plugin's settings ----------------------------------------------------------------------------------------------

// The plugin's [Setting] variables: on / off for a bool, a list for a choice, a slider and a box for a number with
// min and max, a box otherwise; "default" once one has changed. "reset position" when it has windows to drag. Labels
// in one column, controls lined up after them.
class SettingsForm
{
    string plugin;
    array<UI::Button@> toggles;
    array<uint> toggleSetting;
    array<UI::Slider@> sliders;
    array<uint> sliderSetting;
    array<UI::TextInput@> inputs;
    array<uint> inputSetting;
    array<string> inputShown;       // per text box: the value it was last given
    array<UI::Button@> resets;
    array<uint> resetSetting;
    array<UI::Dropdown@> dropdowns;
    array<uint> dropdownSetting;
    UI::Button@ positionReset;
    string shownFrom;               // what the form was built from

    void Clear()
    {
        plugin = "";
        toggles.resize(0); toggleSetting.resize(0); sliders.resize(0); sliderSetting.resize(0);
        inputs.resize(0); inputSetting.resize(0); inputShown.resize(0); resets.resize(0); resetSetting.resize(0);
        dropdowns.resize(0); dropdownSetting.resize(0);
        @positionReset = null;
    }

    string From(const string &in id)
    {
        string state = id + "|" + (UI::HasMovable(id) ? "movable" : "");
        for (uint i = 0; i < Settings::Count(); i++)
            if (Settings::Plugin(i) == id)
                state += "|" + Settings::Name(i);
        return state;
    }

    UI::Text@ Label(const string &in text)
    {
        UI::Text@ label = T(menu, text, 14, WHITE);
        label.SetWidth(520);
        return label;
    }

    void Build(const string &in id)
    {
        plugin = id;
        shownFrom = From(id);
        if (UI::HasMovable(id))
        {
            menu.StartCard();
            Label("window position");
            @positionReset = Grey(menu, "reset position", 14);
            menu.NewRow();
            T(menu, "Drag its windows anywhere while the cursor shows.", 12, MUTED);
            menu.EndCard();
        }
        for (uint i = 0; i < Settings::Count(); i++)
        {
            if (Settings::Plugin(i) != id || Settings::Hidden(i))
                continue;
            menu.StartCard();
            Label(Lower(Settings::Name(i)));
            string settingKind = Settings::Kind(i);
            array<string>@ options = Settings::Choices(i);
            if (settingKind == "bool")
            {
                toggles.insertLast(Btn(menu, "on", LIME, INK, 14, 30, 6));
                toggleSetting.insertLast(i);
            }
            else if (options.length() > 0)
            {
                UI::Dropdown@ drop = menu.AddDropdown(240);
                for (uint k = 0; k < options.length(); k++)
                    drop.AddOption(options[k]);
                drop.selected = options.find(Settings::Get(i));
                dropdowns.insertLast(drop);
                dropdownSetting.insertLast(i);
            }
            else
            {
                // The box shows the value: edit it and press Enter. With a range there's a slider too, and a typed
                // number is clamped to the range.
                if (settingKind != "string" && Settings::HasRange(i))
                {
                    sliders.insertLast(menu.AddSlider(360));
                    sliderSetting.insertLast(i);
                }
                UI::TextInput@ box = menu.AddTextInput(settingKind == "string" ? 360 : 90, "", 15);
                box.clearOnSubmit = false;
                box.value = Settings::Get(i);
                inputs.insertLast(box);
                inputSetting.insertLast(i);
                inputShown.insertLast(Settings::Get(i));
            }
            UI::Button@ reset = Btn(menu, "default", PANEL, MUTED, 13, 12, 5);
            reset.visible = !Settings::IsDefault(i);
            resets.insertLast(reset);
            resetSetting.insertLast(i);
            if (Settings::Description(i) != "")
            {
                menu.NewRow();
                T(menu, Settings::Description(i), 12, MUTED);
            }
            menu.EndCard();
        }
    }

    // False once the plugin's settings changed shape (it was reloaded): the page is built again.
    bool Update()
    {
        if (plugin == "")
            return true;
        if (From(plugin) != shownFrom)
            return false;
        for (uint n = 0; n < toggles.length(); n++)
            if (toggles[n].Clicked())
                Settings::Set(toggleSetting[n], Settings::Get(toggleSetting[n]) == "true" ? "false" : "true");
        for (uint n = 0; n < sliders.length(); n++)
        {
            uint i = sliderSetting[n];
            if (sliders[n].dragging)
                Settings::Set(i, formatFloat(Settings::Min(i) + sliders[n].value * (Settings::Max(i) - Settings::Min(i)), "", 0, 3));
            else
                sliders[n].value = float(Fraction(i));
        }
        for (uint n = 0; n < inputs.length(); n++)
        {
            bool submitted = inputs[n].Submitted();
            if (submitted && !Settings::Set(inputSetting[n], inputs[n].text))
                Log::Warn("not a value for " + Settings::Name(inputSetting[n]) + ": " + inputs[n].text);
            // The box follows the value (the slider, default, clamping) unless the player is typing in it; after
            // Enter it shows what was kept, so a clamped or refused entry is corrected in place.
            string value = Settings::Get(inputSetting[n]);
            if (submitted || (!inputs[n].focused && value != inputShown[n]))
            {
                inputs[n].value = value;
                inputShown[n] = value;
            }
        }
        for (uint n = 0; n < resets.length(); n++)
        {
            if (resets[n].Clicked())
                Settings::Reset(resetSetting[n]);
            resets[n].visible = !Settings::IsDefault(resetSetting[n]);
        }
        for (uint n = 0; n < dropdowns.length(); n++)
        {
            uint i = dropdownSetting[n];
            array<string>@ options = Settings::Choices(i);
            if (dropdowns[n].Changed() && dropdowns[n].selected >= 0 && uint(dropdowns[n].selected) < options.length())
                Settings::Set(i, options[uint(dropdowns[n].selected)]);
            int current = options.find(Settings::Get(i));        // follows a default, say
            if (dropdowns[n].selected != current)
                dropdowns[n].selected = current;
        }
        if (positionReset !is null && positionReset.Clicked())
            UI::ResetPositions(plugin);
        for (uint n = 0; n < toggles.length(); n++)
        {
            bool on = Settings::Get(toggleSetting[n]) == "true";
            toggles[n].label = on ? "on" : "off";
            Paint(toggles[n], on ? LIME : SECOND, on ? INK : 0xc8c8cc);
        }
        return true;
    }
}
SettingsForm form;

double Fraction(uint i)
{
    double range = Settings::Max(i) - Settings::Min(i);
    return range > 0 ? (parseFloat(Settings::Get(i)) - Settings::Min(i)) / range : 0;
}

// --- console ----------------------------------------------------------------------------------------------------------

UI::TextArea@ logView;
UI::Dropdown@ logFilter;
array<string> filterSources;        // per option: "" everything, "commands", "host", or a plugin id
string shownFilterPlugins;          // the plugins the filter options were made from
UI::TextInput@ commandInput;
UI::Button@ runButton;
uint shownLogLines = 0;
const uint LOG_LINES_SHOWN = 400;

void BuildConsole()
{
    menu.ClearView(consoleView);
    T(menu, "show", 15, MUTED);
    @logFilter = menu.AddDropdown(260);
    filterSources.resize(0);
    AddFilter("everything", "");
    AddFilter("my commands", "commands");
    AddFilter("host", "host");
    for (uint i = 0; i < Plugins::Count(); i++)
        AddFilter(Plugins::Name(i), Plugins::Id(i));
    logFilter.selected = 0;
    shownFilterPlugins = FilterPlugins();
    menu.NewRow();
    menu.StartCard();
    @logView = menu.AddTextArea(0, 0, 16);
    menu.EndCard();
    menu.StartCard();
    T(menu, ">", 20, MUTED);
    @commandInput = menu.AddTextInput(0, "find PlayerController, props <Class>, functions <Class>, ...", 18);
    @runButton = Grey(menu, "run", 14);
    menu.EndCard();
}

void AddFilter(const string &in label, const string &in source)
{
    logFilter.AddOption(label);
    filterSources.insertLast(source);
}

string FilterPlugins()
{
    string ids;
    for (uint i = 0; i < Plugins::Count(); i++)
        ids += Plugins::Id(i) + "|";
    return ids;
}

// A log line is "[time] [level] [source] message": where the source's "] " ends, or -1.
int SourceEnd(const string &in line)
{
    int a = line.findFirst("] [");
    int b = a < 0 ? -1 : line.findFirst("] [", a + 3);
    return b < 0 ? -1 : line.findFirst("] ", b + 3);
}

string SourceOf(const string &in line)
{
    int a = line.findFirst("] [");
    int b = a < 0 ? -1 : line.findFirst("] [", a + 3);
    int c = SourceEnd(line);
    return c < 0 ? "" : line.substr(b + 3, c - b - 3);
}

string MessageOf(const string &in line)
{
    int c = SourceEnd(line);
    return c < 0 ? line : line.substr(c + 2);
}

// "" everything, "commands" what was typed here and the host's replies, else one source (a plugin id or "host").
bool Shows(const string &in line, const string &in filter)
{
    if (filter == "")
        return true;
    string source = SourceOf(line);
    if (filter == "commands")
        return (source == "plugin-manager" && MessageOf(line).findFirst("> ") == 0) ||
               (source == "host" && MessageOf(line).findFirst("test: ") == 0);
    return source == filter;
}

// The last LOG_LINES_SHOWN lines of the host log that pass the filter, oldest first.
void ShowLog()
{
    string filter = filterSources[uint(logFilter.selected)];
    uint count = Log::LineCount();
    array<string> lines;
    for (uint i = count; i > 0 && lines.length() < LOG_LINES_SHOWN; i--)
    {
        string line = Log::Line(i - 1);
        if (line == "")
            break;                  // older lines are no longer kept
        if (Shows(line, filter))
            lines.insertLast(line);
    }
    string text;
    for (uint n = lines.length(); n > 0; n--)
    {
        text += lines[n - 1];
        if (n > 1)
            text += "\n";
    }
    logView.text = text == "" ? "Nothing yet." : text;
    shownLogLines = count;
}

void UpdateConsole()
{
    if (runButton.Clicked())
        commandInput.Submit();
    if (commandInput.Submitted())
    {
        Log::Info("> " + commandInput.text);
        Console::Run(commandInput.text);
    }
    if (FilterPlugins() != shownFilterPlugins)
    {
        BuildConsole();             // a plugin was installed or removed: new filter options
        shownLogLines = 0;
    }
    if (logFilter.Changed())
        shownLogLines = 0;
    if (Log::LineCount() != shownLogLines)
        ShowLog();
}

// --- frame ------------------------------------------------------------------------------------------------------------

double lastCheck = 0;

void Do(const string &in action)
{
    int colon = action.findFirst(":");
    string verb = colon < 0 ? action : action.substr(0, colon);
    string target = colon < 0 ? "" : action.substr(colon + 1);
    Log::Info(verb + (target == "" ? "" : " " + target));
    if (verb == "install" || verb == "update")
    {
        if (target == "plugin-manager")
            Plugins::UpdateHost();
        else
            Plugins::Install(target);
    }
    else if (verb == "update-all")
    {
        for (uint i = 0; i < entries.length(); i++)
            if (entries[i].installed && entries[i].update != "")
                Do("update:" + entries[i].id);
        return;
    }
    else if (verb == "remove")
        Plugins::Remove(target);
    else if (verb == "on" || verb == "off")
        Plugins::SetEnabled(target, verb == "on");
    else if (verb == "open")
        Host::OpenUrl(target);
    else if (verb == "refresh")
        Registry::Refresh();
    else if (verb == "page")
    {
        page = target;
        Show();
    }
    else if (verb == "back")
    {
        page = "";
        Show();
    }
    else if (verb == "clear")
    {
        searchBox.value = "";
        search = "";
        kind = "";
        Show();
    }
}

void OpenTab(const string &in t)
{
    tab = t;
    page = "";
    kind = "";                      // each list starts with every kind: a kind picked in one may have none in the other
    Show();
    if (tab == "console")
        commandInput.Focus();
}

void UpdateMenu()
{
    // Escape goes back one step: a plugin's page to its list, a search to empty, the console to installed, then out.
    if (Input::Pressed(Input::Escape))
    {
        if (page != "")
            Do("back");
        else if (tab != "console" && (searchBox.typed != "" || kind != ""))
            Do("clear");
        else if (tab == "console")
            OpenTab("installed");
        else
            CloseMenu();
        return;
    }
    if (backButton.Clicked())
    {
        CloseMenu();
        return;
    }
    if (folderButton.Clicked())
        Plugins::OpenFolder();
    if (consoleButton.Clicked())
        OpenTab("console");
    for (uint t = 0; t < tabs.length(); t++)
        if (tabs[t].Clicked())
            OpenTab(TABS[t]);
    if (tab == "console")
    {
        UpdateConsole();
        return;
    }
    for (uint k = 0; k < kindChips.length(); k++)
        if (kindChips[k].Clicked())
        {
            kind = k == 0 ? "" : KINDS[k - 1];
            Show();
        }
    if (updateAll.Clicked())
        Do("update-all");
    for (uint n = 0; n < listButtons.length(); n++)
        if (listButtons[n].Clicked())
        {
            Do(listActions[n]);
            break;                  // the list may have been rebuilt
        }
    if (!form.Update())
        Show();
    if (Host::Time() - lastCheck > 0.25)
    {
        lastCheck = Host::Time();
        if (State() != entriesFrom)
        {
            ReadEntries();
            Show();
        }
    }
    if (searchBox.typed != search && page == "")
        Show();                     // as it's typed, no Enter needed
    searchBox.Submitted();          // Enter adds nothing: the list already shows what's typed
}

void Update(float dt)
{
    // The footer button opens the menu, and closes it while it's open.
    if (button.Clicked())
    {
        if (menu.visible)
            CloseMenu();
        else
            OpenMenu();
        return;
    }
    if (menu.visible)
        UpdateMenu();
    else if (Host::Time() - lastCheck > 2)
    {
        // closed: keep the footer's update count current, now and then
        lastCheck = Host::Time();
        if (State() != entriesFrom)
        {
            ReadEntries();
            uint updates = CountOfAll("updates");
            button.label = updates > 0 ? "plugins " + updates : "plugins";
        }
    }
}
