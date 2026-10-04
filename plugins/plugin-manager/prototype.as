// ===== PROTOTYPE ==================================================================================================
// grill-design, round 2 (round 1, the overall structure, is in git history): E, categories, taken further. Five variants of the whole menu, switched by
// the picker at the bottom right (its arrows, or the Left and Right keys), each judged against the real installed
// plugins and the real registry. Never merged: the winner is rebuilt properly.
//   protoVariant  which variant the footer's plugins button opens (0..4)
//   protoState    0 as it is, 1 updates waiting (Grind Stats, Hello World and the plugin manager), 2 Hello World
//                 failed and Grind Stats turned off
// Both are hidden settings, so `setting plugin-manager protoVariant 2` picks one from the test channel.

[Setting hidden name="prototype variant"]
int protoVariant = 0;

[Setting hidden name="prototype state"]
int protoState = 0;

[Setting hidden name="prototype theme"]
int protoTheme = 0;

const bool PROTOTYPE = true;
const string FONT = "/Game/UI/Fonts/CocogoosePro.CocogoosePro";
const array<string> VARIANT_NAMES = {"1  E, dark", "2  chips, 4 wide", "3  big icons", "4  list", "5  all in one", "6  combined"};
const array<string> STATE_NAMES = {"as it is", "updates", "a plugin failed"};

// The game's colours, as picked on screen (sRGB hex).
const uint INK = 0x0c0c0e;          // the darkest: value boxes, the window behind
const uint PANEL = 0x1b1b1d;        // the settings page's panel
const uint ROW = 0x262628;          // a settings row
const uint ROW_HI = 0x35353a;       // a raised row, a secondary button
const uint LIME = 0xc6f432;         // the selected tab, primary actions
const uint WHITE = 0xffffff;
const uint MUTED = 0x9a9aa0;
const uint DIM = 0x5c5c62;
const uint LIGHT = 0xcfcfd1;        // the play page's grey
const uint LIGHT_CARD = 0xe6e6e8;
const uint BLUE = 0x0a5ccc;         // the play page's sidebar
const uint WARN = 0xf2c14e;
const uint BAD = 0xff5a50;

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

void Paint(UI::Button@ b, uint bg, uint fg)
{
    b.SetBackground(R(bg), G(bg), B(bg), 1);
    b.SetColor(R(fg), G(fg), B(fg), 1);
}

UI::Button@ Btn(UI::Window@ w, const string &in label, uint bg, uint fg, float size = 15, bool display = false, float radius = 6)
{
    UI::Button@ b = w.AddButton(label);
    b.SetStyle(radius, 14, 5);
    b.SetLabelSize(size);
    if (display)
        b.SetFont(FONT);
    Paint(b, bg, fg);
    return b;
}

// A tab the way the game draws its own: lime with dark text when open, a dark chip with grey text otherwise.
UI::Button@ Chip(UI::Window@ w, const string &in label, bool open, float size = 20)
{
    UI::Button@ b = w.AddButton(label);
    b.SetStyle(2, 10, 2);
    b.SetLabelSize(size);
    b.SetFont(FONT);
    Paint(b, open ? LIME : PANEL, open ? INK : MUTED);
    return b;
}

void WinColor(UI::Window@ w, uint hex, float a = 1) { w.SetBackground(R(hex), G(hex), B(hex), a); }
void CardsColor(UI::Window@ w, uint hex) { w.SetCardBackground(R(hex), G(hex), B(hex), 1); }
void CardColor(UI::Window@ w, uint hex, float a = 1) { w.SetCardColor(R(hex), G(hex), B(hex), a); }

// --- what every variant shows -----------------------------------------------------------------------------------

class Entry
{
    string id, name, version, author, description, icon, page, category, update, status, pending;
    bool installed = false, enabled = true, essential = false, library = false, hasSettings = false, broken = false;
    array<string> needs;
    array<string> neededBy;
}

array<Entry@> entries;
string entriesFrom;

// The registry has no categories or library flag yet (the spec adds them); these stand in for them.
string CategoryOf(const string &in id)
{
    if (id == "grind-stats" || id == "grind-timer" || id == "practice-checkpoints" || id == "replay-manager")
        return "practice";
    if (id == "create-extensions")
        return "editor";
    if (id == "screen-filters" || id == "fit-window")
        return "look";
    if (id == "hub-plus" || id == "player-count" || id == "hello-world" || id == "plugin-manager")
        return "other";
    return "cosmetics";
}
const array<string> CATEGORIES = {"cosmetics", "practice", "editor", "look", "other"};

bool IsLibrary(const string &in id) { return id == "cosmetic-kit" || id == "cosmetic-kit-plus"; }

array<string> NeedsOf(const string &in id)
{
    array<string> needs;
    if (id == "cosmetic-kit-plus")
        needs.insertLast("cosmetic-kit");
    else if (id == "example-arms" || id == "example-bounce")
        needs.insertLast("cosmetic-kit-plus");
    else if (CategoryOf(id) == "cosmetics" && id != "cosmetic-kit")
        needs.insertLast("cosmetic-kit");
    return needs;
}

string FakeUpdate(const string &in id)
{
    if (protoState != 1)
        return "";
    if (id == "grind-stats" || id == "hello-world")
        return "0.3.0";
    if (id == "plugin-manager")
        return "0.24.0";
    return "";
}

