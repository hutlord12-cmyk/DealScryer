local FS = _G.DealScryer
if not FS then return end

local function L(key, ...)
    return FS:L(key, ...)
end

local T = { initialized = false }
FS.Tooltip = T

function T:Initialize()
    if self.initialized then return end
    self.initialized = true

    if not TooltipDataProcessor
        or not TooltipDataProcessor.AddTooltipPostCall
        or not Enum
        or not Enum.TooltipDataType then
        return
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not FS.DB or not FS.DB.settings.tooltip then return end
        if not data then return end

        local itemID = tonumber(data.id)
        if not itemID and data.hyperlink then
            itemID = tonumber(data.hyperlink:match("item:(%d+)"))
        end
        if not itemID then return end

        local r = FS.Scanner and FS.Scanner.lastAnalysis and FS.Scanner.lastAnalysis[itemID]
        if not r then return end

        tooltip:AddLine(" ")
        tooltip:AddLine("|cffF5C542DealScryer|r")
        tooltip:AddDoubleLine(
            L("TOOLTIP_BUY_TARGET"),
            FS:Money(r.buy, true) .. " / " .. FS:Money(r.safeSell, true),
            0.8,0.8,0.8,
            1,0.82,0
        )
        tooltip:AddDoubleLine(
            L("TOOLTIP_PROFIT_ROI"),
            FS:Money(r.profit, true) .. " / " .. string.format("%.0f%%", (r.roi or 0) * 100),
            0.8,0.8,0.8,
            0.35,1,0.35
        )
        if r.suspiciousMarket or r.scoreSuppressed then
            tooltip:AddDoubleLine(
                L("TOOLTIP_SCORE_HISTORY"),
                "! / " .. tostring(r.historyCount or 0) .. L("TOOLTIP_SCANS_SUFFIX"),
                0.8,0.8,0.8,
                1.0,0.12,0.12
            )
        else
            local scoreTier = FS:GetScoreTier(r.score or 0)
            tooltip:AddDoubleLine(
                L("TOOLTIP_SCORE_HISTORY"),
                tostring(r.score or 0) .. " (" .. scoreTier.name .. ") / "
                    .. tostring(r.historyCount or 0) .. L("TOOLTIP_SCANS_SUFFIX"),
                0.8,0.8,0.8,
                scoreTier.r, scoreTier.g, scoreTier.b
            )
        end

        if FS.Undermine and FS.Undermine.ApplyToResult then
            FS.Undermine:ApplyToResult(r)
        end
        if r.oeRealm then
            tooltip:AddDoubleLine(
                L("TT_UNDERMINE_REALM"),
                FS:Money(r.oeRealm, true),
                0.8,0.8,0.8,
                0.40,0.72,1.0
            )
        end
        if r.oeRegion then
            tooltip:AddDoubleLine(
                L("TT_UNDERMINE_REGION"),
                FS:Money(r.oeRegion, true),
                0.8,0.8,0.8,
                0.40,0.72,1.0
            )
        end
    end)
end
