local ADDON_NAME = ...

local FS = _G.DealScryer or {}
_G.DealScryer = FS

FS.ADDON_NAME = ADDON_NAME
FS.VERSION = "3.1.3"
FS.CREATOR = "Burn"
FS.GOLD = 10000
FS.SILVER = 100
FS.SNAPSHOT_COOLDOWN = 15 * 60

local function L(key, ...)
    if FS.L then return FS:L(key, ...) end
    return key
end

FS.DEFAULTS = {
    schema = 42,
    settings = {
        minDiscount = 20,
        minProfitGold = 100,
        minROIPct = 20,
        minMarketGold = 20,
        targetROIPct = 30,
        budgetGold = 100000,
        historySamples = 30,
        historyMinScans = 2,
        alerts = true,
        alertScore = 80,
        tooltip = true,
        autoOpen = false,
        disclaimerAcknowledged = false,
        sort = "score",
        sortDesc = true,
        showCandidates = true,
    },
    searchOptions = {
        minPriceGold = 0,
        maxPriceGold = 0,
        minItemLevel = 0,
        maxItemLevel = 0,
        minQuality = -1,
        classID = -1,
        onlyUsable = false,
        equipmentOnly = false,
        minQuantity = 0,
    },
    window = {
        point = "CENTER",
        x = 0,
        y = 0,
        width = 1280,
        height = 760,
    },
    minimap = {
        angle = 225,
    },
    markets = {},
    watchlist = {},
    blacklist = {},
    history = {},
    scanSessions = {},
    previousScan = {
        t = 0,
        auctions = 0,
        mode = "",
        items = {},
    },
    lastFullScanAt = 0,
    lastSuccessfulScanAt = 0,
    lastSnapshotAuctionCount = 0,
    diagnostics = {
        client = {},
        lastScan = {},
        events = {},
    },
}

FS.state = FS.state or {
    initialized = false,
    ahOpen = false,
}

local function DeepDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            DeepDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end
FS.DeepDefaults = DeepDefaults

function FS:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffF5C542DealScryer:|r " .. tostring(msg))
end

function FS:Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function FS:Money(copper, short)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local g = math.floor(copper / self.GOLD)
    local s = math.floor((copper % self.GOLD) / self.SILVER)
    local c = copper % self.SILVER

    if short then
        if g >= 1000000 then return L("MONEY_MILLIONS_FMT", g / 1000000) end
        if g >= 1000 then return L("MONEY_THOUSANDS_FMT", g / 1000) end
        if g > 0 then return L("MONEY_G_FMT", g) end
        if s > 0 then return L("MONEY_S_FMT", s) end
        return L("MONEY_C_FMT", c)
    end

    if g > 0 then return L("MONEY_GS_FMT", g, s) end
    if s > 0 then return L("MONEY_SC_FMT", s, c) end
    return L("MONEY_C_FMT", c)
end

function FS:Percent(v, digits)
    if v == nil then return "—" end
    return string.format("%." .. tostring(digits or 0) .. "f%%", v * 100)
end

-- DealScryer score tiers deliberately use WoW-style rarity colors.
-- The names describe opportunity quality, not the actual item quality.
FS.SCORE_TIERS = {
    { min = 90, name = "Legendary", hex = "ffff8000", r = 1.00, g = 0.50, b = 0.00 },
    { min = 80, name = "Epic",      hex = "ffa335ee", r = 0.64, g = 0.21, b = 0.93 },
    { min = 65, name = "Rare",      hex = "ff0070dd", r = 0.00, g = 0.44, b = 0.87 },
    { min = 50, name = "Good",      hex = "ff1eff00", r = 0.12, g = 1.00, b = 0.00 },
    { min = 0,  name = "Poor",      hex = "ffffffff", r = 1.00, g = 1.00, b = 1.00 },
}

