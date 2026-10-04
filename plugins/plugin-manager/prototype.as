// ===== PROTOTYPE ==================================================================================================
// grill-design, round 1: the plugin manager menu's overall structure. Five variants of the whole menu, switched by
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

const bool PROTOTYPE = true;
const string FONT = "/Game/UI/Fonts/CocogoosePro.CocogoosePro";
const array<string> VARIANT_NAMES = {"A  game tabs", "B  store", "C  list and page", "D  side drawer", "E  categories"};
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
            T(w, "window position", 16, Fg());
            w.AddSpace(0);
            @positionReset = Btn(w, "reset", light ? LIGHT : ROW_HI, Fg(), 14);
            w.NewRow();
            T(w, "Drag its windows anywhere while the cursor shows.", 14, Sub());
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
            T(w, Lower(Settings::Name(i)), 16, Fg());
            w.AddSpace(0);
            string kind = Settings::Kind(i);
            array<string>@ options = Settings::Choices(i);
            if (kind == "bool")
            {
                toggles.insertLast(Btn(w, "on", INK, WHITE, 14, false, 2));
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
                    sliders.insertLast(w.AddSlider(220));
                    sliderSetting.insertLast(i);
                }
                UI::TextInput@ box = w.AddTextInput(kind == "string" ? 220 : 80, "", 15);
                box.clearOnSubmit = false;
                box.value = Settings::Get(i);
                inputs.insertLast(box);
                inputSetting.insertLast(i);
                inputShown.insertLast(Settings::Get(i));
            }
            UI::Button@ reset = Btn(w, "reset", light ? LIGHT : ROW_HI, Sub(), 13);
            reset.visible = !Settings::IsDefault(i);
            resets.insertLast(reset);
            resetSetting.insertLast(i);
            if (Settings::Description(i) != "")
            {
                w.NewRow();
                T(w, Settings::Description(i), 14, Sub());
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
            Paint(toggles[n], on ? LIME : INK, on ? INK : MUTED);
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
        clicks.Add(Btn(w, "< " + backLabel, light ? LIGHT_CARD : PANEL, sub, 15, true, 2), backAction);
        w.NewRow();
    }
    w.AddImage(IconOf(e), 84, 84);
    T(w, e.name, 34, fg, true);
    w.NewRow();
    w.AddSpace(84);
    T(w, "by " + e.author + "    " + e.version, 15, sub);
    if (StateWord(e) != "")
        T(w, StateWord(e), 15, StateColor(e));
    w.NewRow();
    w.AddSpace(84);
    if (!e.installed)
        clicks.Add(Btn(w, e.pending == "installing" ? "installing..." : "install", LIME, INK, 16, true), "install:" + e.id);
    else
    {
        if (e.update != "")
            clicks.Add(Btn(w, "update to " + e.update, LIME, INK, 16, true), "update:" + e.id);
        if (!e.essential)
        {
            clicks.Add(Btn(w, e.enabled ? "turn off" : "turn on", e.enabled ? raised : LIME, e.enabled ? fg : INK, 16, true),
                       (e.enabled ? "off:" : "on:") + e.id);
            clicks.Add(Btn(w, "remove", raised, fg, 16, true), "remove:" + e.id);
        }
    }
    if (e.page != "")
        clicks.Add(Btn(w, "github", raised, fg, 16, true), "open:" + e.page);
    w.NewRow();
    w.AddSpace(84);
    T(w, e.description == "" ? "No description." : e.description, 16, fg).SetWrap(true);
    if (e.broken)
    {
        w.NewRow();
        w.AddSpace(84);
        T(w, e.status, 15, BAD);
    }
    if (e.needs.length() > 0 || e.neededBy.length() > 0)
    {
        w.NewRow();
        w.AddSpace(84);
        string line = e.needs.length() > 0 ? "needs " + NamesOf(e.needs) : "";
        if (e.neededBy.length() > 0)
            line += (line == "" ? "" : "    ") + "needed by " + Join(e.neededBy);
        T(w, line, 14, sub);
    }
    if (e.installed && e.hasSettings)
    {
        w.NewRow();
        T(w, "settings", 22, fg, true);
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
    picker.movable = true;
    picker.visible = false;
    ShowPicker();
}

