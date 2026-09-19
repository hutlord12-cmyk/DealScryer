local FS = _G.DealScryer
if not FS then return end

local function L(key, ...)
    return FS:L(key, ...)
end

local UI = {
    tab = "results",
    rowOffset = 0,
    selected = nil,
    searchText = "",
    activeRows = 12,
    visibleListCache = nil,
    visibleListCacheKey = nil,
    prefetchToken = 0,
    syncingScrollBar = false,
}
FS.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8X8"

local THEME_PRESETS = {
    classic = {
        label = "Classic",
        fontFlags = "OUTLINE",
        colors = {
            bg = {0.022, 0.025, 0.031, 0.985},
            bg2 = {0.032, 0.036, 0.044, 0.985},
            panel = {0.047, 0.052, 0.063, 0.965},
            panel2 = {0.060, 0.066, 0.078, 0.965},
            row1 = {0.040, 0.044, 0.053, 0.94},
            row2 = {0.050, 0.055, 0.065, 0.94},
            border = {0.135, 0.153, 0.184, 1},
            border2 = {0.100, 0.112, 0.135, 1},
            text = {0.93, 0.94, 0.96, 1},
            muted = {0.56, 0.59, 0.64, 1},
            faint = {0.39, 0.42, 0.47, 1},
            gold = {0.95, 0.72, 0.18, 1},
            green = {0.34, 0.90, 0.53, 1},
            blue = {0.40, 0.72, 1.00, 1},
            orange = {1.00, 0.62, 0.24, 1},
            red = {0.96, 0.42, 0.42, 1},
        },
        button = {
            normalBg = {0.060, 0.066, 0.078, 1},
            normalBorder = {0.135, 0.153, 0.184, 1},
            hoverBg = {0.090, 0.098, 0.114, 1},
            primaryBg = {0.27, 0.19, 0.045, 1},
            primaryHover = {0.37, 0.26, 0.055, 1},
            primaryBorder = {0.95, 0.72, 0.18, 0.72},
            primaryText = {1.00, 0.89, 0.52, 1},
            dangerBg = {0.15, 0.055, 0.060, 1},
            dangerHover = {0.21, 0.072, 0.078, 1},
            dangerText = {1.00, 0.72, 0.73, 1},
            disabledBg = {0.040, 0.043, 0.050, 0.68},
            disabledText = {0.39, 0.42, 0.47, 1},
        },
    },

}

local C = {
    bg = {0.022, 0.025, 0.031, 0.985},
    bg2 = {0.032, 0.036, 0.044, 0.985},
    panel = {0.047, 0.052, 0.063, 0.965},
    panel2 = {0.060, 0.066, 0.078, 0.965},
    row1 = {0.040, 0.044, 0.053, 0.94},
    row2 = {0.050, 0.055, 0.065, 0.94},
    border = {0.135, 0.153, 0.184, 1},
    border2 = {0.100, 0.112, 0.135, 1},
    text = {0.93, 0.94, 0.96, 1},
    muted = {0.56, 0.59, 0.64, 1},
    faint = {0.39, 0.42, 0.47, 1},
    gold = {0.95, 0.72, 0.18, 1},
    green = {0.34, 0.90, 0.53, 1},
    blue = {0.40, 0.72, 1.00, 1},
    orange = {1.00, 0.62, 0.24, 1},
    red = {0.96, 0.42, 0.42, 1},
}

UI.themeRegistry = {
    backdrops = {},
    texts = {},
    buttons = {},
    tabs = {},
    textures = {},
    checks = {},
}
UI.currentTheme = "classic"
UI.currentFontFlags = "OUTLINE"

local function Theme()
    return THEME_PRESETS[UI.currentTheme] or THEME_PRESETS.classic
end

local function ColorRole(color)
    for key, ref in pairs(C) do
        if color == ref then
            return key
        end
    end
    return nil
end

local function ApplyColorTable(dst, src)
    if not dst or not src then return end
    for i = 1, 4 do
        dst[i] = src[i]
    end
end

local function RegisterUnique(pool, obj)
    if not obj then return end
    for i = 1, #pool do
        if pool[i] == obj then return end
    end
    pool[#pool + 1] = obj
end

local function RegisterTextureColor(tex, role, alpha)
    if not tex then return end
    tex._fsColorRole = role
    tex._fsColorAlpha = alpha or 1
    RegisterUnique(UI.themeRegistry.textures, tex)
end

local function RoundPixel(v)
    v = tonumber(v) or 0
    return math.floor(v + 0.5)
end

local function SnapSize(frame, w, h)
    w, h = RoundPixel(w), RoundPixel(h)
    if PixelUtil and PixelUtil.SetSize then
        PixelUtil.SetSize(frame, w, h)
    else
        frame:SetSize(w, h)
    end
end

local function SnapPoint(frame, point, relativeTo, relativePoint, x, y)
    x, y = RoundPixel(x or 0), RoundPixel(y or 0)
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(frame, point, relativeTo, relativePoint, x, y)
    else
        frame:SetPoint(point, relativeTo, relativePoint, x, y)
    end
end

local function Backdrop(frame, bg, border)
    frame:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = 1,
    })
    local b = bg or C.bg
    local e = border or C.border
    frame._fsBgRole = ColorRole(b) or "bg"
    frame._fsBorderRole = ColorRole(e) or "border"
    frame:SetBackdropColor(b[1], b[2], b[3], b[4] or 1)
    frame:SetBackdropBorderColor(e[1], e[2], e[3], e[4] or 1)
    RegisterUnique(UI.themeRegistry.backdrops, frame)
end

local function Text(parent, value, template, color)
    local templateName = template or "GameFontHighlightSmall"
    local fs = parent:CreateFontString(nil, "OVERLAY", templateName)
    fs:SetText(value or "")

    -- DealScryer deliberately renders text slightly larger than Blizzard's
    -- corresponding template and at an integer font size. Combined with OUTLINE
    -- and no shadow this is much easier to read on 1440p/4K UI scales.
    local font, size = fs:GetFont()
    if font and size then
        local boost = 2
        if templateName:find("Huge", 1, true) or templateName:find("Large", 1, true) then
            boost = 1
        end
        local readableSize = math.max(12, RoundPixel(size + boost))
        pcall(fs.SetFont, fs, font, readableSize, "OUTLINE")
    end
    fs:SetShadowColor(0, 0, 0, 0)
    fs:SetShadowOffset(0, 0)

    local c = color or C.text
    fs._fsColorRole = ColorRole(c) or "text"
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    RegisterUnique(UI.themeRegistry.texts, fs)
    return fs
end

local function Panel(parent, bg)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Backdrop(f, bg or C.panel, C.border2)
    return f
end

local function Button(parent, value, width, primary, danger)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 90, 28)
    b.primary = primary == true
    b.danger = danger == true
    Backdrop(b, C.panel2, C.border)

    local label = Text(b, value, "GameFontNormalSmall", C.text)
    label:SetPoint("CENTER")
    b.label = label

    function b:SetText(v) self.label:SetText(v or "") end

    function b:_fsApplyStyle(hovered)
        local style = Theme().button
        if not self:IsEnabled() then
            self:SetBackdropColor(style.disabledBg[1], style.disabledBg[2], style.disabledBg[3], style.disabledBg[4] or 1)
            self:SetBackdropBorderColor(C.border2[1], C.border2[2], C.border2[3], 0.60)
            self.label:SetTextColor(style.disabledText[1], style.disabledText[2], style.disabledText[3], style.disabledText[4] or 1)
        elseif self.primary then
            local bg = hovered and style.primaryHover or style.primaryBg
            self:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
            self:SetBackdropBorderColor(style.primaryBorder[1], style.primaryBorder[2], style.primaryBorder[3], style.primaryBorder[4] or 1)
            self.label:SetTextColor(style.primaryText[1], style.primaryText[2], style.primaryText[3], style.primaryText[4] or 1)
        elseif self.danger then
            local bg = hovered and style.dangerHover or style.dangerBg
            self:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
            self:SetBackdropBorderColor(C.red[1], C.red[2], C.red[3], 0.78)
            self.label:SetTextColor(style.dangerText[1], style.dangerText[2], style.dangerText[3], style.dangerText[4] or 1)
        else
            local bg = hovered and style.hoverBg or style.normalBg
            self:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
            self:SetBackdropBorderColor(style.normalBorder[1], style.normalBorder[2], style.normalBorder[3], style.normalBorder[4] or 1)
            self.label:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        end
    end

    b:SetScript("OnEnter", function(self)
        if not self:IsEnabled() then return end
        self:_fsApplyStyle(true)
    end)
    b:SetScript("OnLeave", function(self) self:_fsApplyStyle(false) end)
    b:SetScript("OnEnable", function(self) self:_fsApplyStyle(false) end)
    b:SetScript("OnDisable", function(self) self:_fsApplyStyle(false) end)
    b:_fsApplyStyle(false)

    RegisterUnique(UI.themeRegistry.buttons, b)
    return b
end

UI.MakeButton = Button

local function Tab(parent, value, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 96, 30)

    local label = Text(b, value, "GameFontNormalSmall", C.muted)
    label:SetPoint("CENTER", 0, 1)
    b.label = label

    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 9, 0)
    line:SetPoint("BOTTOMRIGHT", -9, 0)
    line:SetHeight(2)
    line:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
    line:Hide()
    b.line = line
    RegisterTextureColor(line, "gold", 1)

    function b:SetText(v) self.label:SetText(v or "") end
    function b:SetActive(active)
        self.active = active
        self.line:SetShown(active)
        local c = active and C.gold or C.muted
        self.label:SetTextColor(c[1], c[2], c[3], 1)
    end

    RegisterUnique(UI.themeRegistry.tabs, b)
    return b
end

local function Edit(parent, width, placeholder)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(width or 180, 27)
    e:SetAutoFocus(false)
    e:SetFontObject("ChatFontNormal")
    do
        local font, size = e:GetFont()
        if font and size then
            pcall(e.SetFont, e, font, math.max(13, RoundPixel(size + 2)), "OUTLINE")
        end
    end
    e:SetTextInsets(8, 8, 0, 0)
    Backdrop(e, C.bg2, C.border2)

    if placeholder then
        local p = Text(e, placeholder, "GameFontHighlightSmall", C.faint)
        p:SetPoint("LEFT", 8, 0)
        e.placeholder = p

        local function update()
            p:SetShown((e:GetText() or "") == "" and not e:HasFocus())
        end
        e:HookScript("OnTextChanged", update)
        e:HookScript("OnEditFocusGained", update)
        e:HookScript("OnEditFocusLost", update)
        update()
    end

    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

local function Check(parent, labelText)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    local l = Text(c, labelText, "GameFontHighlightSmall", C.muted)
    l:SetPoint("LEFT", c, "RIGHT", 2, 0)
    c.FSLabel = l
    RegisterUnique(UI.themeRegistry.checks, c)
    return c
end

local function MetricCard(parent, titleText, accentColor)
    local p = Panel(parent, C.panel)
    p:SetHeight(58)

    local accent = p:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    accent:SetColorTexture(accentColor[1], accentColor[2], accentColor[3], 0.95)
    RegisterTextureColor(accent, ColorRole(accentColor) or "gold", 0.95)

    local title = Text(p, titleText, "GameFontHighlightSmall", C.muted)
    title:SetPoint("TOPLEFT", 12, -8)

    local value = Text(p, "—", "GameFontNormalLarge", C.text)
    value:SetPoint("BOTTOMLEFT", 12, 7)

    p.value = value
    p.accent = accent
    return p
end

local function Graph(parent, titleText)
    local g = Panel(parent, C.bg2)
    g.title = Text(g, titleText, "GameFontNormalSmall", C.text)
    g.title:SetPoint("TOPLEFT", 11, -9)

    g.meta = Text(g, "", "GameFontHighlightSmall", C.muted)
    g.meta:SetPoint("TOPRIGHT", -11, -9)
    g.meta:SetJustifyH("RIGHT")

    g.plot = CreateFrame("Frame", nil, g)
    g.plot:SetPoint("TOPLEFT", 11, -31)
    g.plot:SetPoint("BOTTOMRIGHT", -11, 10)

    g.empty = Text(g.plot, L("NO_DATA_YET"), "GameFontHighlightSmall", C.faint)
    g.empty:SetPoint("TOPLEFT", g.plot, "TOPLEFT", 4, -2)
    g.empty:SetPoint("BOTTOMRIGHT", g.plot, "BOTTOMRIGHT", -4, 2)
    g.empty:SetJustifyH("CENTER")
    g.empty:SetJustifyV("MIDDLE")
    g.empty:SetWordWrap(true)
    if g.empty.SetNonSpaceWrap then g.empty:SetNonSpaceWrap(true) end
    g:SetClipsChildren(true)

    g.bars = {}
    g.labels = {}
    g.markers = {}
    g.lines = {}
    return g
end

local function HidePool(pool)
    for _, obj in ipairs(pool or {}) do obj:Hide() end
end

local function PoolTexture(graph, index)
    local t = graph.bars[index]
    if not t then
        t = graph.plot:CreateTexture(nil, "ARTWORK")
        graph.bars[index] = t
    end
    t:Show()
    return t
end

local function PoolLabel(graph, index)
    local t = graph.labels[index]
    if not t then
        t = Text(graph.plot, "", "GameFontHighlightSmall", C.faint)
        graph.labels[index] = t
    end
    t:Show()
    return t
end

local function PoolLine(graph, index)
    local line = graph.lines[index]
    if not line and graph.plot.CreateLine then
        line = graph.plot:CreateLine(nil, "ARTWORK")
        line:SetThickness(2)
        graph.lines[index] = line
    end
    if line then line:Show() end
    return line
end

local function PoolMarker(graph, index)
    local t = graph.markers[index]
    if not t then
        t = graph.plot:CreateTexture(nil, "ARTWORK")
        graph.markers[index] = t
    end
    t:Show()
    return t
end


function UI:UpdateThemeButtons()
    -- Classic is the only available theme.
end