function FS:GetScoreTier(score)
    score = tonumber(score) or 0
    for _, tier in ipairs(self.SCORE_TIERS) do
        if score >= tier.min then
            return tier
        end
    end
    return self.SCORE_TIERS[#self.SCORE_TIERS]
end

function FS:ScoreText(score, includeTier)
    score = math.floor((tonumber(score) or 0) + 0.5)
    local tier = self:GetScoreTier(score)
    local text = includeTier and (tostring(score) .. " • " .. tier.name) or tostring(score)
    return "|c" .. tier.hex .. text .. "|r"
end

function FS:IsWatched(itemID)
    return self.DB and self.DB.watchlist and self.DB.watchlist[tostring(itemID)] ~= nil
end

function FS:IsBlacklisted(itemID)
    return self.DB and self.DB.blacklist and self.DB.blacklist[tostring(itemID)] ~= nil
end

function FS:ToggleWatch(itemID)
    if not itemID or not self.DB then return end
    local key = tostring(itemID)

    if self.DB.watchlist[key] then
        self.DB.watchlist[key] = nil
        self:Print(L("WATCH_REMOVED_FMT", key))
    else
        self.DB.watchlist[key] = {
            addedAt = time(),
            thresholdPct = 70,
        }
        self:Print(L("WATCH_ADDED_FMT", key))
    end

    if self.Scanner then self.Scanner:RebuildVisibleLists() end
    if self.UI then self.UI:Refresh() end
end

function FS:ToggleBlacklist(itemID)
    if not itemID or not self.DB then return end
    local key = tostring(itemID)

    if self.DB.blacklist[key] then
        self.DB.blacklist[key] = nil
        self:Print(L("IGNORE_REMOVED_FMT", key))
    else
        self.DB.blacklist[key] = { addedAt = time() }
        self:Print(L("IGNORED_FMT", key))
    end

    if self.Scanner then self.Scanner:RebuildVisibleLists() end
    if self.UI then self.UI:Refresh() end
end

FS.REGION_INFO = {
    [1] = { slug = "us", label = "NA / Brazil / Oceania", undermine = true },
    [2] = { slug = "kr", label = "Korea", undermine = true },
    [3] = { slug = "eu", label = "Europe", undermine = true },
    [4] = { slug = "tw", label = "Taiwan", undermine = true },
    [5] = { slug = "cn", label = "China", undermine = false },
    [50] = { slug = "ptr", label = "PTR", undermine = false },
    [57] = { slug = "xptr", label = "Experimental PTR", undermine = false },
}

function FS:GetActualRegionID()
    local guid = UnitGUID and UnitGUID("player")
    if guid and C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID then
        local ok, info = pcall(C_BattleNet.GetGameAccountInfoByGUID, guid)
        if ok and type(info) == "table" and tonumber(info.regionID) then
            return tonumber(info.regionID)
        end
    end

    if GetCurrentRegion then
        local ok, regionID = pcall(GetCurrentRegion)
        if ok and tonumber(regionID) then
            return tonumber(regionID)
        end
    end

    return 0
end

function FS:GetRegionInfo()
    local id = self:GetActualRegionID()
    local info = self.REGION_INFO[id]
    if info then
        return {
            id = id,
            slug = info.slug,
            label = info.label,
            undermine = info.undermine == true,
        }
    end

    return {
        id = id,
        slug = "unknown",
        label = "Unknown region",
        undermine = false,
    }
end

function FS:GetMarketKey()
    local region = self:GetRegionInfo()
    local realm = GetRealmName and GetRealmName() or "unknown"
    -- Keep the raw UTF-8 realm name. This is important for Russian, Taiwanese,
    -- Korean and Chinese realms and is perfectly safe as a Lua table key.
    return tostring(region.id) .. ":" .. tostring(realm)
end

function FS:GetMarketLabel()
    local region = self:GetRegionInfo()
    local realm = GetRealmName and GetRealmName() or "Unknown Realm"
    return region.label .. " • " .. realm
end

function FS:GetMarketState()
    if not self.DB then return nil end

    self.DB.markets = type(self.DB.markets) == "table" and self.DB.markets or {}
    local key = self:GetMarketKey()
    local state = self.DB.markets[key]

    if type(state) ~= "table" then
        state = {
            regionID = self:GetActualRegionID(),
            realm = GetRealmName and GetRealmName() or "Unknown Realm",
            history = {},
            oeHistory = {},
            scanSessions = {},
            previousScan = {
                t = 0,
                auctions = 0,
                mode = "",
                items = {},
            },
            lastFullScanAt = 0,
            lastSuccessfulScanAt = 0,
            lastSnapshotAuctionCount = 0,
        }
        self.DB.markets[key] = state
    end

    state.history = type(state.history) == "table" and state.history or {}
    state.oeHistory = type(state.oeHistory) == "table" and state.oeHistory or {}
    state.scanSessions = type(state.scanSessions) == "table" and state.scanSessions or {}
    state.previousScan = type(state.previousScan) == "table" and state.previousScan or {
        t = 0,
        auctions = 0,
        mode = "",
        items = {},
    }

    return state
end

function FS:GetKnownCooldown()
    local state = self:GetMarketState()
    local last = tonumber(state and state.lastFullScanAt) or 0
    if last <= 0 then return 0 end
    return math.max(0, self.SNAPSHOT_COOLDOWN - (time() - last))
end

local function DiagnosticTimestamp(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return "never" end
    if date then
        local ok, value = pcall(date, "%Y-%m-%d %H:%M:%S", ts)
        if ok and value then return value end
    end
    return tostring(ts)
end

function FS:GetDiagnosticsState()
    if not self.DB then return nil end
    self.DB.diagnostics = type(self.DB.diagnostics) == "table" and self.DB.diagnostics or {}
    self.DB.diagnostics.client = type(self.DB.diagnostics.client) == "table" and self.DB.diagnostics.client or {}
    self.DB.diagnostics.lastScan = type(self.DB.diagnostics.lastScan) == "table" and self.DB.diagnostics.lastScan or {}
    self.DB.diagnostics.events = type(self.DB.diagnostics.events) == "table" and self.DB.diagnostics.events or {}
    return self.DB.diagnostics
end

function FS:RecordDiagnosticEvent(eventName, detail)
    local diagnostics = self:GetDiagnosticsState()
    if not diagnostics then return end

    local entry = {
        t = time(),
        event = tostring(eventName or "event"),
    }
    if detail ~= nil then entry.detail = tostring(detail) end

    diagnostics.events[#diagnostics.events + 1] = entry
    while #diagnostics.events > 20 do
        table.remove(diagnostics.events, 1)
    end
end

function FS:StartScanDiagnostics(mode, cachedBefore)
    local diagnostics = self:GetDiagnosticsState()
    if not diagnostics then return end

    diagnostics.lastScan = {
        startedAt = time(),
        completedAt = 0,
        success = false,
        mode = tostring(mode or "unknown"),
        stage = "requesting",
        cachedBefore = tonumber(cachedBefore) or 0,
        auctions = 0,
        items = 0,
        deals = 0,
        candidates = 0,
        topScore = 0,
        error = "",
    }
    self:RecordDiagnosticEvent("scan-start", diagnostics.lastScan.mode)
end

function FS:UpdateScanDiagnostics(fields)
    local diagnostics = self:GetDiagnosticsState()
    if not diagnostics or type(fields) ~= "table" then return end

    diagnostics.lastScan = type(diagnostics.lastScan) == "table" and diagnostics.lastScan or {}
    for key, value in pairs(fields) do
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            diagnostics.lastScan[key] = value
        end
    end
end

function FS:FinishScanDiagnostics(success, fields)
    self:UpdateScanDiagnostics(fields or {})
    local diagnostics = self:GetDiagnosticsState()
    if not diagnostics then return end

    diagnostics.lastScan.success = success == true
    diagnostics.lastScan.completedAt = time()

    if success then
        diagnostics.lastScan.stage = "complete"
        diagnostics.lastScan.error = ""
        self:RecordDiagnosticEvent("scan-complete", diagnostics.lastScan.mode or "unknown")
    else
        diagnostics.lastScan.stage = "failed"
        self:RecordDiagnosticEvent("scan-failed", diagnostics.lastScan.error or "")
    end
end

function FS:CaptureClientDiagnostics()
    local diagnostics = self:GetDiagnosticsState()
    if not diagnostics then return nil end

    local wowVersion, wowBuild, wowBuildDate, interfaceVersion
    if GetBuildInfo then
        local ok, v, b, d, i = pcall(GetBuildInfo)
        if ok then
            wowVersion, wowBuild, wowBuildDate, interfaceVersion = v, b, d, i
        end
    end

    local declaredInterface
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Interface")
        if ok then declaredInterface = value end
    end

    local api = {
        ReplicateItems = C_AuctionHouse and type(C_AuctionHouse.ReplicateItems) == "function" or false,
        GetNumReplicateItems = C_AuctionHouse and type(C_AuctionHouse.GetNumReplicateItems) == "function" or false,
        GetReplicateItemInfo = C_AuctionHouse and type(C_AuctionHouse.GetReplicateItemInfo) == "function" or false,
        IsThrottledMessageSystemReady = C_AuctionHouse and type(C_AuctionHouse.IsThrottledMessageSystemReady) == "function" or false,
    }

    local cached = 0
    if api.GetNumReplicateItems then
        local ok, value = pcall(C_AuctionHouse.GetNumReplicateItems)
        if ok then cached = tonumber(value) or 0 end
    end

    local throttleReady
    if api.IsThrottledMessageSystemReady then
        local ok, value = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
        if ok then throttleReady = value == true end
    end

    local replicateProbeOK, replicateReturnCount
    if cached > 0 and api.GetReplicateItemInfo then
        local function ProbeReplicateTuple()
            return select("#", C_AuctionHouse.GetReplicateItemInfo(0))
        end
        local ok, value = pcall(ProbeReplicateTuple)
        replicateProbeOK = ok == true
        if ok then replicateReturnCount = tonumber(value) end
    end

    diagnostics.client = {
        capturedAt = time(),
        addonVersion = tostring(self.VERSION or ""),
        wowVersion = tostring(wowVersion or ""),
        wowBuild = tostring(wowBuild or ""),
        wowBuildDate = tostring(wowBuildDate or ""),
        interfaceVersion = tonumber(interfaceVersion) or 0,
        declaredInterface = tostring(declaredInterface or ""),
        projectID = tonumber(WOW_PROJECT_ID) or 0,
        locale = GetLocale and tostring(GetLocale() or "") or "",
        regionID = self:GetActualRegionID(),
        realm = GetRealmName and tostring(GetRealmName() or "") or "",
        cachedReplicateItems = cached,
        throttleReady = throttleReady,
        replicateProbeOK = replicateProbeOK,
        replicateReturnCount = replicateReturnCount,
        apiReplicateItems = api.ReplicateItems,
        apiGetNumReplicateItems = api.GetNumReplicateItems,
        apiGetReplicateItemInfo = api.GetReplicateItemInfo,
        apiThrottleReady = api.IsThrottledMessageSystemReady,
    }

    return diagnostics.client
end

function FS:GetDiagnosticLines()
    local client = self:CaptureClientDiagnostics() or {}
    local diagnostics = self:GetDiagnosticsState() or {}
    local lastScan = diagnostics.lastScan or {}
    local lines = {}

    lines[#lines + 1] = "DealScryer " .. tostring(self.VERSION) .. " by " .. tostring(self.CREATOR or "Burn")
    lines[#lines + 1] = "Captured: " .. DiagnosticTimestamp(client.capturedAt)
    lines[#lines + 1] = "WoW: " .. tostring(client.wowVersion or "") .. " • Build " .. tostring(client.wowBuild or "") .. " • " .. tostring(client.wowBuildDate or "")
    lines[#lines + 1] = "Interface: client " .. tostring(client.interfaceVersion or 0) .. " • addon " .. tostring(client.declaredInterface or "")
    lines[#lines + 1] = "Project ID: " .. tostring(client.projectID or 0) .. " • Locale: " .. tostring(client.locale or "")
    lines[#lines + 1] = "Market: " .. self:GetMarketLabel() .. " • Region ID " .. tostring(self:GetActualRegionID())
    lines[#lines + 1] = "AH open: " .. tostring(self.state.ahOpen)
    lines[#lines + 1] = "Scan running: " .. tostring(self.Scanner and self.Scanner.scanRunning)
    lines[#lines + 1] = "Scan phase: " .. tostring(self.Scanner and self.Scanner.scanPhase)
    lines[#lines + 1] = "Status: " .. tostring(self.Scanner and self.Scanner.status)
    lines[#lines + 1] = "Known cooldown: " .. tostring(self:GetKnownCooldown()) .. " sec"
    lines[#lines + 1] = "Replicate cache: " .. tostring(client.cachedReplicateItems or 0)
    lines[#lines + 1] = "Throttle ready: " .. tostring(client.throttleReady)
    lines[#lines + 1] = "AH APIs: ReplicateItems=" .. tostring(client.apiReplicateItems)
        .. " • GetNum=" .. tostring(client.apiGetNumReplicateItems)
        .. " • GetInfo=" .. tostring(client.apiGetReplicateItemInfo)
        .. " • Throttle=" .. tostring(client.apiThrottleReady)

    if client.replicateProbeOK ~= nil then
        lines[#lines + 1] = "Replicate tuple probe: " .. tostring(client.replicateProbeOK)
            .. " • returns=" .. tostring(client.replicateReturnCount or "?")
    else
        lines[#lines + 1] = "Replicate tuple probe: not run (no cached snapshot)"
    end

    if self.Undermine and self.Undermine.GetStatus then
        local ok, available, label = pcall(function()
            local a, l = self.Undermine:GetStatus()
            return a, l
        end)
        if ok then
            lines[#lines + 1] = "Oribos Exchange: " .. tostring(available) .. " • " .. tostring(label or "")
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "LAST SCAN"
    lines[#lines + 1] = "Started: " .. DiagnosticTimestamp(lastScan.startedAt)
    lines[#lines + 1] = "Completed: " .. DiagnosticTimestamp(lastScan.completedAt)
    lines[#lines + 1] = "Success: " .. tostring(lastScan.success)
        .. " • Mode: " .. tostring(lastScan.mode or "unknown")
        .. " • Stage: " .. tostring(lastScan.stage or "none")
    lines[#lines + 1] = "Cached before request: " .. tostring(lastScan.cachedBefore or 0)
        .. " • Auctions: " .. tostring(lastScan.auctions or 0)
    lines[#lines + 1] = "Items: " .. tostring(lastScan.items or 0)
        .. " • Deals: " .. tostring(lastScan.deals or 0)
        .. " • Candidates: " .. tostring(lastScan.candidates or 0)
        .. " • Top score: " .. tostring(lastScan.topScore or 0)
    if lastScan.error and lastScan.error ~= "" then
        lines[#lines + 1] = "Last error: " .. tostring(lastScan.error)
    end

    local state = self:GetMarketState()
    local historyItems = 0
    for _ in pairs((state and state.history) or {}) do historyItems = historyItems + 1 end
    lines[#lines + 1] = "History items: " .. tostring(historyItems)

    local events = diagnostics.events or {}
    if #events > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "RECENT EVENTS"
        local first = math.max(1, #events - 7)
        for i = first, #events do
            local entry = events[i]
            local text = DiagnosticTimestamp(entry.t) .. " • " .. tostring(entry.event or "event")
            if entry.detail and entry.detail ~= "" then
                text = text .. " • " .. tostring(entry.detail)
            end
            lines[#lines + 1] = text
        end
    end

    return lines
end

function FS:PruneHistory()
    if not self.DB then return end
    local cutoff = time() - 90 * 24 * 60 * 60

    for _, state in pairs(self.DB.markets or {}) do
        if type(state) == "table" and type(state.history) == "table" then
            for key, h in pairs(state.history) do
                if type(h) ~= "table" or (tonumber(h.lastSeen) or 0) < cutoff then
                    state.history[key] = nil
                end
            end
        end

        if type(state) == "table" and type(state.oeHistory) == "table" then
            local oeCutoff = time() - (5 * 24 * 60 * 60)
            for itemKey, samples in pairs(state.oeHistory) do
                if type(samples) ~= "table" then
                    state.oeHistory[itemKey] = nil
                else
                    local kept = {}
                    for _, sample in ipairs(samples) do
                        if type(sample) == "table" and (tonumber(sample.t) or 0) >= oeCutoff then
                            kept[#kept + 1] = sample
                        end
                    end
                    if #kept > 0 then
                        state.oeHistory[itemKey] = kept
                    else
                        state.oeHistory[itemKey] = nil
                    end
                end
            end
        end
    end
end

FS.itemDataCache = FS.itemDataCache or {}
FS.itemDataPending = FS.itemDataPending or {}
FS.itemDataRefreshQueued = false

function FS:QueueItemDataRefresh()
    if self.itemDataRefreshQueued then return end
    self.itemDataRefreshQueued = true

    C_Timer.After(0.08, function()
        FS.itemDataRefreshQueued = false
        if FS.UI and FS.UI.OnItemDataBatch then
            FS.UI:OnItemDataBatch()
        elseif FS.UI and FS.UI.RefreshRows then
            FS.UI:RefreshRows(true)
        end
    end)
end

local function IsRealItemName(name, itemID)
    if type(name) ~= "string" or name == "" then return false end

    local low = name:lower()
    if low:find("retrieving item", 1, true)
        or low:find("loading item", 1, true)
        or low == "loading..."
        or low == "loading…"
        or low == "unknown item" then
        return false
    end

    if itemID and name == ("Item " .. tostring(itemID)) then
        return false
    end

    return true
end
FS.IsRealItemName = IsRealItemName

function FS:CacheItemIdentity(itemID, name, link, icon)
    itemID = tonumber(itemID)
    if not itemID then return end

    local old = self.itemDataCache[itemID] or {}
    if IsRealItemName(name, itemID) then old.name = name end
    if type(link) == "string" and link ~= "" then old.link = link end
    if type(icon) == "number" and icon > 0 then old.icon = icon end

    if old.name or old.link or old.icon then
        self.itemDataCache[itemID] = old
    end
end

local function AuctionHouseIdentity(itemID)
    if not C_AuctionHouse or not C_AuctionHouse.GetItemKeyInfo then return nil, nil, nil end

    local key
    if C_AuctionHouse.MakeItemKey then
        local ok, made = pcall(C_AuctionHouse.MakeItemKey, itemID)
        if ok then key = made end
    end
    key = key or {
        itemID = itemID,
        itemLevel = 0,
        itemSuffix = 0,
        battlePetSpeciesID = 0,
    }

    local ok, info = pcall(C_AuctionHouse.GetItemKeyInfo, key)
    if not ok or type(info) ~= "table" then return nil, nil, nil end

    return info.itemName, info.battlePetLink or info.appearanceLink, info.iconFileID
end

function FS:ResolveItemData(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil, nil, nil end

    local cached = self.itemDataCache[itemID]
    if cached and IsRealItemName(cached.name, itemID) then
        return cached.name, cached.link, cached.icon
    end

    local name, link, icon

    if C_Item and C_Item.GetItemInfo then
        local ok, n, l, _, _, _, _, _, _, texture = pcall(C_Item.GetItemInfo, itemID)
        if ok then
            if IsRealItemName(n, itemID) then name = n end
            link = l
            icon = texture
        end
    end

    if not name then
        local n, l, i = AuctionHouseIdentity(itemID)
        if IsRealItemName(n, itemID) then name = n end
        link = link or l
        icon = icon or i
    end

    if not icon and C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, instantIcon = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok then icon = instantIcon end
    end

    self:CacheItemIdentity(itemID, name, link, icon)
    local final = self.itemDataCache[itemID]
    if final then
        return final.name, final.link, final.icon
    end
    return nil, nil, nil
end

function FS:RequestItemData(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end

    local name = self:ResolveItemData(itemID)
    if IsRealItemName(name, itemID) then return end
    if self.itemDataPending[itemID] then return end

    self.itemDataPending[itemID] = true

    -- One explicit Blizzard item-data request is enough. The older code issued
    -- the same request twice and refreshed the whole DealScryer window for every
    -- individual result, which caused stutter while scrolling.
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end

    if Item and Item.CreateFromItemID then
        local ok, item = pcall(function()
            return Item:CreateFromItemID(itemID)
        end)

        if ok and item and item.ContinueOnItemLoad then
            item:ContinueOnItemLoad(function()
                local n, l, i
                pcall(function()
                    n = item:GetItemName()
                    l = item:GetItemLink()
                    i = item:GetItemIcon()
                end)

                FS:CacheItemIdentity(itemID, n, l, i)
                FS.itemDataPending[itemID] = nil

                if FS.Scanner then FS.Scanner:RefreshItemData(itemID) end
                FS:QueueItemDataRefresh()
            end)
        end
    end

    -- Slow-cache fallback. Only touch the entry if the request is still pending;
    -- successful callbacks do not create another redundant UI refresh.
    C_Timer.After(4, function()
        if not FS.itemDataPending[itemID] then return end

        FS.itemDataPending[itemID] = nil
        FS:ResolveItemData(itemID)
        if FS.Scanner then FS.Scanner:RefreshItemData(itemID) end
        FS:QueueItemDataRefresh()
    end)
end

function DealScryer_OnAddonCompartmentClick()
    if FS.UI then FS.UI:Show() end
end

function DealScryer_OnAddonCompartmentEnter(button)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine("DealScryer")
    GameTooltip:AddLine(L("COMPARTMENT_DESC"), 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L("COMPARTMENT_NO_DEPS"), 0.5, 0.9, 0.6)
    GameTooltip:Show()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
eventFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED")
eventFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED")
eventFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
eventFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED")
eventFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon ~= ADDON_NAME then return end

        DealScryerDB = DealScryerDB or {}
        FS.DB = DealScryerDB
        DeepDefaults(FS.DEFAULTS, FS.DB)

        -- 2.0 is deliberately standalone. Old Auctionator/TSM fields are harmless,
        -- but no longer used.
        -- 2.6.2 is English-only and uses the Classic UI only.
        if FS.DB.settings then
            FS.DB.settings.language = nil
            FS.DB.settings.uiTheme = nil
            FS.DB.settings.autoOpen = false
        end
        FS.DB.schema = FS.DEFAULTS.schema
        FS.state.initialized = true

    elseif event == "PLAYER_LOGIN" then
        FS:PruneHistory()
        FS:CaptureClientDiagnostics()
        FS:RecordDiagnosticEvent("player-login", "WoW client diagnostics captured")
        if FS.Tooltip then FS.Tooltip:Initialize() end
        C_Timer.After(1, function()
            if FS.UI and FS.UI.RegisterMoverSupport then
                FS.UI:RegisterMoverSupport()
            end
            if FS.UI and FS.UI.CreateMinimapButton then
                FS.UI:CreateMinimapButton()
            end
        end)
        C_Timer.After(0.5, function()
            if FS.Scanner and FS.Scanner.LoadPreviousScan then
                FS.Scanner:LoadPreviousScan(true)
            end
        end)
        FS:Print(L("LOADED_MSG_FMT", FS.VERSION))

    elseif event == "AUCTION_HOUSE_SHOW" then
        FS.state.ahOpen = true
        if FS.UI then
            FS.UI:OnAuctionHouseShow()
        end

    elseif event == "AUCTION_HOUSE_CLOSED" then
        FS.state.ahOpen = false
        if FS.Scanner then FS.Scanner:OnAuctionHouseClosed() end

    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        if FS.Scanner then FS.Scanner:OnReplicateUpdate() end

    elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED"
        or event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED"
        or event == "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT"
        or event == "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED"
        or event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if FS.Scanner and FS.Scanner.OnThrottleEvent then
            FS.Scanner:OnThrottleEvent(event)
        end

    elseif event == "ITEM_DATA_LOAD_RESULT" then
        local itemID = tonumber((...))
        if itemID and FS.itemDataPending[itemID] then
            FS.itemDataPending[itemID] = nil
            FS:ResolveItemData(itemID)
            if FS.Scanner then FS.Scanner:RefreshItemData(itemID) end
            FS:QueueItemDataRefresh()
        end
    end
end)

SLASH_DEALSCRYER1 = "/dealscryer"
SLASH_DEALSCRYER2 = "/ds"
SLASH_DEALSCRYER3 = "/fs" -- legacy command from FlipScout
SlashCmdList.DEALSCRYER = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local cmd = msg:lower()

    if cmd == "" or cmd == "show" then
        if FS.UI then FS.UI:Show() end

    elseif cmd == "scan" then
        if FS.UI then FS.UI:Show() end
        if FS.Scanner then FS.Scanner:StartFullScan() end

    elseif cmd == "previous" or cmd == "last" then
        if FS.UI then FS.UI:Show() end
        if FS.Scanner and FS.Scanner.LoadPreviousScan then
            FS.Scanner:LoadPreviousScan(false)
        end

    elseif cmd == "cached" then
        if FS.UI then FS.UI:Show() end
        if FS.Scanner then FS.Scanner:AnalyzeCachedSnapshot() end

    elseif cmd == "diag" then
        local lines = FS:GetDiagnosticLines()
        if FS.UI and FS.UI.ShowCopyableText then
            FS.UI:ShowCopyableText(L("DIAG_TITLE"), table.concat(lines, "\n"))
        else
            for _, line in ipairs(lines) do
                FS:Print(line)
            end
        end

    elseif cmd == "clearhistory" then
        local state = FS:GetMarketState()
        if state and state.history then wipe(state.history) end
        FS:Print(L("HISTORY_CLEARED"))

    elseif cmd == "resetwindow" then
        FS.DB.window = {
            point = "CENTER",
            x = 0,
            y = 0,
            width = 1280,
            height = 760,
        }
        if FS.UI then FS.UI:RestorePosition() end

    else
        FS:Print(L("COMMANDS"))
    end
end