void ShowPicker()
{
    pickName.text = VARIANT_NAMES[uint(protoVariant)];
    for (uint s = 0; s < pickStates.length(); s++)
        Paint(pickStates[s], int(s) == protoState ? WHITE : INK, int(s) == protoState ? INK : WHITE);
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
    string name = variable == "protoVariant" ? "prototype variant" : "prototype state";
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
    switch (protoVariant)
    {
    case 0: AOpen(); break;
    case 1: BOpen(); break;
    case 2: COpen(); break;
    case 3: DOpen(); break;
    case 4: EOpen(); break;
    }
}

void ProtoClose()
{
    protoOpen = false;
    if (aWin !is null) aWin.visible = false;
    if (bWin !is null) bWin.visible = false;
    if (cWin !is null) cWin.visible = false;
    if (dWin !is null) dWin.visible = false;
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
    if (!protoOpen)
        return;
    switch (protoVariant)
    {
    case 0: AUpdate(); break;
    case 1: BUpdate(); break;
    case 2: CUpdate(); break;
    case 3: DUpdate(); break;
    case 4: EUpdate(); break;
    }
}

void ProtoRefresh()
{
    switch (protoVariant)
    {
    case 0: ABuild(); break;
    case 1: BBuild(); break;
    case 2: CBuild(); break;
    case 3: DBuild(); break;
    case 4: EBuild(); break;
    }
}

// Escape inside a variant: back one level, or close.
bool EscapePressed() { return Input::Pressed(Input::Escape); }

// ===== A  game tabs: the game's own settings page. Chips down the left (installed, updates, get more), rows on a
// dark panel, a page per plugin with its settings. =====================================================================

UI::Window@ aWin;
int aView = -1;
string aTab = "installed";      // installed, updates, more, page
string aPage;
string aBackTab = "installed";
UI::TextInput@ aSearch;
string aSearchShown;
Clicks aClicks;
SettingsForm aForm;

void AOpen()
{
    if (aWin is null)
    {
        @aWin = UI::CreateWindow();
        aWin.SetScreenSize(0.86f, 0.84f);
        WinColor(aWin, PANEL, 1.0f);
        CardsColor(aWin, ROW);
        aWin.SetBlocksClicks(true);
        aWin.zOrder = 500;
        aWin.StartSidebar(220);
        aView = aWin.StartView();
        aWin.SetScrolling(aView, true);
        aWin.ShowView(aView);
    }
    ABuild();
    aWin.visible = true;
}

void ABuild()
{
    aWin.ClearView(aView);
    aWin.ClearSidebar();
    aClicks.Clear();
    T(aWin, "plugins", 40, WHITE, true);
    uint updates = WithUpdates().length();
    string here = aTab == "page" ? aBackTab : aTab;
    aClicks.Add(Chip(aWin, "installed", here == "installed", 22), "tab:installed");
    aClicks.Add(Chip(aWin, updates > 0 ? "updates  " + updates : "updates", here == "updates", 22), "tab:updates");
    aClicks.Add(Chip(aWin, "get more", here == "more", 22), "tab:more");
    aWin.AddSpace(30);
    aClicks.Add(Chip(aWin, "back", false, 22), "close");
    aWin.AddSpace(30);
    aClicks.Add(Btn(aWin, "plugins folder", PANEL, DIM, 13), "folder");
    aClicks.Add(Btn(aWin, "console", PANEL, DIM, 13), "console");
    aWin.StartMain();
    @aSearch = null;
    if (aTab == "installed" || aTab == "more")
    {
        @aSearch = aWin.AddTextInput(300, "search", 15);
        aSearch.clearOnSubmit = false;
        aSearch.clearButton = true;
        aSearch.value = aSearchShown;
    }
    if (aTab == "page")
    {
        Entry@ e = Find(aPage);
        if (e !is null)
            AddPluginPage(aWin, aClicks, aForm, e, false, "", "");
    }
    else if (aTab == "installed")
    {
        array<Entry@> list = Installed(aSearchShown);
        for (uint i = 0; i < list.length(); i++)
            ARow(list[i]);
        if (list.length() == 0)
            T(aWin, "No installed plugin matches.", 16, MUTED);
    }
    else if (aTab == "updates")
    {
        array<Entry@> list = WithUpdates();
        if (list.length() == 0)
            T(aWin, "Everything is up to date.", 18, MUTED);
        else
        {
            T(aWin, list.length() + (list.length() == 1 ? " update" : " updates"), 22, WHITE, true);
            aWin.AddSpace(0);
            aClicks.Add(Btn(aWin, "update all", LIME, INK, 16, true), "update-all");
            for (uint i = 0; i < list.length(); i++)
                ARow(list[i]);
        }
    }
    else
    {
        for (uint c = 0; c < CATEGORIES.length(); c++)
        {
            array<Entry@> list = Available(CATEGORIES[c], aSearchShown);
            if (list.length() == 0)
                continue;
            aWin.NewRow();
            T(aWin, CATEGORIES[c], 20, LIME, true);
            for (uint i = 0; i < list.length(); i++)
                ARow(list[i]);
        }
    }
}

