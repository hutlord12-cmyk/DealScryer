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

function U:GetAddonState()
    local state = {
        exists = false,
        loaded = false,
        loadable = false,
        reason = nil,
        version = self:GetAddonVersion(),
        available = self:IsAvailable(),
    }

    if not C_AddOns then
        return state
    end

    if C_AddOns.DoesAddOnExist then
        local ok, exists = pcall(C_AddOns.DoesAddOnExist, "OribosExchange")
        if ok then state.exists = exists == true end
    end

    if C_AddOns.GetAddOnInfo then
        local ok, name, _, _, loadable, reason = pcall(C_AddOns.GetAddOnInfo, "OribosExchange")
        if ok and name then
            state.exists = true
            state.loadable = loadable == true
            state.reason = reason
        end
    end

    if C_AddOns.IsAddOnLoaded then
        local ok, loadedOrLoading, loaded = pcall(C_AddOns.IsAddOnLoaded, "OribosExchange")
        if ok then
            state.loaded = loaded == true or loadedOrLoading == true
        end
    end

    if state.available then
        state.exists = true
        state.loaded = true
        state.loadable = true
        state.reason = nil
    end

    return state
end

local function FriendlyReason(reason)
    reason = tostring(reason or "")
    if reason == "INCOMPATIBLE" or reason == "WRONG_GAME_TYPE"
        or reason == "WRONG_ACTIVE_INTERFACE" or reason == "NO_ACTIVE_INTERFACE" then
        return "incompatible with this WoW client"
    elseif reason == "INTERFACE_VERSION" then
        return "out of date for this WoW client"
    elseif reason == "DISABLED" then
        return "disabled"
    elseif reason == "DEP_DISABLED" then
        return "blocked by a disabled dependency"
    elseif reason == "DEP_INCOMPATIBLE" or reason == "DEP_INTERFACE_VERSION" then
        return "blocked by an incompatible dependency"
    elseif reason ~= "" and reason ~= "nil" then
        return string.lower(reason:gsub("_", " "))
    end
    return nil
end

function U:GetStatus()
    local version = self:GetAddonVersion()
    local base = version and ("Oribos Exchange " .. version) or "Oribos Exchange"

    if self:IsAvailable() then
        return true, base, self:GetAddonState()
    end

    local state = self:GetAddonState()
    if state.exists then
        local reason = FriendlyReason(state.reason)
        if state.loaded then
            return false, base .. " is loaded, but OEMarketInfo is unavailable", state
        elseif reason then
            return false, base .. " is installed but " .. reason, state
        else
            return false, base .. " is installed but not loaded", state
        end
    end

    return false, "Oribos Exchange is not installed", state
end

function U:GetUnavailableText()
    local connected, label = self:GetStatus()
    if connected then return nil end
    return "Undermine Exchange • " .. tostring(label or "Oribos Exchange unavailable")
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

    -- Keep enough points for a readable 4-day sparkline without growing
    -- SavedVariables aggressively. If the value changes, record immediately;
    -- otherwise one point per hour is enough.
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