Entry@ Find(const string &in id)
{
    for (uint i = 0; i < entries.length(); i++)
        if (entries[i].id == id)
            return entries[i];
    return null;
}

string EntriesState() { return CardState() + "|s" + protoState; }

void LoadEntries()
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
            if (Registry::Description(r) != "")
                e.description = Registry::Description(r);
            if (CompareVersions(Registry::Version(r), e.version) > 0)
                e.update = Registry::Version(r);
        }
        if (e.id == "plugin-manager")
            e.update = HostUpdate();
        if (FakeUpdate(e.id) != "")
            e.update = FakeUpdate(e.id);
        if (protoState == 2 && e.id == "hello-world")
        {
            e.status = "error: main.as line 12: null pointer access";
        }
        if (protoState == 2 && e.id == "grind-stats")
            e.enabled = false;
        e.broken = e.status != "running" && e.enabled;
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
        e.pending = Plugins::Pending(e.id);
        entries.insertLast(e);
    }
    for (uint i = 0; i < entries.length(); i++)
    {
        Entry@ e = entries[i];
        e.category = CategoryOf(e.id);
        e.library = IsLibrary(e.id);
        e.needs = NeedsOf(e.id);
        if (e.author == "")
            e.author = "AnythingGoes";
    }
    for (uint i = 0; i < entries.length(); i++)
        for (uint k = 0; k < entries[i].needs.length(); k++)
        {
            Entry@ lib = Find(entries[i].needs[k]);
            if (lib !is null && entries[i].installed)
                lib.neededBy.insertLast(entries[i].name);
        }
    entriesFrom = EntriesState();
}

string IconOf(Entry@ e) { return e.icon == "" ? Plugins::DefaultIcon() : e.icon; }

// One word for where a plugin stands, and its colour.
string StateWord(Entry@ e)
{
    if (e.pending != "")
        return e.pending;
    if (!e.installed)
        return "";
    if (!e.enabled)
        return "off";
    if (e.broken)
        return "stopped";
    if (e.update != "")
        return "update " + e.update;
    return "on";
}

uint StateColor(Entry@ e)
{
    string s = StateWord(e);
    if (s == "off" || s == "")
        return MUTED;
    if (s == "stopped" || s.findFirst("error") == 0)
        return BAD;
    if (s.findFirst("update") == 0)
        return WARN;
    return LIME;
}

array<Entry@> Installed(const string &in search = "")
{
    array<Entry@> list;
    for (uint i = 0; i < entries.length(); i++)
        if (entries[i].installed && SearchScore(entries[i].name, search) >= 0)
            list.insertLast(entries[i]);
    return list;
}

array<Entry@> Available(const string &in category, const string &in search = "")
{
    array<Entry@> list;
    bool searching = WithoutSpaces(search) != "";
    for (uint i = 0; i < entries.length(); i++)
    {
        Entry@ e = entries[i];
        if (e.installed || (category != "" && e.category != category) || (e.library && !searching))
            continue;
        if (SearchScore(e.name, search) >= 0)
            list.insertLast(e);
    }
    return list;
}

array<Entry@> WithUpdates()
{
    array<Entry@> list;
    for (uint i = 0; i < entries.length(); i++)
        if (entries[i].installed && entries[i].update != "")
            list.insertLast(entries[i]);
    return list;
}

string ShortText(const string &in s, int n) { return Shorten(s, n); }

// --- buttons and what they do -----------------------------------------------------------------------------------

class Clicks
{
    array<UI::Button@> buttons;
    array<string> actions;
    void Clear() { buttons.resize(0); actions.resize(0); }
    UI::Button@ Add(UI::Button@ b, const string &in action) { buttons.insertLast(b); actions.insertLast(action); return b; }
    string Poll()
    {
        for (uint n = 0; n < buttons.length(); n++)
            if (buttons[n].Clicked())
                return actions[n];
        return "";
    }
}

// The plugin actions every variant shares; anything else ("page:<id>", "tab:<n>", ...) is the variant's own.
// Returns false when the action isn't one of these.
bool DoPluginAction(const string &in action)
{
    int colon = action.findFirst(":");
    string verb = colon < 0 ? action : action.substr(0, colon);
    string target = colon < 0 ? "" : action.substr(colon + 1);
    if (verb == "install" || verb == "update")
    {
        if (target == "plugin-manager")
            Plugins::UpdateHost();
        else if (FakeUpdate(target) != "")
            Log::Info("prototype: would update " + target);
        else
            Plugins::Install(target);
    }
    else if (verb == "update-all")
    {
        array<Entry@> list = WithUpdates();
        for (uint i = 0; i < list.length(); i++)
            DoPluginAction("update:" + list[i].id);
    }
    else if (verb == "remove")
        Plugins::Remove(target);
    else if (verb == "on" || verb == "off")
        Plugins::SetEnabled(target, verb == "on");
    else if (verb == "open")
        Host::OpenUrl(target);
    else if (verb == "folder")
        Plugins::OpenFolder();
    else if (verb == "console")
    {
        ProtoClose();
        OpenMenu();
        ShowView(consoleView);
    }
    else
        return false;
    Log::Info("prototype: " + action);
    return true;
}

// --- a plugin's settings, in any window ---------------------------------------------------------------------------