void ARow(Entry@ e)
{
    aWin.StartCard();
    aWin.AddImage(IconOf(e), 40, 40);
    aClicks.Add(Btn(aWin, e.name, ROW, WHITE, 18, true, 2), "page:" + e.id);
    if (e.installed)
    {
        T(aWin, e.version, 13, DIM);
        if (e.update != "")
            T(aWin, "update " + e.update, 14, WARN);
        if (e.broken)
            T(aWin, "stopped", 14, BAD);
    }
    else
        T(aWin, "by " + e.author, 14, MUTED);
    UI::Text@ d = T(aWin, ShortText(e.description, 70), 14, MUTED);
    d.SetFill(true);
    if (!e.installed)
        aClicks.Add(Btn(aWin, e.pending == "installing" ? "installing" : "install", LIME, INK, 15, true), "install:" + e.id);
    else if (e.update != "" && aTab == "updates")
        aClicks.Add(Btn(aWin, "update", LIME, INK, 15, true), "update:" + e.id);
    else if (e.essential)
        T(aWin, "built in", 14, DIM);
    else
    {
        UI::Button@ b = Btn(aWin, e.enabled ? "On" : "Off", INK, e.enabled ? WHITE : MUTED, 14, false, 0);
        b.SetStyle(0, 34, 5);
        aClicks.Add(b, (e.enabled ? "off:" : "on:") + e.id);
    }
    aWin.EndCard();
}

void AUpdate()
{
    string a = aClicks.Poll();
    bool escape = EscapePressed();
    if (a == "close" || (escape && aTab != "page"))
    {
        ProtoClose();
        return;
    }
    if (escape)
        a = "tab:" + aBackTab;
    if (a.findFirst("tab:") == 0)
    {
        aTab = a.substr(4);
        if (aTab != "page")
            aBackTab = aTab;
        ABuild();
    }
    else if (a.findFirst("page:") == 0)
    {
        aPage = a.substr(5);
        aTab = "page";
        ABuild();
    }
    else if (a != "")
        DoPluginAction(a);
    if (aSearch !is null && aSearch.typed != aSearchShown)
    {
        aSearchShown = aSearch.typed;
        ABuild();
    }
    if (aTab == "page")
        aForm.Update();
}

// ===== B  store: one scrolling page of tiles, yours first, then every category; a tile opens the plugin's page. ======

UI::Window@ bWin;
int bView = -1;
string bPage;
UI::TextInput@ bSearch;
string bSearchShown;
Clicks bClicks;
SettingsForm bForm;
const uint B_PER_ROW = 4;

void BOpen()
{
    if (bWin is null)
    {
        @bWin = UI::CreateWindow();
        bWin.SetScreenSize(0.86f, 0.86f);
        WinColor(bWin, PANEL, 1.0f);
        CardsColor(bWin, ROW);
        bWin.SetBlocksClicks(true);
        bWin.zOrder = 500;
        bView = bWin.StartView();
        bWin.SetScrolling(bView, true);
        bWin.ShowView(bView);
    }
    BBuild();
    bWin.visible = true;
}

