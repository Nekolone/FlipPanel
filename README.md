# FlipPanel

[Русская версия](README.ru.md)

An auction house addon for **WoW Forever** (`Interface: 16001`) for flipping one commodity fast.
Pick an item, a max price and a quantity, then buy with one button or Ctrl + mouse wheel. No search needed.

Commodities only: items sold by quantity, such as cloth, ore, bars and herbs.

## Features

- Buys exactly N units when the average price is at or below your max. It never buys above your max.
- One button (or Ctrl + mouse wheel). Every press sends exactly one request: get the price, confirm, or cancel.
- Posts the chosen quantity at a separate sell price for the chosen duration.
- Item history: 1, 2 or 3 rows of 10 (the "History" button in Settings), each item with its own buy price, sell price and quantity.
- Quantity buttons 5 / 10 / 20 / 50 plus your own (right-click the 5th button to store the number in the Quantity box), each can have a key binding.
- Quantity spread (the tick box and the "±" box next to Quantity, per item): each price request asks for Quantity ± this number, so a small cheap lot can fit sometimes. 0 means exactly Quantity.
- Sounds and per-session spending stats.
- A Settings window (button at the bottom of the panel): sounds, Ctrl + wheel, fast mode, debug, history rows, reset stats and panel position.
- A log window: purchases and posts in one tab, errors and cancels in another. The log is saved between sessions.

## Install

Copy the `FlipPanel` folder into the WoW Forever client's `Interface/AddOns` folder and restart the game.
Or install it with WowUp: Get Addons → Install from URL → paste this repository's link.

## Usage

The panel opens to the right of the auction house window. It has three blocks, top to bottom:
Item, Sell and Buy. The Settings and Log buttons and session stats sit at the bottom.

1. Item: drag an item onto the slot, type its ID and press Enter, or Shift+click its link while the ID box has focus.
2. Sell: set the price each (`3s`, `55c`, `1g20s`), the quantity and the duration, then press "Post".
3. Buy: set the max price each and the quantity, then press the buy button or use Ctrl + mouse wheel.
   The button label tells you what the next press does:
   - "Buy": asks the server for the price of N units;
   - "CONFIRM": the price fits, the press buys;
   - "CANCEL quote": the price didn't fit (too expensive, not enough gold, not enough on sale), the press cancels.
4. If the server never answers (the button is stuck on "Waiting for the server..."), press the same button again after
   3 seconds: it resets the panel. If someone bought the units before your "CONFIRM" press, the purchase fails
   with an auction house error and the panel goes back to "Buy" by itself: the next press asks for a new price.
   The panel does the same when the server answers a price request with an error.

Quantity keys: Esc → Options → Keybindings → AddOns → FlipPanel, for example Ctrl+1 … Ctrl+5.
No keys are set by default. A key only fills in the quantity, it sends nothing to the auction house.

The interface follows the game client language: Russian on a Russian client, English on any other.

Commands: `/flip` show/hide, `/flip log` log window, `/flip debug` log every auction house request and answer to the "Debug" log tab (the "Copy" button there lets you copy it), `/flip fast` fast mode (experimental): when the price does not fit there is no cancel, the next press asks for a new price right away, `/flip wheel` toggle Ctrl + mouse wheel,
`/flip reset` reset stats, `/flip resetpos` move the panel back to its default spot.

## How it works

- Uses only the in-game Lua API (`C_AuctionHouse`). No external programs.
- One action, one press. The addon has no timers and sends nothing on its own: asking the price, buying,
  cancelling a quote and posting are each sent only by your press, one request per press.
- It does not scan the auction house and it respects the server's request limit.

## License

[MIT](LICENSE).

FlipPanel is not affiliated with or endorsed by Blizzard Entertainment. Use it at your own risk.