class SettingsForm
{
    string plugin;
    array<UI::Button@> toggles;
    array<uint> toggleSetting;
    array<UI::Slider@> sliders;
    array<uint> sliderSetting;
    array<UI::TextInput@> inputs;
    array<uint> inputSetting;
    array<string> inputShown;
    array<UI::Button@> resets;
    array<uint> resetSetting;
    array<UI::Dropdown@> dropdowns;
    array<uint> dropdownSetting;
    UI::Button@ positionReset;
    bool light = false;
    bool aligned = false;       // labels 520 wide and the controls straight after them, all at one x

    uint Fg() { return light ? INK : WHITE; }
    uint Sub() { return light ? DIM : MUTED; }

    void Clear()
    {
        toggles.resize(0); toggleSetting.resize(0); sliders.resize(0); sliderSetting.resize(0);
        inputs.resize(0); inputSetting.resize(0); inputShown.resize(0); resets.resize(0); resetSetting.resize(0);
        dropdowns.resize(0); dropdownSetting.resize(0);
        @positionReset = null;
    }

    // Rows for every setting, each its own card; `rowColor` < 0 keeps the window's card colour.
    uint Build(UI::Window@ w, const string &in id, int rowColor = -1)
    {
        Clear();
        plugin = id;
        uint shown = 0;
        if (UI::HasMovable(id))
        {
            w.StartCard();
            if (rowColor >= 0) CardColor(w, uint(rowColor));
            UI::Text@ label = T(w, "window position", 14, Fg());
            if (aligned)
                label.SetWidth(520);
            else
                w.AddSpace(0);
            @positionReset = Btn(w, aligned ? "reset position" : "reset", aligned ? SECOND : light ? LIGHT : ROW_HI, aligned ? 0xe8e8ea : Fg(), 14, aligned, aligned ? 8 : 6);
            w.NewRow();
            T(w, "Drag its windows anywhere while the cursor shows.", 12, Sub());
            w.EndCard();
            shown++;
        }
        for (uint i = 0; i < Settings::Count(); i++)
        {
            if (Settings::Plugin(i) != id || Settings::Hidden(i))
                continue;
            shown++;
            w.StartCard();
            if (rowColor >= 0) CardColor(w, uint(rowColor));
            UI::Text@ label = T(w, Lower(Settings::Name(i)), 14, Fg());
            if (aligned)
                label.SetWidth(520);
            else
                w.AddSpace(0);
            string kind = Settings::Kind(i);
            array<string>@ options = Settings::Choices(i);
            if (kind == "bool")
            {
                UI::Button@ toggle = Btn(w, "on", INK, WHITE, 14, aligned, aligned ? 8 : 2);
                if (aligned)
                    toggle.SetStyle(8, 30, 6);
                toggles.insertLast(toggle);
                toggleSetting.insertLast(i);
            }
            else if (options.length() > 0)
            {
                UI::Dropdown@ drop = w.AddDropdown(220);
                for (uint k = 0; k < options.length(); k++)
                    drop.AddOption(options[k]);
                drop.selected = options.find(Settings::Get(i));
                dropdowns.insertLast(drop);
                dropdownSetting.insertLast(i);
            }
            else
            {
                if (kind != "string" && Settings::HasRange(i))
                {
                    sliders.insertLast(w.AddSlider(aligned ? 360 : 220));
                    sliderSetting.insertLast(i);
                }
                UI::TextInput@ box = w.AddTextInput(kind == "string" ? (aligned ? 360 : 220) : (aligned ? 90 : 80), "", 15);
                box.clearOnSubmit = false;
                box.value = Settings::Get(i);
                inputs.insertLast(box);
                inputSetting.insertLast(i);
                inputShown.insertLast(Settings::Get(i));
            }
            UI::Button@ reset = Btn(w, aligned ? "default" : "reset", light ? LIGHT : aligned ? PANEL : ROW_HI, Sub(), 13, false, aligned ? 8 : 6);
            reset.visible = !Settings::IsDefault(i);
            resets.insertLast(reset);
            resetSetting.insertLast(i);
            if (Settings::Description(i) != "")
            {
                w.NewRow();
                T(w, Settings::Description(i), 12, Sub());
            }
            w.EndCard();
        }
        return shown;
    }

    void Update()
    {
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
            if (submitted)
                Settings::Set(inputSetting[n], inputs[n].text);
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
            int current = options.find(Settings::Get(i));
            if (dropdowns[n].selected != current)
                dropdowns[n].selected = current;
        }
        if (positionReset !is null && positionReset.Clicked())
            UI::ResetPositions(plugin);
        for (uint n = 0; n < toggles.length(); n++)
        {
            bool on = Settings::Get(toggleSetting[n]) == "true";
            toggles[n].label = on ? "on" : "off";
            Paint(toggles[n], on ? LIME : aligned ? SECOND : INK, on ? INK : aligned ? 0xc8c8cc : MUTED);
        }
    }
}