void BBuild()
{
    bWin.ClearView(bView);
    bClicks.Clear();
    @bSearch = null;
    if (bPage != "")
    {
        Entry@ e = Find(bPage);
        if (e !is null)
        {
            AddPluginPage(bWin, bClicks, bForm, e, false, "back", "all plugins");
            return;
        }
        bPage = "";
    }
    T(bWin, "plugins", 38, WHITE, true);
    bWin.AddSpace(20);
    @bSearch = bWin.AddTextInput(320, "search every plugin", 16);
    bSearch.clearOnSubmit = false;
    bSearch.clearButton = true;
    bSearch.value = bSearchShown;
    bWin.AddSpace(0);
    uint updates = WithUpdates().length();
    if (updates > 0)
        bClicks.Add(Btn(bWin, "update all  " + updates, LIME, INK, 16, true), "update-all");
    bClicks.Add(Btn(bWin, "close", ROW_HI, WHITE, 16, true), "close");
    BSection("your plugins", Installed(bSearchShown));
    for (uint c = 0; c < CATEGORIES.length(); c++)
        BSection(CATEGORIES[c], Available(CATEGORIES[c], bSearchShown));
    bWin.NewRow();
    bClicks.Add(Btn(bWin, "open plugins folder", ROW, MUTED, 13), "folder");
    bClicks.Add(Btn(bWin, "console", ROW, MUTED, 13), "console");
}

void BSection(const string &in title, array<Entry@> list)
{
    if (list.length() == 0)
        return;
    bWin.NewRow();
    bWin.AddSpace(0);
    bWin.NewRow();
    T(bWin, title, 22, WHITE, true);
    T(bWin, "" + list.length(), 16, DIM);
    for (uint start = 0; start < list.length(); start += B_PER_ROW)
    {
        bWin.StartCardRow();
        for (uint k = 0; k < B_PER_ROW; k++)
        {
            bWin.StartCard();
            if (start + k >= list.length())
            {
                CardColor(bWin, PANEL, 0);      // keeps the last row's tiles the same width
                bWin.AddSpace(10);
                continue;
            }
            Entry@ e = list[start + k];
            bWin.AddImage(IconOf(e), 64, 64);
            bWin.AddSpace(0);
            if (e.installed)
                T(bWin, StateWord(e), 14, StateColor(e));
            bWin.NewRow();
            bClicks.Add(Btn(bWin, e.name, ROW, WHITE, 18, true, 2), "page:" + e.id);
            bWin.NewRow();
            T(bWin, ShortText(e.description, 46), 13, MUTED);
            bWin.NewRow();
            if (!e.installed)
                bClicks.Add(Btn(bWin, e.pending == "installing" ? "installing" : "install", LIME, INK, 15, true), "install:" + e.id);
            else if (e.update != "")
                bClicks.Add(Btn(bWin, "update", LIME, INK, 15, true), "update:" + e.id);
            else if (!e.essential)
                bClicks.Add(Btn(bWin, e.enabled ? "turn off" : "turn on", ROW_HI, WHITE, 15, true), (e.enabled ? "off:" : "on:") + e.id);
            else
                T(bWin, "built in", 14, DIM);
            T(bWin, e.installed ? e.version : "by " + e.author, 13, DIM);
        }
        bWin.EndCardRow();
    }
}

void BUpdate()
{
    string a = bClicks.Poll();
    if (EscapePressed())
        a = bPage != "" ? "back" : "close";
    if (a == "close")
    {
        ProtoClose();
        return;
    }
    if (a == "back")
    {
        bPage = "";
        BBuild();
    }
    else if (a.findFirst("page:") == 0)
    {
        bPage = a.substr(5);
        BBuild();
    }
    else if (a != "")
        DoPluginAction(a);
    if (bSearch !is null && bSearch.typed != bSearchShown)
    {
        bSearchShown = bSearch.typed;
        BBuild();
    }
    if (bPage != "")
        bForm.Update();
}

// ===== C  list and page: every plugin down the left (yours, then the rest by category), the chosen one's page on
// the right with its settings right there. ============================================================================

UI::Window@ cWin;
int cView = -1;
string cSelected = "grind-stats";
string cOpenCategory = "practice";
UI::TextInput@ cSearch;
string cSearchShown;
Clicks cClicks;
SettingsForm cForm;

void COpen()
{
    if (cWin is null)
    {
        @cWin = UI::CreateWindow();
        cWin.SetScreenSize(0.86f, 0.86f);
        WinColor(cWin, PANEL, 1.0f);
        CardsColor(cWin, ROW);
        cWin.SetBlocksClicks(true);
        cWin.zOrder = 500;
        cWin.StartSidebar(300);
        cView = cWin.StartView();
        cWin.SetScrolling(cView, true);
        cWin.ShowView(cView);
    }
    CBuild();
    cWin.visible = true;
}

