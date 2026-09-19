# DealScryer 3.2.0

## 3.2.0: new controls

The results footer contains **Why this deal?**, **Profiles**, **Watch target**, **Journal**, and **Advanced/Compact**.

- **Compact** displays item, buy, estimated net profit per unit, ROI and score. **Advanced** also displays target and discount. The choice is saved.
- **Why this deal?** explains price gaps, target source, available history and risk. A score is not a probability of sale. Suspicious markets retain the red ! and appear below ordinary opportunities in every sort order.
- **Search Options** includes minimum ROI and Risk: all / hide / only. "Hide" excludes suspicious markets; "only" isolates them. Other filters still apply. The top-profit card excludes suspicious estimates.
- **Profiles** offers Small Budget (maximum 1,000 gold per unit), Materials (Trade Goods class), and High Margin (minimum 50% ROI). All three hide suspicious markets. Presets replace search filters but do not change the qualification settings on Settings. All preset values can be edited in Search Options. Save custom names; saving the same name overwrites that profile.
- **Watch target** sets a maximum gold price per unit for the selected item. "Use % rule" returns an existing watch entry to its percentage threshold. Alerts run after scans, skip suspicious items and do not repeat unchanged qualifying prices. They rearm after a recorded threshold exit or price change. These are not continuous live-market alerts.
- **Journal** records completed trades manually, separately for each market. Enter quantity and TOTAL gold for purchase, gross sale and all fees (including the AH cut and lost deposits). Net realized profit equals proceeds minus purchase cost minus fees; losses remain negative. Entries are saved, pageable and exportable. Undo/Restore applies to the current session; it does not trade or modify game inventory.
- **Local history** shows date/reference-price tooltips while hovering. Fewer than three plotted observations are labelled Collecting history. At narrow widths only the most recent points that fit are displayed; stored observations remain intact.

### Optional Oribos data

Oribos status text is centered, wrapped and constrained to its panel. The panel is smaller when the provider is unavailable. Installation/load problems remain distinct from missing per-item values. See Settings or Why this deal? for details.

An addon marked incompatible by WoW must be replaced with a version compatible with the installed Retail client; DealScryer cannot override that failure. Local scans continue without it. Provider prices are listing medians, not completed sales. The graph records observations locally, not a downloadable retrospective daily series. Scan age is shown separately; provider version and the time DealScryer observes a value do not prove source freshness.

### Installation and validation

Replace the existing `Interface/AddOns/DealScryer` folder with the packaged folder, then restart WoW or reload as appropriate. Keep your SavedVariables to retain settings, watchlist and history.

Headless tests cover filters, suspicious sorting, alerts, profile controls, journal accounting/validation/undo and UI construction. These checks do not reproduce WoW's renderer. In-game checks should include the minimum window size, UI scaling, Oribos present/absent/incompatible, AH addons together and saved launcher positions.


DealScryer is a standalone World of Warcraft Retail Auction House scanning and flip-analysis addon.

It uses Blizzard Auction House snapshot data, builds its own local price history, scores possible opportunities, and warns when a market reference looks suspicious or too thin to trust.

**No Auctionator or TradeSkillMaster dependency is required.**


## Creator

**DealScryer is created by Burn.**

The creator credit is also shown directly in-game beside the DealScryer version number.

## Quick start

1. Install the `DealScryer` folder in `World of Warcraft/_retail_/Interface/AddOns/`.
2. Log in or `/reload`.
3. Left-click the DealScryer minimap icon.
4. Open the Auction House.
5. Click **Full Scan (15m)** when the Blizzard full-snapshot cooldown is ready.
6. During the cooldown, use **Previous Scan** to reopen your last saved analysis.
7. Sort/filter the results and right-click an item for live AH search, chat linking, Watchlist actions, or Undermine Exchange price-history lookup.

## Auction House shortcut

The coin shortcut sits just above the Auction House’s top-left edge. Shift-drag it to choose another location; its position persists between sessions. Right-click it to reset the position. The shortcut remains visible only with the Auction House.

Oribos Exchange remains an optional installed addon. Missing lookups are retried after ten seconds when the item is refreshed. The embedded graph contains locally collected observations of the provider’s median, not downloaded historical daily prices. These changes do not repair an incompatible or disabled Oribos Exchange installation.

## What is DealScryer for?

DealScryer is for players who want a fast shortlist of Auction House listings that may be worth investigating for resale.