// A plugin's page: header, what it does, its actions, then its settings. Shared by the variants that open one.
void AddPluginPage(UI::Window@ w, Clicks@ clicks, SettingsForm@ form, Entry@ e, bool light, const string &in backAction,
                   const string &in backLabel)
{
    uint fg = light ? INK : WHITE, sub = light ? DIM : MUTED, raised = light ? LIGHT_CARD : ROW_HI;
    if (backAction != "")
    {
        clicks.Add(Btn(w, "< " + backLabel, raised, sub, 13, true, 2), backAction);
        w.NewRow();
    }
    w.AddImage(IconOf(e), 64, 64);
    T(w, e.name, 26, fg, true);
    w.NewRow();
    w.AddSpace(64);
    T(w, "by " + e.author + "    " + e.version, 13, sub);
    if (StateWord(e) != "")
        T(w, StateWord(e), 13, light && StateColor(e) == LIME ? 0x4f7d0f : StateColor(e));
    w.NewRow();
    w.AddSpace(64);
    if (!e.installed)
        clicks.Add(Btn(w, e.pending == "installing" ? "installing..." : "install", LIME, INK, 14, true), "install:" + e.id);
    else
    {
        if (e.update != "")
            clicks.Add(Btn(w, "update to " + e.update, LIME, INK, 14, true), "update:" + e.id);
        if (!e.essential)
        {
            clicks.Add(Btn(w, e.enabled ? "turn off" : "turn on", e.enabled ? raised : LIME, e.enabled ? fg : INK, 14, true),
                       (e.enabled ? "off:" : "on:") + e.id);
            clicks.Add(Btn(w, "remove", raised, fg, 14, true), "remove:" + e.id);
        }
    }
    if (e.page != "")
        clicks.Add(Btn(w, "github", raised, fg, 14, true), "open:" + e.page);
    w.NewRow();
    w.AddSpace(64);
    T(w, e.description == "" ? "No description." : e.description, 14, fg).SetWrap(true);
    if (e.broken)
    {
        w.NewRow();
        w.AddSpace(64);
        T(w, e.status, 15, BAD);
    }
    if (e.needs.length() > 0 || e.neededBy.length() > 0)
    {
        w.NewRow();
        w.AddSpace(64);
        string line = e.needs.length() > 0 ? "needs " + NamesOf(e.needs) : "";
        if (e.neededBy.length() > 0)
            line += (line == "" ? "" : "    ") + "needed by " + Join(e.neededBy);
        T(w, line, 14, sub);
    }
    if (e.installed && e.hasSettings)
    {
        w.NewRow();
        T(w, "settings", 18, fg, true);
        form.light = light;
        form.Build(w, e.id, light ? int(LIGHT_CARD) : -1);
    }
}

string Join(const array<string> &in list)
{
    string s;
    for (uint i = 0; i < list.length(); i++)
        s += (i > 0 ? ", " : "") + list[i];
    return s;
}

string NamesOf(const array<string> &in ids)
{
    array<string> names;
    for (uint i = 0; i < ids.length(); i++)
    {
        Entry@ e = Find(ids[i]);
        names.insertLast(e is null ? ids[i] : e.name);
    }
    return Join(names);
}

// --- the picker ---------------------------------------------------------------------------------------------------

UI::Window@ picker;
UI::Button@ pickPrev;
UI::Button@ pickNext;
UI::Text@ pickName;
array<UI::Button@> pickStates;
UI::Button@ pickTheme;

void BuildPicker()
{
    @picker = UI::CreateWindow();
    picker.SetAnchor(1, 1);
    picker.SetPivot(1, 1);
    picker.SetOffset(-16, -UI::FooterHeight() - 12);
    picker.SetBackground(1, 0, 0.6f, 1);
    picker.SetCornerRadius(18);
    picker.SetPadding(10, 6);
    picker.zOrder = 3000;
    picker.SetBlocksClicks(true);
    UI::Text@ tag = picker.AddText("PROTOTYPE", 12);
    tag.SetColor(1, 1, 1, 1);
    @pickPrev = picker.AddButton("<");
    @pickName = picker.AddText("", 17);
    pickName.SetFont(FONT);
    pickName.SetColor(1, 1, 1, 1);
    @pickNext = picker.AddButton(">");
    Paint(pickPrev, INK, WHITE);
    Paint(pickNext, INK, WHITE);
    picker.NewRow();
    for (uint s = 0; s < STATE_NAMES.length(); s++)
    {
        UI::Button@ b = picker.AddButton(STATE_NAMES[s]);
        b.SetLabelSize(13);
        pickStates.insertLast(b);
    }
    @pickTheme = picker.AddButton("dark");
    pickTheme.SetLabelSize(13);
    picker.movable = true;
    picker.visible = false;
    ShowPicker();
}

void ShowPicker()
{
    pickName.text = VARIANT_NAMES[uint(protoVariant)];
    for (uint s = 0; s < pickStates.length(); s++)
        Paint(pickStates[s], int(s) == protoState ? WHITE : INK, int(s) == protoState ? INK : WHITE);
    pickTheme.label = protoTheme == 1 ? "light" : "dark";
    Paint(pickTheme, protoTheme == 1 ? WHITE : INK, protoTheme == 1 ? INK : WHITE);
}

void SetVariant(int v)
{
    bool open = protoOpen;
    if (open)
        ProtoClose();
    protoVariant = (v + int(VARIANT_NAMES.length())) % int(VARIANT_NAMES.length());
    Settings::Set(ProtoSetting("protoVariant"), "" + protoVariant);
    ShowPicker();
    if (open)
        ProtoOpen();
}

uint ProtoSetting(const string &in variable)
{
    string name = variable == "protoVariant" ? "prototype variant" : variable == "protoTheme" ? "prototype theme" : "prototype state";
    for (uint i = 0; i < Settings::Count(); i++)
        if (Settings::Plugin(i) == "plugin-manager" && Settings::Name(i) == name)
            return i;
    return 0;
}

// --- open, close, frame -------------------------------------------------------------------------------------------

