local FS = _G.DealScryer
if not FS then return end

local function L(key, ...)
    return FS:L(key, ...)
end

local S = {
    results = {},
    candidates = {},
    watchResults = {},
    lastAnalysis = {},
    grouped = nil,
    scanRunning = false,
    scanPhase = nil,
    scanToken = 0,
    progress = 0,
    status = L("READY"),
    waitingSince = 0,
    currentSnapshotAt = 0,
    currentAuctionCount = 0,
    requestStartedAt = 0,
    requestStartCachedCount = 0,
    requestFallbackUsed = false,
    throttleReadyAt = 0,
}
FS.Scanner = S

local function Median(values)
    if not values or #values == 0 then return nil end
    local tmp = {}
    for _, v in ipairs(values) do
        v = tonumber(v)
        if v and v > 0 then tmp[#tmp + 1] = v end
    end
    if #tmp == 0 then return nil end

    table.sort(tmp)
    local n = #tmp
    if n % 2 == 1 then return tmp[(n + 1) / 2] end
    return math.floor((tmp[n / 2] + tmp[n / 2 + 1]) / 2)
end

local function WeightedPercentile(levels, percentile, skipCheapest)
    if not levels or #levels == 0 then return nil end

    local start = 1
    if skipCheapest and #levels > 1 then start = 2 end
    if start > #levels then start = 1 end

    local total = 0
    for i = start, #levels do
        total = total + math.max(1, tonumber(levels[i].qty) or 1)
    end
    if total <= 0 then return nil end

    local target = total * percentile
    local running = 0

    for i = start, #levels do
        running = running + math.max(1, tonumber(levels[i].qty) or 1)
        if running >= target then
            return levels[i].price
        end
    end

    return levels[#levels].price
end

local function GetHistoryStats(itemID)
    local market = FS:GetMarketState()
    local h = market and market.history[tostring(itemID)]
    if type(h) ~= "table" or type(h.samples) ~= "table" then
        return nil, 0, nil
    end

    local values = {}
    for _, sample in ipairs(h.samples) do
        if type(sample) == "table" then
            if tonumber(sample.ref) and sample.ref > 0 then
                values[#values + 1] = sample.ref
            end
        elseif tonumber(sample) then
            values[#values + 1] = tonumber(sample)
        end
    end

    return Median(values), #values, h
end

local function UpdateHistory(itemID, stats)
    if not stats or not stats.reference or stats.reference <= 0 then return end
    if stats.reference < (FS.DB.settings.minMarketGold or 20) * FS.GOLD then return end

    local market = FS:GetMarketState()
    if not market then return end

    local key = tostring(itemID)
    local h = market.history[key]
    if type(h) ~= "table" then
        h = {
            samples = {},
            lastSeen = 0,
        }
        market.history[key] = h
    end

    h.samples = type(h.samples) == "table" and h.samples or {}
    local now = S.currentSnapshotAt > 0 and S.currentSnapshotAt or time()

    local last = h.samples[#h.samples]
    if type(last) == "table" and tonumber(last.t) == now then
        return
    end

    h.samples[#h.samples + 1] = {
        t = now,
        ref = math.floor(stats.reference),
        low = math.floor(stats.cheapest),
        median = math.floor(stats.median or stats.reference),
        qty = stats.totalQty or 0,
    }

    local keep = math.max(5, tonumber(FS.DB.settings.historySamples) or 30)
    while #h.samples > keep do
        table.remove(h.samples, 1)
    end

    h.lastSeen = now
    h.lastRef = math.floor(stats.reference)
end

local function GetClassInfo(itemID)
    local equipLoc, icon, classID, subClassID

    if C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, e, i, c, s = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok then
            equipLoc, icon, classID, subClassID = e, i, c, s
        end
    end

    local className, subClassName
    if classID ~= nil and GetItemClassInfo then
        local ok, n = pcall(GetItemClassInfo, classID)
        if ok then className = n end
    end
    if classID ~= nil and subClassID ~= nil and GetItemSubClassInfo then
        local ok, n = pcall(GetItemSubClassInfo, classID, subClassID)
        if ok then subClassName = n end
    end

    return {
        equipLoc = equipLoc,
        icon = icon,
        classID = classID,
        subClassID = subClassID,
        className = className,
        subClassName = subClassName,
        isEquipment = equipLoc ~= nil and equipLoc ~= "",
    }
end

local function BuildGroupStats(group)
    local levels = {}
    for price, bucket in pairs(group.prices or {}) do
        levels[#levels + 1] = {
            price = tonumber(price),
            qty = bucket.qty or 0,
            listings = bucket.listings or 0,
        }
    end

    if #levels == 0 then return nil end
    table.sort(levels, function(a, b) return a.price < b.price end)

    local cheapest = levels[1].price
    local cheapestQty = levels[1].qty
    local nextHigher = levels[2] and levels[2].price or nil
    local totalQty, listingCount = 0, 0

    for _, level in ipairs(levels) do
        totalQty = totalQty + math.max(0, level.qty or 0)
        listingCount = listingCount + math.max(0, level.listings or 0)
    end

    local currentRef
    if #levels >= 2 then
        currentRef = WeightedPercentile(levels, 0.25, true)
    end

    local currentMedian = WeightedPercentile(levels, 0.50, false)

    return {
        levels = levels,
        cheapest = cheapest,
        cheapestQty = cheapestQty,
        nextHigher = nextHigher,
        distinctPrices = #levels,
        totalQty = totalQty,
        listingCount = listingCount,
        currentRef = currentRef,
        median = currentMedian,
    }
end

local function BuildLadder(levels)
    local ladder = {}
    for i = 1, math.min(#levels, 10) do
        ladder[#ladder + 1] = {
            price = levels[i].price,
            qty = levels[i].qty,
            listings = levels[i].listings,
        }
    end
    return ladder
end


local GOLD_CAP_COPPER = 10000000 * FS.GOLD

local function DetectSuspiciousMarket(r)
    local reasons = {}
    local buy = tonumber(r.buy) or 0
    local target = tonumber(r.safeSell) or 0
    local quality = tonumber(r.quality)
    local historyCount = tonumber(r.historyCount) or 0
    local gapRatio = tonumber(r.gapRatio) or 0
    local listings = tonumber(r.listingCount) or 0
    local distinctPrices = tonumber(r.distinctPrices) or 0

    -- Obvious vendor-trash / grey-item manipulation or novelty listings.
    if quality == 0 then
        if target >= 100000 * FS.GOLD or buy >= 100000 * FS.GOLD then
            reasons[#reasons + 1] = "grey item at extreme price"
        end
        if target >= GOLD_CAP_COPPER * 0.50 or buy >= GOLD_CAP_COPPER * 0.50 then
            reasons[#reasons + 1] = "grey item near gold cap"
        end
    end

    -- Any item that sits close to gold cap without meaningful supporting history.
    if target >= GOLD_CAP_COPPER * 0.80 and historyCount < 3 then
        reasons[#reasons + 1] = "near gold cap with weak history"
    end

    -- A huge gap with very little market depth is commonly a manipulated/stale market.
    if gapRatio >= 9 and listings <= 3 then
        reasons[#reasons + 1] = "extreme gap with thin market"
    end

    -- One or two price levels at a very high value are not a robust market reference.
    if target >= 500000 * FS.GOLD and distinctPrices <= 2 and historyCount < 3 then
        reasons[#reasons + 1] = "high value with too few price levels"
    end

    -- Current target wildly above own historical median.
    if r.historyMedian and r.historyMedian > 0 and target >= r.historyMedian * 5 then
        reasons[#reasons + 1] = "current market far above history"
    end

    if r.oeReference and r.oeReference > 0 and r.localTargetBeforeOE and r.localTargetBeforeOE > 0 then
        if r.localTargetBeforeOE >= r.oeReference * 3 then
            reasons[#reasons + 1] = "current market far above Undermine Exchange"
        end
    end

    -- Historical target wildly above current meaningful depth.
    if r.currentRef and r.currentRef > 0 and r.historyMedian and r.historyMedian > r.currentRef * 5 then
        reasons[#reasons + 1] = "history far above current market"
    end

    return #reasons > 0, reasons
end

local function BuildRisk(r)
    local flags = {}

    if (r.listingCount or 0) < 3 then flags[#flags + 1] = "thin market" end
    if (r.distinctPrices or 0) < 2 then flags[#flags + 1] = "one price level" end
    if r.isEquipment then flags[#flags + 1] = "gear variant risk" end
    if (r.historyCount or 0) == 0 then flags[#flags + 1] = "no history yet" end

    if r.currentRef and r.historyMedian and r.historyMedian > 0 then
        local ratio = r.currentRef / r.historyMedian
        if ratio > 1.8 or ratio < 0.55 then
            flags[#flags + 1] = "history disagreement"
        end
    end

    if r.gapRatio and r.gapRatio > 4 then
        flags[#flags + 1] = "extreme price gap"
    end

    if r.oeReference and r.oeReference > 0 and r.localTargetBeforeOE and r.localTargetBeforeOE > 0 then
        local ratio = r.localTargetBeforeOE / r.oeReference
        if ratio > 1.8 or ratio < 0.55 then
            flags[#flags + 1] = "Undermine Exchange disagreement"
        end
    end

    if r.suspiciousMarket then
        flags[#flags + 1] = "market price may be unreliable"
    end

    return #flags > 0 and table.concat(flags, ", ") or "low"
end

local function ScoreResult(r)
    local discountScore = FS:Clamp(((r.discount or 0) / 0.60) * 30, 0, 30)
    local roiScore = FS:Clamp(((r.roi or 0) / 2.00) * 20, 0, 20)

    local profitGold = math.max(0, (r.profit or 0) / FS.GOLD)
    local profitScore = FS:Clamp((math.log(profitGold + 1) / math.log(10)) * 5, 0, 15)

    local gapScore = 0
    if r.gapRatio and r.gapRatio > 0 then
        gapScore = FS:Clamp((r.gapRatio / 2.0) * 20, 0, 20)
    end

    local confidence = 3
    confidence = confidence + math.min(7, (r.historyCount or 0) * 1.5)
    if (r.distinctPrices or 0) >= 3 then confidence = confidence + 3 end
    if (r.listingCount or 0) >= 5 then confidence = confidence + 2 end

    if r.oeReference and r.oeReference > 0 and r.localTargetBeforeOE and r.localTargetBeforeOE > 0 then
        local ratio = r.localTargetBeforeOE / r.oeReference
        if ratio >= 0.75 and ratio <= 1.35 then
            confidence = confidence + 2
        elseif ratio > 2.0 or ratio < 0.50 then
            confidence = confidence - 2
        end
    end

    if r.isEquipment then confidence = confidence - 2 end
    confidence = FS:Clamp(confidence, 0, 15)

    return math.floor(FS:Clamp(discountScore + roiScore + profitScore + gapScore + confidence, 0, 100) + 0.5)
end

local function PassesDealFilters(r)
    local st = FS.DB.settings

    if FS:IsBlacklisted(r.itemID) then return false end
    if (r.safeSell or 0) < (st.minMarketGold or 0) * FS.GOLD then return false end
    if (r.discount or 0) * 100 < (st.minDiscount or 0) then return false end
    if (r.profit or 0) < (st.minProfitGold or 0) * FS.GOLD then return false end
    if (r.roi or 0) * 100 < (st.minROIPct or 0) then return false end

    return true
end

local function IsCandidate(r)
    if not r or FS:IsBlacklisted(r.itemID) then return false end
    if (r.profit or 0) <= 0 then return false end
    if (r.roi or 0) <= 0.05 then return false end
    if (r.discount or 0) <= 0.05 then return false end
    return true
end

function S:SetStatus(text, progress)
    self.status = text or self.status
    if progress ~= nil then self.progress = progress end
    if FS.UI and FS.UI.UpdateStatus then FS.UI:UpdateStatus() end
end

function S:OnAuctionHouseClosed()
    if self.scanRunning and self.scanPhase == "waiting" then
        if FS.FinishScanDiagnostics then
            FS:FinishScanDiagnostics(false, { error = L("AH_CLOSED") })
        end
        self.scanRunning = false
        self.scanPhase = nil
        self:SetStatus(L("AH_CLOSED"), 0)
    end
end

function S:IsThrottleReady()
    if not C_AuctionHouse or not C_AuctionHouse.IsThrottledMessageSystemReady then
        return true
    end

    local ok, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
    if not ok then return true end
    return ready == true
end

function S:GetCachedReplicateCount()
    if not C_AuctionHouse or not C_AuctionHouse.GetNumReplicateItems then
        return 0
    end

    local ok, n = pcall(C_AuctionHouse.GetNumReplicateItems)
    if not ok then return 0 end
    return tonumber(n) or 0
end

function S:FailSnapshot(message)
    local failure = message or L("SNAPSHOT_FAILED")
    if FS.FinishScanDiagnostics then
        FS:FinishScanDiagnostics(false, {
            error = tostring(failure),
            auctions = tonumber(self.currentAuctionCount) or 0,
        })
    end
    self.scanRunning = false
    self.scanPhase = nil
    self:SetStatus(failure, 0)
end

function S:RequestSnapshotNow()
    if not self.scanRunning then return end
    if not FS.state.ahOpen then
        self:FailSnapshot(L("AH_CLOSED"))
        return
    end

    if not C_AuctionHouse or type(C_AuctionHouse.ReplicateItems) ~= "function" then
        self:FailSnapshot(L("API_UNAVAILABLE"))
        FS:Print(L("API_UNAVAILABLE_CHAT"))
        return
    end

    self.scanPhase = "waiting"
    self.requestStartedAt = GetTime()
    self.requestStartCachedCount = self:GetCachedReplicateCount()
    self.requestFallbackUsed = false
    if FS.UpdateScanDiagnostics then
        FS:UpdateScanDiagnostics({
            stage = "requesting",
            cachedBefore = self.requestStartCachedCount,
        })
    end
    if FS.RecordDiagnosticEvent then
        FS:RecordDiagnosticEvent("replicate-request", "cached=" .. tostring(self.requestStartCachedCount))
    end
    self:SetStatus(L("REQUESTING_BLIZZARD_SNAPSHOT"), 0.02)

    local token = self.scanToken
    local ok, err = pcall(C_AuctionHouse.ReplicateItems)

    if not ok then
        self:FailSnapshot(L("REPLICATE_REJECTED"))
        FS:Print(L("REPLICATE_ERROR_FMT", tostring(err or L("UNKNOWN_ERROR"))))
        return
    end

    -- Blizzard normally signals REPLICATE_ITEM_LIST_UPDATE. If the full-scan
    -- cooldown was already consumed elsewhere, that event may never arrive.
    -- Poll the client cache as a useful fallback instead of making the button
    -- appear completely broken.
    C_Timer.After(3, function()
        if token ~= self.scanToken or not self.scanRunning then return end
        if self.scanPhase ~= "waiting" then return end

        local cached = self:GetCachedReplicateCount()
        if cached > 0 then
            self.requestFallbackUsed = true
            self.currentSnapshotAt = time()
            self.currentAuctionCount = cached
            self.scanPhase = "collect"

            self:SetStatus(
                L("USING_CACHED_FMT", cached),
                0.04
            )
            self:CollectSnapshot(cached, false)
        end
    end)

    C_Timer.After(60, function()
        if token ~= self.scanToken or not self.scanRunning then return end
        if self.scanPhase ~= "waiting" and self.scanPhase ~= "throttle-wait" then return end

        local cached = self:GetCachedReplicateCount()
        if cached > 0 then
            self.requestFallbackUsed = true
            self.currentSnapshotAt = time()
            self.currentAuctionCount = cached
            self.scanPhase = "collect"
            self:SetStatus(
                L("FRESH_UNAVAILABLE_CACHED_FMT", cached),
                0.04
            )
            self:CollectSnapshot(cached, false)
            return
        end

        self:FailSnapshot(L("NO_FULL_SNAPSHOT"))
        FS:Print(L("NO_FULL_SNAPSHOT_CHAT"))
    end)
end


local PERSIST_FIELDS = {
    "itemID", "name", "link", "icon",
    "buy", "safeSell", "profit", "roi", "discount",
    "nextHigher", "gapRatio", "currentRef", "currentMedian",
    "historyMedian", "historyCount", "distinctPrices",
    "listingCount", "totalQty", "cheapestQty",
    "recommendedQty", "investment", "totalProfit",
    "source", "isEquipment", "equipLoc",
    "classID", "subClassID", "className", "subClassName",
    "quality", "canUse", "itemLevel", "levelType",
    "suspiciousMarket", "risk", "score", "rawScore", "scoreSuppressed",
    "oeAvailable", "oeRealm", "oeRegion", "oeReference", "oeReferenceKind", "localTargetBeforeOE",
}

local function CopySimpleTable(src)
    if type(src) ~= "table" then return nil end
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopySimpleTable(v)
        elseif type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
            dst[k] = v
        end
    end
    return dst
end

function S:SavePreviousScan(mode)
    if not FS.DB then return end

    local saved = {
        t = self.currentSnapshotAt > 0 and self.currentSnapshotAt or time(),
        auctions = self.currentAuctionCount or 0,
        mode = mode or "scan",
        items = {},
    }

    for itemID, r in pairs(self.lastAnalysis or {}) do
        local copy = {}

        for _, field in ipairs(PERSIST_FIELDS) do
            local value = r[field]
            if type(value) == "number"
                or type(value) == "string"
                or type(value) == "boolean" then
                copy[field] = value
            end
        end

        copy.itemID = tonumber(copy.itemID) or tonumber(itemID)

        if type(r.ladder) == "table" then
            copy.ladder = CopySimpleTable(r.ladder)
        end
        if type(r.suspiciousReasons) == "table" then
            copy.suspiciousReasons = CopySimpleTable(r.suspiciousReasons)
        end

        saved.items[tostring(itemID)] = copy
    end

    local market = FS:GetMarketState()
    if market then market.previousScan = saved end
end

function S:HasPreviousScan()
    local market = FS:GetMarketState()
    local prev = market and market.previousScan
    return type(prev) == "table"
        and type(prev.items) == "table"
        and next(prev.items) ~= nil
end

function S:GetPreviousScanInfo()
    local market = FS:GetMarketState()
    local prev = market and market.previousScan
    if type(prev) ~= "table" then return 0, 0, "" end
    return tonumber(prev.t) or 0, tonumber(prev.auctions) or 0, tostring(prev.mode or "")
end

function S:LoadPreviousScan(silent)
    if self.scanRunning then
        if not silent then FS:Print(L("WAIT_CURRENT_SCAN")) end
        return false
    end

    local market = FS:GetMarketState()
    local prev = market and market.previousScan
    if type(prev) ~= "table"
        or type(prev.items) ~= "table"
        or next(prev.items) == nil then
        if not silent then FS:Print(L("NO_PREVIOUS")) end
        return false
    end

    local restored = {}
    for key, r in pairs(prev.items) do
        if type(r) == "table" then
            local itemID = tonumber(r.itemID) or tonumber(key)
            if itemID then
                r.itemID = itemID
                r.watched = FS:IsWatched(itemID)
                restored[itemID] = r
            end
        end
    end

    self.lastAnalysis = restored
    self.currentSnapshotAt = tonumber(prev.t) or 0
    self.currentAuctionCount = tonumber(prev.auctions) or 0
    self.requestFallbackUsed = tostring(prev.mode or "") ~= "fresh"
    self.scanRunning = false
    self.scanPhase = nil
    self.progress = 1

    self:RebuildVisibleLists()

    local age = 0
    if self.currentSnapshotAt > 0 then
        age = math.max(0, time() - self.currentSnapshotAt)
    end

    self:SetStatus(
        L(
            "PREVIOUS_LOADED_STATUS_FMT",
            self.currentAuctionCount or 0,
            (function()
                local n = 0
                for _ in pairs(restored) do n = n + 1 end
                return n
            end)(),
            math.floor(age / 60)
        ),
        1
    )

    if not silent then
        FS:Print(L("PREVIOUS_LOADED_CHAT"))
    end

    if FS.UI then FS.UI:Refresh() end
    return true
end

function S:StartFullScan()
    if not FS.state.ahOpen then
        FS:Print(L("OPEN_AH_FIRST"))
        self:SetStatus(L("OPEN_AH_FIRST_STATUS"), 0)
        return
    end

    if self.scanRunning then
        FS:Print(L("SCAN_ALREADY_RUNNING"))
        return
    end

    if not C_AuctionHouse or type(C_AuctionHouse.ReplicateItems) ~= "function" then
        self:SetStatus(L("API_UNAVAILABLE"), 0)
        FS:Print(L("API_UNAVAILABLE_CHAT"))
        return
    end

    local knownCooldown = FS:GetKnownCooldown()
    if knownCooldown > 0 then
        self:SetStatus(
            L(
                "FULLSCAN_COOLDOWN_STATUS_FMT",
                math.floor(knownCooldown / 60),
                knownCooldown % 60
            ),
            0
        )
        FS:Print(L(
            "FULLSCAN_COOLDOWN_CHAT_FMT",
            math.floor(knownCooldown / 60),
            knownCooldown % 60
        ))
        return
    end

    -- Full Scan means exactly that: request a fresh Blizzard snapshot.
    -- It never silently swaps to a cached/previous result.
    self.scanRunning = true
    self.scanPhase = "waiting"
    self.scanToken = self.scanToken + 1
    self.requestStartedAt = GetTime()
    self.requestStartCachedCount = self:GetCachedReplicateCount()
    self.requestFallbackUsed = false
    if FS.StartScanDiagnostics then
        FS:StartScanDiagnostics("fresh", self.requestStartCachedCount)
    end

    local token = self.scanToken
    self:SetStatus(L("REQUESTING_FRESH"), 0.015)

    local ok, err = pcall(C_AuctionHouse.ReplicateItems)
    if not ok then
        self:FailSnapshot(L("REPLICATE_REJECTED_FRESH"))
        FS:Print(L("REPLICATE_ERROR_FMT", tostring(err or L("UNKNOWN_ERROR"))))
        return
    end

    self:SetStatus(L("REQUESTED_WAITING"), 0.025)

    C_Timer.After(2, function()
        if token ~= self.scanToken
            or not self.scanRunning
            or self.scanPhase ~= "waiting" then
            return
        end

        local cached = self:GetCachedReplicateCount()

        -- If the cache count changed, Blizzard delivered a new replicate list even if
        -- the normal REPLICATE_ITEM_LIST_UPDATE event was missed.
        if cached > 0 and cached ~= self.requestStartCachedCount then
            self.currentSnapshotAt = time()
            self.currentAuctionCount = cached
            self.scanPhase = "collect"
            self.requestFallbackUsed = false

            local market = FS:GetMarketState()
            if market then
                market.lastFullScanAt = self.currentSnapshotAt
                market.lastSuccessfulScanAt = self.currentSnapshotAt
                market.lastSnapshotAuctionCount = cached
            end

            self:SetStatus(
                L("FRESH_DETECTED_FMT", cached),
                0.04
            )
            self:CollectSnapshot(cached, true)
        end
    end)

    C_Timer.After(30, function()
        if token ~= self.scanToken
            or not self.scanRunning
            or self.scanPhase ~= "waiting" then
            return
        end

        self:FailSnapshot(L("NO_FRESH_RETURNED"))
        FS:Print(L("NO_FRESH_RETURNED_CHAT"))
    end)
end

function S:OnThrottleEvent(event)
    if FS.RecordDiagnosticEvent then
        FS:RecordDiagnosticEvent("ah-throttle", event)
    end

    if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        self.throttleReadyAt = GetTime()

        if self.scanRunning and self.scanPhase == "throttle-wait" then
            self:SetStatus(L("THROTTLE_READY"), 0.015)
            self:RequestSnapshotNow()
        end
        return
    end

    if not self.scanRunning then return end

    if event == "AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED" then
        self:SetStatus(L("BLIZZARD_QUEUED"), 0.02)

    elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT" then
        self:SetStatus(L("SNAPSHOT_SENT"), 0.025)

    elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED" then
        if self.scanPhase == "waiting" then
            self:SetStatus(L("BLIZZARD_RESPONDED"), 0.03)
        end

    elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" then
        self:FailSnapshot(L("BLIZZARD_DROPPED"))
        FS:Print(L("BLIZZARD_DROPPED_CHAT"))
    end
end

function S:AnalyzeCachedSnapshot()
    if self.scanRunning then
        FS:Print(L("SCAN_RUNNING_GENERIC"))
        return
    end

    if not C_AuctionHouse or not C_AuctionHouse.GetNumReplicateItems then return end
    local n = C_AuctionHouse.GetNumReplicateItems() or 0

    if n <= 0 then
        FS:Print(L("NO_CACHED"))
        return
    end

    self.scanRunning = true
    self.scanPhase = "collect"
    self.scanToken = self.scanToken + 1
    self.currentSnapshotAt = time()
    self.currentAuctionCount = n
    self.requestFallbackUsed = true
    if FS.StartScanDiagnostics then
        FS:StartScanDiagnostics("cached", n)
    end
    if FS.UpdateScanDiagnostics then
        FS:UpdateScanDiagnostics({ stage = "collect", auctions = n })
    end
    self:SetStatus(L("ANALYZING_CACHED_FMT", n), 0.03)
    self:CollectSnapshot(n, false)
end

function S:OnReplicateUpdate()
    if not self.scanRunning or self.scanPhase ~= "waiting" then return end

    local n = self:GetCachedReplicateCount()
    if not n or n <= 0 then return end

    self.scanPhase = "collect"
    self.currentSnapshotAt = time()
    self.currentAuctionCount = n
    self.requestFallbackUsed = false
    if FS.UpdateScanDiagnostics then
        FS:UpdateScanDiagnostics({ stage = "snapshot-received", auctions = n })
    end
    if FS.RecordDiagnosticEvent then
        FS:RecordDiagnosticEvent("replicate-update", tostring(n) .. " auctions")
    end

    local market = FS:GetMarketState()
    if market then
        market.lastFullScanAt = self.currentSnapshotAt
        market.lastSuccessfulScanAt = self.currentSnapshotAt
        market.lastSnapshotAuctionCount = n
    end

    self:SetStatus(L("FRESH_RECEIVED_FMT", n), 0.04)
    self:CollectSnapshot(n, true)
end

function S:CollectSnapshot(total, freshSnapshot)
    if FS.UpdateScanDiagnostics then
        FS:UpdateScanDiagnostics({
            stage = "collect",
            auctions = tonumber(total) or 0,
            freshSnapshot = freshSnapshot == true,
        })
    end
    if FS.RecordDiagnosticEvent then
        FS:RecordDiagnosticEvent("collect-start", tostring(total or 0) .. " auctions")
    end

    local token = self.scanToken
    local grouped = {}
    local index = 0
    local CHUNK = 180

    local function addAuction(i)
        local name, texture, count, quality, canUse, level, levelType, _, _, buyoutPrice, _, _, _, _, _, saleStatus, itemID =
            C_AuctionHouse.GetReplicateItemInfo(i)

        itemID = tonumber(itemID)
        count = math.max(1, tonumber(count) or 1)
        buyoutPrice = tonumber(buyoutPrice) or 0

        if not itemID or itemID <= 0 or buyoutPrice <= 0 or tonumber(saleStatus or 0) ~= 0 then
            return
        end

        local unit = buyoutPrice / count
        if unit <= 0 then return end

        local group = grouped[itemID]
        if not group then
            group = {
                itemID = itemID,
                prices = {},
                name = name,
                icon = texture,
                quality = tonumber(quality),
                canUse = canUse,
                itemLevel = tonumber(level) or 0,
                levelType = levelType,
            }
            grouped[itemID] = group
        else
            if not group.name and name and name ~= "" then group.name = name end
            if not group.icon and texture then group.icon = texture end
            if group.quality == nil and quality ~= nil then group.quality = tonumber(quality) end
            if group.canUse == nil and canUse ~= nil then group.canUse = canUse end
            if (group.itemLevel or 0) <= 0 and tonumber(level) then group.itemLevel = tonumber(level) end
            if not group.levelType and levelType then group.levelType = levelType end
        end

        local bucket = group.prices[unit]
        if not bucket then
            bucket = { qty = 0, listings = 0 }
            group.prices[unit] = bucket
        end

        bucket.qty = bucket.qty + count
        bucket.listings = bucket.listings + 1

        if name and FS.IsRealItemName(name, itemID) then
            FS:CacheItemIdentity(itemID, name, nil, texture)
        end
    end

    local function step()
        if token ~= self.scanToken or not self.scanRunning then return end

        local stop = math.min(total - 1, index + CHUNK - 1)

        for i = index, stop do
            addAuction(i)
        end

        index = stop + 1
        local p = total > 0 and (index / total) or 1
        self:SetStatus(
            L("READING_AUCTIONS_FMT", math.min(index, total), total),
            0.03 + p * 0.42
        )

        if index < total then
            C_Timer.After(0.02, step)
        else
            self.grouped = grouped
            self:AnalyzeGroups(grouped, freshSnapshot)
        end
    end

    step()
end

function S:AnalyzeGroups(grouped, freshSnapshot)
    local token = self.scanToken
    local ids = {}
    for itemID in pairs(grouped) do ids[#ids + 1] = itemID end
    table.sort(ids)

    local pos = 1
    local total = #ids
    local CHUNK = 80
    local analyzed = {}
    local candidates = {}
    local watchResults = {}
    local statsByItem = {}

    local function analyzeItem(itemID)
        local group = grouped[itemID]
        local gs = BuildGroupStats(group)
        if not gs or not gs.cheapest or gs.cheapest <= 0 then return end

        local historyMedian, historyCount = GetHistoryStats(itemID)

        local name, link, icon = FS:ResolveItemData(itemID)
        name = name or group.name
        icon = icon or group.icon

        local oeData
        local oeReference
        local oeReferenceKind
        if FS.Undermine and FS.Undermine.IsAvailable and FS.Undermine:IsAvailable() then
            oeData = FS.Undermine:GetItemData(itemID, link)
            oeReference, oeReferenceKind = FS.Undermine:GetReference(oeData)
        end

        local target
        local source

        if gs.currentRef and historyMedian and historyMedian > 0 then
            -- Do not let a temporarily inflated current market drag the target far above
            -- recent history. Conversely, current depth prevents stale history from
            -- forcing a target far above today's market.
            target = math.min(gs.currentRef, historyMedian * 1.10)
            source = "current market + history"

        elseif gs.currentRef then
            target = gs.currentRef
            source = "current market gap"

        elseif historyMedian and historyCount >= (FS.DB.settings.historyMinScans or 2) then
            target = historyMedian
            source = "DealScryer history"

        else
            -- Undermine Exchange corroborates DealScryer's own market evidence;
            -- it is deliberately not used as the sole reason to create a flip.
            statsByItem[itemID] = {
                reference = gs.median or gs.cheapest,
                cheapest = gs.cheapest,
                median = gs.median,
                totalQty = gs.totalQty,
            }
            return
        end

        local localTargetBeforeOE = target
        if oeReference and oeReference > 0 then
            -- Conservative secondary ceiling: UE may reduce an optimistic target
            -- but is never allowed to inflate DealScryer's target.
            target = math.min(target, oeReference * 1.10)
            source = source .. " + Undermine Exchange"
        end

        if not target or target <= gs.cheapest then
            statsByItem[itemID] = {
                reference = gs.currentRef or gs.median or gs.cheapest,
                cheapest = gs.cheapest,
                median = gs.median,
                totalQty = gs.totalQty,
            }
            return
        end

        local netSale = target * 0.95
        local profit = netSale - gs.cheapest
        local roi = gs.cheapest > 0 and profit / gs.cheapest or 0
        local discount = 1 - (gs.cheapest / target)
        local gapRatio = gs.nextHigher and ((gs.nextHigher / gs.cheapest) - 1) or 0

        local info = GetClassInfo(itemID)
        local maxByBudget = math.max(1, math.floor(
            ((FS.DB.settings.budgetGold or 100000) * FS.GOLD) / gs.cheapest
        ))
        local recommendedQty = math.max(1, math.min(
            tonumber(gs.cheapestQty) or 1,
            maxByBudget,
            20
        ))

        icon = icon or info.icon

        local r = {
            itemID = itemID,
            name = name,
            link = link,
            icon = icon,
            buy = gs.cheapest,
            safeSell = target,
            profit = profit,
            roi = roi,
            discount = discount,
            nextHigher = gs.nextHigher,
            gapRatio = gapRatio,
            currentRef = gs.currentRef,
            currentMedian = gs.median,
            historyMedian = historyMedian,
            historyCount = historyCount,
            oeAvailable = oeData ~= nil,
            oeRealm = oeData and oeData.realm or nil,
            oeRegion = oeData and oeData.region or nil,
            oeReference = oeReference,
            oeReferenceKind = oeReferenceKind,
            localTargetBeforeOE = localTargetBeforeOE,
            distinctPrices = gs.distinctPrices,
            listingCount = gs.listingCount,
            totalQty = gs.totalQty,
            cheapestQty = gs.cheapestQty,
            recommendedQty = recommendedQty,
            investment = gs.cheapest * recommendedQty,
            totalProfit = profit * recommendedQty,
            source = source,
            ladder = BuildLadder(gs.levels),
            isEquipment = info.isEquipment,
            equipLoc = info.equipLoc,
            classID = info.classID,
            subClassID = info.subClassID,
            className = info.className,
            subClassName = info.subClassName,
            quality = group.quality,
            canUse = group.canUse,
            itemLevel = group.itemLevel or 0,
            levelType = group.levelType,
        }

        local suspicious, suspiciousReasons = DetectSuspiciousMarket(r)
        r.suspiciousMarket = suspicious
        r.suspiciousReasons = suspiciousReasons

        r.risk = BuildRisk(r)
        r.rawScore = ScoreResult(r)
        r.score = r.rawScore
        r.scoreSuppressed = false

        if r.suspiciousMarket then
            -- Suspicious markets are intentionally unscored. Their market
            -- reference is too unreliable for the normal 0–100 ranking.
            -- Internally they sort at the bottom and cannot trigger score alerts.
            r.score = 0
            r.scoreSuppressed = true
        end

        r.watched = FS:IsWatched(itemID)

        analyzed[itemID] = r

        if PassesDealFilters(r) then
            self.results[#self.results + 1] = r
        elseif IsCandidate(r) then
            candidates[#candidates + 1] = r
        end

        if r.watched then
            watchResults[#watchResults + 1] = r
        end

        statsByItem[itemID] = {
            reference = gs.currentRef or gs.median or target,
            cheapest = gs.cheapest,
            median = gs.median,
            totalQty = gs.totalQty,
        }
    end

    wipe(self.results)

    local function finish()
        self.lastAnalysis = analyzed
        self.candidates = candidates
        self.watchResults = watchResults

        local function sorter(a, b)
            if (a.score or 0) == (b.score or 0) then
                return (a.profit or 0) > (b.profit or 0)
            end
            return (a.score or 0) > (b.score or 0)
        end

        table.sort(self.results, sorter)
        table.sort(self.candidates, sorter)
        table.sort(self.watchResults, sorter)

        -- Update history only after all current deals were scored, so the current scan
        -- never becomes its own historical reference.
        for itemID, hs in pairs(statsByItem) do
            UpdateHistory(itemID, hs)
        end

        local now = self.currentSnapshotAt > 0 and self.currentSnapshotAt or time()
        local market = FS:GetMarketState()
        if market then
            market.scanSessions = type(market.scanSessions) == "table" and market.scanSessions or {}
            table.insert(market.scanSessions, {
                t = now,
                auctions = self.currentAuctionCount or 0,
                items = total,
                deals = #self.results,
                candidates = #self.candidates,
                topScore = self.results[1] and self.results[1].score or 0,
            })
            while #market.scanSessions > 40 do
                table.remove(market.scanSessions, 1)
            end
        end

        local topScore = self.results[1] and self.results[1].score or 0
        if FS.FinishScanDiagnostics then
            FS:FinishScanDiagnostics(true, {
                mode = self.requestFallbackUsed and "cached" or "fresh",
                auctions = self.currentAuctionCount or 0,
                items = total,
                deals = #self.results,
                candidates = #self.candidates,
                topScore = topScore,
            })
        end

        self.scanRunning = false
        self.scanPhase = nil
        local mode = self.requestFallbackUsed and "cached" or "fresh"
        local modeLabel = self.requestFallbackUsed and L("MODE_CACHED") or L("MODE_FRESH")

        self:SavePreviousScan(mode)

        self:SetStatus(
            L(
                "COMPLETE_FMT",
                modeLabel,
                self.currentAuctionCount or 0,
                total,
                #self.results,
                #self.candidates
            ),
            1
        )

        self:FireAlerts()
        if FS.UI then FS.UI:Refresh() end
    end

    local function step()
        if token ~= self.scanToken or not self.scanRunning then return end

        local stop = math.min(total, pos + CHUNK - 1)
        for i = pos, stop do
            analyzeItem(ids[i])
        end
        pos = stop + 1

        local p = total > 0 and ((pos - 1) / total) or 1
        self:SetStatus(
            L("SCORING_MARKET_FMT", math.min(pos - 1, total), total),
            0.45 + p * 0.52
        )

        if pos <= total then
            C_Timer.After(0.01, step)
        else
            finish()
        end
    end

    step()
end

function S:FireAlerts()
    if not FS.DB.settings.alerts then return end
    local threshold = tonumber(FS.DB.settings.alertScore) or 80

    local shown = 0
    for _, r in ipairs(self.results) do
        if (r.score or 0) >= threshold and shown < 5 then
            local name = r.name or L("ITEM_FALLBACK_FMT", r.itemID)
            FS:Print(L(
                "ALERT_DEAL_FMT",
                name,
                FS:Money(r.buy, true),
                FS:Money(r.safeSell, true),
                FS:Money(r.profit, true),
                r.score or 0
            ))
            shown = shown + 1
        end
    end

    for key, watch in pairs(FS.DB.watchlist or {}) do
        local itemID = tonumber(key)
        local r = itemID and self.lastAnalysis[itemID]
        if r then
            local pct = tonumber(watch.thresholdPct) or 70
            if r.buy <= r.safeSell * (pct / 100) then
                FS:Print(L(
                    "WATCH_ALERT_FMT",
                    r.name or L("ITEM_FALLBACK_FMT", itemID),
                    (r.buy / r.safeSell) * 100,
                    FS:Money(r.buy, true),
                    FS:Money(r.safeSell, true)
                ))
            end
        end
    end
end

function S:RefreshItemData(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end

    local name, link, icon = FS:ResolveItemData(itemID)
    local r = self.lastAnalysis[itemID]
    if r then
        if name then r.name = name end
        if link then r.link = link end
        if icon then r.icon = icon end
    end
end

function S:RebuildVisibleLists()
    self.visibleRevision = (tonumber(self.visibleRevision) or 0) + 1
    self.results = {}
    self.candidates = {}
    self.watchResults = {}

    for itemID, r in pairs(self.lastAnalysis or {}) do
        r.watched = FS:IsWatched(itemID)

        if PassesDealFilters(r) then
            self.results[#self.results + 1] = r
        elseif IsCandidate(r) then
            self.candidates[#self.candidates + 1] = r
        end

        if r.watched then
            self.watchResults[#self.watchResults + 1] = r
        end
    end

    local function sorter(a, b)
        if (a.score or 0) == (b.score or 0) then
            return (a.profit or 0) > (b.profit or 0)
        end
        return (a.score or 0) > (b.score or 0)
    end

    table.sort(self.results, sorter)
    table.sort(self.candidates, sorter)
    table.sort(self.watchResults, sorter)
end

function S:SetSort(key)
    local st = FS.DB.settings
    if st.sort == key then
        st.sortDesc = not st.sortDesc
    else
        st.sort = key
        st.sortDesc = true
    end
    if FS.UI then FS.UI:RefreshRows() end
end

function S:GetVisibleList(tab, searchText)
    local list
    if tab == "watch" then
        list = self.watchResults
    elseif tab == "candidates" then
        list = self.candidates
    else
        list = self.results
    end

    local filtered = {}
    local q = (searchText or ""):lower()
    local opt = FS.DB.searchOptions or {}

    local minPrice = math.max(0, tonumber(opt.minPriceGold) or 0) * FS.GOLD
    local maxPrice = math.max(0, tonumber(opt.maxPriceGold) or 0) * FS.GOLD
    local minLevel = math.max(0, tonumber(opt.minItemLevel) or 0)
    local maxLevel = math.max(0, tonumber(opt.maxItemLevel) or 0)
    local minQuality = tonumber(opt.minQuality) or -1
    local classID = tonumber(opt.classID) or -1
    local minQty = math.max(0, tonumber(opt.minQuantity) or 0)

    for _, r in ipairs(list or {}) do
        local name = (r.name or ""):lower()
        local textMatch = q == ""
            or name:find(q, 1, true)
            or tostring(r.itemID):find(q, 1, true)

        local priceOK = (minPrice <= 0 or (r.buy or 0) >= minPrice)
            and (maxPrice <= 0 or (r.buy or 0) <= maxPrice)

        local level = tonumber(r.itemLevel) or 0
        local levelOK = (minLevel <= 0 or level >= minLevel)
            and (maxLevel <= 0 or level <= maxLevel)

        local quality = tonumber(r.quality)
        local qualityOK = minQuality < 0 or (quality ~= nil and quality >= minQuality)

        local classOK = classID < 0 or tonumber(r.classID) == classID
        local usableOK = not opt.onlyUsable or r.canUse == true
        local equipmentOK = not opt.equipmentOnly or r.isEquipment == true
        local quantityOK = minQty <= 0 or (tonumber(r.totalQty) or 0) >= minQty

        if textMatch
            and priceOK
            and levelOK
            and qualityOK
            and classOK
            and usableOK
            and equipmentOK
            and quantityOK then
            filtered[#filtered + 1] = r
        end
    end

    local key = FS.DB.settings.sort or "score"
    local desc = FS.DB.settings.sortDesc ~= false

    table.sort(filtered, function(a, b)
        local av, bv
        if key == "name" then
            av = a.name or ""
            bv = b.name or ""
        elseif key == "buy" then
            av, bv = a.buy or 0, b.buy or 0
        elseif key == "profit" then
            av, bv = a.profit or 0, b.profit or 0
        elseif key == "roi" then
            av, bv = a.roi or 0, b.roi or 0
        elseif key == "discount" then
            av, bv = a.discount or 0, b.discount or 0
        else
            av, bv = a.score or 0, b.score or 0
        end

        if av == bv then
            return (a.itemID or 0) < (b.itemID or 0)
        end

        if desc then return av > bv end
        return av < bv
    end)

    return filtered
end