Instead of replacing your judgment, it helps answer:

- Is the cheapest price meaningfully below the rest of the current market?
- Is the possible profit large enough after the 5% Auction House cut?
- Is the ROI attractive?
- Does DealScryer's own scan history support the target price?
- Is the market deep enough to trust?
- Does the price look manipulated, stale, or otherwise suspicious?

DealScryer **does not guarantee profit**, does not automatically buy items, and does not automatically post auctions.

## Score system

DealScryer assigns each analyzed opportunity a score from 0 to 100.

The score is built from five components:

- **Discount — up to 30 points:** how far the buy price is below the target.
- **ROI — up to 20 points:** expected return relative to the buy price.
- **Profit — up to 15 points:** expected profit per unit, scaled logarithmically.
- **Market gap — up to 20 points:** separation between the cheapest listing and the next meaningful price levels.
- **Confidence — up to 15 points:** scan history and market depth, with a penalty for equipment/variant risk.

### WoW-style score rarity

- **0–49 — White — Poor**
- **50–64 — Green — Good**
- **65–79 — Blue — Rare**
- **80–89 — Purple — Epic**
- **90–100 — Orange — Legendary**
- **Red ! — Suspicious / unscored**

These are opportunity-quality labels only. They do not describe the item's actual rarity.

## Why do suspicious items show a big red !?

Suspicious items **do not receive a normal numerical DealScryer score**.

When DealScryer detects that the market reference may be unreliable, the Score column displays a large red **!** instead of a number. Suspicious items are sorted below normal scored opportunities and cannot trigger score-based alerts.

Typical reasons include grey items at extreme prices, near-gold-cap listings without supporting history, enormous gaps in thin markets, or current prices that disagree dramatically with local scan history.

The red **!** is not proof of manipulation. It means the opportunity should be manually verified before risking gold.

## Previous Scan vs Full Scan

**Previous Scan**
- Uses DealScryer's saved local result.
- Makes no Auction House request.
- Works during Blizzard's full-scan cooldown.
- Persists across reloads/restarts.

**Full Scan (15m)**
- Requests a fresh Blizzard full Auction House snapshot.
- Subject to Blizzard's account-wide full-snapshot cooldown.
- Saves the finished analysis as the next Previous Scan.

## Search and filters

DealScryer includes:
- item name / item ID search,
- min/max price,
- min/max item level,
- minimum quantity,
- minimum quality,
- item category,
- usable-only,
- equipment-only.

## Right-click actions

Right-click a result to:
- open a live Blizzard Auction House search,
- insert the item link into chat,
- open copyable Undermine Exchange price-history information,
- add/remove Watchlist,
- set Watchlist thresholds,
- ignore/unignore an item.

## Risk disclaimer

DealScryer is an informational tool only. Auction House prices can be manipulated, stale, incomplete, or change before a transaction is completed. No accuracy or profit is guaranteed. You are responsible for every in-game purchase, sale, listing, and pricing decision.

## Privacy

DealScryer does not send personal data to an external service. Scan history and settings are stored locally in WoW SavedVariables. The Undermine Exchange action only displays a copyable website address; the addon cannot open a browser or transmit your scan data to the site.

## Compatibility

- World of Warcraft Retail
- TOC: 120100 / 120105
- No required addon dependencies

## Commands

- `/fs` — open DealScryer
- `/fs scan` — full scan
- `/fs previous` — load previous saved scan
- `/fs cached` — troubleshooting path for WoW's in-memory replicate cache
- `/fs diag` — diagnostics
- `/fs clearhistory` — clear local price history
- `/fs resetwindow` — reset window position


## Region support

DealScryer is region-aware and uses the Auction House data of the Retail region/realm you are currently logged into.

Supported live Retail regions:
- **US / North America**
- **Brazil**
- **Oceania / Australia / New Zealand**
- **Europe**
- **Korea**
- **Taiwan**
- **China**

Blizzard reports Oceania/Australia and Brazil under Retail region ID 1 together with the US/NA portal. DealScryer handles that automatically.

Local history, Previous Scan data, scan sessions, and the known full-scan cooldown are isolated by **region + realm**, so switching between EU, NA/Oceania, KR, TW, or CN does not mix market history.

Undermine Exchange research is available when the external provider supports the detected region (US, EU, TW, KR). DealScryer's own scanner does not depend on Undermine Exchange and continues to work on other live Retail regions.