bool protoOpen = false;
int openVariant = -1;
int shownVariant = -1;
int shownState = -1;
int shownTheme = -1;

void ProtoMain()
{
    BuildPicker();
}

void ProtoOpen()
{
    if (entriesFrom != EntriesState())
        LoadEntries();
    protoOpen = true;
    openVariant = protoVariant;
    UI::SetCursorVisible(true);
    picker.visible = true;
    EOpen();
}

void ProtoClose()
{
    protoOpen = false;
    if (eWin !is null) eWin.visible = false;
    picker.visible = false;
    UI::SetCursorVisible(false);
}

void ProtoFooterLabel()
{
    uint n = 0;
    for (uint i = 0; i < entries.length(); i++)
        if (entries[i].installed && entries[i].update != "")
            n++;
    button.label = n > 0 ? "plugins  " + n + " new" : "plugins";
}

void ProtoUpdate()
{
    if (shownTheme != protoTheme)
    {
        shownTheme = protoTheme;
        ShowPicker();
        if (protoOpen)
        {
            ProtoClose();
            ProtoOpen();
        }
    }
    if (shownVariant != protoVariant || shownState != protoState)
    {
        // a setting changed from outside (the test channel): follow it
        bool stateChanged = shownState != protoState;
        shownVariant = protoVariant;
        shownState = protoState;
        ShowPicker();
        if (stateChanged)
            LoadEntries();
        if (protoOpen && openVariant != protoVariant)
        {
            ProtoClose();
            ProtoOpen();
        }
        else if (protoOpen)
            ProtoRefresh();
    }
    if (button.Clicked())
    {
        if (protoOpen)
            ProtoClose();
        else
            ProtoOpen();
        return;
    }
    if (entriesFrom != EntriesState())
    {
        LoadEntries();
        if (protoOpen)
            ProtoRefresh();
    }
    ProtoFooterLabel();
    if (!protoOpen)
        return;
    if (pickPrev.Clicked() || Input::Pressed(Input::Left))
        SetVariant(protoVariant - 1);
    if (pickNext.Clicked() || Input::Pressed(Input::Right))
        SetVariant(protoVariant + 1);
    for (uint s = 0; s < pickStates.length(); s++)
        if (pickStates[s].Clicked())
            Settings::Set(ProtoSetting("protoState"), "" + s);
    if (pickTheme.Clicked())
        Settings::Set(ProtoSetting("protoTheme"), protoTheme == 1 ? "0" : "1");
    if (!protoOpen)
        return;
    EUpdate();
}

void ProtoRefresh()
{
    EBuild();
}

// Escape inside a variant: back one level, or close.
bool EscapePressed() { return Input::Pressed(Input::Escape); }

// ===== Round 2: E (categories down the left, tiles) taken further, in dark by default (the picker's theme button
// flips it to light). Smaller type everywhere but on the tiles. The five differ in the category column and in what a
// plugin looks like in the list:
//   1  E, dark         the play page's blue blocks; tiles three wide with icon, name, description and an action
//   2  chips, 4 wide   the game settings' lime chips; the same tiles, four wide and shorter
//   3  big icons       a plain text column; tiles of a large icon, the name and one action, no description
//   4  list            chips; one row per plugin (icon, name, description, action), the densest
//   5  all in one      blocks with counts and no "yours": each category lists its installed plugins first, then the
//                      ones to get; "updates" appears as a category while there are any
// =====================================================================================================================

class Look
{
    string column;      // blocks, chips, text
    string tiles;       // rich, art, rows
    uint cols = 3;
    bool mixed = false; // no "yours": installed first inside each category
    bool counts = false;
}

Look@ LookFor(int v)
{
    Look l;
    l.column = v == 0 || v == 4 ? "blocks" : v == 2 ? "text" : v == 5 ? "list" : "chips";
    l.tiles = v == 2 ? "art" : v == 3 ? "rows" : v == 5 ? "art2" : "rich";
    l.cols = v == 1 || v == 2 || v == 5 ? 4 : 3;
    l.mixed = v == 4 || v == 5;
    l.counts = v == 4 || v == 5;
    return l;
}

bool Light() { return protoTheme == 1; }
uint Bg() { return Light() ? LIGHT : PANEL; }
uint TileBg() { return Light() ? WHITE : ROW; }
uint Fg() { return Light() ? INK : WHITE; }
uint Sub() { return Light() ? DIM : MUTED; }
uint Raised() { return Light() ? LIGHT_CARD : ROW_HI; }
uint OnColor() { return Light() ? 0x4f7d0f : LIME; }      // lime text is unreadable on white

UI::Window@ eWin;
int eView = -1;
string eCategory = "";
string ePage;
Clicks eClicks;
SettingsForm eForm;
int eBuiltTheme = -1;

array<string> Categories(Look@ l)
{
    array<string> cats;
    if (l.mixed)
    {
        cats.insertLast("all");
        if (WithUpdates().length() > 0)
            cats.insertLast("updates");
    }
    else
        cats.insertLast("yours");
    for (uint c = 0; c < CATEGORIES.length(); c++)
        cats.insertLast(CATEGORIES[c]);
    return cats;
}