function UI:SetTheme(themeID, silent)
    themeID = "classic"

    UI.currentTheme = "classic"
    UI.currentFontFlags = THEME_PRESETS.classic.fontFlags or "OUTLINE"

    for key, values in pairs(THEME_PRESETS[themeID].colors) do
        if C[key] then
            ApplyColorTable(C[key], values)
        end
    end

    for _, frame in ipairs(self.themeRegistry.backdrops or {}) do
        if frame and frame.SetBackdropColor then
            local bg = C[frame._fsBgRole or "bg"] or C.bg
            local border = C[frame._fsBorderRole or "border"] or C.border
            frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
            frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
        end
    end

    for _, fontString in ipairs(self.themeRegistry.texts or {}) do
        if fontString and fontString.SetTextColor then
            local color = C[fontString._fsColorRole or "text"] or C.text
            local font, size = fontString:GetFont()
            if font and size then
                pcall(fontString.SetFont, fontString, font, RoundPixel(size), UI.currentFontFlags or "OUTLINE")
            end
            fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
            fontString:SetShadowColor(0, 0, 0, 0)
            fontString:SetShadowOffset(0, 0)
        end
    end

    for _, texture in ipairs(self.themeRegistry.textures or {}) do
        if texture and texture.SetColorTexture then
            local color = C[texture._fsColorRole or "gold"] or C.gold
            texture:SetColorTexture(color[1], color[2], color[3], texture._fsColorAlpha or 1)
        end
    end

    for _, tab in ipairs(self.themeRegistry.tabs or {}) do
        if tab and tab.SetActive then
            tab:SetActive(tab.active == true)
        end
    end

    for _, button in ipairs(self.themeRegistry.buttons or {}) do
        if button and button._fsApplyStyle then
            button:_fsApplyStyle(false)
        end
    end

    if self.rows then
        for _, row in ipairs(self.rows) do
            if row.selectedBar then
                row.selectedBar:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.95)
            end
        end
    end

    if self.headerDivider then
        self.headerDivider:SetColorTexture(C.border2[1], C.border2[2], C.border2[3], 1)
    end

    if self.titleAccent then
        self.titleAccent:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.82)
    end

    if self.searchOptionsAccent then
        self.searchOptionsAccent:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.85)
    end

    if self.resizeDots then
        for _, dot in ipairs(self.resizeDots) do
            dot:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 0.75)
        end
    end

    if self.progressBar and not FS.Scanner.scanRunning then
        self.progressBar:SetStatusBarColor(C.faint[1], C.faint[2], C.faint[3], 0.45)
    end

    self:UpdateThemeButtons()
end

function UI:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "DealScryerMainFrame", UIParent, "BackdropTemplate")
    self.frame = f
    _G.DealScryerWindow = f

    f:SetSize(1280, 760)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetUserPlaced(true)
    f:EnableMouse(true)
    Backdrop(f, C.bg, C.border)
    f:Hide()

    if f.SetResizeBounds then
        f:SetResizeBounds(1120, 750, 1650, 1000)
    end

    table.insert(UISpecialFrames, "DealScryerMainFrame")

    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    accent:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.82)
    self.titleAccent = accent
    RegisterTextureColor(accent, "gold", 0.82)

    local titleBar = CreateFrame("Frame", "DealScryerTitleBar", f)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOP", 300, 0)
    titleBar:SetHeight(64)
    titleBar:SetFrameLevel(f:GetFrameLevel() + 1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        UI:SaveWindowGeometry()
    end)

    local brandIcon = f:CreateTexture(nil, "ARTWORK")
    brandIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    brandIcon:SetSize(31, 31)
    brandIcon:SetPoint("TOPLEFT", 16, -11)
    brandIcon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    self.brandIcon = brandIcon

    local title = Text(f, "DEALSCRYER", "GameFontNormalHuge", C.text)
    title:SetPoint("TOPLEFT", 54, -15)

    local version = Text(f, "v" .. FS.VERSION, "GameFontHighlightSmall", C.faint)
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)
    self.version = version

    local creator = Text(f, L("CREATOR_BY"), "GameFontNormalSmall", C.gold)
    creator:SetPoint("LEFT", version, "RIGHT", 10, 0)
    self.creatorMark = creator

    local provider = Text(f, L("PROVIDER_STANDALONE"), "GameFontHighlightSmall", C.muted)
    provider:SetPoint("TOPLEFT", 18, -43)
    self.provider = provider

    local creatorHit = CreateFrame("Frame", nil, f)
    creatorHit:SetAllPoints(creator)
    creatorHit:EnableMouse(true)
    creatorHit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L("CREATOR_TOOLTIP"))
        GameTooltip:Show()
    end)
    creatorHit:SetScript("OnLeave", GameTooltip_Hide)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetFrameLevel(f:GetFrameLevel() + 20)

    local fullScan = Button(f, L("FULL_SCAN"), 132, true)
    fullScan:SetPoint("TOPRIGHT", -40, -17)
    fullScan:SetFrameLevel(f:GetFrameLevel() + 10)
    fullScan:SetScript("OnClick", function()
        FS.Scanner:SetStatus(L("FULL_SCAN_CLICKED"), 0.005)
        FS.Scanner:StartFullScan()
    end)
    self.scanButton = fullScan

    local previous = Button(f, L("PREVIOUS_SCAN"), 126)
    previous:SetFrameLevel(f:GetFrameLevel() + 10)
    previous:SetPoint("RIGHT", fullScan, "LEFT", -7, 0)
    previous:SetScript("OnClick", function()
        FS.Scanner:LoadPreviousScan(false)
    end)
    self.previousScanButton = previous

    local searchSelected = Button(f, L("OPEN_AH"), 105)
    searchSelected:SetFrameLevel(f:GetFrameLevel() + 10)
    searchSelected:SetPoint("RIGHT", previous, "LEFT", -7, 0)
    searchSelected:SetScript("OnClick", function() self:OpenSelectedInAH() end)
    self.searchSelected = searchSelected

    local watch = Button(f, L("WATCH"), 90)
    watch:SetFrameLevel(f:GetFrameLevel() + 10)
    watch:SetPoint("RIGHT", searchSelected, "LEFT", -7, 0)
    watch:SetScript("OnClick", function()
        if self.selected then FS:ToggleWatch(self.selected.itemID) end
    end)
    self.watch = watch

    local ignore = Button(f, L("IGNORE"), 90, false, true)
    ignore:SetFrameLevel(f:GetFrameLevel() + 10)
    ignore:SetPoint("RIGHT", watch, "LEFT", -7, 0)
    ignore:SetScript("OnClick", function()
        if self.selected then FS:ToggleBlacklist(self.selected.itemID) end
    end)
    self.ignore = ignore

    local export = Button(f, L("EXPORT"), 72)
    export:SetFrameLevel(f:GetFrameLevel() + 10)
    export:SetPoint("RIGHT", ignore, "LEFT", -7, 0)
    export:SetScript("OnClick", function() self:ShowExport() end)
    self.export = export

    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 0, -66)
    line:SetPoint("TOPRIGHT", 0, -66)
    line:SetHeight(1)
    line:SetColorTexture(C.border2[1], C.border2[2], C.border2[3], 1)
    self.headerDivider = line
    RegisterTextureColor(line, "border2", 1)

    self.tabDeals = Tab(f, L("DEALS"), 92)
    self.tabDeals:SetPoint("TOPLEFT", 14, -70)
    self.tabDeals:SetScript("OnClick", function() self:SetTab("results") end)

    self.tabCandidates = Tab(f, L("CANDIDATES"), 112)
    self.tabCandidates:SetPoint("LEFT", self.tabDeals, "RIGHT", 1, 0)
    self.tabCandidates:SetScript("OnClick", function() self:SetTab("candidates") end)

    self.tabWatch = Tab(f, L("WATCHLIST"), 116)
    self.tabWatch:SetPoint("LEFT", self.tabCandidates, "RIGHT", 1, 0)
    self.tabWatch:SetScript("OnClick", function() self:SetTab("watch") end)

    self.tabSettings = Tab(f, L("SETTINGS"), 106)
    self.tabSettings:SetPoint("LEFT", self.tabWatch, "RIGHT", 1, 0)
    self.tabSettings:SetScript("OnClick", function() self:SetTab("settings") end)

    self.searchOptionsButton = Button(f, L("SEARCH_OPTIONS"), 132)
    self.searchOptionsButton:SetPoint("TOPRIGHT", -17, -72)
    self.searchOptionsButton:SetScript("OnClick", function()
        UI:ToggleSearchOptions()
    end)

    self.filter = Edit(f, 175, L("SEARCH_ITEMS"))
    self.filter:SetPoint("RIGHT", self.searchOptionsButton, "LEFT", -7, 0)
    self.filter:SetScript("OnTextChanged", function(box)
        UI.searchText = box:GetText() or ""
        UI.rowOffset = 0
        UI:InvalidateVisibleList()
        UI:RefreshRows()
    end)

    self:CreateSearchOptionsPanel()

    self.metrics = CreateFrame("Frame", nil, f)
    self.metrics:SetPoint("TOPLEFT", 17, -109)
    self.metrics:SetPoint("TOPRIGHT", -17, -109)
    self.metrics:SetHeight(58)

    self.metricDeals = MetricCard(self.metrics, L("METRIC_DEALS"), C.green)
    self.metricCandidates = MetricCard(self.metrics, L("METRIC_CANDIDATES"), C.blue)
    self.metricBest = MetricCard(self.metrics, L("BEST_SCORE"), C.gold)
    self.metricProfit = MetricCard(self.metrics, L("TOP_PROFIT_UNIT"), C.orange)

    self:CreateResultsArea()
    self:CreateSettings()
    self:CreateResizeGrip()

    self.status = Text(f, L("READY"), "GameFontHighlightSmall", C.muted)
    self.status:SetPoint("BOTTOMLEFT", 18, 25)
    self.status:SetWidth(780)
    self.status:SetJustifyH("LEFT")

    self.range = Text(f, "", "GameFontHighlightSmall", C.muted)
    self.range:SetPoint("BOTTOMRIGHT", -31, 25)
    self.range:SetJustifyH("RIGHT")

    self.progressBar = CreateFrame("StatusBar", "DealScryerAnalysisProgressBar", f, "BackdropTemplate")
    self.progressBar:SetPoint("BOTTOMLEFT", 18, 10)
    self.progressBar:SetPoint("BOTTOMRIGHT", -31, 10)
    self.progressBar:SetHeight(7)
    self.progressBar:SetMinMaxValues(0, 1)
    self.progressBar:SetValue(0)
    self.progressBar:SetStatusBarTexture(WHITE)
    self.progressBar:SetStatusBarColor(C.gold[1], C.gold[2], C.gold[3], 0.95)
    Backdrop(self.progressBar, C.bg2, C.border2)

    f:SetScript("OnSizeChanged", function(_, w, h)
        if not UI.suppressGeometrySave and FS.DB then
            FS.DB.window.width = math.floor(w + 0.5)
            FS.DB.window.height = math.floor(h + 0.5)
        end
        UI:Layout()
    end)

    f:SetScript("OnHide", function() UI:SaveWindowGeometry() end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        UI:ScrollBy(-delta * 4)
    end)

    self:SetTheme("classic", true)
    self:RestorePosition()
    self:SetTab("results")
    self:RegisterMoverSupport()

    C_Timer.NewTicker(0.20, function()
        if UI.frame and UI.frame:IsShown() then UI:UpdateStatus() end
    end)
end


local QUALITY_KEYS = {
    [-1] = "ANY_QUALITY",
    [0] = "POOR_PLUS",
    [1] = "COMMON_PLUS",
    [2] = "UNCOMMON_PLUS",
    [3] = "RARE_PLUS",
    [4] = "EPIC_PLUS",
    [5] = "LEGENDARY_PLUS",
}

local function QualityName(q)
    return L(QUALITY_KEYS[q] or "ANY_QUALITY")
end

function UI:GetClassFilterName()
    local id = tonumber(FS.DB.searchOptions and FS.DB.searchOptions.classID) or -1
    if id < 0 then return L("ALL_CATEGORIES") end
    if GetItemClassInfo then
        local ok, name = pcall(GetItemClassInfo, id)
        if ok and name then return name end
    end
    return L("CATEGORY_FMT", id)
end

