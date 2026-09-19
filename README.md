# DealScryer

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


**World of Warcraft Retail Auction House scanner**  
Created by **Burn**

> **DealScryer 3.2.0 is live.** Read the [launch announcement](ANNOUNCEMENT.md) or leave feedback in the [public feedback thread](https://github.com/hutlord12-cmyk/DealScryer/issues/1).

DealScryer helps players spot potential Auction House flips by analyzing live Blizzard Auction House snapshot data, estimating profit and ROI, ranking opportunities, and warning about suspicious or unreliable markets.

## Download

**CurseForge:** https://www.curseforge.com/wow/addons/dealscryer

Current public version: **3.1.4**

## Features

- Standalone Auction House scanning — no TSM or Auctionator required
- Profit, ROI, discount and target-price calculations
- 0–100 opportunity score with WoW-style rarity colors
- Large red **!** for suspicious / unscored markets
- Previous Scan and local market history
- Search, filters and Watchlist support
- Direct live Auction House search and chat linking
- Region- and realm-aware storage
- Minimap launcher and Auction House launcher button
- Mouse-wheel scrolling and draggable scrollbar
- Faster item loading and prefetching
- Undermine Exchange integration through **Oribos Exchange**
- Realm / region market values inside DealScryer
- Compact **4-day Oribos Exchange trend graph**
- Persistent patch diagnostics for WoW build/interface/API and last-scan troubleshooting via `/fs diag`
- Oribos Exchange load-state diagnostics that distinguish missing, disabled, out-of-date and incompatible installs
- Auction House launcher moved to the top-right title bar to avoid conflicts with Auctionator/other AH tab replacements

## Scoring

DealScryer combines five components:

| Component | Maximum |
| --- | ---: |
| Discount | 30 |
| ROI | 20 |
| Profit | 15 |
| Market gap | 20 |
| Confidence | 15 |

Score colors:

- White — 0–49
- Green — 50–64
- Blue — 65–79
- Purple — 80–89
- Orange — 90–100
- Red **!** — suspicious / unscored

## Undermine Exchange / Oribos Exchange

When **Oribos Exchange** is installed, DealScryer reads its in-game market data and displays realm and region market references. The external value is used conservatively: it may reduce an overly optimistic DealScryer target, but it is never allowed to raise the target.

The 4-day graph records the rolling Oribos Exchange median values DealScryer actually observes over time. Oribos Exchange does not expose confirmed completed-sale transactions, so DealScryer does not present these values as "last sales."

## Quick start

1. Install DealScryer from CurseForge.
2. Install Oribos Exchange for Undermine Exchange market data.
3. Open the Auction House.
4. Open DealScryer with `/ds`, the minimap icon, or the DealScryer AH button.
5. Run **Full Scan**.
6. Review Deals, Candidates and suspicious markets.

## Slash commands

- `/ds` — open DealScryer
- `/dealscryer` — open DealScryer
- `/fs scan` — start a Full Scan
- `/fs previous` — open Previous Scan
- `/fs diag` — diagnostics
- `/fs clearhistory` — clear local history
- `/fs resetwindow` — reset window position

## Repository layout

The actual addon source is kept in [`DealScryer/`](DealScryer/).

## Disclaimer

DealScryer is a decision-support addon. Auction House prices can change, be stale, or be manipulated. No accuracy, resale price, sale probability, or profit is guaranteed. You are responsible for every purchase and sale made using the addon.

## License

**All Rights Reserved.** See [`LICENSE.txt`](LICENSE.txt).

World of Warcraft and related trademarks are property of Blizzard Entertainment. DealScryer is an independent community addon and is not affiliated with or endorsed by Blizzard Entertainment or Undermine Exchange.
