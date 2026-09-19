-- User-facing analysis tools. No purchases, sales or postings are automated.
local FS = _G.DealScryer
local UI, S = FS.UI, FS.Scanner
local function Label(parent, value, x, y, width)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", x, y)
    t:SetWidth(width or 200)
    t:SetJustifyH("LEFT")
    t:SetWordWrap(true)
    t:SetText(value)
    return t
end
local function Button(parent, label, x, y, width, callback)
    local b = UI.MakeButton(parent, label, width or 105)
    b:SetHeight(26)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", callback)
    return b
end
local function Box(parent, x, y, width, value)
    local b = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    b:SetSize(width or 130, 25)
    b:SetPoint("TOPLEFT", x, y)
    b:SetFontObject("GameFontHighlight")
    b:SetAutoFocus(false)
    b:SetMaxLetters(80)
    b:SetText(tostring(value or ""))
    b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    b:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return b
end
local function Window(name, title, w, h)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    f:SetBackdropColor(0.025, 0.028, 0.035, 1)
    f:SetBackdropBorderColor(0.65, 0.49, 0.13, 1)
    Label(f, title, 18, -16, w-60):SetTextColor(1, 0.82, 0.3)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    UISpecialFrames = UISpecialFrames or {}
    table.insert(UISpecialFrames, name)
    return f
end
local function Copy(t)
    local out = {}
    for k,v in pairs(t or {}) do if type(v) ~= "table" then out[k] = v end end
    return out
end
local function RefreshFilters()
    UI.rowOffset = 0
    UI:InvalidateVisibleList()
    UI:LoadSearchOptions()
    UI:RefreshRows()
    UI:UpdateSearchOptionsBadge()
end
function FS:GetDataAge()
    local stamp = tonumber(S.currentSnapshotAt) or 0
    if stamp <= 0 then return "No scan recorded" end
    local mins = math.floor(math.max(0, time()-stamp)/60)
    return string.format("Scan: %dm ago%s", mins, mins >= 15 and " (older snapshot)" or "")