void CBuild()
{
    cWin.ClearView(cView);
    cWin.ClearSidebar();
    cClicks.Clear();
    T(cWin, "plugins", 34, WHITE, true);
    @cSearch = cWin.AddTextInput(0, "search", 15);
    cSearch.clearOnSubmit = false;
    cSearch.clearButton = true;
    cSearch.value = cSearchShown;
    uint updates = WithUpdates().length();
    if (updates > 0)
        cClicks.Add(Btn(cWin, "update all  " + updates, LIME, INK, 15, true), "update-all");
    T(cWin, "yours", 15, DIM, true);
    array<Entry@> mine = Installed(cSearchShown);
    for (uint i = 0; i < mine.length(); i++)
        CItem(mine[i]);
    // The sidebar doesn't scroll, so the categories fold: only the open one (or every match while searching) lists.
    T(cWin, "get more", 15, DIM, true);
    bool searching = WithoutSpaces(cSearchShown) != "";
    for (uint c = 0; c < CATEGORIES.length(); c++)
    {
        array<Entry@> list = Available(CATEGORIES[c], cSearchShown);
        if (list.length() == 0)
            continue;
        bool open = searching || CATEGORIES[c] == cOpenCategory;
        cClicks.Add(Btn(cWin, (open ? "- " : "+ ") + CATEGORIES[c] + "  " + list.length(), PANEL, MUTED, 15, true, 2),
                    "fold:" + CATEGORIES[c]);
        if (open)
            for (uint i = 0; i < list.length(); i++)
                CItem(list[i]);
    }
    cWin.StartMain();
    cWin.AddSpace(0);
    cClicks.Add(Btn(cWin, "plugins folder", PANEL, DIM, 13), "folder");
    cClicks.Add(Btn(cWin, "console", PANEL, DIM, 13), "console");
    cClicks.Add(Btn(cWin, "close", ROW_HI, WHITE, 15, true), "close");
    cWin.NewRow();
    Entry@ e = Find(cSelected);
    if (e !is null)
        AddPluginPage(cWin, cClicks, cForm, e, false, "", "");
}

void CItem(Entry@ e)
{
    bool on = e.id == cSelected;
    string word = StateWord(e);
    string label = e.name + (word != "" && word != "on" ? "   " + word : "");
    UI::Button@ b = Btn(cWin, label, on ? LIME : INK, on ? INK : (word == "off" ? MUTED : WHITE), 16, true, 2);
    cClicks.Add(b, "select:" + e.id);
}

void CUpdate()
{
    string a = cClicks.Poll();
    if (a == "close" || EscapePressed())
    {
        ProtoClose();
        return;
    }
    if (a.findFirst("select:") == 0)
    {
        cSelected = a.substr(7);
        CBuild();
    }
    else if (a.findFirst("fold:") == 0)
    {
        cOpenCategory = cOpenCategory == a.substr(5) ? "" : a.substr(5);
        CBuild();
    }
    else if (a != "")
        DoPluginAction(a);
    if (cSearch.typed != cSearchShown)
    {
        cSearchShown = cSearch.typed;
        CBuild();
    }
    cForm.Update();
}

// ===== D  side drawer: a panel down the right edge that leaves the game in view. Your plugins with an on / off
// switch each; a plugin opens in place with its settings; "get more" swaps the list. =================================

UI::Window@ dWin;
int dView = -1;
bool dMore = false;
string dOpen;
string dCategory = "";
Clicks dClicks;
SettingsForm dForm;

void DOpen()
{
    if (dWin is null)
    {
        @dWin = UI::CreateWindow();
        WinColor(dWin, PANEL, 1.0f);
        CardsColor(dWin, ROW);
        dWin.SetCornerRadius(12);
        dWin.SetPadding(16, 14);
        dWin.SetBlocksClicks(true);
        dWin.zOrder = 500;
        dView = dWin.StartView();
        dWin.SetScrolling(dView, true);
        dWin.ShowView(dView);
    }
    float w, h;
    if (UI::ScreenSize(w, h))
        dWin.SetRect(w - 470, 50, 450, h - UI::FooterHeight() - 64);
    DBuild();
    dWin.visible = true;
}

