# Changelog

## 3.1.2 — Oribos Exchange 4-day trend

- Added a compact Oribos Exchange 4-day trend graph to the selected-item panel.
- DealScryer now records Oribos Exchange rolling-median snapshots locally for up to four days.
- Graph prefers realm data and falls back to region data.
- Shows the latest OE market value directly on the graph.
- Uses a sparkline when Retail's line drawing API is available, with point markers as fallback.
- Clarified that Oribos Exchange exposes a rolling 4-day median, not a retroactive day-by-day time series.

## 3.1.1 — creator credit

- Added **by Burn** beside the DealScryer version in the main window.
- Added creator tooltip.
- Updated addon metadata to list **Burn** as the author.
- Added creator credit to the user manual and CurseForge materials.

## 3.1.0 — Undermine Exchange integration

- Added integration with the official Oribos Exchange addon.
- Shows Undermine Exchange realm and region market values directly in DealScryer details/tooltips.
- Uses the external market value as a conservative secondary reference.
- External data can lower an optimistic target, but never raise it.
- Adds confidence when external/local values agree and risk when they strongly disagree.
- Adds Settings connection status.
- Clarifies that the data is recent listing-price history/medians, not confirmed completed-sale transactions.
- Added `OribosExchange` as an optional in-game dependency for load ordering.

## 3.0.4 — responsive UI & Auction House launcher

- Raised the safe minimum DealScryer window size to prevent Settings text from leaving its panels.
- Added clipping to Settings, results and detail content panels.
- Reworked the Settings footer so it no longer overlaps Apply / Defaults / Clear History.
- Constrained provider/status text so it cannot run underneath neighboring controls while resizing.
- Prevented hidden result panels from being refreshed while Settings is open.
- Moved the in-Auction-House DealScryer coin button into Blizzard's Buy / Sell / Auctions bottom-tab row.
- Auction House DealScryer button now toggles the addon open/closed.

## 3.0.3 — direct item price-history links

- Reworded the right-click price-history action to display the complete Undermine Exchange link directly.
- The generated link now includes the currently detected region, current realm/server, and selected item ID.
- The copy window shows the exact full URL plus region, server, item name and item ID.
- Added realm-slug normalization for common Latin Retail realm names.

## 3.0.2 — faster scrolling & result loading

- Added a visible draggable scrollbar to the results table.
- Mouse-wheel scrolling now works directly over result rows and the results panel.
- Increased mouse-wheel movement to four rows per wheel step.
- Prefetches item names/icons for the visible page, two pages ahead, and one page behind.
- Batches asynchronous item-data updates instead of refreshing the entire DealScryer UI for every individual item.
- Ignores unrelated global `ITEM_DATA_LOAD_RESULT` events.
- Removed the duplicate item-data request previously sent for unresolved items.
- Added a cached filtered/sorted visible list so scrolling does not repeatedly filter and sort the entire result set.

## 3.0.1 — suspicious score display & in-game icon fix

- Restored Blizzard's classic coin icon for all in-game DealScryer branding.
- The CurseForge project artwork remains separate from the in-game icon.
- Suspicious items no longer show a numerical score.
- Suspicious items now display a large red **!** in the Score column.
- Suspicious items sort below normal score-ranked opportunities and do not trigger score alerts.
- Tooltips, exports, Settings, and documentation now describe suspicious items as **unscored** instead of using the old 45-point safety cap.

## 3.0.0 — DealScryer rebrand & global region support

- Renamed FlipScout to **DealScryer**.
- Added automatic live-region detection using Battle.net game-account region data with `GetCurrentRegion()` fallback.
- Added region-aware local markets so history and Previous Scan data never mix between realms/regions.
- Supports US/NA, Brazil, Oceania/Australia, EU, KR, TW and CN for in-game scanning.
- Added detected region/realm to diagnostics and the dashboard provider line.
- Undermine Exchange hints now map Oceania/Australia to its `us` region and clearly explain when the external provider does not cover the detected region.
- Added `/dealscryer` and `/ds`; legacy `/fs` remains available.



## 2.8.0

### Branding
- Added a custom DealScryer icon.
- Added the icon beside the DealScryer title.
- Added the icon to the minimap button and addon metadata.

### Score system
- Added WoW-style rarity colors for scores.
- White: 0–49 Poor.
- Green: 50–64 Good.
- Blue: 65–79 Rare.
- Purple: 80–89 Epic.
- Orange: 90–100 Legendary.
- Added score-system explanation to Settings and documentation.
- Suspicious market results now preserve their raw score internally while the displayed score remains capped at a maximum of 45.
- Added an in-addon explanation of why 45 is used as the suspicious-market safety ceiling.

### Distribution
- Added CurseForge-ready documentation.
- Declared Retail interface 120100 and 120105.