## Installing over a development FlipScout build

DealScryer is a separate public addon identity. Remove the old development `FlipScout` addon folder before installing DealScryer to avoid loading two different addons at once. DealScryer starts with its own `DealScryerDB` SavedVariables.


## Faster result browsing

DealScryer preloads item names/icons for the visible rows, the next two screens, and one screen behind the current position. Item-cache responses are batched instead of forcing a complete UI refresh for every individual item.

The results table also includes a draggable vertical scrollbar. The mouse wheel works while the cursor is over the main window, results panel, or an individual result row.


## Direct price-history links

The right-click price-history entry now shows the complete Undermine Exchange URL for the selected item directly in the menu.

Example:

`Price history: https://undermine.exchange/#eu-draenor/194641`

The link is built from:
- the currently detected region,
- the current server/realm,
- the selected item ID.

Clicking it opens DealScryer's copy window with the same full URL plus the detected region, server, item name and item ID.


## UI safety and Auction House launcher

DealScryer now enforces a safe minimum window size so the Settings descriptions, score legend and warning text stay inside their panels when the window is resized.

The Settings footer is kept to one line beside the Settings action buttons, and long header/status text is clipped to the available space instead of drawing underneath nearby controls.

When the Blizzard Auction House is open, a small DealScryer coin button appears directly beside the standard **Buy / Sell / Auctions** bottom-tab row. Clicking it toggles the DealScryer window.


## Undermine Exchange integration

DealScryer can use the market data embedded by the official **Oribos Exchange** addon from Undermine Exchange.

When Oribos Exchange is installed, DealScryer reads its public `OEMarketInfo` data and shows recent realm and region market values directly in the selected-item details and item tooltips.

DealScryer also uses that external value conservatively:
- it can reduce an over-optimistic resale target,
- agreement can improve confidence slightly,
- major disagreement adds risk,
- extreme disagreement can contribute to a suspicious-market warning.

The external value is never allowed to raise DealScryer's target.

### Important data terminology

Undermine Exchange's published data is based on Auction House price/quantity snapshots. The Oribos Exchange addon exposes recent market medians; it does **not** expose confirmed completed-sale transactions.

WoW addons cannot make live HTTP requests to Undermine Exchange from Lua. Oribos Exchange works around that limitation by packaging refreshed market data inside the addon, which DealScryer can consume in-game.


## Oribos Exchange 4-day trend graph

The selected-item panel now contains a compact **Oribos Exchange • 4-Day Trend** graph.

Oribos Exchange exposes a rolling 4-day median rather than a day-by-day historical series. DealScryer therefore records the Oribos Exchange median snapshots it actually sees and plots those snapshots over the most recent four days.

The graph:
- prefers realm median data when Oribos Exchange provides it,
- falls back to region median data for commodities/other region-only items,
- keeps up to four days of captured OE snapshots,
- labels the newest point with its current market value.

A new install cannot retroactively reconstruct the previous four days from Oribos Exchange. The graph fills naturally as DealScryer is used and Oribos Exchange data is refreshed.


## Patch diagnostics

DealScryer 3.1.3 expands `/fs diag` into a copyable troubleshooting report intended for use after WoW patches and hotfixes.

It records the current WoW version/build/interface, DealScryer's declared interface, region/realm, Auction House replication API availability, throttle readiness, cached replicate-item count, and the lifecycle of the most recent scan.

If Blizzard changes the replicate API, the report also probes the current `GetReplicateItemInfo()` return-value count whenever a cached snapshot exists. DealScryer keeps a small rolling event log so scan failures can be compared against recent Auction House throttle/replicate events.

Use `/fs diag` and copy the complete report when reporting a post-patch problem.


## Oribos load-state diagnostics

DealScryer now checks WoW's addon state for Oribos Exchange instead of treating every unavailable `OEMarketInfo` function as "not installed".

The UI can now distinguish an actually missing Oribos Exchange install from an installed addon that WoW considers disabled, out of date, incompatible, or otherwise unloadable. This is especially useful immediately after WoW patches.

## Auction House launcher compatibility

The small DealScryer Auction House launcher is anchored in the top-right title bar beside the close button. It no longer depends on Blizzard's Buy / Sell / Auctions tab positions, so Auctionator or other Auction House addons can replace those tabs without pushing the DealScryer launcher into the content area.