void DBuild()
{
    dWin.ClearView(dView);
    dClicks.Clear();
    T(dWin, "plugins", 30, WHITE, true);
    dWin.AddSpace(0);
    dClicks.Add(Btn(dWin, "x", ROW_HI, WHITE, 16, true), "close");
    dWin.NewRow();
    dClicks.Add(Chip(dWin, "mine", !dMore, 17), "mine");
    dClicks.Add(Chip(dWin, "get more", dMore, 17), "more");
    if (!dMore)
    {
        array<Entry@> updates = WithUpdates();
        if (updates.length() > 0)
        {
            dWin.StartCard();
            CardColor(dWin, 0x3a3415);
            T(dWin, updates.length() + (updates.length() == 1 ? " update" : " updates"), 17, WARN, true);
            dWin.AddSpace(0);
            dClicks.Add(Btn(dWin, "update all", LIME, INK, 15, true), "update-all");
            dWin.EndCard();
        }
        array<Entry@> list = Installed();
        for (uint i = 0; i < list.length(); i++)
            DRow(list[i]);
        dWin.NewRow();
        dClicks.Add(Btn(dWin, "open plugins folder", ROW, MUTED, 13), "folder");
        dClicks.Add(Btn(dWin, "console", ROW, MUTED, 13), "console");
    }
    else
    {
        dWin.NewRow();
        dClicks.Add(Chip(dWin, "all", dCategory == "", 15), "cat:");
        for (uint c = 0; c < CATEGORIES.length(); c++)
            dClicks.Add(Chip(dWin, CATEGORIES[c], dCategory == CATEGORIES[c], 15), "cat:" + CATEGORIES[c]);
        array<Entry@> list = Available(dCategory);
        for (uint i = 0; i < list.length(); i++)
            DRow(list[i]);
    }
}

void DRow(Entry@ e)
{
    bool open = e.id == dOpen;
    dWin.StartCard();
    if (open)
        CardColor(dWin, ROW_HI);
    dWin.AddImage(IconOf(e), 34, 34);
    dClicks.Add(Btn(dWin, e.name, open ? ROW_HI : ROW, WHITE, 16, true, 2), "toggle:" + e.id);
    dWin.AddSpace(0);
    if (!e.installed)
        dClicks.Add(Btn(dWin, e.pending == "installing" ? "..." : "install", LIME, INK, 14, true), "install:" + e.id);
    else if (e.essential)
        T(dWin, "built in", 13, DIM);
    else if (e.broken)
        T(dWin, "stopped", 13, BAD);
    else
    {
        UI::Button@ s = Btn(dWin, e.enabled ? "on" : "off", e.enabled ? LIME : INK, e.enabled ? INK : MUTED, 14, true, 12);
        dClicks.Add(s, (e.enabled ? "off:" : "on:") + e.id);
    }
    if (e.update != "" && !open)
    {
        dWin.NewRow();
        dWin.AddSpace(34);
        T(dWin, "update " + e.update + " waiting", 13, WARN);
    }
    if (open)
    {
        dWin.NewRow();
        T(dWin, e.description, 14, MUTED).SetWrap(true);
        if (e.broken)
        {
            dWin.NewRow();
            T(dWin, e.status, 13, BAD);
        }
        dWin.NewRow();
        if (e.update != "")
            dClicks.Add(Btn(dWin, "update to " + e.update, LIME, INK, 14, true), "update:" + e.id);
        if (e.installed && !e.essential)
            dClicks.Add(Btn(dWin, "remove", ROW, WHITE, 14, true), "remove:" + e.id);
        if (e.page != "")
            dClicks.Add(Btn(dWin, "github", ROW, WHITE, 14, true), "open:" + e.page);
        T(dWin, "by " + e.author + "  " + e.version, 13, DIM);
        dWin.EndCard();
        if (e.installed && e.hasSettings)
            dForm.Build(dWin, e.id);
        return;
    }
    dWin.EndCard();
}

void DUpdate()
{
    string a = dClicks.Poll();
    if (EscapePressed())
        a = dOpen != "" ? "toggle:" + dOpen : "close";
    if (a == "close")
    {
        ProtoClose();
        return;
    }
    if (a == "mine" || a == "more")
    {
        dMore = a == "more";
        dOpen = "";
        DBuild();
    }
    else if (a.findFirst("cat:") == 0)
    {
        dCategory = a.substr(4);
        DBuild();
    }
    else if (a.findFirst("toggle:") == 0)
    {
        string id = a.substr(7);
        dOpen = dOpen == id ? "" : id;
        DBuild();
    }
    else if (a != "")
        DoPluginAction(a);
    dForm.Update();
}