// What a category lists. Mixed: its installed plugins, then the rest; otherwise "yours" is the installed ones and a
// category is what there is to get.
array<Entry@> Listed(Look@ l, const string &in cat, uint &out installedCount)
{
    array<Entry@> list;
    installedCount = 0;
    if (cat == "yours")
        list = Installed();
    else if (cat == "updates")
        list = WithUpdates();
    else if (!l.mixed)
        list = Available(cat);
    else
    {
        for (uint i = 0; i < entries.length(); i++)
            if (entries[i].installed && (cat == "all" || entries[i].category == cat))
                list.insertLast(entries[i]);
        installedCount = list.length();
        array<Entry@> more = Available(cat == "all" ? "" : cat);
        for (uint i = 0; i < more.length(); i++)
            list.insertLast(more[i]);
    }
    if (cat == "yours" || cat == "updates")
        installedCount = list.length();
    return list;
}

uint CountIn(Look@ l, const string &in cat)
{
    uint n;
    return Listed(l, cat, n).length();
}

void EOpen()
{
    if (eWin is null || eBuiltTheme != protoTheme)
    {
        if (eWin !is null)
            eWin.visible = false;      // windows can't be freed; a new one in the other colours replaces it
        @eWin = UI::CreateWindow();
        eWin.SetScreenSize(0.86f, 0.84f);
        WinColor(eWin, Bg(), 1.0f);
        CardsColor(eWin, TileBg());
        eWin.SetBlocksClicks(true);
        eWin.zOrder = 500;
        eWin.StartSidebar(200);
        eView = eWin.StartView();
        eWin.SetScrolling(eView, true);
        eWin.ShowView(eView);
        eBuiltTheme = protoTheme;
    }
    Look@ l = LookFor(protoVariant);
    array<string> cats = Categories(l);
    if (cats.find(eCategory) < 0)
        eCategory = cats[0];
    EBuild();
    eWin.visible = true;
}

UI::Button@ ColumnButton(Look@ l, const string &in label, bool on)
{
    UI::Button@ b;
    if (l.column == "list")
        return ListButton(l, label, on);
    if (l.column == "blocks")
    {
        @b = Btn(eWin, label, on ? WHITE : BLUE, on ? INK : WHITE, 18, true, 2);
        b.SetStyle(2, 12, 6);
    }
    else if (l.column == "chips")
        @b = Chip(eWin, label, on, 17);
    else
    {
        @b = Btn(eWin, label, Bg(), on ? (Light() ? INK : LIME) : Sub(), on ? 19 : 17, true, 0);
        b.SetStyle(0, 4, 3);
    }
    return b;
}

void EBuild()
{
    Look@ l = LookFor(protoVariant);
    eWin.ClearView(eView);
    eWin.ClearSidebar();
    eClicks.Clear();
    // the column
    T(eWin, "plugins", l.column == "list" ? 30 : 28, Fg(), true);
    eWin.AddSpace(8);
    array<string> cats = Categories(l);
    for (uint c = 0; c < cats.length(); c++)
    {
        string label = cats[c];
        if (l.counts)
            label += "  " + CountIn(l, cats[c]);
        eClicks.Add(ColumnButton(l, label, cats[c] == eCategory && (ePage == "" || l.column == "list")), "cat:" + cats[c]);
    }
    eWin.AddSpace(16);
    eClicks.Add(ColumnButton(l, "back", false), "close");
    eWin.AddSpace(16);
    eClicks.Add(Btn(eWin, "plugins folder", Bg(), Sub(), 12, false, 2), "folder");
    eClicks.Add(Btn(eWin, "console", Bg(), Sub(), 12, false, 2), "console");
    eWin.StartMain();
    // the heading row
    T(eWin, ePage != "" ? "" : eCategory == "yours" ? "installed" : eCategory, l.column == "list" ? 24 : 24, Fg(), true);
    eWin.AddSpace(0);
    uint updates = WithUpdates().length();
    if (updates > 0 && !(ePage != "" && l.tiles == "art2"))
        eClicks.Add(Btn(eWin, "update all  " + updates, LIME, INK, 14, true, 4), "update-all");
    eWin.NewRow();
    if (ePage != "")
    {
        Entry@ e = Find(ePage);
        if (e !is null && l.tiles == "art2")
            AddPluginPage2(eWin, eClicks, eForm, e, "cat:" + eCategory, eCategory);
        else if (e !is null)
            AddPluginPage(eWin, eClicks, eForm, e, Light(), "cat:" + eCategory, eCategory);
        return;
    }
    uint installedCount;
    array<Entry@> list = Listed(l, eCategory, installedCount);
    if (list.length() == 0)
    {
        T(eWin, eCategory == "yours" ? "No plugins installed yet." : "Every plugin here is installed.", 15, Sub());
        return;
    }
    if (l.mixed && installedCount > 0 && installedCount < list.length())
    {
        // two groups: installed, then to get
        array<Entry@> mine, rest;
        for (uint i = 0; i < list.length(); i++)
        {
            if (i < installedCount)
                mine.insertLast(list[i]);
            else
                rest.insertLast(list[i]);
        }
        Group(l, "installed", mine);
        Group(l, "get more", rest);
    }
    else
        Group(l, "", list);
    if (l.tiles == "art2")
    {
        eWin.NewRow();
        T(eWin, " ", 60, Bg());
    }
}