function UI:CreateSearchOptionsPanel()
    if self.searchOptionsPanel then return end

    local p = CreateFrame("Frame", "DealScryerSearchOptionsPanel", self.frame, "BackdropTemplate")
    self.searchOptionsPanel = p
    p:SetSize(360, 355)
    p:SetPoint("TOPRIGHT", self.searchOptionsButton, "BOTTOMRIGHT", 0, -6)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetFrameLevel(self.frame:GetFrameLevel() + 40)
    p:EnableMouse(true)
    Backdrop(p, C.bg, C.border)
    p:Hide()

    local accent = p:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    accent:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.85)
    self.searchOptionsAccent = accent
    RegisterTextureColor(accent, "gold", 0.85)

    local title = Text(p, L("SEARCH_OPTIONS_TITLE"), "GameFontNormalLarge", C.text)
    title:SetPoint("TOPLEFT", 14, -13)

    local sub = Text(
        p,
        L("SEARCH_OPTIONS_SUB"),
        "GameFontHighlightSmall",
        C.muted
    )
    sub:SetPoint("TOPLEFT", 14, -38)

    local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    self.searchOptionBoxes = {}

    local function Field(id, labelText, x, y, width)
        local label = Text(p, labelText, "GameFontHighlightSmall", C.muted)
        label:SetPoint("TOPLEFT", x, y)

        local box = Edit(p, width or 92)
        box:SetPoint("TOPLEFT", x, y - 18)
        self.searchOptionBoxes[id] = box
        return box
    end

    Field("minPriceGold", L("MIN_PRICE_GOLD"), 14, -72, 104)
    Field("maxPriceGold", L("MAX_PRICE_GOLD"), 130, -72, 104)
    Field("minQuantity", L("MIN_QUANTITY"), 246, -72, 96)

    Field("minItemLevel", L("MIN_ITEM_LEVEL"), 14, -128, 104)
    Field("maxItemLevel", L("MAX_ITEM_LEVEL"), 130, -128, 104)

    local qualityLabel = Text(p, L("MIN_QUALITY"), "GameFontHighlightSmall", C.muted)
    qualityLabel:SetPoint("TOPLEFT", 14, -188)

    self.qualityFilterButton = Button(p, L("ANY_QUALITY"), 150)
    self.qualityFilterButton:SetPoint("TOPLEFT", 14, -207)
    self.qualityFilterButton:SetScript("OnClick", function(button)
        if not MenuUtil or not MenuUtil.CreateContextMenu then return end
        MenuUtil.CreateContextMenu(button, function(_, root)
            root:CreateTitle(L("MIN_QUALITY"))
            for _, q in ipairs({-1, 0, 1, 2, 3, 4, 5}) do
                root:CreateButton(QualityName(q), function()
                    FS.DB.searchOptions.minQuality = q
                    UI.qualityFilterButton:SetText(QualityName(q))
                    UI:RefreshRows()
                end)
            end
        end)
    end)

    local classLabel = Text(p, L("ITEM_CATEGORY"), "GameFontHighlightSmall", C.muted)
    classLabel:SetPoint("TOPLEFT", 180, -188)

    self.classFilterButton = Button(p, L("ALL_CATEGORIES"), 164)
    self.classFilterButton:SetPoint("TOPLEFT", 180, -207)
    self.classFilterButton:SetScript("OnClick", function(button)
        if not MenuUtil or not MenuUtil.CreateContextMenu then return end
        MenuUtil.CreateContextMenu(button, function(_, root)
            root:CreateTitle(L("ITEM_CATEGORY"))
            root:CreateButton(L("ALL_CATEGORIES"), function()
                FS.DB.searchOptions.classID = -1
                UI.classFilterButton:SetText(L("ALL_CATEGORIES"))
                UI:RefreshRows()
            end)

            root:CreateDivider()

            for id = 0, 25 do
                local name
                if GetItemClassInfo then
                    local ok, n = pcall(GetItemClassInfo, id)
                    if ok then name = n end
                end
                if name and name ~= "" then
                    root:CreateButton(name, function()
                        FS.DB.searchOptions.classID = id
                        UI.classFilterButton:SetText(name)
                        UI:RefreshRows()
                    end)
                end
            end
        end)
    end)

    self.onlyUsableCheck = Check(p, L("USABLE_ONLY"))
    self.onlyUsableCheck:SetPoint("TOPLEFT", 11, -252)

    self.equipmentOnlyCheck = Check(p, L("EQUIPMENT_ONLY"))
    self.equipmentOnlyCheck:SetPoint("TOPLEFT", 180, -252)

    local apply = Button(p, L("APPLY"), 100, true)
    apply:SetPoint("BOTTOMLEFT", 14, 14)
    apply:SetScript("OnClick", function()
        UI:ApplySearchOptions()
        p:Hide()
    end)

    local reset = Button(p, L("RESET"), 82)
    reset:SetPoint("LEFT", apply, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function()
        for k, v in pairs(FS.DEFAULTS.searchOptions) do
            FS.DB.searchOptions[k] = v
        end
        UI:LoadSearchOptions()
        UI.rowOffset = 0
        UI:InvalidateVisibleList()
        UI:RefreshRows()
    end)

    local active = Text(p, "", "GameFontHighlightSmall", C.faint)
    active:SetPoint("BOTTOMRIGHT", -14, 20)
    active:SetJustifyH("RIGHT")
    self.searchOptionsActiveText = active
end

function UI:ToggleSearchOptions()
    if not self.searchOptionsPanel then return end
    if self.searchOptionsPanel:IsShown() then
        self.searchOptionsPanel:Hide()
    else
        self:LoadSearchOptions()
        self.searchOptionsPanel:Show()
    end
end

function UI:LoadSearchOptions()
    if not self.searchOptionBoxes then return end
    local opt = FS.DB.searchOptions or {}

    for key, box in pairs(self.searchOptionBoxes) do
        box:SetText(tostring(opt[key] or 0))
    end

    self.qualityFilterButton:SetText(
        QualityName(tonumber(opt.minQuality) or -1)
    )
    self.classFilterButton:SetText(self:GetClassFilterName())
    self.onlyUsableCheck:SetChecked(opt.onlyUsable == true)
    self.equipmentOnlyCheck:SetChecked(opt.equipmentOnly == true)
    self:UpdateSearchOptionsBadge()
end

function UI:ApplySearchOptions()
    local opt = FS.DB.searchOptions
    for key, box in pairs(self.searchOptionBoxes or {}) do
        opt[key] = math.max(0, tonumber(box:GetText()) or 0)
    end

    opt.onlyUsable = self.onlyUsableCheck:GetChecked() == true
    opt.equipmentOnly = self.equipmentOnlyCheck:GetChecked() == true

    self.rowOffset = 0
    self:InvalidateVisibleList()
    self:UpdateSearchOptionsBadge()
    self:RefreshRows()
end

function UI:UpdateSearchOptionsBadge()
    if not self.searchOptionsButton or not FS.DB then return end

    local opt = FS.DB.searchOptions or {}
    local active = 0

    for _, key in ipairs({
        "minPriceGold",
        "maxPriceGold",
        "minItemLevel",
        "maxItemLevel",
        "minQuantity",
        "minROIPct",
    }) do
        if (tonumber(opt[key]) or 0) > 0 then active = active + 1 end
    end

    if (tonumber(opt.minQuality) or -1) >= 0 then active = active + 1 end
    if (tonumber(opt.classID) or -1) >= 0 then active = active + 1 end
    if opt.riskMode and opt.riskMode ~= "all" then active = active + 1 end
    if opt.onlyUsable then active = active + 1 end
    if opt.equipmentOnly then active = active + 1 end

    if active > 0 then
        self.searchOptionsButton:SetText(L("ACTIVE_FILTERS_FMT", active))
    else
        self.searchOptionsButton:SetText(L("SEARCH_OPTIONS"))
    end

    if self.searchOptionsActiveText then
        self.searchOptionsActiveText:SetText(active > 0 and L("ACTIVE_FILTERS_FMT", active) or L("NO_EXTRA_FILTERS"))
    end
end

function UI:CreateResultsArea()
    local f = self.frame

    self.tablePanel = Panel(f, C.panel)
    self.detailPanel = Panel(f, C.panel)

    if self.tablePanel.SetClipsChildren then self.tablePanel:SetClipsChildren(true) end
    if self.detailPanel.SetClipsChildren then self.detailPanel:SetClipsChildren(true) end

    self.tableHeader = CreateFrame("Frame", nil, self.tablePanel, "BackdropTemplate")
    Backdrop(self.tableHeader, C.bg2, C.border2)

    self.columns = {
        {key="name", text=L("COLUMN_ITEM"), ratio=0.42, sortable=true},
        {key="buy", text=L("COLUMN_BUY"), ratio=0.115, sortable=true},
        {key="sell", text=L("COLUMN_TARGET"), ratio=0.115},
        {key="profit", text=L("COLUMN_PROFIT"), ratio=0.125, sortable=true},
        {key="roi", text=L("COLUMN_ROI"), ratio=0.080, sortable=true},
        {key="discount", text=L("COLUMN_OFF"), ratio=0.065, sortable=true},
        {key="score", text=L("COLUMN_SCORE"), ratio=0.080, sortable=true},
    }

    self.headerButtons = {}
    for _, col in ipairs(self.columns) do
        local b = CreateFrame("Button", nil, self.tableHeader)
        local t = Text(b, col.text, "GameFontNormalSmall", C.muted)
        t:SetPoint("LEFT")
        t:SetJustifyH("LEFT")
        b.label = t
        b.baseText = col.text
        b.sortKey = col.key

        if col.sortable then
            b:SetScript("OnClick", function() FS.Scanner:SetSort(col.key) end)
        end

        self.headerButtons[col.key] = b
    end

    self.rows = {}
    for i = 1, 24 do
        local row = CreateFrame("Button", nil, self.tablePanel, "BackdropTemplate")
        row:SetHeight(27)
        row:SetBackdrop({bgFile = WHITE})

        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetPoint("TOPLEFT")
        selected:SetPoint("BOTTOMLEFT")
        selected:SetWidth(3)
        selected:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.95)
        selected:Hide()
        row.selectedBar = selected

        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.035)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon = icon

        local warning = row:CreateTexture(nil, "OVERLAY")
        warning:SetSize(15, 15)
        warning:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
        warning:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        warning:Hide()
        row.warningIcon = warning

        row.cells = {}
        for _, col in ipairs(self.columns) do
            local cell = Text(row, "", "GameFontHighlightSmall", C.text)
            cell:SetJustifyH("LEFT")
            cell:SetWordWrap(false)
            row.cells[col.key] = cell
        end

        row:RegisterForClicks("LeftButtonUp")

        row:SetScript("OnMouseDown", function(r, button)
            if button ~= "RightButton" or not r.data then return end

            UI.selected = r.data
            UI:RefreshRows()
            UI:RefreshDetail()

            -- Blizzard's modern MenuUtil context menus are intended to be opened
            -- from the mouse-down event. Opening them on mouse-up can immediately
            -- dismiss the menu again.
            UI:ShowItemContextMenu(r, r.data)
        end)

        row:SetScript("OnClick", function(r, button)
            if button ~= "LeftButton" or not r.data then return end

            UI.selected = r.data

            if IsShiftKeyDown() then
                UI:LinkItemToChat(r.data)
            end

            UI:RefreshRows()
            UI:RefreshDetail()
        end)

        row:SetScript("OnEnter", function(r)
            if r.data then UI:ShowRowTooltip(r) end
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)

        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            UI:ScrollBy(-delta * 4)
        end)

        self.rows[i] = row
    end

    self.tablePanel:EnableMouseWheel(true)
    self.tablePanel:SetScript("OnMouseWheel", function(_, delta)
        UI:ScrollBy(-delta * 4)
    end)

    local scrollBar = CreateFrame("Slider", "DealScryerResultsScrollBar", self.tablePanel, "BackdropTemplate")
    self.scrollBar = scrollBar
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)
    if scrollBar.SetObeyStepOnDrag then scrollBar:SetObeyStepOnDrag(true) end
    Backdrop(scrollBar, C.bg2, C.border2)

    local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetSize(12, 38)
    thumb:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.90)
    scrollBar:SetThumbTexture(thumb)
    scrollBar.thumb = thumb

    scrollBar:SetScript("OnValueChanged", function(_, value)
        if UI.syncingScrollBar or UI.tab == "settings" then return end
        local newOffset = math.floor((tonumber(value) or 0) + 0.5)
        if newOffset == UI.rowOffset then return end
        UI.rowOffset = newOffset
        UI:RefreshRows()
    end)

    self.tableHint = Text(
        self.tablePanel,
        L("TABLE_HINT"),
        "GameFontHighlightSmall",
        C.faint
    )

    self.detailIcon = self.detailPanel:CreateTexture(nil, "ARTWORK")
    self.detailIcon:SetSize(38, 38)
    self.detailIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    self.detailName = Text(self.detailPanel, L("SELECT_ITEM"), "GameFontNormalLarge", C.text)
    self.detailName:SetWordWrap(false)

    self.detailMeta = Text(
        self.detailPanel,
        L("DETAIL_HELP"),
        "GameFontHighlightSmall",
        C.muted
    )

    self.detailBuy = MetricCard(self.detailPanel, L("BUY_UPPER"), C.gold)
    self.detailTarget = MetricCard(self.detailPanel, L("TARGET_UPPER"), C.blue)
    self.detailProfit = MetricCard(self.detailPanel, L("PROFIT_UNIT_UPPER"), C.green)

    self.priceGraph = Graph(self.detailPanel, L("PRICE_HISTORY"))
    self.oeGraph = Graph(self.detailPanel, L("UNDERMINE_GRAPH_TITLE"))
    self.depthGraph = Graph(self.detailPanel, L("MARKET_LADDER"))

    self.riskTitle = Text(self.detailPanel, "EVIDENCE & RISK", "GameFontHighlightSmall", C.muted)
    self.riskText = Text(self.detailPanel, "—", "GameFontHighlightSmall", C.orange)
    self.riskText:SetWordWrap(true)
    self.sourceText = Text(self.detailPanel, "—", "GameFontHighlightSmall", C.faint)
    self.sourceText:SetWordWrap(true)

    self.undermineText = Text(self.detailPanel, "", "GameFontHighlightSmall", C.blue)
    self.undermineText:SetWordWrap(true)
    self.undermineText:SetJustifyH("CENTER")

    self.outlierWarning = Text(
        self.detailPanel,
        "",
        "GameFontHighlightSmall",
        C.orange
    )
    self.outlierWarning:SetWordWrap(true)
    self.outlierWarning:SetJustifyH("LEFT")
    self.outlierWarning:Hide()
end