end
function FS:ExplainDeal(r)
    if not r then return "Select an item to inspect its evidence." end
    local lines = {r.name or tostring(r.itemID), self:GetDataAge(), ""}
    if r.suspiciousMarket then
        lines[#lines+1] = "! Suspicious market - unscored"
        lines[#lines+1] = self:LocalizeReasonList(r.suspiciousReasons)
        lines[#lines+1] = "The target and profit are unreliable estimates."
    else
        lines[#lines+1] = "Opportunity score: " .. tostring(r.score or 0) .. "/100 (not a sale probability)"
    end
    lines[#lines+1] = string.format("Discount to target: %.1f%%; gap to next price: %.1f%%", (r.discount or 0)*100, (r.gapRatio or 0)*100)
    lines[#lines+1] = "Buy: " .. self:Money(r.buy) .. " | Target: " .. self:Money(r.safeSell)
    lines[#lines+1] = "Estimated net/unit after 5% AH cut: " .. self:Money(r.profit) .. " (before lost deposits)"
    lines[#lines+1] = "Local historical observations: " .. tostring(r.historyCount or 0)
    lines[#lines+1] = "Distinct current price levels: " .. tostring(r.distinctPrices or 0)
    lines[#lines+1] = "Target source: " .. self:LocalizePhrase(tostring(r.source or "unknown"))
    local data = self.Undermine:GetItemData(r.itemID, r.link)
    if data then
        lines[#lines+1] = "Oribos realm median: " .. (data.realm and self:Money(data.realm) or "not provided")
        lines[#lines+1] = "Oribos region median: " .. (data.region and self:Money(data.region) or "not provided")
        lines[#lines+1] = "Provider version: " .. tostring(self.Undermine:GetAddonVersion() or "unknown") .. "; observation time is not source freshness."
    else
        local available, status = self.Undermine:GetStatus()
        lines[#lines+1] = available and self.Undermine:GetItemStatusText(r.itemID, r.link) or status
        if not available then
            lines[#lines+1] = "Check the WoW addon list: enable Oribos or install a release compatible with your Retail client. DealScryer local scans remain usable."
        end
    end
    lines[#lines+1] = "Risk: " .. self:LocalizeCommaList(r.risk or "unknown")
    lines[#lines+1] = "Listing medians are not completed sales. Verify availability in the AH."
    return table.concat(lines, "\n")
end
function UI:ShowExplanation()
    self:ShowCopyableText("Why this deal?", FS:ExplainDeal(self.selected))
end

local builtins = {
    {name="Small Budget", values={maxPriceGold=1000, riskMode="hide"}},
    {name="Materials", values={classID=7, riskMode="hide"}},
    {name="High Margin", values={minROIPct=50, riskMode="hide"}},
}
function FS:ApplyProfile(values)
    self.DB.searchOptions = Copy(self.DEFAULTS.searchOptions)
    for k,v in pairs(values) do self.DB.searchOptions[k] = v end
end
function UI:ShowProfiles()
    if self.searchOptionsPanel then self.searchOptionsPanel:Hide() end
    if not self.profileWindow then
        local f = Window("DealScryerProfiles", "Search profiles", 470, 365)
        self.profileWindow = f
        Label(f, "Presets replace search filters; deal qualification settings still apply.", 18, -48, 430)
        for i,p in ipairs(builtins) do
            Button(f, p.name, 18+(i-1)*145, -92, 138, function()
                FS:ApplyProfile(p.values); RefreshFilters(); UI:UpdateProfileSummary()
            end)
        end
        Label(f, "Save current filters under a name (same name replaces it):", 18, -137, 430)
        f.name = Box(f, 23, -163, 265)
        Button(f, "Save", 308, -162, 138, function()
            UI:ApplySearchOptions()
            local name = f.name:GetText():match("^%s*(.-)%s*$")
            if name == "" then f.summary:SetText("Enter a profile name."); return end
            FS.DB.profiles[name] = Copy(FS.DB.searchOptions)
            UI:UpdateProfileSummary()
        end)
        Button(f, "Load saved", 18, -210, 138, function(button)
            if not MenuUtil then return end
            MenuUtil.CreateContextMenu(button, function(_, menu)
                local names = {}; for n in pairs(FS.DB.profiles) do names[#names+1]=n end; table.sort(names)
                menu:CreateTitle(#names == 0 and "No saved profiles" or "Saved profiles")
                for _,name in ipairs(names) do
                    menu:CreateButton(name, function()
                        FS:ApplyProfile(FS.DB.profiles[name]); f.name:SetText(name)
                        RefreshFilters(); UI:UpdateProfileSummary()
                    end)
                end
            end)
        end)
        Button(f, "Reset filters", 169, -210, 138, function()
            FS:ApplyProfile({}); RefreshFilters(); UI:UpdateProfileSummary()
        end)
        f.summary = Label(f, "", 18, -258, 430)
    end
    self:UpdateProfileSummary()
    self.profileWindow:Show()
end
function UI:UpdateProfileSummary()
    local o = FS.DB.searchOptions
    self.profileWindow.summary:SetText(string.format("Current: price %.0f-%.0fg (0 = unlimited), min ROI %.0f%%, class %s, risk %s.\nEdit all values in Search Options.", o.minPriceGold or 0, o.maxPriceGold or 0, o.minROIPct or 0, tostring(o.classID), o.riskMode or "all"))
end

function UI:ShowWatchTarget()
    local r = self.selected
    if not r then FS:Print("Select an item first."); return end
    if not self.watchWindow then
        local f = Window("DealScryerWatchTarget", "Watch price target", 430, 235)
        self.watchWindow = f
        f.item = Label(f, "", 18, -52, 390)
        Label(f, "Maximum purchase price per unit (gold):", 18, -86, 390)
        f.price = Box(f, 23, -112, 180)
        f.message = Label(f, "", 18, -193, 390)
        Button(f, "Save target", 18, -154, 125, function()
            local value = tonumber(f.price:GetText())
            if not value or value <= 0 or value > 100000000 then f.message:SetText("Enter a positive gold amount."); return end
            local item = f.record
            if not FS:IsWatched(item.itemID) then FS:ToggleWatch(item.itemID) end
            FS.DB.watchlist[tostring(item.itemID)].targetGold = value
            local m = FS:GetMarketState()
            if m.alertState then m.alertState["watch:" .. item.itemID] = nil end
            UI:Refresh(); f:Hide()
        end)
        Button(f, "Use % rule", 153, -154, 125, function()
            local watch = FS.DB.watchlist[tostring(f.record.itemID)]
            if watch then watch.targetGold = nil end
            f:Hide()
        end)
    end
    local f = self.watchWindow
    f.record = r
    f.item:SetText(r.name or tostring(r.itemID))
    local watch = FS.DB.watchlist[tostring(r.itemID)]
    f.price:SetText(tostring(watch and watch.targetGold or (r.buy or 0)/FS.GOLD))
    f.message:SetText("Alerts run after scans; unchanged prices are not repeated.")
    f:Show()
end

-- Journal records completed trades explicitly entered by the user. Amounts are
-- totals for the whole trade. Fees include the AH cut and any lost deposits.
function FS:AddJournalTrade(item, qty, cost, proceeds, fees)
    qty, cost, proceeds, fees = tonumber(qty), tonumber(cost), tonumber(proceeds), tonumber(fees)
    if not item or item == "" or not qty or qty < 1 or qty ~= math.floor(qty) or qty > 1000000 then return false, "Enter an item and a whole quantity above zero." end
    for _,v in ipairs({cost or -1, proceeds or -1, fees or -1}) do
        if v ~= v or v < 0 or v > 100000000 then return false, "Enter valid non-negative gold totals (up to 100 million)." end
    end
    local market = self:GetMarketState()
    market.journal = market.journal or {}
    local function copper(v) return math.floor(v*self.GOLD+0.5) end
    market.journal[#market.journal+1] = {item=item, qty=qty, cost=copper(cost), proceeds=copper(proceeds), fees=copper(fees), t=time()}
    return true
end
function FS:JournalProfit(e) return e.proceeds-e.cost-e.fees end
local function SignedGold(v) return string.format("%+.2fg", v/FS.GOLD) end
function UI:ShowJournal()
    if not self.journalWindow then
        local f = Window("DealScryerJournal", "Trading journal - confirmed trades", 700, 540)
        self.journalWindow = f
        Label(f, "Manual entries for this realm/region. All amounts are TOTAL gold, not per unit.", 18, -48, 660)
        local fields = {{"item","Item",22,260},{"qty","Quantity",300,95},{"cost","Purchase total",22,190},{"proceeds","Gross sale total",242,190},{"fees","All fees / lost deposits",462,205}}
        f.fields = {}
        for i,field in ipairs(fields) do
            local y = i <= 2 and -86 or -148
            Label(f, field[2], field[3], y, field[4])
            f.fields[field[1]] = Box(f, field[3]+4, y-24, field[4], field[1]=="qty" and "1" or "")
        end
        f.message = Label(f, "Enter completed sales only. Include the AH cut in fees.", 18, -224, 660)
        Button(f, "Record trade", 18, -259, 140, function()
            local v = f.fields
            local ok, message = FS:AddJournalTrade(v.item:GetText():match("^%s*(.-)%s*$"),v.qty:GetText(),v.cost:GetText(),v.proceeds:GetText(),v.fees:GetText())
            f.message:SetText(ok and "Trade saved. Realized profit updated." or message)
            if ok then
                for _,key in ipairs({"cost","proceeds","fees"}) do v[key]:SetText("") end
                f.offset=0; UI:RefreshJournal()
            end
        end)
        Button(f, "Export", 172, -259, 95, function()
            local lines={"Date\tItem\tQuantity\tCost gold\tGross sale gold\tFees gold\tNet profit gold"}
            for _,e in ipairs(FS:GetMarketState().journal or {}) do
                lines[#lines+1]=string.format("%s\t%s\t%d\t%.2f\t%.2f\t%.2f\t%.2f", date("%Y-%m-%d %H:%M",e.t),e.item:gsub("[\t\r\n]"," "),e.qty,e.cost/FS.GOLD,e.proceeds/FS.GOLD,e.fees/FS.GOLD,FS:JournalProfit(e)/FS.GOLD)
            end
            UI:ShowCopyableText("Journal export",table.concat(lines,"\n"))
        end)
        Button(f, "Undo last", 281, -259, 110, function()
            local journal = FS:GetMarketState().journal or {}
            local e = table.remove(journal)
            f.undo = f.undo or {}; local key = FS:GetMarketKey(); f.undo[key] = f.undo[key] or {}
            if e then table.insert(f.undo[key], e) end
            UI:RefreshJournal()
        end)
        Button(f, "Restore", 404, -259, 95, function()
            local stack = f.undo and f.undo[FS:GetMarketKey()]
            local e = stack and table.remove(stack)
            if e then
                local m=FS:GetMarketState(); m.journal=m.journal or {}; table.insert(m.journal,e)
                UI:RefreshJournal()
            end
        end)
        f.summary = Label(f, "", 18, -302, 660)
        f.rows={}
        for i=1,5 do f.rows[i]=Label(f,"",18,-336-(i-1)*29,660); f.rows[i]:SetWordWrap(false) end
        f.offset=0
        Button(f,"Newer",18,-494,95,function() f.offset=math.max(0,f.offset-5); UI:RefreshJournal() end)
        Button(f,"Older",125,-494,95,function()
            local n=#(FS:GetMarketState().journal or {}); f.offset=math.min(math.max(0,n-1),f.offset+5); UI:RefreshJournal()
        end)
    end
    local f=self.journalWindow
    if self.selected then f.fields.item:SetText(self.selected.name or tostring(self.selected.itemID)) end
    self:RefreshJournal(); f:Show()
end
function UI:RefreshJournal()
    local f=self.journalWindow
    local journal=FS:GetMarketState().journal or {}
    local total=0; for _,e in ipairs(journal) do total=total+FS:JournalProfit(e) end
    f.offset=math.min(f.offset,math.max(0,#journal-1))
    f.summary:SetText(string.format("%s | %d trades | Realized net: %s",FS:GetMarketLabel(),#journal,SignedGold(total)))
    for i,row in ipairs(f.rows) do
        local e=journal[#journal-f.offset-i+1]
        row:SetText(e and string.format("%s  %dx %s  |  %s",date("%d %b",e.t),e.qty,e.item,SignedGold(FS:JournalProfit(e))) or "")
    end
end

local originalCreateOptions=UI.CreateSearchOptionsPanel
function UI:CreateSearchOptionsPanel()
    originalCreateOptions(self)
    local p=self.searchOptionsPanel
    if p.experienceAdded then return end
    p.experienceAdded=true; p:SetHeight(455)
    Label(p,"Minimum ROI (%)",14,-297,150)
    self.searchOptionBoxes.minROIPct=Box(p,19,-319,125,0)
    self.riskFilter=Button(p,"Risk: all",180,-319,163,function(button)
        local modes={all="hide",hide="only",only="all"}
        local o=FS.DB.searchOptions; o.riskMode=modes[o.riskMode or "all"] or "all"
        button:SetText("Risk: "..o.riskMode); RefreshFilters()
    end)
    Button(p,"Profiles",14,-362,125,function() UI:ShowProfiles() end)
end
local originalLoadOptions=UI.LoadSearchOptions
function UI:LoadSearchOptions()
    originalLoadOptions(self)
    if self.riskFilter then self.riskFilter:SetText("Risk: "..(FS.DB.searchOptions.riskMode or "all")) end
end
local originalKey=UI.VisibleListKey
function UI:VisibleListKey()
    return originalKey(self).."|"..tostring(FS.DB.searchOptions.riskMode).."|"..tostring(FS.DB.searchOptions.minROIPct)
end
local originalCreate=UI.CreateResultsArea
function UI:CreateResultsArea()
    originalCreate(self)
    self.tableHint:Hide()
    local actions={
        {"Why this deal?",125,function() UI:ShowExplanation() end},
        {"Profiles",85,function() UI:ShowProfiles() end},
        {"Watch target",110,function() UI:ShowWatchTarget() end},
        {"Journal",85,function() UI:ShowJournal() end},
        {"Advanced",95,function(b)
            FS.DB.settings.advancedColumns=not FS.DB.settings.advancedColumns
            b:SetText(FS.DB.settings.advancedColumns and "Compact" or "Advanced"); UI:Layout()
        end},
    }
    local x=10
    for _,a in ipairs(actions) do
        local b=Button(self.tablePanel,a[1],0,0,a[2],a[3]); b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT",x,5)
        x=x+a[2]+5
        if a[1]=="Advanced" then b:SetText(FS.DB.settings.advancedColumns and "Compact" or "Advanced") end
    end
    local plot=self.priceGraph.plot
    plot:EnableMouse(true)
    plot:SetScript("OnLeave",GameTooltip_Hide)
    plot:SetScript("OnUpdate",function(p)
        if not p:IsMouseOver() then return end
        local g=UI.priceGraph; local samples=g.historySamples or {}; local geometry=g.historyGeometry
        if not geometry or #samples==0 then GameTooltip:Hide(); return end
        local x=GetCursorPosition()/p:GetEffectiveScale()-(p:GetLeft() or 0)
        local n=math.floor((x-geometry.startX)/geometry.step)+1
        local sample=samples[n]
        if not sample then GameTooltip:Hide(); return end
        GameTooltip:SetOwner(p,"ANCHOR_RIGHT")
        GameTooltip:SetText(sample.t and date("%d %b %Y %H:%M",sample.t) or "Observation")
        GameTooltip:AddLine("Local reference: "..FS:Money(sample.ref))
        GameTooltip:AddLine("Listing observation, not a completed sale.",0.7,0.7,0.7)
        GameTooltip:Show()
    end)
end
local originalDetail=UI.RefreshDetail
function UI:RefreshDetail()
    originalDetail(self)
    if self.selected and self.sourceText then
        self.sourceText:SetText(FS:GetDataAge().." | "..tostring(self.selected.historyCount or 0).." observations")
    end
end

local originalStatus=UI.UpdateStatus
function UI:UpdateStatus()
    originalStatus(self)
    if self.selected and self.sourceText then
        self.sourceText:SetText(FS:GetDataAge().." | "..tostring(self.selected.historyCount or 0).." observations")
    end
end