void Group(Look@ l, const string &in title, array<Entry@> list)
{
    if (title != "")
    {
        eWin.NewRow();
        if (l.tiles == "art2")
            T(eWin, title + "  " + list.length(), 16.5f, HEAD, true);
        else
            T(eWin, title, 15, Sub(), true);
    }
    if (l.tiles == "rows")
    {
        for (uint i = 0; i < list.length(); i++)
            RowTile(list[i]);
        return;
    }
    for (uint start = 0; start < list.length(); start += l.cols)
    {
        eWin.StartCardRow();
        for (uint k = 0; k < l.cols; k++)
        {
            eWin.StartCard();
            if (start + k >= list.length())
            {
                CardColor(eWin, Bg(), 0);
                eWin.AddSpace(10);
                continue;
            }
            if (l.tiles == "art2")
                ArtTile2(list[start + k]);
            else if (l.tiles == "art")
                ArtTile(list[start + k]);
            else
                RichTile(list[start + k], l.cols);
        }
        eWin.EndCardRow();
    }
}

// The one thing to do with a plugin from the list, or "" when there is none (built in).
void ActionButton(Entry@ e, float size)
{
    if (!e.installed)
        eClicks.Add(Btn(eWin, e.pending == "installing" ? "installing" : "install", LIME, INK, size, true, 4), "install:" + e.id);
    else if (e.update != "")
        eClicks.Add(Btn(eWin, "update", LIME, INK, size, true, 4), "update:" + e.id);
    else if (!e.essential)
        eClicks.Add(Btn(eWin, e.enabled ? "turn off" : "turn on", Raised(), Fg(), size, true, 4), (e.enabled ? "off:" : "on:") + e.id);
}

void StateText(Entry@ e, float size)
{
    if (!e.installed)
        return;
    uint c = StateColor(e);
    T(eWin, e.essential && StateWord(e) == "on" ? "built in" : StateWord(e), size, c == LIME ? OnColor() : c, true);
}

void RichTile(Entry@ e, uint cols)
{
    eWin.AddImage(IconOf(e), 56, 56);
    eWin.AddSpace(0);
    StateText(e, 13);
    eWin.NewRow();
    eClicks.Add(Btn(eWin, e.name, TileBg(), Fg(), 18, true, 2), "page:" + e.id);
    eWin.NewRow();
    T(eWin, ShortText(e.description, cols == 4 ? 34 : 48), 12, Sub());
    eWin.NewRow();
    ActionButton(e, 13);
    T(eWin, e.installed ? e.version : "by " + e.author, 12, Light() ? DIM : DIM);
}

void ArtTile(Entry@ e)
{
    eWin.AddSpace(0);
    eWin.AddImage(IconOf(e), 104, 104);
    eWin.AddSpace(0);
    eWin.NewRow();
    eWin.AddSpace(0);
    eClicks.Add(Btn(eWin, e.name, TileBg(), Fg(), 18, true, 2), "page:" + e.id);
    eWin.AddSpace(0);
    eWin.NewRow();
    eWin.AddSpace(0);
    ActionButton(e, 13);
    StateText(e, 13);
    eWin.AddSpace(0);
}

void RowTile(Entry@ e)
{
    eWin.StartCard();
    eWin.AddImage(IconOf(e), 36, 36);
    eClicks.Add(Btn(eWin, e.name, TileBg(), Fg(), 17, true, 2), "page:" + e.id);
    StateText(e, 12);
    UI::Text@ d = T(eWin, ShortText(e.description, 80), 12, Sub());
    d.SetFill(true);
    ActionButton(e, 13);
    eWin.EndCard();
}

void EUpdate()
{
    string a = eClicks.Poll();
    if (EscapePressed())
        a = ePage != "" ? "cat:" + eCategory : "close";
    if (a == "close")
    {
        ProtoClose();
        return;
    }
    if (a.findFirst("cat:") == 0)
    {
        eCategory = a.substr(4);
        ePage = "";
        EBuild();
    }
    else if (a.findFirst("page:") == 0)
    {
        ePage = a.substr(5);
        EBuild();
    }
    else if (a != "")
        DoPluginAction(a);
    eForm.Update();
}

// ===== 6  combined: 5's column (counts, installed first in each category) with 3's big-icon tiles, dark, reworked
// after a design review of the screenshots (iteration 1): a quiet column with one lime "you are here", installed
// tiles tinted and switched on / off in place, one type scale with the tiles as the only large text, a two-card
// plugin page. Iteration 2: lime only means "on, or needs you" (install is grey with lime text), installed tiles are a
// dark tint of the game's blue, update tiles say which version they're on, the page is one hero card with the settings
// straight under it, labels and controls line up, no crumb (the column keeps the category). Iteration 3: a page's own
// install is lime, an update waits on its own line, the description stops at 900 wide, a dependency says whether you
// have it, toggles and actions look different, and lists end with room to scroll the last row into view. =========================================================================================================

const uint TILE = 0x252528;
const uint TILE_ON = 0x1f2b3d;      // an installed plugin's tile: a dark tint of the game's blue
const uint SECOND = 0x3a3a3e;       // secondary buttons
const uint SIDE_TEXT = 0xb8b8bc;
const uint COUNT = 0x7a7a80;
const uint HEAD = 0x8a8a90;
const uint META = 0xa8a8ae;

UI::Button@ Primary2(UI::Window@ w, const string &in label, float size = 15)
{
    UI::Button@ b = Btn(w, label, LIME, INK, size, true, 8);
    b.SetStyle(8, 24, 7);
    return b;
}

UI::Button@ Install2(UI::Window@ w, const string &in label, float size = 15)
{
    UI::Button@ b = Btn(w, label, SECOND, LIME, size, true, 8);
    b.SetStyle(8, 24, 7);
    return b;
}