function UI:CreateSettings()
    local f = self.frame
    local page = CreateFrame("Frame", nil, f)
    self.settingsPage = page
    self.settingBoxes = {}

    self.settingsLeft = Panel(page, C.panel)
    self.settingsRight = Panel(page, C.panel)

    if page.SetClipsChildren then page:SetClipsChildren(true) end
    if self.settingsLeft.SetClipsChildren then self.settingsLeft:SetClipsChildren(true) end
    if self.settingsRight.SetClipsChildren then self.settingsRight:SetClipsChildren(true) end

    local lt = Text(self.settingsLeft, L("DEAL_FILTERS"), "GameFontNormalLarge", C.text)
    lt:SetPoint("TOPLEFT", 15, -14)
    local ls = Text(self.settingsLeft, L("DEAL_FILTERS_DESC"), "GameFontHighlightSmall", C.muted)
    ls:SetPoint("TOPLEFT", 15, -39)

    local rt = Text(self.settingsRight, L("HISTORY_BEHAVIOR"), "GameFontNormalLarge", C.text)
    rt:SetPoint("TOPLEFT", 15, -14)
    local rs = Text(self.settingsRight, L("NO_DEPS_SETTINGS"), "GameFontHighlightSmall", C.muted)
    rs:SetPoint("TOPLEFT", 15, -39)

    local function Field(panel, id, labelText, y)
        local l = Text(panel, labelText, "GameFontHighlightSmall", C.muted)
        l:SetPoint("TOPLEFT", 15, y)
        l:SetWidth(260)
        l:SetJustifyH("LEFT")

        local e = Edit(panel, 125)
        e:SetPoint("TOPRIGHT", -15, y + 5)
        UI.settingBoxes[id] = e
    end

    Field(self.settingsLeft, "minDiscount", L("MIN_DISCOUNT"), -78)
    Field(self.settingsLeft, "minProfitGold", L("MIN_PROFIT_GOLD"), -117)
    Field(self.settingsLeft, "minROIPct", L("MIN_ROI"), -156)
    Field(self.settingsLeft, "minMarketGold", L("MIN_TARGET_VALUE"), -195)
    Field(self.settingsLeft, "budgetGold", L("BUDGET_PER_ITEM"), -234)
    Field(self.settingsLeft, "targetROIPct", L("TARGET_ROI"), -273)

    local scoreTitle = Text(self.settingsLeft, L("SCORE_SYSTEM"), "GameFontNormal", C.gold)
    scoreTitle:SetPoint("TOPLEFT", 15, -322)

    local scoreDesc = Text(self.settingsLeft, L("SCORE_SYSTEM_DESC"), "GameFontHighlightSmall", C.muted)
    scoreDesc:SetPoint("TOPLEFT", 15, -344)
    scoreDesc:SetPoint("RIGHT", -15, 0)
    scoreDesc:SetJustifyH("LEFT")
    scoreDesc:SetWordWrap(true)

    local scoreLegend = {
        {L("SCORE_POOR"),       "ffffffff"},
        {L("SCORE_GOOD"),       "ff1eff00"},
        {L("SCORE_RARE"),       "ff0070dd"},
        {L("SCORE_EPIC"),       "ffa335ee"},
        {L("SCORE_LEGENDARY"),  "ffff8000"},
        {L("SCORE_SUSPICIOUS"), "ffff2020"},
    }

    self.scoreLegendTexts = {}
    for i, data in ipairs(scoreLegend) do
        local line = Text(self.settingsLeft, "|c" .. data[2] .. data[1] .. "|r", "GameFontHighlightSmall", C.text)
        line:SetPoint("TOPLEFT", 18, -390 - ((i - 1) * 20))
        self.scoreLegendTexts[#self.scoreLegendTexts + 1] = line
    end

    Field(self.settingsRight, "historySamples", L("HISTORY_SAMPLES"), -78)
    Field(self.settingsRight, "historyMinScans", L("HISTORY_ONLY_SCANS"), -117)
    Field(self.settingsRight, "alertScore", L("ALERT_SCORE"), -156)

    self.alertsCheck = Check(self.settingsRight, L("CHAT_ALERTS"))
    self.alertsCheck:SetPoint("TOPLEFT", 12, -198)

    self.tooltipCheck = Check(self.settingsRight, L("TOOLTIP_SETTING"))
    self.tooltipCheck:SetPoint("TOPLEFT", 12, -230)

    self.undermineTitle = Text(self.settingsRight, L("UNDERMINE_TITLE"), "GameFontNormal", C.blue)
    self.undermineTitle:SetPoint("TOPLEFT", 15, -270)

    self.undermineStatus = Text(self.settingsRight, "", "GameFontHighlightSmall", C.muted)
    self.undermineStatus:SetPoint("TOPLEFT", 15, -293)
    self.undermineStatus:SetPoint("RIGHT", -15, 0)
    self.undermineStatus:SetWordWrap(true)
    self.undermineStatus:SetJustifyH("LEFT")

    local disclaimerTitle = Text(
        self.settingsRight,
        L("RISK_DISCLAIMER"),
        "GameFontNormal",
        C.gold
    )
    disclaimerTitle:SetPoint("TOPLEFT", 15, -346)

    local disclaimerText = Text(
        self.settingsRight,
        L("DISCLAIMER_TEXT"),
        "GameFontHighlightSmall",
        C.muted
    )
    disclaimerText:SetPoint("TOPLEFT", 15, -369)
    disclaimerText:SetPoint("RIGHT", -15, 0)
    disclaimerText:SetJustifyH("LEFT")
    disclaimerText:SetWordWrap(true)
    self.disclaimerText = disclaimerText

    self.disclaimerCheck = Check(self.settingsRight, L("DISCLAIMER_ACK"))
    self.disclaimerCheck:SetPoint("TOPLEFT", 12, -447)

    local suspiciousScoreTitle = Text(
        self.settingsRight,
        L("SUSPICIOUS_SCORE_TITLE"),
        "GameFontNormal",
        C.orange
    )
    suspiciousScoreTitle:SetPoint("TOPLEFT", 15, -489)

    local suspiciousScoreDesc = Text(
        self.settingsRight,
        L("SUSPICIOUS_SCORE_DESC"),
        "GameFontHighlightSmall",
        C.muted
    )
    suspiciousScoreDesc:SetPoint("TOPLEFT", 15, -512)
    suspiciousScoreDesc:SetPoint("RIGHT", -15, 0)
    suspiciousScoreDesc:SetJustifyH("LEFT")
    suspiciousScoreDesc:SetWordWrap(true)
    self.suspiciousScoreDesc = suspiciousScoreDesc

    self.settingsApply = Button(page, L("APPLY_RESCORE"), 150, true)
    self.settingsApply:SetScript("OnClick", function() UI:ApplySettings() end)

    self.settingsDefaults = Button(page, L("DEFAULTS"), 105)
    self.settingsDefaults:SetScript("OnClick", function()
        for k, v in pairs(FS.DEFAULTS.settings) do
            FS.DB.settings[k] = v
        end
        UI:LoadSettings()
        FS.Scanner:RebuildVisibleLists()
        UI:Refresh()
    end)

    self.settingsClearHistory = Button(page, L("CLEAR_HISTORY"), 120, false, true)
    self.settingsClearHistory:SetScript("OnClick", function()
        local market = FS:GetMarketState()
        if market and market.history then wipe(market.history) end
        FS:Print(L("HISTORY_CLEARED"))
        UI:Refresh()
    end)

    self.settingsNote = Text(
        page,
        L("SETTINGS_NOTE"),
        "GameFontHighlightSmall",
        C.faint
    )
    self.settingsNote:SetWordWrap(false)
    self.settingsNote:SetJustifyH("LEFT")
    if self.settingsNote.SetMaxLines then self.settingsNote:SetMaxLines(1) end
end

function UI:CreateResizeGrip()
    local grip = CreateFrame("Button", "DealScryerResizeGrip", self.frame)
    grip:SetSize(24, 24)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(self.frame:GetFrameLevel() + 20)
    grip:EnableMouse(true)

    self.resizeDots = {}
    for i = 0, 2 do
        local d = grip:CreateTexture(nil, "ARTWORK")
        d:SetSize(2, 2)
        d:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 0.75)
        d:SetPoint("BOTTOMRIGHT", -5 - i * 5, 5)
        self.resizeDots[#self.resizeDots + 1] = d
        RegisterTextureColor(d, "muted", 0.75)
    end

    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then self.frame:StartSizing("BOTTOMRIGHT") end
    end)
    grip:SetScript("OnMouseUp", function()
        self.frame:StopMovingOrSizing()

        local w = RoundPixel(self.frame:GetWidth())
        local h = RoundPixel(self.frame:GetHeight())
        self.suppressGeometrySave = true
        SnapSize(self.frame, w, h)
        self.suppressGeometrySave = false

        self:SaveWindowGeometry()
        self:Layout()
    end)
end


local function DealScryerAtan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end
    return 0
end

function UI:UpdateMinimapButtonPosition()
    if not self.minimapButton or not Minimap or not FS.DB then return end

    FS.DB.minimap = FS.DB.minimap or { angle = 225 }
    local angle = tonumber(FS.DB.minimap.angle) or 225
    local radians = math.rad(angle)
    local radius = math.max(70, (Minimap:GetWidth() or 140) * 0.5 + 12)

    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(radians) * radius,
        math.sin(radians) * radius
    )
end

function UI:CreateMinimapButton()
    if self.minimapButton or not Minimap then
        if self.minimapButton then self:UpdateMinimapButtonPosition() end
        return
    end

    FS.DB.minimap = FS.DB.minimap or { angle = 225 }

    local button = CreateFrame("Button", "DealScryerMinimapButton", Minimap)
    self.minimapButton = button
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetSize(19, 19)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints()

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            UI:Show()
            UI:SetTab("settings")
            return
        end

        if UI.frame and UI.frame:IsShown() then
            UI.frame:Hide()
        else
            UI:Show()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L("MINIMAP_TITLE"))
        GameTooltip:AddLine(L("MINIMAP_LEFT"), 0.88, 0.88, 0.88)
        GameTooltip:AddLine(L("MINIMAP_RIGHT"), 0.88, 0.88, 0.88)
        GameTooltip:AddLine(L("MINIMAP_DRAG"), 0.60, 0.65, 0.72)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    button:SetScript("OnDragStart", function(self)
        self.isDragging = true
        GameTooltip_Hide()

        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            if not mx or not my then return end

            local cursorX, cursorY = GetCursorPosition()
            local scale = UIParent and UIParent:GetEffectiveScale() or 1
            cursorX = cursorX / scale
            cursorY = cursorY / scale

            local angle = math.deg(DealScryerAtan2(cursorY - my, cursorX - mx))
            FS.DB.minimap.angle = angle
            UI:UpdateMinimapButtonPosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        UI:UpdateMinimapButtonPosition()
    end)

    self:UpdateMinimapButtonPosition()
end

function UI:RegisterMoverSupport()
    if not self.frame then self:Create() end

    if _G.BlizzMoveAPI
        and _G.BlizzMoveAPI.RegisterAddOnFrames
        and not self.blizzMoveRegistered then

        local ok = pcall(function()
            _G.BlizzMoveAPI:RegisterAddOnFrames({
                DealScryer = {
                    DealScryerMainFrame = {
                        FrameReference = self.frame,
                        IgnoreMouseWheel = true,
                        IgnoreClamping = true,
                    },
                },
            })
        end)

        if ok then self.blizzMoveRegistered = true end
    end

    self.frame:SetMovable(true)
    self.frame:SetResizable(true)
    self.frame:SetUserPlaced(true)
end

function UI:SaveWindowGeometry()
    if not self.frame or not FS.DB then return end

    local point, _, _, x, y = self.frame:GetPoint(1)
    FS.DB.window.point = point or "CENTER"
    FS.DB.window.x = RoundPixel(x or 0)
    FS.DB.window.y = RoundPixel(y or 0)
    FS.DB.window.width = RoundPixel(self.frame:GetWidth())
    FS.DB.window.height = RoundPixel(self.frame:GetHeight())
end

function UI:RestorePosition()
    if not self.frame then return end

    local w = FS.DB.window or {}
    local width = FS:Clamp(tonumber(w.width) or 1280, 1120, 1650)
    local height = FS:Clamp(tonumber(w.height) or 760, 750, 1000)

    self.suppressGeometrySave = true
    SnapSize(self.frame, width, height)
    self.frame:ClearAllPoints()
    local point = w.point or "CENTER"
    SnapPoint(self.frame, point, UIParent, point, tonumber(w.x) or 0, tonumber(w.y) or 0)
    self.suppressGeometrySave = false

    self:Layout()
end

