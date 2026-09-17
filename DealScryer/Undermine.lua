local FS = _G.DealScryer
if not FS then return end

local U = { cache = {} }
FS.Undermine = U

local function PositiveNumber(value)
    value = tonumber(value)
    if value and value > 0 then return value end
    return nil
end

function U:IsAvailable()
    return type(_G.OEMarketInfo) == "function"
end

function U:GetAddonVersion()
    if not C_AddOns or not C_AddOns.GetAddOnMetadata then return nil end
    local ok, value = pcall(C_AddOns.GetAddOnMetadata, "OribosExchange", "Version")
    if ok and value and value ~= "" then return tostring(value) end
    return nil
end

function U:GetStatus()
    if self:IsAvailable() then
        local version = self:GetAddonVersion()
        return true, version and ("Oribos Exchange " .. version) or "Oribos Exchange"
    end
    return false, "Oribos Exchange not installed"
end

function U:ClearCache()
    wipe(self.cache)
end

function U:RecordHistorySnapshot(itemID, data)
    itemID = tonumber(itemID)
    if not itemID or type(data) ~= "table" then return end

    local realm = PositiveNumber(data.realm)
    local region = PositiveNumber(data.region)
    if not realm and not region then return end

    local market = FS:GetMarketState()
    if not market then return end

    market.oeHistory = type(market.oeHistory) == "table" and market.oeHistory or {}
    local key = tostring(itemID)
    local samples = market.oeHistory[key]
    if type(samples) ~= "table" then
        samples = {}
        market.oeHistory[key] = samples
    end

    local now = time()
    local last = samples[#samples]

    local changed = not last
        or tonumber(last.realm) ~= realm
        or tonumber(last.region) ~= region
    local oldEnough = not last or (now - (tonumber(last.t) or 0)) >= 60 * 60

    if changed or oldEnough then
        samples[#samples + 1] = {
            t = now,
            realm = realm,
            region = region,
        }
    end

    local cutoff = now - (4 * 24 * 60 * 60)
    local kept = {}
    for _, sample in ipairs(samples) do
        if type(sample) == "table" and (tonumber(sample.t) or 0) >= cutoff then
            kept[#kept + 1] = sample
        end
    end

    while #kept > 96 do
        table.remove(kept, 1)
    end

    market.oeHistory[key] = kept
end

function U:GetHistory(itemID)
    itemID = tonumber(itemID)
    if not itemID then return {} end

    local market = FS:GetMarketState()
    local samples = market
        and market.oeHistory
        and market.oeHistory[tostring(itemID)]
        or {}

    local cutoff = time() - (4 * 24 * 60 * 60)
    local out = {}

    for _, sample in ipairs(samples or {}) do
        if type(sample) == "table" and (tonumber(sample.t) or 0) >= cutoff then
            out[#out + 1] = sample
        end
    end

    table.sort(out, function(a, b)
        return (tonumber(a.t) or 0) < (tonumber(b.t) or 0)
    end)

    return out
end

function U:GetItemData(itemID, itemLink)
    itemID = tonumber(itemID)
    if not itemID or not self:IsAvailable() then return nil end

    local key = tostring(itemLink or ("item:" .. itemID))
    local cached = self.cache[key]
    if cached ~= nil then
        if cached then self:RecordHistorySnapshot(itemID, cached) end
        return cached or nil
    end

    local function query(value)
        local out = {}
        local ok = pcall(_G.OEMarketInfo, value, out)
        if not ok then return nil end

        local realm = PositiveNumber(out.market)
        local region = PositiveNumber(out.region)
        if not realm and not region then return nil end

        return {
            realm = realm,
            region = region,
            source = "Undermine Exchange / Oribos Exchange",
        }
    end

    local data = query(itemLink or ("item:" .. itemID))
    if not data and itemLink then
        data = query("item:" .. itemID)
    end

    self.cache[key] = data or false
    if data then
        self:RecordHistorySnapshot(itemID, data)
    end
    return data
end

function U:GetReference(data)
    if type(data) ~= "table" then return nil, nil end
    if PositiveNumber(data.realm) then return tonumber(data.realm), "realm" end
    if PositiveNumber(data.region) then return tonumber(data.region), "region" end
    return nil, nil
end

function U:ApplyToResult(result)
    if type(result) ~= "table" or not result.itemID then return nil end

    local data = self:GetItemData(result.itemID, result.link)
    if not data then
        result.oeAvailable = false
        return nil
    end

    result.oeAvailable = true
    result.oeRealm = data.realm
    result.oeRegion = data.region

    local ref, kind = self:GetReference(data)
    result.oeReference = ref
    result.oeReferenceKind = kind
    return data
end
