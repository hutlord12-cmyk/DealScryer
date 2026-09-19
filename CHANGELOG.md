# Changelog

## 3.2.0 — clearer evidence and trading tools

- Centered and bounded graph empty-state text, with wrapping and clipping; shortened Oribos failure messages.
- Reduced the Oribos panel when its market API is unavailable and tightened detail-panel graph sizing.
- Added compact result columns by default, with a persisted Advanced/Compact switch and aligned numeric columns.
- Added Why this deal? with score context, discount, price gap, historical observations, sources and concrete risk reasons.
- Added scan age to item details and explicit distinctions between source version, observations and confirmed sales.
- Keep suspicious items below ordinary opportunities for every sort; exclude their profit from the top-profit metric.
- Added all/hide/only suspicious-market filters and editable minimum ROI under Search Options.
- Added Small Budget, Materials and High Margin presets plus named, saved custom search profiles.
- Added hover date/price inspection for local history; limited plotted samples to panel width and labelled sparse history as collecting.
- Added absolute per-item watch-price targets and price-change/threshold-entry alert deduplication scoped to the market.
- Added a manual, market-scoped journal for completed trades: quantity, purchase total, gross proceeds, fees, signed realized profit, paging, undo/restore and export.
- Preserved standalone operation, English interface, creator credit, the classic coin icon and existing AH search/open behavior.
- Added headless regression coverage and a Lua 5.1 CI regression step. Live WoW rendering and third-party compatibility still require in-game verification.


## 3.1.5 — movable launcher and Oribos recovery

- Placed the AH shortcut above the top-left edge, outside title-bar controls and tabs.
- Added Shift-drag with saved position, screen clamping, and right-click reset.
- Retry failed/missing Oribos lookups after 10 seconds on the next lookup; refresh successful cached values after five minutes.
- Clear Oribos cache when the provider loads, and remove obsolete market values when a lookup becomes unavailable.
- Distinguish provider lookup errors from missing item data in item details.
- Relabel the graph as local history to distinguish it from the provider’s four-day median.
- Validated with mocked Lua checks; in-game compatibility still requires testing.


## 3.1.4 — Oribos compatibility status & AH launcher

- DealScryer now distinguishes between Oribos Exchange being missing, disabled, out of date, incompatible, loaded without `OEMarketInfo`, or fully connected.
- The selected-item panel, 4-day Oribos graph and Settings page now show the real Oribos load problem instead of incorrectly saying "not installed".
- This makes WoW patch/version mismatches much easier to diagnose.
- Moved the in-Auction-House DealScryer launcher away from Blizzard/Auctionator bottom tabs.
- The launcher now sits in the Auction House top-right title bar next to the close button, reducing conflicts with Auctionator and other Auction House addons.
- Bumped DealScryer to 3.1.4.

## 3.1.3 — patch diagnostics

- Expanded `/fs diag` into a copyable patch-diagnostics report.
- Records WoW version, build, build date, client interface version, addon-declared interface, project ID, locale, region and realm.
- Verifies availability of the Auction House replication APIs used by DealScryer.
- Reports the current replicate cache count and Auction House throttle readiness.
- When a cached snapshot exists, probes the current `GetReplicateItemInfo()` return-value count to help detect Blizzard API signature changes.
- Persists the last scan lifecycle: request mode, stage, cached count before the request, auction/item/deal counts, top score, success/failure and last error.
- Keeps a small rolling log of recent scan/throttle events for post-patch troubleshooting.
- Fixed the addon metadata version so the TOC now correctly reports 3.1.3.

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