function UI:Layout()
    if not self.frame or not self.tablePanel then return end

    local f = self.frame
    local width = f:GetWidth()

    -- Keep header/footer text inside the space that remains between controls.
    self.provider:ClearAllPoints()
    self.provider:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -43)
    self.provider:SetPoint("RIGHT", self.export, "LEFT", -14, 0)
    self.provider:SetWordWrap(false)
    if self.provider.SetMaxLines then self.provider:SetMaxLines(1) end

    self.range:SetWidth(300)
    self.status:ClearAllPoints()
    self.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 25)
    self.status:SetPoint("RIGHT", self.range, "LEFT", -18, 0)
    self.status:SetWordWrap(false)
    if self.status.SetMaxLines then self.status:SetMaxLines(1) end

    local gap = 8
    local metricsW = self.metrics:GetWidth()
    if metricsW and metricsW > 1 then
        local cardW = math.floor((metricsW - gap * 3) / 4)
        local cards = {
            self.metricDeals,
            self.metricCandidates,
            self.metricBest,
            self.metricProfit,
        }

        for i, card in ipairs(cards) do
            card:ClearAllPoints()
            card:SetWidth(cardW)

            if i == 1 then
                card:SetPoint("TOPLEFT", self.metrics, "TOPLEFT")
            else
                card:SetPoint("LEFT", cards[i - 1], "RIGHT", gap, 0)
            end
        end
    end

    local rightW = FS:Clamp(math.floor(width * 0.30), 330, 420)
    local outer = 17
    local panelGap = 10
    local top = -177
    local bottom = 45

    self.tablePanel:ClearAllPoints()
    self.tablePanel:SetPoint("TOPLEFT", f, "TOPLEFT", outer, top)
    self.tablePanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(rightW + outer + panelGap), bottom)

    self.detailPanel:ClearAllPoints()
    self.detailPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -outer, top)
    self.detailPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -outer, bottom)
    self.detailPanel:SetWidth(rightW)

    self.tableHeader:ClearAllPoints()
    self.tableHeader:SetPoint("TOPLEFT", self.tablePanel, "TOPLEFT", 10, -10)
    self.tableHeader:SetPoint("TOPRIGHT", self.tablePanel, "TOPRIGHT", -30, -10)
    self.tableHeader:SetHeight(28)

    local usableW = math.max(600, self.tablePanel:GetWidth() - 40)
    local x = 0

    local compact = not FS.DB.settings.advancedColumns
    local ratios = {name=0.46, buy=0.15, profit=0.17, roi=0.11, score=0.11, sell=0, discount=0}
    for _, col in ipairs(self.columns) do
        local ratio = compact and ratios[col.key] or col.ratio
        col.hidden = ratio == 0
        self.headerButtons[col.key]:SetShown(not col.hidden)
        local w = math.floor(usableW * ratio)
        local hb = self.headerButtons[col.key]

        hb:ClearAllPoints()
        hb:SetPoint("TOPLEFT", self.tableHeader, "TOPLEFT", x + 8, 0)
        hb:SetSize(w - 4, 28)
        hb.label:SetWidth(math.max(1, w - 8))
        hb.label:SetJustifyH(col.key == "name" and "LEFT" or "RIGHT")

        col._x = x
        col._w = w
        x = x + w
    end

    local availableH = self.tablePanel:GetHeight() - 10 - 28 - 34
    self.activeRows = FS:Clamp(math.floor(availableH / 28), 8, #self.rows)

    for i, row in ipairs(self.rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.tablePanel, "TOPLEFT", 10, -41 - (i - 1) * 28)
        row:SetPoint("TOPRIGHT", self.tablePanel, "TOPRIGHT", -30, -41 - (i - 1) * 28)

        if i <= self.activeRows then row:SetHeight(26) else row:Hide() end

        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", 8, 0)

        row.warningIcon:ClearAllPoints()
        row.warningIcon:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)

        for _, col in ipairs(self.columns) do
            local cell = row.cells[col.key]
            cell:ClearAllPoints()

            local cx = col._x + 8
            local cw = col._w - 8

            if col.key == "name" then
                cx = col._x + 54
                cw = col._w - 54
            end

            cell:SetPoint("LEFT", cx, 0)
            cell:SetWidth(math.max(20, cw))
            cell:SetShown(not col.hidden)
            cell:SetJustifyH(col.key == "name" and "LEFT" or "RIGHT")
        end
    end

    self.scrollBar:ClearAllPoints()
    self.scrollBar:SetPoint("TOPRIGHT", self.tablePanel, "TOPRIGHT", -8, -41)
    self.scrollBar:SetPoint("BOTTOMRIGHT", self.tablePanel, "BOTTOMRIGHT", -8, 34)
    self.scrollBar:SetWidth(14)

    self.tableHint:ClearAllPoints()
    self.tableHint:SetPoint("BOTTOMLEFT", self.tablePanel, "BOTTOMLEFT", 11, 9)

    self.detailIcon:ClearAllPoints()
    self.detailIcon:SetPoint("TOPLEFT", self.detailPanel, "TOPLEFT", 12, -12)

    self.detailName:ClearAllPoints()
    self.detailName:SetPoint("TOPLEFT", self.detailPanel, "TOPLEFT", 59, -13)
    self.detailName:SetWidth(rightW - 73)

    self.detailMeta:ClearAllPoints()
    self.detailMeta:SetPoint("TOPLEFT", self.detailPanel, "TOPLEFT", 59, -38)
    self.detailMeta:SetWidth(rightW - 73)

    local cardsW = rightW - 24
    local miniW = math.floor((cardsW - 12) / 3)
    local cards = {self.detailBuy, self.detailTarget, self.detailProfit}

    for i, card in ipairs(cards) do
        card:ClearAllPoints()
        card:SetWidth(miniW)

        if i == 1 then
            card:SetPoint("TOPLEFT", self.detailPanel, "TOPLEFT", 12, -67)
        else
            card:SetPoint("LEFT", cards[i - 1], "RIGHT", 6, 0)
        end
    end

    local detailH = self.detailPanel:GetHeight()
    local oeAvailable = FS.Undermine and FS.Undermine:IsAvailable()
    local oeGraphH = oeAvailable and 96 or 72
    local graphH = math.max(55, math.floor((detailH - 134 - oeGraphH - 27 - 165) / 2))

    self.priceGraph:ClearAllPoints()
    self.priceGraph:SetPoint("TOPLEFT", self.detailPanel, "TOPLEFT", 12, -134)
    self.priceGraph:SetPoint("TOPRIGHT", self.detailPanel, "TOPRIGHT", -12, -134)
    self.priceGraph:SetHeight(graphH)

    self.oeGraph:ClearAllPoints()
    self.oeGraph:SetPoint("TOPLEFT", self.priceGraph, "BOTTOMLEFT", 0, -9)
    self.oeGraph:SetPoint("TOPRIGHT", self.priceGraph, "BOTTOMRIGHT", 0, -9)
    self.oeGraph:SetHeight(oeGraphH)

    self.depthGraph:ClearAllPoints()
    self.depthGraph:SetPoint("TOPLEFT", self.oeGraph, "BOTTOMLEFT", 0, -9)
    self.depthGraph:SetPoint("TOPRIGHT", self.oeGraph, "BOTTOMRIGHT", 0, -9)
    self.depthGraph:SetHeight(graphH)

    self.riskTitle:ClearAllPoints()
    self.riskTitle:SetPoint("TOPLEFT", self.depthGraph, "BOTTOMLEFT", 0, -11)

    self.riskText:ClearAllPoints()
    self.riskText:SetPoint("TOPLEFT", self.riskTitle, "BOTTOMLEFT", 0, -4)
    self.riskText:SetWidth(rightW - 24)
    self.riskText:SetMaxLines(2)
    self.riskText:SetJustifyH("LEFT")

    self.sourceText:ClearAllPoints()
    self.sourceText:SetPoint("TOPLEFT", self.riskText, "BOTTOMLEFT", 0, -5)
    self.sourceText:SetWidth(rightW - 24)
    self.sourceText:SetMaxLines(1)
    self.sourceText:SetJustifyH("LEFT")

    self.undermineText:ClearAllPoints()
    self.undermineText:SetPoint("TOPLEFT", self.sourceText, "BOTTOMLEFT", 0, -5)
    self.undermineText:SetWidth(rightW - 24)
    self.undermineText:SetMaxLines(3)

    self.outlierWarning:ClearAllPoints()
    self.outlierWarning:SetPoint("TOPLEFT", self.undermineText, "BOTTOMLEFT", 0, -5)
    self.outlierWarning:SetWidth(rightW - 24)
    self.outlierWarning:SetMaxLines(2)

    self.settingsPage:ClearAllPoints()
    self.settingsPage:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -112)
    self.settingsPage:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -17, 46)

    local sw = self.settingsPage:GetWidth()
    local leftW = math.floor((sw - 10) / 2)

    self.settingsLeft:ClearAllPoints()
    self.settingsLeft:SetPoint("TOPLEFT")
    self.settingsLeft:SetPoint("BOTTOMLEFT", 0, 58)
    self.settingsLeft:SetWidth(leftW)

    self.settingsRight:ClearAllPoints()
    self.settingsRight:SetPoint("TOPRIGHT")
    self.settingsRight:SetPoint("BOTTOMRIGHT", 0, 58)
    self.settingsRight:SetWidth(sw - leftW - 10)

    self.settingsApply:ClearAllPoints()
    self.settingsApply:SetPoint("BOTTOMLEFT", 0, 10)

    self.settingsDefaults:ClearAllPoints()
    self.settingsDefaults:SetPoint("LEFT", self.settingsApply, "RIGHT", 8, 0)

    self.settingsClearHistory:ClearAllPoints()
    self.settingsClearHistory:SetPoint("LEFT", self.settingsDefaults, "RIGHT", 8, 0)

    self.settingsNote:ClearAllPoints()
    self.settingsNote:SetPoint("LEFT", self.settingsClearHistory, "RIGHT", 18, 0)
    self.settingsNote:SetPoint("RIGHT", self.settingsPage, "RIGHT", -4, 0)

    C_Timer.After(0, function()
        if UI.frame and UI.frame:IsShown() and UI.tab ~= "settings" then
            UI:RefreshRows()
            UI:RefreshDetail()
        end
    end)
end

function UI:SetTab(tab)
    if self.switchingTab then return end
    self.switchingTab = true

    self.tab = tab
    self.rowOffset = 0
    self.selected = nil
    self.prefetchToken = (tonumber(self.prefetchToken) or 0) + 1
    self:InvalidateVisibleList()

    local settings = tab == "settings"
    self.tablePanel:SetShown(not settings)
    self.detailPanel:SetShown(not settings)
    self.metrics:SetShown(not settings)
    self.filter:SetShown(not settings)
    self.settingsPage:SetShown(settings)

    self.tabDeals:SetActive(tab == "results")
    self.tabCandidates:SetActive(tab == "candidates")
    self.tabWatch:SetActive(tab == "watch")
    self.tabSettings:SetActive(tab == "settings")

    if settings then
        self:LoadSettings()
    else
        self:RefreshRows()
        self:RefreshDetail()
    end

    self.switchingTab = false
end

function UI:Show()
    self:Create()
    self:RestorePosition()
    self.frame:Show()
    self:RegisterMoverSupport()
    self:Refresh()
end

function UI:Refresh()
    if not self.frame then return end

    self.version:SetText("v" .. FS.VERSION)
    self:UpdateStatus()
    self:UpdateSearchOptionsBadge()

    if self.tab ~= "settings" then
        self:RefreshRows()
        self:RefreshDetail()
    end
end

local function MaxScore(list)
    local v = 0
    for _, r in ipairs(list or {}) do v = math.max(v, r.score or 0) end
    return v
end

local function MaxProfit(list)
    local v = 0
    for _, r in ipairs(list or {}) do if not r.suspiciousMarket then v = math.max(v, r.profit or 0) end end
    return v
end