UI::Button@ Second2(UI::Window@ w, const string &in label, float size = 15)
{
    UI::Button@ b = Btn(w, label, SECOND, 0xe8e8ea, size, true, 8);
    b.SetStyle(8, 24, 7);
    return b;
}

UI::Button@ ListButton(Look@ l, const string &in label, bool on)
{
    if (label == "back")
    {
        UI::Button@ back = Btn(eWin, label, BLUE, WHITE, 18, true, 8);
        back.SetStyle(8, 16, 8);
        return back;
    }
    bool updates = label.findFirst("updates") == 0;
    UI::Button@ b = Btn(eWin, label, on ? LIME : Bg(), on ? INK : updates ? LIME : SIDE_TEXT, 18, true, 8);
    b.SetStyle(8, 16, 8);
    return b;
}

void ArtTile2(Entry@ e)
{
    CardColor(eWin, e.installed ? TILE_ON : TILE);
    eWin.AddSpace(0);
    eWin.AddImage(IconOf(e), 128, 128);
    eWin.AddSpace(0);
    eWin.NewRow();
    eWin.AddSpace(0);
    eClicks.Add(Btn(eWin, e.name, e.installed ? TILE_ON : TILE, WHITE, 19.5f, true, 4), "page:" + e.id);
    eWin.AddSpace(0);
    eWin.NewRow();
    eWin.AddSpace(0);
    if (!e.installed)
        eClicks.Add(Install2(eWin, e.pending == "installing" ? "installing" : "install"), "install:" + e.id);
    else if (e.update != "")
    {
        T(eWin, e.version + " to " + e.update, 13.5f, META);
        eWin.AddSpace(0);
        eWin.NewRow();
        eWin.AddSpace(0);
        eClicks.Add(Primary2(eWin, "update"), "update:" + e.id);
    }
    else if (e.essential)
        T(eWin, "built in", 13.5f, COUNT, true);
    else if (e.broken)
        T(eWin, "stopped", 13.5f, BAD, true);
    else
    {
        UI::Button@ b = e.enabled ? Primary2(eWin, "on") : Second2(eWin, "off");
        eClicks.Add(b, (e.enabled ? "off:" : "on:") + e.id);
    }
    eWin.AddSpace(0);
}

// A plugin's page: one hero card (icon, name, what to do, what it is), its settings straight under it.
void AddPluginPage2(UI::Window@ w, Clicks@ clicks, SettingsForm@ form, Entry@ e, const string &in backAction, const string &in backLabel)
{
    w.StartCard();
    CardColor(w, e.installed ? TILE_ON : TILE);
    w.AddImage(IconOf(e), 128, 128);
    T(w, e.name, 27, WHITE, true);
    T(w, "by " + e.author + "   " + e.version, 13.5f, META);
    w.AddSpace(0);
    if (!e.installed)
        clicks.Add(Primary2(w, e.pending == "installing" ? "installing" : "install", 18), "install:" + e.id);
    else
    {
        if (e.essential)
            T(w, "built in", 13.5f, COUNT, true);
        else
            clicks.Add(e.enabled ? Primary2(w, "on", 18) : Second2(w, "off", 18), (e.enabled ? "off:" : "on:") + e.id);
    }
    if (e.installed && !e.essential)
        clicks.Add(Second2(w, "remove", 13.5f), "remove:" + e.id);
    if (e.page != "")
        clicks.Add(Second2(w, "github", 13.5f), "open:" + e.page);
    if (e.installed && e.update != "")
    {
        w.NewRow();
        w.AddSpace(128);
        clicks.Add(Primary2(w, "update to " + e.update, 16.5f), "update:" + e.id);
        T(w, "you have " + e.version, 13.5f, META);
    }
    w.NewRow();
    w.AddSpace(128);
    UI::Text@ about = T(w, e.description == "" ? "No description." : e.description, 15, WHITE);
    about.SetWrap(true);
    about.SetFill(false);
    about.SetWidth(900);
    if (e.broken)
    {
        w.NewRow();
        w.AddSpace(128);
        T(w, e.status, 13.5f, BAD).SetWrap(true);
    }
    if (e.needs.length() > 0 || e.neededBy.length() > 0)
    {
        w.NewRow();
        w.AddSpace(128);
        for (uint k = 0; k < e.needs.length(); k++)
        {
            Entry@ need = Find(e.needs[k]);
            bool have = need !is null && need.installed;
            T(w, "needs " + (need is null ? e.needs[k] : need.name) + (have ? ": installed" : ""), 13.5f, META);
            if (!have && e.installed)
            {
                UI::Button@ get = Install2(w, "install it", 13.5f);
                clicks.Add(get, "install:" + e.needs[k]);
            }
            else if (!have)
                T(w, "(installed with it)", 13.5f, COUNT);
        }
        if (e.neededBy.length() > 0)
            T(w, "needed by " + Join(e.neededBy), 13.5f, META);
    }
    w.EndCard();
    if (e.installed && e.hasSettings)
    {
        w.NewRow();
        T(w, "settings", 18, HEAD, true);
        form.light = false;
        form.aligned = true;
        form.Build(w, e.id, int(TILE));
        w.NewRow();
        T(w, " ", 60, TILE);
    }
}

// ===== end of PROTOTYPE ===========================================================================================