// ===== E  categories: the game's light play page. Big title, the categories down the left as the play page's
// sidebar, tiles on grey; "yours" is one of the categories. ============================================================

UI::Window@ eWin;
int eView = -1;
string eCategory = "yours";
string ePage;
Clicks eClicks;
SettingsForm eForm;

void EOpen()
{
    if (eWin is null)
    {
        @eWin = UI::CreateWindow();
        eWin.SetScreenSize(0.88f, 0.86f);
        WinColor(eWin, LIGHT, 1.0f);
        CardsColor(eWin, WHITE);
        eWin.SetBlocksClicks(true);
        eWin.zOrder = 500;
        eWin.StartSidebar(220);
        eView = eWin.StartView();
        eWin.SetScrolling(eView, true);
        eWin.ShowView(eView);
    }
    EBuild();
    eWin.visible = true;
}

void EBuild()
{
    eWin.ClearView(eView);
    eWin.ClearSidebar();
    eClicks.Clear();
    array<string> cats = {"yours"};
    for (uint c = 0; c < CATEGORIES.length(); c++)
        cats.insertLast(CATEGORIES[c]);
    eWin.AddSpace(90);
    for (uint c = 0; c < cats.length(); c++)
    {
        bool on = cats[c] == eCategory;
        UI::Button@ b = Btn(eWin, cats[c], on ? WHITE : BLUE, on ? INK : WHITE, 24, true, 2);
        b.SetStyle(2, 16, 8);
        eClicks.Add(b, "cat:" + cats[c]);
    }
    eWin.AddSpace(20);
    eClicks.Add(Btn(eWin, "back", INK, WHITE, 20, true, 2), "close");
    eClicks.Add(Btn(eWin, "console", LIGHT, DIM, 13, false, 2), "console");
    eWin.StartMain();
    T(eWin, "Plugins", 64, INK, true);
    T(eWin, ePage != "" ? "plugin" : eCategory == "yours" ? "installed" : eCategory, 28, INK, true);
    eWin.AddSpace(0);
    uint updates = WithUpdates().length();
    if (updates > 0)
        eClicks.Add(Btn(eWin, "update all  " + updates, LIME, INK, 16, true, 2), "update-all");
    eWin.NewRow();
    if (ePage != "")
    {
        Entry@ e = Find(ePage);
        if (e !is null)
            AddPluginPage(eWin, eClicks, eForm, e, true, "cat:" + eCategory, eCategory);
        return;
    }
    array<Entry@> list = eCategory == "yours" ? Installed() : Available(eCategory);
    for (uint start = 0; start < list.length(); start += 3)
    {
        eWin.StartCardRow();
        for (uint k = 0; k < 3; k++)
        {
            eWin.StartCard();
            if (start + k >= list.length())
            {
                CardColor(eWin, LIGHT, 0);
                eWin.AddSpace(10);
                continue;
            }
            Entry@ e = list[start + k];
            eWin.AddImage(IconOf(e), 72, 72);
            eWin.AddSpace(0);
            if (e.installed)
                T(eWin, StateWord(e), 15, StateColor(e) == LIME ? 0x4f7d0f : StateColor(e), true);
            eWin.NewRow();
            eClicks.Add(Btn(eWin, e.name, WHITE, INK, 20, true, 2), "page:" + e.id);
            eWin.NewRow();
            T(eWin, ShortText(e.description, 40), 13, DIM);
            eWin.NewRow();
            if (!e.installed)
                eClicks.Add(Btn(eWin, "install", LIME, INK, 15, true, 2), "install:" + e.id);
            else if (e.update != "")
                eClicks.Add(Btn(eWin, "update", LIME, INK, 15, true, 2), "update:" + e.id);
            else if (!e.essential)
                eClicks.Add(Btn(eWin, e.enabled ? "turn off" : "turn on", LIGHT, INK, 15, true, 2), (e.enabled ? "off:" : "on:") + e.id);
        }
        eWin.EndCardRow();
    }
    if (list.length() == 0)
        T(eWin, "Nothing here yet.", 18, DIM);
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
// ===== end of PROTOTYPE ===========================================================================================