function UI:RefreshMetrics()
    local deals = FS.Scanner.results or {}
    local candidates = FS.Scanner.candidates or {}

    self.metricDeals.value:SetText(tostring(#deals))
    self.metricCandidates.value:SetText(tostring(#candidates))

    local bestScore = math.max(MaxScore(deals), MaxScore(candidates))
    local bestTier = FS:GetScoreTier(bestScore)
    self.metricBest.value:SetText(tostring(bestScore))
    self.metricBest.value:SetTextColor(bestTier.r, bestTier.g, bestTier.b, 1)

    self.metricProfit.value:SetText(FS:Money(MaxProfit(deals), true))
end


function UI:VisibleListKey()
    local opt = FS.DB.searchOptions or {}
    local st = FS.DB.settings or {}

    return table.concat({
        tostring(self.tab or "results"),
        tostring(self.searchText or ""),
        tostring(FS.Scanner.visibleRevision or 0),
        tostring(st.sort or "score"),
        tostring(st.sortDesc ~= false),
        tostring(opt.minPriceGold or 0),
        tostring(opt.maxPriceGold or 0),
        tostring(opt.minItemLevel or 0),
        tostring(opt.maxItemLevel or 0),
        tostring(opt.minQuality or -1),
        tostring(opt.classID or -1),
        tostring(opt.onlyUsable == true),
        tostring(opt.equipmentOnly == true),
        tostring(opt.minQuantity or 0),
    }, "|")
end

function UI:InvalidateVisibleList()
    self.visibleListCache = nil
    self.visibleListCacheKey = nil
end

function UI:GetCurrentVisibleList()
    local key = self:VisibleListKey()
    if not self.visibleListCache or self.visibleListCacheKey ~= key then
        self.visibleListCache = FS.Scanner:GetVisibleList(self.tab, self.searchText)
        self.visibleListCacheKey = key
    end
    return self.visibleListCache
end

function UI:UpdateScrollBar(list)
    if not self.scrollBar then return end
    list = list or self:GetCurrentVisibleList()

    local maxOffset = math.max(0, #list - self.activeRows)
    self.syncingScrollBar = true
    self.scrollBar:SetMinMaxValues(0, maxOffset)
    self.scrollBar:SetValue(FS:Clamp(self.rowOffset, 0, maxOffset))
    self.scrollBar:SetShown(maxOffset > 0)
    self.syncingScrollBar = false
end

function UI:ScrollBy(rows)
    if self.tab == "settings" then return end

    local list = self:GetCurrentVisibleList()
    local maxOffset = math.max(0, #list - self.activeRows)
    local newOffset = FS:Clamp(self.rowOffset + (tonumber(rows) or 0), 0, maxOffset)

    if newOffset == self.rowOffset then
        self:UpdateScrollBar(list)
        return
    end

    self.rowOffset = newOffset
    self:RefreshRows()
end

function UI:QueueVisiblePrefetch(list)
    if not list or #list == 0 then return end

    self.prefetchToken = (tonumber(self.prefetchToken) or 0) + 1
    local token = self.prefetchToken

    -- Prioritize what is visible now, then two screens ahead and one screen
    -- behind. This means item names/icons are normally cached before the user
    -- reaches them with the mouse wheel or scrollbar.
    local order, seen = {}, {}
    local function addRange(first, last)
        first = math.max(1, first)
        last = math.min(#list, last)
        for index = first, last do
            local r = list[index]
            local itemID = r and tonumber(r.itemID)
            if itemID and not seen[itemID] then
                seen[itemID] = true
                order[#order + 1] = itemID
            end
        end
    end

    local firstVisible = self.rowOffset + 1
    local lastVisible = math.min(#list, self.rowOffset + self.activeRows)

    addRange(firstVisible, lastVisible)
    addRange(lastVisible + 1, lastVisible + self.activeRows * 2)
    addRange(firstVisible - self.activeRows, firstVisible - 1)

    local cursor = 1
    local function step()
        if token ~= UI.prefetchToken then return end
        if not UI.frame or not UI.frame:IsShown() or UI.tab == "settings" then return end

        local stop = math.min(#order, cursor + 7)
        while cursor <= stop do
            local itemID = order[cursor]
            local name = FS:ResolveItemData(itemID)
            if not FS.IsRealItemName(name, itemID) then
                FS:RequestItemData(itemID)
            end
            cursor = cursor + 1
        end

        if cursor <= #order then
            C_Timer.After(0.03, step)
        end
    end

    step()
end

function UI:OnItemDataBatch()
    if not self.frame or not self.frame:IsShown() or self.tab == "settings" then return end

    -- Only repaint the rows/detail. Do not rebuild the whole dashboard for every
    -- item cache response.
    self:RefreshRows(true)
    if self.selected then
        self:RefreshDetail()
    end
end

function UI:RefreshRows(skipPrefetch)
    if not self.rows or self.tab == "settings" then return end

    local list = self:GetCurrentVisibleList()
    local maxOffset = math.max(0, #list - self.activeRows)
    self.rowOffset = FS:Clamp(self.rowOffset, 0, maxOffset)

    local selectedFound = false
    if self.selected then
        for _, r in ipairs(list) do
            if r.itemID == self.selected.itemID then
                self.selected = r
                selectedFound = true
                break
            end
        end
    end

    if not selectedFound then self.selected = list[1] end

    for key, header in pairs(self.headerButtons) do
        local active = FS.DB.settings.sort == key
        header.label:SetText(
            header.baseText .. (active and (FS.DB.settings.sortDesc == false and " ▲" or " ▼") or "")
        )
        local c = active and C.gold or C.muted
        header.label:SetTextColor(c[1], c[2], c[3], 1)
    end

    for i, row in ipairs(self.rows) do
        if i > self.activeRows then
            row:Hide()
        else
            local r = list[self.rowOffset + i]
            row.data = r

            if not r then
                row.warningIcon:Hide()
                row:Hide()
            else
                row:Show()

                local base = i % 2 == 0 and C.row2 or C.row1
                local selected = self.selected and self.selected.itemID == r.itemID

                if selected then
                    row:SetBackdropColor(0.105, 0.086, 0.034, 0.98)
                    row.selectedBar:Show()
                else
                    row:SetBackdropColor(base[1], base[2], base[3], base[4])
                    row.selectedBar:Hide()
                end

                local name, link, icon = FS:ResolveItemData(r.itemID)
                if name and FS.IsRealItemName(name, r.itemID) then r.name = name end
                if link then r.link = link end
                if icon then r.icon = icon end

                if not r.name or not FS.IsRealItemName(r.name, r.itemID) then
                    FS:RequestItemData(r.itemID)
                    row.cells.name:SetText("|cff7d818a" .. L("LOADING_ITEM_FMT", r.itemID) .. "|r")
                else
                    row.cells.name:SetText(r.link or r.name)
                end

                row.icon:SetTexture(r.icon or 134400)
                row.warningIcon:SetShown(r.suspiciousMarket == true)

                if r.suspiciousMarket then
                    row.cells.name:SetTextColor(C.orange[1], C.orange[2], C.orange[3], 1)
                else
                    row.cells.name:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
                end

                row.cells.buy:SetText("|cffffd66b" .. FS:Money(r.buy, true) .. "|r")
                row.cells.sell:SetText("|cff8ec9ff" .. FS:Money(r.safeSell, true) .. "|r")
                row.cells.profit:SetText("|cff67e88a" .. FS:Money(math.max(0, r.profit or 0), true) .. "|r")
                row.cells.roi:SetText(string.format("%.0f%%", (r.roi or 0) * 100))
                row.cells.discount:SetText(string.format("%.0f%%", (r.discount or 0) * 100))

                local scoreCell = row.cells.score
                if not scoreCell._dsBaseFont then
                    local fnt, sz, flags = scoreCell:GetFont()
                    scoreCell._dsBaseFont = fnt
                    scoreCell._dsBaseSize = sz
                    scoreCell._dsBaseFlags = flags
                end

                if r.suspiciousMarket or r.scoreSuppressed then
                    if scoreCell._dsBaseFont then
                        pcall(
                            scoreCell.SetFont,
                            scoreCell,
                            scoreCell._dsBaseFont,
                            math.max(20, RoundPixel((scoreCell._dsBaseSize or 12) + 7)),
                            "OUTLINE"
                        )
                    end
                    scoreCell:SetText("|cffff2020!|r")
                else
                    if scoreCell._dsBaseFont then
                        pcall(
                            scoreCell.SetFont,
                            scoreCell,
                            scoreCell._dsBaseFont,
                            scoreCell._dsBaseSize or 12,
                            scoreCell._dsBaseFlags or "OUTLINE"
                        )
                    end
                    scoreCell:SetText(FS:ScoreText(r.score or 0, false))
                end
            end
        end
    end

    local first = #list > 0 and self.rowOffset + 1 or 0
    local last = math.min(#list, self.rowOffset + self.activeRows)
    self.range:SetText(L("RANGE_FMT", first, last, #list))

    self:UpdateScrollBar(list)
    if not skipPrefetch then
        self:QueueVisiblePrefetch(list)
    end

    self.tabDeals:SetText(L("DEALS") .. "  " .. tostring(#(FS.Scanner.results or {})))
    self.tabCandidates:SetText(L("CANDIDATES") .. "  " .. tostring(#(FS.Scanner.candidates or {})))
    self.tabWatch:SetText(L("WATCHLIST") .. "  " .. tostring(#(FS.Scanner.watchResults or {})))

    if self.selected then
        self.searchSelected:Enable()
        self.watch:Enable()
        self.ignore:Enable()
        self.watch:SetText(FS:IsWatched(self.selected.itemID) and L("UNWATCH") or L("WATCH"))
    else
        self.searchSelected:Disable()
        self.watch:Disable()
        self.ignore:Disable()
    end

    self:RefreshMetrics()
    self:RefreshDetail()
end

function UI:RefreshDetail()
    if not self.detailPanel or self.tab == "settings" then return end
    local r = self.selected

    if not r then
        self.detailIcon:SetTexture(134400)
        self.detailName:SetText(L("NO_ITEM_SELECTED"))
        self.detailMeta:SetText(L("RUN_SCAN_SELECT"))
        self.detailBuy.value:SetText("—")
        self.detailTarget.value:SetText("—")
        self.detailProfit.value:SetText("—")
        self.riskText:SetText("—")
        self.sourceText:SetText("—")
        self.undermineText:SetText("")
        self.outlierWarning:SetText("")
        self.outlierWarning:Hide()
        self:DrawPriceHistory()
        self:DrawUndermineHistory()
        self:DrawMarketDepth()
        return
    end

    local name, link, icon = FS:ResolveItemData(r.itemID)
    if name and FS.IsRealItemName(name, r.itemID) then r.name = name end
    if link then r.link = link end
    if icon then r.icon = icon end
    if not r.name or not FS.IsRealItemName(r.name, r.itemID) then FS:RequestItemData(r.itemID) end

    self.detailIcon:SetTexture(r.icon or 134400)
    self.detailName:SetText(
        (r.name and FS.IsRealItemName(r.name, r.itemID))
            and r.name
            or L("ITEM_FALLBACK_FMT", r.itemID)
    )
    if r.suspiciousMarket or r.scoreSuppressed then
        self.detailMeta:SetText(
            "|cffff2020!|r  " .. L(
                "DETAIL_META_SUSPICIOUS_FMT",
                (r.roi or 0) * 100,
                (r.discount or 0) * 100
            )
        )
    else
        local scoreTier = FS:GetScoreTier(r.score or 0)
        self.detailMeta:SetText(L(
            "DETAIL_META_FMT",
            r.score or 0,
            scoreTier.name,
            (r.roi or 0) * 100,
            (r.discount or 0) * 100
        ))
    end

    self.detailBuy.value:SetText(FS:Money(r.buy, true))
    self.detailTarget.value:SetText(FS:Money(r.safeSell, true))
    self.detailProfit.value:SetText(FS:Money(math.max(0, r.profit or 0), true))
    self.riskText:SetText(FS:LocalizeCommaList(r.risk or "low"))
    self.sourceText:SetText(
        L(
            "SOURCE_SCANS_FMT",
            FS:LocalizePhrase(tostring(r.source or "")),
            r.historyCount or 0
        )
    )

    local oeData
    if FS.Undermine and FS.Undermine.ApplyToResult then
        oeData = FS.Undermine:ApplyToResult(r)
    end

    if oeData then
        if r.oeRealm and r.oeRegion then
            self.undermineText:SetText(
                L("UNDERMINE_BOTH_FMT", FS:Money(r.oeRealm, true), FS:Money(r.oeRegion, true))
                    .. "\n" .. L("UNDERMINE_HISTORY_NOTE")
            )
        elseif r.oeRealm then
            self.undermineText:SetText(
                L("UNDERMINE_REALM_ONLY_FMT", FS:Money(r.oeRealm, true))
                    .. "\n" .. L("UNDERMINE_HISTORY_NOTE")
            )
        elseif r.oeRegion then
            self.undermineText:SetText(
                L("UNDERMINE_REGION_ONLY_FMT", FS:Money(r.oeRegion, true))
                    .. "\n" .. L("UNDERMINE_HISTORY_NOTE")
            )
        else
            self.undermineText:SetText(L("UNDERMINE_NO_ITEM_DATA"))
        end
    elseif FS.Undermine and FS.Undermine.IsAvailable and FS.Undermine:IsAvailable() then
        self.undermineText:SetText(FS.Undermine:GetItemStatusText(r.itemID, r.link))
    else
        local unavailable = FS.Undermine and FS.Undermine.GetUnavailableText
            and FS.Undermine:GetUnavailableText()
            or L("UNDERMINE_NOT_INSTALLED_SHORT")
        self.undermineText:SetText(unavailable)
    end

    if r.suspiciousMarket then
        self.outlierWarning:SetText(
            L("OUTLIER_WARNING_FMT", FS:LocalizeReasonList(r.suspiciousReasons))
        )
        self.outlierWarning:Show()
    else
        self.outlierWarning:SetText("")
        self.outlierWarning:Hide()
    end

    self:DrawPriceHistory()
    self:DrawUndermineHistory()
    self:DrawMarketDepth()
end

function UI:DrawUndermineHistory()
    local g = self.oeGraph
    if not g then return end

    HidePool(g.bars)
    HidePool(g.labels)
    HidePool(g.markers)
    HidePool(g.lines)

    local r = self.selected
    if not r then
        g.empty:SetText(L("NO_ITEM_SELECTED"))
        g.empty:Show()
        g.meta:SetText("")
        return
    end

    if not FS.Undermine or not FS.Undermine.IsAvailable or not FS.Undermine:IsAvailable() then
        local unavailable = FS.Undermine and FS.Undermine.GetUnavailableText
            and FS.Undermine:GetUnavailableText()
            or L("UNDERMINE_NOT_INSTALLED_SHORT")
        g.empty:SetText(unavailable)
        g.empty:Show()
        g.meta:SetText("")
        return
    end

    FS.Undermine:ApplyToResult(r)
    local samples = FS.Undermine:GetHistory(r.itemID)

    local useRealm = false
    for _, s in ipairs(samples) do
        if tonumber(s.realm) and tonumber(s.realm) > 0 then
            useRealm = true
            break
        end
    end

    local points = {}
    for _, s in ipairs(samples) do
        local value = useRealm and tonumber(s.realm) or tonumber(s.region)
        if value and value > 0 then
            points[#points + 1] = {
                t = tonumber(s.t) or time(),
                v = value,
            }
        end
    end

    if #points == 0 then
        g.empty:SetText(L("UNDERMINE_GRAPH_NO_DATA"))
        g.empty:Show()
        g.meta:SetText(L("UNDERMINE_GRAPH_COLLECTING"))
        return
    end

    g.empty:Hide()
    g.meta:SetText(useRealm and L("UNDERMINE_GRAPH_META_REALM") or L("UNDERMINE_GRAPH_META_REGION"))

    local minV, maxV
    for _, p in ipairs(points) do
        minV = minV and math.min(minV, p.v) or p.v
        maxV = maxV and math.max(maxV, p.v) or p.v
    end

    if not minV or not maxV then return end

    -- Add breathing room so a flat median still renders as a visible center line.
    if maxV <= minV then
        local pad = math.max(1, minV * 0.02)
        minV = math.max(0, minV - pad)
        maxV = maxV + pad
    else
        local pad = (maxV - minV) * 0.12
        minV = math.max(0, minV - pad)
        maxV = maxV + pad
    end

    local now = time()
    local startT = now - (4 * 24 * 60 * 60)
    local pw = math.max(20, g.plot:GetWidth())
    local ph = math.max(20, g.plot:GetHeight())

    local function xy(point)
        local xNorm = FS:Clamp((point.t - startT) / math.max(1, now - startT), 0, 1)
        local yNorm = FS:Clamp((point.v - minV) / math.max(1, maxV - minV), 0, 1)
        return math.floor(xNorm * pw), math.floor(yNorm * ph)
    end

    -- If CreateLine is available, render a proper sparkline.
    if g.plot.CreateLine and #points >= 2 then
        for i = 2, #points do
            local x1, y1 = xy(points[i - 1])
            local x2, y2 = xy(points[i])
            local line = PoolLine(g, i - 1)
            if line then
                line:ClearAllPoints()
                line:SetStartPoint("BOTTOMLEFT", g.plot, x1, y1)
                line:SetEndPoint("BOTTOMLEFT", g.plot, x2, y2)
                line:SetThickness(2)
                line:SetColorTexture(C.blue[1], C.blue[2], C.blue[3], 0.90)
            end
        end
    end

    -- Always show point markers; these also act as a fallback if CreateLine is
    -- unavailable for any reason.
    for i, point in ipairs(points) do
        local x, y = xy(point)
        local dot = PoolTexture(g, i)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", g.plot, "BOTTOMLEFT", x, y)
        dot:SetSize(i == #points and 6 or 4, i == #points and 6 or 4)
        dot:SetColorTexture(C.blue[1], C.blue[2], C.blue[3], i == #points and 1.0 or 0.72)
    end

    local left = PoolLabel(g, 1)
    left:ClearAllPoints()
    left:SetPoint("BOTTOMLEFT", g.plot, "BOTTOMLEFT", 0, -1)
    left:SetText("-4d")

    local right = PoolLabel(g, 2)
    right:ClearAllPoints()
    right:SetPoint("BOTTOMRIGHT", g.plot, "BOTTOMRIGHT", 0, -1)
    right:SetText("Now")

    local latest = points[#points]
    local latestLabel = PoolLabel(g, 3)
    latestLabel:ClearAllPoints()
    latestLabel:SetPoint("TOPRIGHT", g.plot, "TOPRIGHT", 0, 0)
    latestLabel:SetText(FS:Money(latest.v, true))
end

function UI:DrawPriceHistory()
    local g = self.priceGraph
    if not g then return end

    HidePool(g.bars)
    HidePool(g.labels)
    HidePool(g.markers)
    g.historySamples = nil

    local r = self.selected
    if not r then
        g.empty:SetText(L("NO_ITEM_SELECTED"))
        g.empty:Show()
        g.meta:SetText("")
        return
    end

    local market = FS:GetMarketState()
    local h = market and market.history[tostring(r.itemID)]
    local samples = h and h.samples or {}
    local values = {}
    local plotted = {}

    for _, s in ipairs(samples) do
        if type(s) == "table" and tonumber(s.ref) then
            values[#values + 1] = s.ref
            plotted[#plotted + 1] = s
        end
    end

    local capacity = math.max(1, math.floor(math.max(20, g.plot:GetWidth()) / 9))
    while #values > capacity do table.remove(values, 1); table.remove(plotted, 1) end
    g.historySamples = plotted
    if #values == 0 then
        g.empty:SetText(L("HISTORY_STARTS"))
        g.empty:Show()
        g.meta:SetText(L("CURRENT_SCAN_GAPS"))
        return
    end

    g.empty:Hide()

    local minV, maxV
    for _, v in ipairs(values) do
        minV = minV and math.min(minV, v) or v
        maxV = maxV and math.max(maxV, v) or v
    end

    minV = math.min(minV, r.buy or minV)
    maxV = math.max(maxV, r.safeSell or maxV)
    if maxV <= minV then maxV = minV + 1 end

    local pw = math.max(20, g.plot:GetWidth())
    local ph = math.max(20, g.plot:GetHeight())
    local n = #values
    local gap = 5
    local bw = math.max(5, math.floor((pw - gap * math.max(0, n - 1)) / math.max(1, n)))
    bw = math.min(bw, 24)

    local totalW = bw * n + gap * math.max(0, n - 1)
    local startX = math.max(0, math.floor((pw - totalW) / 2))
    g.historyGeometry = {startX = startX, step = bw + gap, width = bw}

    for i, v in ipairs(values) do
        local norm = (v - minV) / (maxV - minV)
        local bh = math.max(2, math.floor(norm * (ph - 5)))
        local bar = PoolTexture(g, i)
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", g.plot, "BOTTOMLEFT", startX + (i - 1) * (bw + gap), 0)
        bar:SetSize(bw, bh)
        bar:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], i == n and 0.95 or 0.48)
    end

    local function marker(index, price, color)
        if not price or price <= 0 then return end
        local norm = (price - minV) / (maxV - minV)
        local y = FS:Clamp(math.floor(norm * ph), 0, ph)

        local m = PoolMarker(g, index)
        m:ClearAllPoints()
        m:SetPoint("BOTTOMLEFT", g.plot, "BOTTOMLEFT", 0, y)
        m:SetPoint("BOTTOMRIGHT", g.plot, "BOTTOMRIGHT", 0, y)
        m:SetHeight(1)
        m:SetColorTexture(color[1], color[2], color[3], 0.85)
    end

    marker(1, r.buy, C.green)
    marker(2, r.safeSell, C.blue)

    g.meta:SetText(#values < 3 and "Collecting history" or L("SCANS_FMT", #values))
end

function UI:DrawMarketDepth()
    local g = self.depthGraph
    if not g then return end

    HidePool(g.bars)
    HidePool(g.labels)
    HidePool(g.markers)

    local r = self.selected
    local ladder = r and r.ladder

    if not ladder or #ladder == 0 then
        g.empty:SetText(L("NO_MARKET_LADDER"))
        g.empty:Show()
        g.meta:SetText("")
        return
    end

    g.empty:Hide()

    local maxPrice = 0
    for _, l in ipairs(ladder) do maxPrice = math.max(maxPrice, l.price or 0) end
    if maxPrice <= 0 then maxPrice = 1 end

    local pw = math.max(20, g.plot:GetWidth())
    local ph = math.max(20, g.plot:GetHeight())
    local n = #ladder
    local gap = 7
    local bw = math.max(12, math.floor((pw - gap * (n - 1)) / n))
    local totalW = bw * n + gap * (n - 1)
    local startX = math.max(0, math.floor((pw - totalW) / 2))

    for i, l in ipairs(ladder) do
        local bh = math.max(3, math.floor(((l.price or 0) / maxPrice) * (ph - 22)))
        local bar = PoolTexture(g, i)
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", g.plot, "BOTTOMLEFT", startX + (i - 1) * (bw + gap), 14)
        bar:SetSize(bw, bh)

        local color = i == 1 and C.green or C.blue
        bar:SetColorTexture(color[1], color[2], color[3], i == 1 and 0.95 or 0.60)

        local label = PoolLabel(g, i)
        label:ClearAllPoints()
        label:SetPoint("TOP", bar, "BOTTOM", 0, -2)
        label:SetText(tostring(l.qty or 0))
    end

    g.meta:SetText(L("GRAPH_LADDER_META"))
end

function UI:LoadSettings()
    if not self.settingBoxes or self.loadingSettings then return end
    self.loadingSettings = true

    for key, box in pairs(self.settingBoxes) do
        box:SetText(tostring(FS.DB.settings[key] or ""))
    end

    self.alertsCheck:SetChecked(FS.DB.settings.alerts == true)
    self.tooltipCheck:SetChecked(FS.DB.settings.tooltip == true)
    self.disclaimerCheck:SetChecked(FS.DB.settings.disclaimerAcknowledged == true)

    if self.undermineStatus and FS.Undermine and FS.Undermine.GetStatus then
        local connected, label = FS.Undermine:GetStatus()
        if connected then
            self.undermineStatus:SetText(
                L("UNDERMINE_CONNECTED_FMT", label)
                    .. "\n" .. L("UNDERMINE_EXPLAIN")
                    .. "\n" .. L("UNDERMINE_NO_SALES")
            )
            self.undermineStatus:SetTextColor(C.green[1], C.green[2], C.green[3], 1)
        else
            self.undermineStatus:SetText(
                tostring(label or L("UNDERMINE_MISSING"))
                    .. "\n" .. L("UNDERMINE_NO_SALES")
            )
            self.undermineStatus:SetTextColor(C.orange[1], C.orange[2], C.orange[3], 1)
        end
    end

    self.loadingSettings = false
end

function UI:ApplySettings()
    for key, box in pairs(self.settingBoxes) do
        local n = tonumber(box:GetText())
        if n ~= nil then FS.DB.settings[key] = n end
    end

    FS.DB.settings.alerts = self.alertsCheck:GetChecked() == true
    FS.DB.settings.tooltip = self.tooltipCheck:GetChecked() == true
    FS.DB.settings.disclaimerAcknowledged = self.disclaimerCheck:GetChecked() == true

    FS.Scanner:RebuildVisibleLists()
    self:InvalidateVisibleList()
    self:Refresh()
    FS:Print(L("SETTINGS_APPLIED"))
end

function UI:UpdateStatus()
    if not self.status then return end

    self.status:SetText(FS.Scanner.status or L("READY"))
    local p = FS:Clamp(tonumber(FS.Scanner.progress) or 0, 0, 1)
    self.progressBar:SetValue(p)

    local hasPrevious = FS.Scanner:HasPreviousScan()
    local prevTime, prevAuctions = FS.Scanner:GetPreviousScanInfo()

    if hasPrevious then
        self.previousScanButton:Enable()

        if prevTime > 0 then
            local age = math.max(0, time() - prevTime)
            if age < 60 * 60 then
                self.previousScanButton:SetText(L("PREVIOUS_AGE_MIN_FMT", math.floor(age / 60)))
            elseif age < 24 * 60 * 60 then
                self.previousScanButton:SetText(L("PREVIOUS_AGE_HOUR_FMT", math.floor(age / 3600)))
            else
                self.previousScanButton:SetText(L("PREVIOUS_AGE_DAY_FMT", math.floor(age / 86400)))
            end
        else
            self.previousScanButton:SetText(L("PREVIOUS_SCAN"))
        end
    else
        self.previousScanButton:Disable()
        self.previousScanButton:SetText(L("NO_PREVIOUS_BUTTON"))
    end

    local cooldown = FS:GetKnownCooldown()

    if FS.Scanner.scanRunning then
        self.progressBar:SetStatusBarColor(C.gold[1], C.gold[2], C.gold[3], 0.95)
        self.scanButton:Disable()

        if FS.Scanner.scanPhase == "waiting" then
            self.scanButton:SetText(L("REQUESTING"))
        else
            self.scanButton:SetText(L("SCANNING"))
        end
    else
        if cooldown > 0 then
            self.scanButton:Disable()
            self.scanButton:SetText(L(
                "FULL_COOLDOWN_FMT",
                math.floor(cooldown / 60),
                cooldown % 60
            ))
        else
            self.scanButton:Enable()
            self.scanButton:SetText(L("FULL_SCAN"))
        end

        if p >= 1 then
            self.progressBar:SetStatusBarColor(C.green[1], C.green[2], C.green[3], 0.90)
        else
            self.progressBar:SetStatusBarColor(C.faint[1], C.faint[2], C.faint[3], 0.45)
        end
    end

    if hasPrevious and prevTime > 0 then
        local age = math.max(0, time() - prevTime)
        local ageText
        if age < 3600 then
            ageText = L("AGE_MIN_FMT", math.floor(age / 60))
        elseif age < 86400 then
            ageText = L("AGE_HOUR_FMT", math.floor(age / 3600))
        else
            ageText = L("AGE_DAY_FMT", math.floor(age / 86400))
        end

        if cooldown > 0 then
            self.provider:SetText(L(
                "PROVIDER_PREVIOUS_COOLDOWN_FMT",
                ageText,
                prevAuctions or 0,
                math.floor(cooldown / 60),
                cooldown % 60
            ))
        else
            self.provider:SetText(L(
                "PROVIDER_PREVIOUS_READY_FMT",
                ageText,
                prevAuctions or 0
            ))
        end
    else
        self.provider:SetText(
            cooldown > 0
                and L(
                    "PROVIDER_NO_PREVIOUS_COOLDOWN_FMT",
                    math.floor(cooldown / 60),
                    cooldown % 60
                )
                or L("PROVIDER_NO_PREVIOUS_READY")
        )
    end

    self.provider:SetText((self.provider:GetText() or "") .. " • " .. FS:GetMarketLabel())
end

function UI:GetItemLinkForRecord(r)
    if not r then return nil end
    if type(r.link) == "string" and r.link ~= "" then
        return r.link
    end

    local _, link
    if C_Item and C_Item.GetItemInfo then
        local ok, name, itemLink = pcall(C_Item.GetItemInfo, r.itemID)
        if ok then
            if name and FS.IsRealItemName(name, r.itemID) then r.name = name end
            link = itemLink
        end
    end

    if not link and C_Item and C_Item.GetItemLinkByID then
        local ok, itemLink = pcall(C_Item.GetItemLinkByID, r.itemID)
        if ok then link = itemLink end
    end

    if link then
        r.link = link
        FS:CacheItemIdentity(r.itemID, r.name, link, r.icon)
        return link
    end

    FS:RequestItemData(r.itemID)
    return nil
end

function UI:LinkItemToChat(r)
    if not r then return false end

    local link = self:GetItemLinkForRecord(r)
    if not link then
        FS:Print(L("CHAT_LINK_UNAVAILABLE"))
        return false
    end

    -- Current Blizzard chat code exposes ChatFrameUtil.LinkItem(), which opens
    -- a chat edit box automatically when none is active. This is more reliable
    -- than ChatEdit_InsertLink() by itself.
    if ChatFrameUtil and ChatFrameUtil.LinkItem then
        local ok = pcall(ChatFrameUtil.LinkItem, r.itemID, link)
        if ok then return true end
    end

    if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and ChatEdit_InsertLink then
        local ok, inserted = pcall(ChatEdit_InsertLink, link)
        if ok and inserted ~= false then return true end
    end

    if ChatFrame_OpenChat then
        local ok = pcall(ChatFrame_OpenChat, link)
        if ok then return true end
    end

    FS:Print(L("CHAT_LINK_UNAVAILABLE"))
    return false
end

function UI:OpenItemInAH(r)
    if not r then return false end
    if not FS.state.ahOpen or not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
        FS:Print(L("OPEN_AH_FIRST"))
        return false
    end

    local name = r.name
    if not name or not FS.IsRealItemName(name, r.itemID) then
        local resolved = FS:ResolveItemData(r.itemID)
        if resolved and FS.IsRealItemName(resolved, r.itemID) then
            name = resolved
            r.name = resolved
        end
    end

    if not name or not FS.IsRealItemName(name, r.itemID) then
        FS:RequestItemData(r.itemID)
        FS:Print(L("AH_SEARCH_NO_NAME"))
        return false
    end

    -- Drive Blizzard's own Auction House UI instead of only firing the backend
    -- C_AuctionHouse.SendSearchQuery call. The latter updates search data but does
    -- not by itself navigate the visible Auction House interface.
    local ok, err = pcall(function()
        if AuctionHouseFrameDisplayMode
            and AuctionHouseFrameDisplayMode.Buy
            and AuctionHouseFrame.SetDisplayMode then
            AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
        end

        if AuctionHouseFrame.GetCategoriesList then
            local categories = AuctionHouseFrame:GetCategoriesList()
            if categories and categories.SetSelectedCategory then
                categories:SetSelectedCategory(nil)
            end
        end

        if AuctionHouseFrame.SetSearchText then
            AuctionHouseFrame:SetSearchText(name)
        elseif AuctionHouseFrame.SearchBar and AuctionHouseFrame.SearchBar.SetSearchText then
            AuctionHouseFrame.SearchBar:SetSearchText(name)
        end

        if AuctionHouseFrame.SearchBar and AuctionHouseFrame.SearchBar.StartSearch then
            AuctionHouseFrame.SearchBar:StartSearch()
        elseif AuctionHouseFrame.SendBrowseQuery then
            AuctionHouseFrame:SendBrowseQuery(name, 0, 0, {})
        else
            error("Auction House search UI unavailable")
        end
    end)

    if not ok then
        FS:Print(L("AH_SEARCH_FAILED_FMT", tostring(err or L("UNKNOWN_ERROR"))))
        return false
    end

    -- Keep DealScryer open. The user can inspect the Blizzard Auction House
    -- results and DealScryer side-by-side or move/resize DealScryer as desired.
    FS:Print(L("AH_SEARCH_STARTED_FMT", name))
    return true
end

local REALM_TRANSLITERATION = {
    ["ä"]="a", ["ö"]="o", ["ü"]="u", ["ß"]="ss",
    ["á"]="a", ["à"]="a", ["â"]="a", ["ã"]="a", ["å"]="a",
    ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e",
    ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i",
    ["ó"]="o", ["ò"]="o", ["ô"]="o", ["õ"]="o",
    ["ú"]="u", ["ù"]="u", ["û"]="u",
    ["ç"]="c", ["ñ"]="n",
    ["ý"]="y", ["ÿ"]="y",
}

local function DealScryerRealmSlug(name)
    name = tostring(name or ""):lower()

    -- Common Latin characters used by Retail realm names. Undermine Exchange
    -- uses Blizzard-style lowercase realm slugs such as "area-52" and
    -- "zuljin". For non-Latin localized realm names, we still display the
    -- detected server explicitly in the copy window so the user can verify it.
    for from, to in pairs(REALM_TRANSLITERATION) do
        name = name:gsub(from, to)
    end

    name = name:gsub("['’`]", "")
    name = name:gsub("%.", "")
    name = name:gsub("%(", "")
    name = name:gsub("%)", "")
    name = name:gsub("&", "and")
    name = name:gsub("%s+", "-")
    name = name:gsub("%-+", "-")
    name = name:gsub("^%-+", "")
    name = name:gsub("%-+$", "")

    return name ~= "" and name or "unknown"
end

function UI:GetExternalPriceHistoryURL(r)
    if not r then return nil end

    local region = FS:GetRegionInfo()
    if not region or not region.undermine then
        return nil
    end

    local realmName = GetRealmName and GetRealmName() or "unknown"
    local realmSlug = DealScryerRealmSlug(realmName)
    local itemID = tonumber(r.itemID)
    if not itemID then return nil end

    return string.format(
        "https://undermine.exchange/#%s-%s/%d",
        tostring(region.slug),
        tostring(realmSlug),
        itemID
    )
end

function UI:GetExternalPriceHistoryMenuText(r)
    local url = self:GetExternalPriceHistoryURL(r)
    if url then
        return L("CONTEXT_PRICE_HISTORY_FMT", url)
    end

    return L("CONTEXT_PRICE_HISTORY") .. " — " .. FS:GetMarketLabel()
end

function UI:ShowExternalPriceHistory(r)
    if not r then return end

    local name = r.name
    if not name or not FS.IsRealItemName(name, r.itemID) then
        name = select(1, FS:ResolveItemData(r.itemID)) or L("ITEM_FALLBACK_FMT", r.itemID)
    end

    local realm = GetRealmName and GetRealmName() or "Unknown Realm"
    local region = FS:GetRegionInfo()

    if not region.undermine then
        self:ShowCopyableText(
            "External price history",
            "DealScryer's in-game scanner works on this region, but Undermine Exchange "
                .. "currently publishes Retail history for US, EU, TW and KR only.\n\n"
                .. "Detected region: " .. tostring(region.label) .. "\n"
                .. "Server: " .. tostring(realm) .. "\n"
                .. "Item: " .. tostring(name) .. "\n"
                .. "Item ID: " .. tostring(r.itemID)
        )
        return
    end

    local url = self:GetExternalPriceHistoryURL(r)
    if not url then return end

    self:ShowCopyableText(
        L("PRICE_HISTORY_TITLE"),
        L(
            "PRICE_HISTORY_BODY_FMT",
            url,
            name,
            r.itemID,
            tostring(region.label) .. " (" .. tostring(region.slug) .. ")",
            realm
        )
    )
end

function UI:ShowItemContextMenu(owner, r)
    if not r then return end

    -- Blizzard_Menu is normally already loaded on Retail, but explicitly try to
    -- load it before giving up. This keeps DealScryer independent of other addons.
    if (not MenuUtil or not MenuUtil.CreateContextMenu)
        and C_AddOns
        and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Menu")
    end

    if not MenuUtil or not MenuUtil.CreateContextMenu then
        -- Useful fallback rather than silently toggling the Watchlist.
        self:ShowExternalPriceHistory(r)
        return
    end

    local ok, err = pcall(function()
        MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            local name = r.name or L("ITEM_FALLBACK_FMT", r.itemID)
            rootDescription:CreateTitle(name)

            rootDescription:CreateButton(L("CONTEXT_OPEN_LIVE"), function()
                UI:OpenItemInAH(r)
            end)

            rootDescription:CreateButton(L("CONTEXT_LINK_CHAT"), function()
                UI:LinkItemToChat(r)
            end)

            rootDescription:CreateButton(UI:GetExternalPriceHistoryMenuText(r), function()
                UI:ShowExternalPriceHistory(r)
            end)

            rootDescription:CreateDivider()

            rootDescription:CreateButton(
                FS:IsWatched(r.itemID) and L("CONTEXT_REMOVE_WATCH") or L("CONTEXT_ADD_WATCH"),
                function()
                    FS:ToggleWatch(r.itemID)
                    UI:Refresh()
                end
            )

            if FS:IsWatched(r.itemID) then
                local sub = rootDescription:CreateButton(L("CONTEXT_WATCH_THRESHOLD"))
                for _, pct in ipairs({50, 60, 70, 80, 90}) do
                    sub:CreateButton(L("CONTEXT_THRESHOLD_FMT", pct), function()
                        local entry = FS.DB.watchlist[tostring(r.itemID)]
                        if entry then entry.thresholdPct = pct end
                    end)
                end
            end

            rootDescription:CreateButton(
                FS:IsBlacklisted(r.itemID) and L("CONTEXT_REMOVE_IGNORE") or L("CONTEXT_IGNORE"),
                function()
                    FS:ToggleBlacklist(r.itemID)
                    UI.selected = nil
                    UI:Refresh()
                end
            )
        end)
    end)

    if not ok then
        FS:Print(L("AH_SEARCH_FAILED_FMT", tostring(err or L("UNKNOWN_ERROR"))))
    end
end

function UI:ShowRowTooltip(row)
    local r = row.data
    if not r then return end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")

    if r.link then
        GameTooltip:SetHyperlink(r.link)
    else
        GameTooltip:SetText(r.name or L("ITEM_FALLBACK_FMT", r.itemID))
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L("TT_BUY"), FS:Money(r.buy), 1,1,1, 1,0.82,0)
    GameTooltip:AddDoubleLine(L("TT_TARGET"), FS:Money(r.safeSell), 1,1,1, 0.55,0.82,1)
    GameTooltip:AddDoubleLine(L("TT_PROFIT_UNIT"), FS:Money(r.profit), 1,1,1, 0.35,1,0.5)
    GameTooltip:AddDoubleLine(L("TT_ROI"), string.format("%.1f%%", (r.roi or 0) * 100), 1,1,1, 1,1,1)
    GameTooltip:AddDoubleLine(L("TT_DISCOUNT"), string.format("%.1f%%", (r.discount or 0) * 100), 1,1,1, 1,1,1)

    if FS.Undermine and FS.Undermine.ApplyToResult then
        FS.Undermine:ApplyToResult(r)
    end
    if r.oeRealm then
        GameTooltip:AddDoubleLine(L("TT_UNDERMINE_REALM"), FS:Money(r.oeRealm, true), 1,1,1, 0.40,0.72,1.0)
    end
    if r.oeRegion then
        GameTooltip:AddDoubleLine(L("TT_UNDERMINE_REGION"), FS:Money(r.oeRegion, true), 1,1,1, 0.40,0.72,1.0)
    end
    if r.oeRealm or r.oeRegion then
        GameTooltip:AddLine(L("TT_UNDERMINE_NOTE"), 0.55,0.60,0.70, true)
    end

    if r.suspiciousMarket or r.scoreSuppressed then
        GameTooltip:AddDoubleLine(
            L("TT_SCORE"),
            "!",
            1,1,1,
            1,0.12,0.12
        )
    else
        local tier = FS:GetScoreTier(r.score or 0)
        GameTooltip:AddDoubleLine(
            L("TT_SCORE"),
            tostring(r.score or 0) .. " • " .. tier.name,
            1,1,1,
            tier.r, tier.g, tier.b
        )
    end
    if (r.itemLevel or 0) > 0 then
        GameTooltip:AddDoubleLine(L("TT_ITEM_LEVEL"), tostring(r.itemLevel), 1,1,1, 1,1,1)
    end
    if r.className then
        GameTooltip:AddDoubleLine(L("TT_CATEGORY"), tostring(r.className), 1,1,1, 1,1,1)
    end
    GameTooltip:AddDoubleLine(L("TT_QUANTITY"), tostring(r.totalQty or 0), 1,1,1, 1,1,1)
    GameTooltip:AddDoubleLine(L("TT_HISTORY_SCANS"), tostring(r.historyCount or 0), 1,1,1, 1,1,1)
    GameTooltip:AddDoubleLine(L("TT_RISK"), FS:LocalizeCommaList(r.risk or "low"), 1,1,1, 1,0.60,0.30)

    if r.suspiciousMarket then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("TT_WARNING"), 1, 0.55, 0.20, true)
        GameTooltip:AddLine(
            FS:LocalizeReasonList(r.suspiciousReasons),
            1, 0.72, 0.25, true
        )
    end

    GameTooltip:AddLine(L("TT_VERIFY"), 0.65, 0.67, 0.72, true)
    GameTooltip:Show()
end

function UI:PositionAHLauncher()
    local button = self.ahButton
    if not button then return end
    button:SetScale(UIParent:GetEffectiveScale() / AuctionHouseFrame:GetEffectiveScale())
    button:ClearAllPoints()
    local position = FS.DB and FS.DB.ahLauncher
    if position and tonumber(position.x) and tonumber(position.y) then
        button:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
    else
        -- Outside the AH title bar, tabs and search controls. Users can move
        -- this if another addon extends the Auction House into this space.
        button:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "TOPLEFT", 8, 8)
    end
end

function UI:OnAuctionHouseShow()
    if not AuctionHouseFrame then return end

    if not self.ahButton then
        local b = CreateFrame("Button", "DealScryerAuctionHouseButton", AuctionHouseFrame, "BackdropTemplate")
        b:SetSize(29, 29)
        b:SetMovable(true)
        b:SetClampedToScreen(true)
        b:RegisterForDrag("LeftButton")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnDragStart", function(self)
            if IsShiftKeyDown() then self:StartMoving() end
        end)
        b:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local x, y = self:GetCenter()
            if x and y then
                FS.DB.ahLauncher = { x = x - UIParent:GetWidth() / 2, y = y - UIParent:GetHeight() / 2 }
                UI:PositionAHLauncher()
            end
        end)
        b:SetFrameLevel((AuctionHouseFrame:GetFrameLevel() or 1) + 30)
        Backdrop(b, C.panel2, C.border)

        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetSize(19, 19)
        icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetPoint("CENTER")

        local highlight = b:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.14)

        b:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                FS.DB.ahLauncher = nil
                UI:PositionAHLauncher()
                return
            end
            if IsShiftKeyDown() then return end
            if UI.frame and UI.frame:IsShown() then
                UI.frame:Hide()
            else
                UI:Show()
            end
        end)

        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("DealScryer")
            GameTooltip:AddLine(L("AH_BUTTON_TOOLTIP"), 0.75, 0.78, 0.83, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)

        self.ahButton = b
    end

    self:PositionAHLauncher()

    self.ahButton:Show()
end

function UI:BuildExportText()
    local list = FS.Scanner:GetVisibleList(
        self.tab == "settings" and "results" or self.tab,
        self.searchText
    )

    local lines = {
        L("EXPORT_HEADERS")
    }

    for i = 1, math.min(#list, 250) do
        local r = list[i]
        lines[#lines + 1] = table.concat({
            tostring(r.name or ""),
            tostring(r.itemID),
            tostring(math.floor(r.buy or 0)),
            tostring(math.floor(r.safeSell or 0)),
            tostring(math.floor(r.profit or 0)),
            string.format("%.2f", (r.roi or 0) * 100),
            string.format("%.2f", (r.discount or 0) * 100),
            (r.suspiciousMarket or r.scoreSuppressed) and "!" or tostring(r.score or 0),
            tostring(r.historyCount or 0),
            FS:LocalizeCommaList(tostring(r.risk or "")):gsub("\t", " "),
            FS:LocalizePhrase(tostring(r.source or "")),
        }, "\t")
    end

    return table.concat(lines, "\n")
end

function UI:ShowCopyableText(titleText, bodyText)
    self:Create()

    if not self.copyFrame then
        local frame = CreateFrame("Frame", "DealScryerCopyFrame", UIParent, "BackdropTemplate")
        frame:SetSize(760, 440)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetClampedToScreen(true)
        Backdrop(frame, C.bg, C.border)

        local title = Text(frame, "", "GameFontNormalLarge", C.text)
        title:SetPoint("TOPLEFT", 17, -16)

        local hint = Text(frame, L("COPY_HINT"), "GameFontHighlightSmall", C.muted)
        hint:SetPoint("TOPLEFT", 17, -42)

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -3, -3)

        local box = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
        box:SetPoint("TOPLEFT", 17, -68)
        box:SetPoint("BOTTOMRIGHT", -17, 17)
        box:SetMultiLine(true)
        box:SetAutoFocus(true)
        box:SetFontObject("ChatFontNormal")
        do
            local font, size = box:GetFont()
            if font and size then
                pcall(box.SetFont, box, font, math.max(13, RoundPixel(size + 2)), "OUTLINE")
            end
        end
        box:SetTextInsets(8, 8, 8, 8)
        Backdrop(box, C.panel, C.border2)
        box:SetScript("OnEscapePressed", function() frame:Hide() end)

        self.copyFrame = frame
        self.copyTitle = title
        self.copyBox = box
    end

    self.copyTitle:SetText(titleText or "DealScryer")
    self.copyBox:SetText(bodyText or "")
    self.copyBox:HighlightText()
    self.copyBox:SetFocus()
    self.copyFrame:Show()
end

function UI:ShowExport()
    self:ShowCopyableText(L("EXPORT_TITLE"), self:BuildExportText())
end
