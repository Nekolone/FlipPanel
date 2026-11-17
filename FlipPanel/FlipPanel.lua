-- FlipPanel: flip one commodity at a time. Buy exactly N units at or below your price, post at your price.
-- Pure WoW API (C_AuctionHouse). One press of the buy button (click, or Ctrl + mouse wheel while the AH
-- is open) sends exactly one request: ask price, confirm, or cancel. A purchase always takes two presses.
-- No timers and no automatic requests: even a cancel is a press. One action = one press.
-- An AH error (on a purchase: someone bought first; on a price request: the server refused it) returns the
-- panel to "Купить" at once, without a request; if the server never answers, the next press of the same
-- button after STUCK_AFTER s resets the panel.
-- /flip fast (experiment): a quote that does not fit is not cancelled, the next press just asks again.
local _, ns = ...

---------------------------------------------------------------- localization
-- Russian text is the key; any non-Russian client gets the English line. Resolved once per call, no frame cost.
local EN = {
  ["ошибка аукциона "] = "auction error ",
  ["Сессия: попыток %d, отмен %d, занято %d"] = "Session: tries %d, cancels %d, busy %d",
  ["Этот предмет: куплено %d на %s, ср. %s"] = "This item: bought %d for %s, avg %s",
  ["Этот предмет: пока ничего не куплено"] = "This item: nothing bought yet",
  ["Купить x%s <= %s"] = "Buy x%s <= %s",
  ["Разброс количества"] = "Quantity spread",
  ["Настройки"] = "Settings",
  ["FlipPanel — настройки"] = "FlipPanel settings",
  ["Быстрый режим (эксперимент): без отмены котировки"] = "Fast mode (experimental): no quote cancel",
  ["Сбросить статистику"] = "Reset stats",
  ["Панель на место"] = "Reset position",
  ["Каждый запрос цены берёт Кол-во ± это число (не меньше 1). 0 — ровно Кол-во"] =
    "Each price request takes Quantity ± this number (at least 1). 0: exactly Quantity",
  ["Купить"] = "Buy",
  ["ПОДТВЕРДИТЬ x%d %s за %s"] = "CONFIRM x%d %s for %s",
  ["ОТМЕНИТЬ котировку"] = "CANCEL quote",
  ["Жду ответ сервера..."] = "Waiting for the server...",
  ["Выставить %d шт. по %s"] = "Post %d at %s",
  ["Задай цену продажи: 3s, 55c, 1g20s"] = "Set a sell price: 3s, 55c, 1g20s",
  ["Предмет"] = "Item",
  ["Продажа"] = "Sell",
  ["Покупка"] = "Buy",
  ["FlipPanel: продать по %s, купить x%d <= %s"] = "FlipPanel: sell at %s, buy x%d <= %s",
  ["Цена за шт. (3s, 55c, 1g20s)"] = "Price each (3s, 55c, 1g20s)",
  ["Кол-во"] = "Quantity",
  ["Срок"] = "Duration",
  ["Макс. цена за шт."] = "Max price each",
  ["Лог"] = "Log",
  ["Сервер занят, жми ещё"] = "Server busy, press again",
  [". Жми, чтобы отменить котировку"] = ". Press to cancel the quote",
  ["Настройки изменились"] = "Settings changed",
  ["Беру %d за %s"] = "Buying %d for %s",
  ["Цена ок: %d за %s. Жми ещё раз, чтобы купить"] = "Price ok: %d for %s. Press again to buy",
  ["Не успел: покупка не прошла (ошибка аукциона). Жми, чтобы узнать цену заново"] =
    "Too late: the purchase failed (auction house error). Press to get a new price",
  ["Котировка отменена"] = "Quote cancelled",
  ["Котировка устарела, отменена"] = "Quote expired, cancelled",
  ["Котировка устарела и отменена, жми снова"] = "Quote expired and cancelled, press again",
  ["Выбери предмет (слот, ID или список)"] = "Pick an item (slot, ID or list)",
  ["Задай цену для этого предмета: 3s, 55c, 1g20s"] = "Set a price for this item: 3s, 55c, 1g20s",
  ["Количество должно быть > 0"] = "Quantity must be > 0",
  ["Сервер занят, нажми ещё раз"] = "Server busy, press again",
  ["Предмета нет в сумках"] = "Item not in your bags",
  ["Подтвердить выставление"] = "Confirm posting",
  ["Игра предупреждает о цене, нажми ещё раз"] = "The game warns about the price, press again",
  ["Выставляю %d шт. по %s"] = "Posting %d at %s",
  ["Перетащи предмет, введи ID или выбери в списке"] = "Drop an item, type its ID or pick from the list",
  ["Нет предмета с ID "] = "No item with ID ",
  ["Это не ресурс: FlipPanel покупает только то, что продаётся по количеству"] =
    "Not a commodity: FlipPanel only buys items sold by quantity",
  ["ЛКМ — выбрать, ПКМ — убрать из списка"] = "Left-click: select, right-click: remove from list",
  ["ID (Enter или Shift+клик по ссылке)"] = "ID (Enter or Shift+click a link)",
  ["Звуки"] = "Sounds",
  ["Ctrl + колесо мыши = кнопка покупки"] = "Ctrl + mouse wheel = buy button",
  ["FlipPanel — лог"] = "FlipPanel log",
  ["Покупки"] = "Purchases",
  ["Ошибки и отмены"] = "Errors & cancels",
  ["Очистить"] = "Clear",
  ["Ctrl+колесо: "] = "Ctrl+wheel: ",
  ["вкл"] = "on",
  ["выкл"] = "off",
  ["Окно закрыто: жми «ОТМЕНИТЬ котировку»"] = "Window closed: press \"CANCEL quote\"",
  ["Выставлено %d %s по %s (%s)"] = "Posted %d %s at %s (%s)",
  ["Настройки изменились, пока сервер отвечал"] = "Settings changed while the server was answering",
  ["Дорого: %d за %s (макс. %s)"] = "Too expensive: %d for %s (max %s)",
  ["Не хватает золота: нужно %s"] = "Not enough gold: need %s",
  ["Нет в продаже %d шт."] = "Not %d on sale",
  ["Куплено %d %s за %s (ср. %s)"] = "Bought %d %s for %s (avg %s)",
  ["Куплено %d шт. за %s"] = "Bought %d for %s",
  ["Покупка не прошла (сервер отказал)"] = "Purchase failed (server refused)",
  ["Покупка не прошла"] = "Purchase failed",
  ["Аукцион: "] = "Auction house: ",
  ["Ошибка выставления"] = "Posting error",
  ["Сервер отбросил запрос: превышен лимит"] = "Server dropped a request: limit exceeded",
  ["Игра заблокировала вызов "] = "The game blocked a call to ",
  ["Ошибка Lua: "] = "Lua error: ",
  ["Сброс нажатием: нет ответа на «%s»"] = "Reset by press: no answer to \"%s\"",
  ["цена"] = "price",
  ["покупка"] = "purchase",
  ["Сброшено, жми снова"] = "Reset, press again",
  ["Отладка"] = "Debug",
  ["Копировать"] = "Copy",
  ["Писать отладку: каждый запрос к аукциону и ответ сервера"] = "Debug log: every auction house request and server answer",
  ["Открой аукцион, панель появится рядом с ним"] = "Open the auction house, the panel appears next to it",
  ["Отладка: "] = "Debug: ",
  ["/flip — показать/скрыть, /flip log, /flip debug, /flip fast, /flip wheel, /flip reset, /flip resetpos"] =
    "/flip: show/hide, /flip log, /flip debug, /flip fast, /flip wheel, /flip reset, /flip resetpos",
  ["Ошибка аукциона. Жми, чтобы узнать цену заново"] = "Auction house error. Press to get a new price",
  [". Жми, чтобы узнать цену заново"] = ". Press to get a new price",
  ["Быстрый режим (цена не подошла — следующее нажатие сразу запрашивает новую, без отмены): "] =
    "Fast mode (price does not fit: the next press asks for a new one right away, no cancel): ",
  ["История: %d"] = "History: %d",
  ["Своя пачка"] = "Your own quantity",
  ["ПКМ — запомнить число из поля «Кол-во»"] = "Right-click: remember the number in the Quantity box",
  ["Кол-во: %d"] = "Quantity: %d",
  ["Кол-во: своё"] = "Quantity: your own",
}
local isRU = GetLocale and GetLocale() == "ruRU"
local function L(s) return isRU and s or EN[s] or s end
ns.EN = EN -- for the offline check that every string has a translation

local STUCK_AFTER = 3     -- seconds without a server answer after which the next press resets the panel
-- After a failed purchase the client lifts its usual 0.5 s pause, but the server still refuses a price request
-- sent sooner than that after the purchase request ("Internal auction error", seen in debug logs: +0.13 s and
-- +0.32 s refused, +0.51 s answered). Presses inside this window send nothing.
local FAIL_HOLD = 0.5
local MIN_QUOTE_LEFT = 2  -- a stale quote fails on Forever ("Internal auction error", per ForeverFlip): requote
local ROW_ITEMS = 10      -- icons per history row
local MAX_ROWS = 3        -- history rows you can show
local MAX_ITEMS = ROW_ITEMS * MAX_ROWS -- items kept, even while fewer rows are shown
local LOG_MAX = 200       -- lines kept per log
local DEBUG_MAX = 600     -- lines kept in the debug log
local QTY_PRESETS = { 5, 10, 20, 50 } -- plus a 5th, your own: db().customQty
local DURATIONS = { "AUCTION_DURATION_ONE", "AUCTION_DURATION_TWO", "AUCTION_DURATION_THREE" }

-- Key bindings (Bindings.xml, Esc > Options > Keybindings > AddOns): set the buy quantity, nothing else
BINDING_HEADER_FLIPPANEL = "FlipPanel"
for i, n in ipairs(QTY_PRESETS) do _G["BINDING_NAME_FLIPPANEL_QTY" .. i] = (L("Кол-во: %d")):format(n) end
BINDING_NAME_FLIPPANEL_QTY5 = L("Кол-во: своё")
function FlipPanel_SetQty(i) ns.setBuyQty(ns.presetQty(i)) end

local ui
local host -- parent for the UI helpers below: the panel, or its body under the history rows
-- idle    --press--> quoting (StartCommoditiesPurchase)
-- quoting --answer--> ready (price ok) | cancel (too expensive, no gold, unavailable, settings changed)
-- ready   --press--> confirming (ConfirmCommoditiesPurchase) | idle (quote nearly expired: Cancel)
-- cancel  --press--> idle (CancelCommoditiesPurchase)
-- quoting/confirming --AH error--> idle (no request)
-- quoting/confirming --press after STUCK_AFTER s--> idle (Cancel if a quote may exist)
-- fast mode: "cancel" is skipped, a quote that does not fit goes straight to idle
local state = "idle"      -- idle | quoting | ready | cancel | confirming
local pending = nil       -- { itemID, qty, maxUnit, total, stale }
local postTry = nil       -- { loc, qty, dur, price } of the last post attempt
local pendingPost = nil   -- set only when the server asked to confirm postTry
local ahOpen = false
local stats = { tries = 0, cancels = 0, busy = 0, byItem = {} } -- session only
local holdUntil = 0       -- GetTime() before which a press asks no price (set by a failed purchase, see FAIL_HOLD)

local function db() return FlipPanelDB end
local function cur() return db().itemID and db().items[db().itemID] end -- settings of the selected item
local function msg(s) print("|cff33ff99FlipPanel|r: " .. s) end
local function money(c) return GetMoneyString(c or 0, true) end
local function durText(i) return _G[DURATIONS[i]] or tostring(i) end

---------------------------------------------------------------- pure helpers
-- "1g20s5c", "55c", "3s", "1з20с" or a plain number (copper) -> copper.
-- Anything else (e.g. "1.5g", "2,5s") -> 0, so a typo can never raise the max price.
local function parseMoney(text)
  text = (text or ""):lower():gsub("%s+", "")
  -- Russian layout (UTF-8, so plain replacements, not [] classes which work on bytes)
  for ru, en in pairs({ ["з"] = "g", ["З"] = "g", ["с"] = "s", ["С"] = "s", ["м"] = "c", ["М"] = "c" }) do
    text = text:gsub(ru, en)
  end
  if text:match("^%d+$") then return tonumber(text) end
  local mult = { g = 10000, s = 100, c = 1 }
  local total, seen, rebuilt = 0, {}, ""
  for num, unit in text:gmatch("(%d+)([gsc])") do
    if seen[unit] then return 0 end
    seen[unit] = true
    total = total + tonumber(num) * mult[unit]
    rebuilt = rebuilt .. num .. unit
  end
  if rebuilt ~= text then return 0 end
  return total
end

-- "2589" or an item link "|Hitem:2589:...|h" -> 2589, else nil
local function parseItemID(text)
  text = text or ""
  local id = text:match("^%s*(%d+)%s*$") or text:match("item:(%d+)")
  id = tonumber(id)
  if id and id > 0 then return id end
end

-- Item IDs sorted by last use, newest first
local function sortedItems(items)
  local ids = {}
  for id in pairs(items) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return (items[a].last or 0) > (items[b].last or 0) end)
  return ids
end

-- Append and drop the oldest lines beyond max
local function pushLog(list, text, max)
  list[#list + 1] = text
  while #list > max do table.remove(list, 1) end
end

-- for the offline self-check
ns.parseMoney, ns.parseItemID, ns.sortedItems, ns.pushLog = parseMoney, parseItemID, sortedItems, pushLog

---------------------------------------------------------------- log (saved between sessions)
local refreshLog -- defined with the log window
local function log(kind, text) -- kind: "buys" | "errors"
  local d = FlipPanelDB
  if not (d and d.log) then return end
  local line = date("%d.%m %H:%M:%S") .. "  " .. text
  pushLog(d.log[kind], line, kind == "debug" and DEBUG_MAX or LOG_MAX)
  if refreshLog then refreshLog(kind, line) end
end

-- /flip debug: every AH request and server answer goes to the "Отладка" log tab (English, for bug reports)
local function dbg(text)
  if FlipPanelDB and FlipPanelDB.debug then log("debug", ("%06.2f  "):format(GetTime() % 1000) .. text) end
end

local function quoteLeft()
  return C_AuctionHouse.GetQuoteDurationRemaining and C_AuctionHouse.GetQuoteDurationRemaining()
end

local function ahErrorText(err)
  local ok, text = pcall(function() return AuctionHouseUtil.GetErrorText(err) end)
  if ok and type(text) == "string" then return text end
  return L("ошибка аукциона ") .. tostring(err)
end

---------------------------------------------------------------- game helpers
local function findInBags(itemID)
  for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID == itemID and not info.isLocked then
        return ItemLocation:CreateFromBagAndSlot(bag, slot)
      end
    end
  end
end

local function serverReady()
  return not C_AuctionHouse.IsThrottledMessageSystemReady or C_AuctionHouse.IsThrottledMessageSystemReady()
end

-- Same rounding as Blizzard's sell frame: up to whole silver when the server has no copper prices
local function postPrice(copper)
  if C_AuctionHouse.SupportsCopperValues and not C_AuctionHouse.SupportsCopperValues() then
    return math.max(100, math.ceil(copper / 100) * 100)
  end
  return copper
end

local function play(kit)
  if db().sound and SOUNDKIT and SOUNDKIT[kit] then PlaySound(SOUNDKIT[kit]) end
end

---------------------------------------------------------------- UI refresh
local function setStatus(text) -- buy block
  if ui then ui.status:SetText(text) end
end

local function setPostStatus(text) -- sell block
  if ui then ui.postStatus:SetText(text) end
end

local refreshStats
function ns.resetStats()
  stats = { tries = 0, cancels = 0, busy = 0, byItem = {} }
  refreshStats()
end

refreshStats = function()
  if not ui then return end
  ui.stats:SetText((L("Сессия: попыток %d, отмен %d, занято %d")):format(stats.tries, stats.cancels, stats.busy))
  local s = db().itemID and stats.byItem[db().itemID]
  if s and s.bought > 0 then
    ui.itemStats:SetText((L("Этот предмет: куплено %d на %s, ср. %s")):format(
      s.bought, money(s.spent), money(math.floor(s.spent / s.bought))))
  else
    ui.itemStats:SetText(L("Этот предмет: пока ничего не куплено"))
  end
end

local function refreshBuyButton()
  if not ui then return end
  local c = cur()
  local spread = c and c.spreadOn and c.spread or 0
  local label = c and (L("Купить x%s <= %s")):format(c.qty .. (spread > 0 and "±" .. spread or ""),
    money(parseMoney(c.priceText))) or L("Купить")
  if state == "ready" then
    label = (L("ПОДТВЕРДИТЬ x%d %s за %s")):format(pending.qty,
      C_Item.GetItemNameByID(pending.itemID) or "", money(pending.total))
  elseif state == "cancel" then
    label = L("ОТМЕНИТЬ котировку")
  elseif state ~= "idle" then
    label = L("Жду ответ сервера...")
  end
  ui.buy:SetText(label)
end

local function refreshPost()
  if not ui then return end
  local c = cur()
  ui.dur:SetText(durText(db().postDur))
  if pendingPost then
    ui.post:SetText(L("Подтвердить выставление"))
  else
    ui.post:SetText((L("Выставить %d шт. по %s")):format(db().postQty, money(c and parseMoney(c.sellText) or 0)))
  end
end

local function resetPost()
  pendingPost = nil
  refreshPost()
end

local function toIdle(text)
  state, pending = "idle", nil
  if text then setStatus(text) end
  refreshBuyButton()
  refreshStats()
end

---------------------------------------------------------------- buy
local function busy()
  dbg("press skipped: throttle not ready (state=" .. state .. ")")
  stats.busy = stats.busy + 1
  refreshStats()
  setStatus(L("Сервер занят, жми ещё"))
end

-- Only ever called from a press of the buy button
local function sendCancel(why)
  dbg(("-> Cancel (%s, state=%s, quoteLeft=%s)"):format(why, state, tostring(quoteLeft())))
  pcall(C_AuctionHouse.CancelCommoditiesPurchase)
end

local function toCancel(reason)
  stats.cancels = stats.cancels + 1
  log("errors", reason)
  if db().fast then -- no cancel press: the next press asks for a new price, which replaces this quote
    return toIdle(reason .. L(". Жми, чтобы узнать цену заново"))
  end
  state = "cancel" -- a quote we won't confirm: the next press of the same button sends the cancel
  setStatus(reason .. L(". Жми, чтобы отменить котировку"))
  refreshBuyButton()
  refreshStats()
end

-- A quote must not survive a change of item / price / qty: a ready one goes to cancel now,
-- one still in flight is marked so its answer goes to cancel instead of being checked against old settings
local function dropReady()
  if state == "ready" then
    toCancel(L("Настройки изменились"))
  elseif state == "quoting" and pending then
    pending.stale = true
  end
end

-- Called only from a hardware press (onBuyClick)
local function startQuote(itemID, qty, maxUnit)
  pending = { itemID = itemID, qty = qty, maxUnit = maxUnit, sentAt = GetTime() }
  state = "quoting"
  stats.tries = stats.tries + 1
  refreshBuyButton()
  refreshStats()
  dbg(("-> Start item=%d qty=%d"):format(itemID, qty))
  C_AuctionHouse.StartCommoditiesPurchase(itemID, qty)
end

-- Called only from the 2nd press (onBuyClick)
local function confirm()
  state = "confirming"
  pending.sentAt = GetTime()
  setStatus((L("Беру %d за %s")):format(pending.qty, money(pending.total)))
  refreshBuyButton()
  dbg(("-> Confirm qty=%d quoteLeft=%s quoteAge=%.1fs"):format(pending.qty,
    tostring(quoteLeft()), GetTime() - (pending.quotedAt or GetTime())))
  C_AuctionHouse.ConfirmCommoditiesPurchase(pending.itemID, pending.qty)
end

local function toReady()
  state = "ready"
  setStatus((L("Цена ок: %d за %s. Жми ещё раз, чтобы купить")):format(pending.qty, money(pending.total)))
  refreshBuyButton()
  play("IG_MAINMENU_OPTION_CHECKBOX_ON")
end

-- One press = exactly one AH request (or none, if the server is busy or a request is in flight)
local function onBuyClick()
  if not ui:IsVisible() then return end -- hidden panel never buys (binding may survive a hide in combat)

  -- Waiting for the server: presses are ignored, unless it's stuck. Then this same press resets the panel,
  -- once STUCK_AFTER s passed with no answer. No timer: only your press.
  if state == "quoting" or state == "confirming" then
    if GetTime() - pending.sentAt < STUCK_AFTER then
      return dbg(("press ignored: %s for %.2fs"):format(state, GetTime() - pending.sentAt))
    end
    if state == "quoting" then -- a quote may still be open: this press cancels it (one request)
      if not serverReady() then return busy() end
      sendCancel("stuck reset")
    end
    log("errors", (L("Сброс нажатием: нет ответа на «%s»")):format(state == "quoting" and L("цена") or L("покупка")))
    return toIdle(L("Сброшено, жми снова"))
  end

  if state == "cancel" then
    if not serverReady() then return busy() end
    sendCancel("cancel press")
    return toIdle(L("Котировка отменена"))
  end

  if state == "ready" then -- 2nd press confirms the checked quote
    if not serverReady() then return busy() end
    local left = quoteLeft()
    if left and left < MIN_QUOTE_LEFT then -- this press only cancels; the next one asks for a fresh price
      sendCancel("quote nearly expired")
      stats.cancels = stats.cancels + 1
      log("errors", L("Котировка устарела, отменена"))
      return toIdle(L("Котировка устарела и отменена, жми снова"))
    end
    return confirm()
  end

  if state ~= "idle" then return end -- ignore presses while a request is in flight
  if GetTime() < holdUntil then return dbg("press skipped: too soon after a failed purchase") end
  local c = cur()
  if not c then return setStatus(L("Выбери предмет (слот, ID или список)")) end
  local price = parseMoney(c.priceText)
  if price <= 0 then return setStatus(L("Задай цену для этого предмета: 3s, 55c, 1g20s")) end
  if c.qty <= 0 then return setStatus(L("Количество должно быть > 0")) end
  if not serverReady() then return busy() end
  -- Optional spread: this one request asks for qty ± spread units (at least 1), so a smaller cheap lot can fit
  -- the average. The confirm and the max-price check use this same quoted quantity.
  local qty, spread = c.qty, c.spread or 0
  if c.spreadOn and spread > 0 then qty = math.max(1, qty + math.random(-spread, spread)) end
  startQuote(db().itemID, qty, price)
end

---------------------------------------------------------------- post
local function onPostClick()
  local d, c = db(), cur()
  if pendingPost then -- second click after the server asked for confirmation
    if not serverReady() then return setPostStatus(L("Сервер занят, нажми ещё раз")) end
    local p = pendingPost
    resetPost()
    StaticPopup_Hide("AUCTION_HOUSE_POST_WARNING") -- Blizzard's own popup has nothing to confirm
    C_AuctionHouse.ConfirmPostCommodity(p.loc, p.dur, p.qty, p.price)
    return
  end

  if not c then return setPostStatus(L("Выбери предмет (слот, ID или список)")) end
  local price = parseMoney(c.sellText)
  if price <= 0 then return setPostStatus(L("Задай цену продажи: 3s, 55c, 1g20s")) end
  if not serverReady() then return setPostStatus(L("Сервер занят, нажми ещё раз")) end
  local loc = findInBags(d.itemID)
  if not loc then return setPostStatus(L("Предмета нет в сумках")) end

  -- One bag slot can post more than its stack: the server takes the rest from other stacks (as Blizzard's UI does)
  local have = C_AuctionHouse.GetAvailablePostCount and C_AuctionHouse.GetAvailablePostCount(loc)
    or C_Item.GetItemCount(d.itemID)
  local qty = math.min(d.postQty, have)
  if qty < 1 then return setPostStatus(L("Предмета нет в сумках")) end

  postTry = { loc = loc, qty = qty, dur = d.postDur, price = postPrice(price) }
  local needsConfirmation = C_AuctionHouse.PostCommodity(loc, postTry.dur, qty, postTry.price)
  if needsConfirmation then
    pendingPost = postTry
    refreshPost()
    setPostStatus(L("Игра предупреждает о цене, нажми ещё раз"))
  else
    setPostStatus((L("Выставляю %d шт. по %s")):format(qty, money(postTry.price)))
  end
end

---------------------------------------------------------------- item selection
local refreshList -- defined with the UI

local function refreshItem()
  local id, c = db().itemID, cur()
  ui.slot.icon:SetTexture(id and C_Item.GetItemIconByID(id) or "Interface\\Icons\\INV_Misc_QuestionMark")
  ui.slot.name:SetText(id and (C_Item.GetItemNameByID(id) or ("item " .. id)) or L("Перетащи предмет, введи ID или выбери в списке"))
  ui.idBox:SetText(id and tostring(id) or "")
  ui.priceBox:SetText(c and c.priceText or "")
  ui.qtyBox:SetText(c and tostring(c.qty) or "")
  ui.spreadBox:SetText(c and tostring(c.spread or 0) or "")
  ui.spreadCheck:SetChecked(c and c.spreadOn or false)
  ui.sellBox:SetText(c and c.sellText or "")
  refreshPost()
  refreshList()
  refreshBuyButton()
  refreshStats()
end

-- Commit-only (Enter, focus lost, drag, Shift+click, list click): never on each keystroke
local function selectItem(id)
  local d = db()
  if not id then return refreshItem() end
  if C_Item.DoesItemExistByID and not C_Item.DoesItemExistByID(id) then
    setStatus(L("Нет предмета с ID ") .. id)
    return refreshItem()
  end
  local stack = C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(id)
  if stack == 1 then -- nil = not cached yet: let the server decide (COMMODITY_PRICE_UNAVAILABLE)
    setStatus(L("Это не ресурс: FlipPanel покупает только то, что продаётся по количеству"))
    return refreshItem()
  end
  if id ~= d.itemID then dropReady() end

  -- New items start without prices, so they never inherit another item's max or sell price
  d.items[id] = d.items[id] or { priceText = "", sellText = "", qty = 10 }
  d.items[id].last = time()
  local ids = sortedItems(d.items)
  for i = MAX_ITEMS + 1, #ids do d.items[ids[i]] = nil end

  d.itemID = id
  resetPost()
  refreshItem()
  if not C_Item.GetItemNameByID(id) then
    Item:CreateFromItemID(id):ContinueOnItemLoad(function() if db().itemID == id then refreshItem() end end)
  end
end

local function removeItem(id)
  local d = db()
  d.items[id] = nil
  if d.itemID == id then
    dropReady()
    d.itemID = nil
    resetPost()
  end
  refreshItem()
end

local function takeCursor()
  local kind, id = GetCursorInfo()
  if kind ~= "item" then return end
  ClearCursor()
  selectItem(id)
end

---------------------------------------------------------------- UI build
local function makeLabel(text, y, x)
  local fs = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("TOPLEFT", x or 16, y)
  fs:SetText(text)
  return fs
end

-- onUserChange runs only for typing, not for SetText from code
local function makeBox(y, width, numeric, onUserChange)
  local eb = CreateFrame("EditBox", nil, host, "InputBoxTemplate")
  eb:SetSize(width, 20)
  eb:SetPoint("TOPRIGHT", -16, y + 4)
  eb:SetAutoFocus(false)
  if numeric then eb:SetNumeric(true) end
  if onUserChange then
    eb:SetScript("OnTextChanged", function(self, userInput)
      if userInput then onUserChange(self:GetText()) refreshBuyButton() end
    end)
  end
  eb:SetScript("OnEnterPressed", eb.ClearFocus)
  eb:SetScript("OnEscapePressed", eb.ClearFocus)
  return eb
end

local function makeButton(name, text, width, onClick, parent)
  local b = CreateFrame("Button", name, parent or host, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function makeCheck(x, y, text, key, onToggle)
  local cb = CreateFrame("CheckButton", nil, host, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", x, y)
  cb:SetChecked(db()[key])
  cb:SetScript("OnClick", function(self)
    db()[key] = self:GetChecked() and true or false
    if onToggle then onToggle() end
  end)
  local fs = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("LEFT", cb, "RIGHT", 0, 0)
  fs:SetText(text)
  return cb
end

-- Block header: thin gold line plus title; returns the y below it. No title = just the line.
local function section(title, y)
  local line = host:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 0.82, 0, 0.3)
  line:SetPoint("TOPLEFT", 12, y)
  line:SetPoint("TOPRIGHT", -12, y)
  line:SetHeight(1)
  if not title then return y - 8 end
  local fs = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", 14, y - 5)
  fs:SetText(title)
  return y - 24
end

local function statusLine(y, font)
  local fs = host:CreateFontString(nil, "OVERLAY", font)
  fs:SetPoint("TOPLEFT", 16, y)
  fs:SetWidth(228)
  fs:SetJustifyH("LEFT")
  return fs
end

local function placeUI()
  ui:ClearAllPoints()
  local p = db().pos
  if p then
    ui:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    ui:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, 0)
  end
end

local function presetQty(i) return QTY_PRESETS[i] or db().customQty end
ns.presetQty = presetQty

-- Show db().rows history rows: the body moves under the last row and the panel resizes. UI only.
local function layoutRows()
  local top = ui.listY - 28 - (db().rows - 1) * 23
  ui.body:ClearAllPoints()
  ui.body:SetPoint("TOPLEFT", ui, "TOPLEFT", 0, top)
  ui.body:SetPoint("TOPRIGHT", ui, "TOPRIGHT", 0, top)
  ui:SetHeight(-top + ui.bodyHeight)
  ui.rowsBtn:SetText((L("История: %d")):format(db().rows))
  refreshList()
end

-- Buy quantity from a preset button or its key binding. Only fills the box: no AH request.
function ns.setBuyQty(n)
  local c = ui and cur()
  if not c or not n or n < 1 then return end
  c.qty = n
  dropReady()
  ui.qtyBox:SetText(tostring(n))
  refreshBuyButton()
end

local function buildUI()
  local d = db()
  ui = CreateFrame("Frame", "FlipPanelFrame", AuctionHouseFrame, "BasicFrameTemplateWithInset")
  host = ui
  ui:SetSize(260, 400)
  ui:SetMovable(true)
  ui:SetClampedToScreen(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    db().pos = { p, rp, x, y }
    self:SetUserPlaced(false) -- our SavedVariables own the position, not the layout cache
  end)
  placeUI()
  if ui.TitleText then ui.TitleText:SetText("FlipPanel") end

  ---------------- item block
  local y = section(L("Предмет"), -26)
  ui.slot = CreateFrame("Button", nil, ui)
  ui.slot:SetSize(36, 36)
  ui.slot:SetPoint("TOPLEFT", 16, y)
  ui.slot.icon = ui.slot:CreateTexture(nil, "ARTWORK")
  ui.slot.icon:SetAllPoints()
  ui.slot.name = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.slot.name:SetPoint("LEFT", ui.slot, "RIGHT", 8, 0)
  ui.slot.name:SetWidth(184)
  ui.slot.name:SetJustifyH("LEFT")
  ui.slot:SetScript("OnReceiveDrag", takeCursor)
  ui.slot:SetScript("OnClick", takeCursor)
  y = y - 42

  -- history rows (1..MAX_ROWS shown): recent items, each with its own prices and qty
  ui.list = {}
  for i = 1, MAX_ITEMS do
    local b = CreateFrame("Button", nil, ui)
    b:SetSize(20, 20)
    b:SetPoint("TOPLEFT", 16 + (i - 1) % ROW_ITEMS * 23, y - math.floor((i - 1) / ROW_ITEMS) * 23)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.mark = b:CreateTexture(nil, "OVERLAY")
    b.mark:SetPoint("TOPLEFT", -2, 2)
    b.mark:SetPoint("BOTTOMRIGHT", 2, -2)
    b.mark:SetColorTexture(1, 0.82, 0, 0.35)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
      if button == "RightButton" then removeItem(self.id) else selectItem(self.id) end
    end)
    b:SetScript("OnEnter", function(self)
      local c = db().items[self.id]
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetItemByID(self.id)
      if c then
        GameTooltip:AddLine((L("FlipPanel: продать по %s, купить x%d <= %s")):format(
          money(parseMoney(c.sellText)), c.qty, money(parseMoney(c.priceText))), 0.2, 1, 0.6)
      end
      GameTooltip:AddLine(L("ЛКМ — выбрать, ПКМ — убрать из списка"), 0.7, 0.7, 0.7)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.list[i] = b
  end
  ui.listY = y

  -- everything below the history lives in one frame that moves when the row count changes
  ui.body = CreateFrame("Frame", nil, ui)
  host = ui.body
  y = 0

  makeLabel(L("ID (Enter или Shift+клик по ссылке)"), y)
  ui.idBox = makeBox(y, 60, true)
  ui.idBox:SetScript("OnEscapePressed", function(self) self.escaping = true; self:ClearFocus() end)
  ui.idBox:HookScript("OnEditFocusLost", function(self) -- Hook keeps InputBoxTemplate's own handler
    if self.escaping then -- Escape = undo typing
      self.escaping = nil
      return self:SetText(db().itemID and tostring(db().itemID) or "")
    end
    local id = parseItemID(self:GetText())
    if id ~= db().itemID then selectItem(id) end
  end)
  y = y - 26

  ---------------- sell block
  y = section(L("Продажа"), y)
  makeLabel(L("Цена за шт. (3s, 55c, 1g20s)"), y)
  ui.sellBox = makeBox(y, 80, false, function(t)
    local c = cur()
    if c then c.sellText = t; refreshPost() end
  end)
  y = y - 26

  makeLabel(L("Кол-во"), y)
  ui.postQtyBox = makeBox(y, 40, true, function(t)
    db().postQty = math.max(1, tonumber(t) or 1)
    resetPost()
  end)
  ui.postQtyBox:SetText(tostring(d.postQty))
  y = y - 26

  makeLabel(L("Срок"), y)
  ui.dur = makeButton(nil, "", 80, function()
    db().postDur = db().postDur % #DURATIONS + 1
    resetPost()
  end)
  ui.dur:SetPoint("TOPRIGHT", -16, y + 4)
  y = y - 28

  ui.post = makeButton("FlipPanelPostButton", "", 228, onPostClick)
  ui.post:SetPoint("TOP", 0, y)
  y = y - 26
  ui.postStatus = statusLine(y, "GameFontHighlightSmall")
  y = y - 28 -- status may wrap to two lines

  ---------------- buy block
  y = section(L("Покупка"), y)
  makeLabel(L("Макс. цена за шт."), y)
  ui.priceBox = makeBox(y, 80, false, function(t)
    local c = cur()
    if c then c.priceText = t; dropReady() end
  end)
  y = y - 26

  makeLabel(L("Кол-во"), y)
  ui.qtyBox = makeBox(y, 50, true, function(t)
    local c = cur()
    if c then c.qty = tonumber(t) or 0; dropReady() end
  end)
  -- spread, per item: [x] ± [n]. Changes only the next price request, so a ready quote stays as it is
  ui.spreadBox = makeBox(y, 30, true, function(t)
    local c = cur()
    if c then c.spread = tonumber(t) or 0 end
  end)
  ui.spreadBox:SetPoint("TOPRIGHT", -84, y + 4)
  local pm = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  pm:SetPoint("RIGHT", ui.spreadBox, "LEFT", -6, 0)
  pm:SetText("±")
  ui.spreadCheck = CreateFrame("CheckButton", nil, host, "UICheckButtonTemplate")
  ui.spreadCheck:SetSize(24, 24)
  ui.spreadCheck:SetPoint("RIGHT", pm, "LEFT", 0, 0)
  ui.spreadCheck:SetScript("OnClick", function(self)
    local c = cur()
    if c then c.spreadOn = self:GetChecked() and true or nil else self:SetChecked(false) end
    refreshBuyButton()
  end)
  local function spreadTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L("Разброс количества"))
    GameTooltip:AddLine(L("Каждый запрос цены берёт Кол-во ± это число (не меньше 1). 0 — ровно Кол-во"),
      0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end
  for _, w in ipairs({ ui.spreadBox, ui.spreadCheck }) do
    w:SetScript("OnEnter", spreadTip)
    w:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  y = y - 24

  -- presets 5/10/20/50 + your own (RMB stores the number typed in the qty box); key bindings press the same
  local count = #QTY_PRESETS + 1
  for i = 1, count do
    local b = makeButton(nil, tostring(presetQty(i)), 40, function(self, button)
      if i == count and button == "RightButton" then
        local n = tonumber(ui.qtyBox:GetText())
        if n and n > 0 then db().customQty = n; self:SetText(tostring(n)) end
        return
      end
      ns.setBuyQty(presetQty(i))
    end)
    b:SetPoint("TOPRIGHT", -16 - (count - i) * 44, y)
    if i == count then
      ui.customBtn = b
      b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("Своя пачка"))
        GameTooltip:AddLine(L("ПКМ — запомнить число из поля «Кол-во»"), 0.7, 0.7, 0.7)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
  end
  y = y - 30

  -- the one buy button: asks price / confirms / cancels; its label says which
  ui.buy = makeButton("FlipPanelBuyButton", "", 228, onBuyClick)
  ui.buy:SetHeight(28)
  ui.buy:SetPoint("TOP", 0, y)
  y = y - 32

  local hint = host:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOP", 0, y)
  hint:SetText(L("Ctrl + колесо мыши = кнопка покупки"))
  y = y - 18
  ui.status = statusLine(y, "GameFontHighlightSmall")
  y = y - 28 -- status may wrap to two lines
  ui.itemStats = statusLine(y, "GameFontDisableSmall")
  y = y - 20

  ---------------- bottom: settings, log, session stats
  y = section(nil, y)
  local logBtn = makeButton(nil, L("Лог"), 70, function() ns.toggleLog() end)
  logBtn:SetPoint("TOPRIGHT", -16, y)
  local optBtn = makeButton(nil, L("Настройки"), 90, function() ui.opt:SetShown(not ui.opt:IsShown()) end)
  optBtn:SetPoint("TOPRIGHT", -90, y)
  y = y - 26
  ui.stats = statusLine(y, "GameFontDisableSmall")
  y = y - 20
  ui.bodyHeight = -y + 8
  ui.body:SetHeight(ui.bodyHeight)

  ---------------- settings window: every switch that /flip commands toggle, plus history rows. UI only.
  local opt = CreateFrame("Frame", "FlipPanelSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
  ui.opt = opt
  opt:SetSize(300, 210)
  opt:SetPoint("TOPLEFT", ui, "TOPRIGHT", 4, 0)
  opt:SetMovable(true)
  opt:SetClampedToScreen(true)
  opt:EnableMouse(true)
  opt:RegisterForDrag("LeftButton")
  opt:SetScript("OnDragStart", opt.StartMoving)
  opt:SetScript("OnDragStop", opt.StopMovingOrSizing)
  if opt.TitleText then opt.TitleText:SetText(L("FlipPanel — настройки")) end
  if UISpecialFrames then table.insert(UISpecialFrames, "FlipPanelSettingsFrame") end -- Esc closes it
  host = opt
  local checks = {
    makeCheck(12, -30, L("Звуки"), "sound"),
    makeCheck(12, -54, L("Ctrl + колесо мыши = кнопка покупки"), "wheel", function()
      if ahOpen and db().wheel then ns.bindWheel() else ns.unbindWheel() end
    end),
    makeCheck(12, -78, L("Быстрый режим (эксперимент): без отмены котировки"), "fast"),
    makeCheck(12, -102, L("Писать отладку: каждый запрос к аукциону и ответ сервера"), "debug"),
  }
  opt.checks = checks
  opt:SetScript("OnShow", function() -- /flip commands may have changed them meanwhile
    for i, key in ipairs({ "sound", "wheel", "fast", "debug" }) do checks[i]:SetChecked(db()[key]) end
  end)
  ui.rowsBtn = makeButton(nil, "", 120, function()
    db().rows = db().rows % MAX_ROWS + 1
    layoutRows()
  end)
  ui.rowsBtn:SetPoint("TOPLEFT", 16, -134)
  local resetBtn = makeButton(nil, L("Сбросить статистику"), 130, function() ns.resetStats() end)
  resetBtn:SetPoint("TOPLEFT", 16, -164)
  local posBtn = makeButton(nil, L("Панель на место"), 130, function() db().pos = nil; placeUI() end)
  posBtn:SetPoint("TOPLEFT", 152, -164)
  opt:Hide()
  layoutRows()

  resetPost()
  refreshItem()
  -- Hidden panel = no wheel buying (bindWheel/unbindWheel are defined below, looked up at call time)
  ui:SetScript("OnShow", function() ns.bindWheel() end)
  ui:SetScript("OnHide", function() ns.unbindWheel(); ui.opt:Hide() end)
end

---------------------------------------------------------------- log window
local logUI
local logTab = "buys" -- "buys" | "errors" | "debug"

local function fillLog()
  logUI.copy:Hide()
  logUI.msgs:Show()
  logUI.msgs:Clear()
  for _, line in ipairs(db().log[logTab]) do logUI.msgs:AddMessage(line) end
  for kind, b in pairs(logUI.tabs) do b:SetEnabled(kind ~= logTab) end
  logUI.debugCheck:SetChecked(db().debug)
end

refreshLog = function(kind, line)
  if logUI and logUI:IsShown() and kind == logTab then logUI.msgs:AddMessage(line) end
end

-- The message frame can't be selected; "Копировать" swaps in an edit box with the tab's text highlighted
local function toggleCopy()
  if logUI.copy:IsShown() then return fillLog() end
  logUI.copyBox:SetText(table.concat(db().log[logTab], "\n"))
  logUI.msgs:Hide()
  logUI.copy:Show()
  logUI.copyBox:SetFocus()
  logUI.copyBox:HighlightText()
end

local function buildLog()
  logUI = CreateFrame("Frame", "FlipPanelLogFrame", UIParent, "BasicFrameTemplateWithInset")
  logUI:SetSize(540, 300)
  logUI:SetPoint("CENTER")
  logUI:SetMovable(true)
  logUI:SetClampedToScreen(true)
  logUI:EnableMouse(true)
  logUI:RegisterForDrag("LeftButton")
  logUI:SetScript("OnDragStart", logUI.StartMoving)
  logUI:SetScript("OnDragStop", logUI.StopMovingOrSizing)
  if logUI.TitleText then logUI.TitleText:SetText(L("FlipPanel — лог")) end
  if UISpecialFrames then table.insert(UISpecialFrames, "FlipPanelLogFrame") end -- Esc closes it

  logUI.tabs = {}
  for i, t in ipairs({ { "buys", L("Покупки") }, { "errors", L("Ошибки и отмены") }, { "debug", L("Отладка") } }) do
    local kind = t[1]
    local b = makeButton(nil, t[2], 105, function() logTab = kind; fillLog() end, logUI)
    b:SetPoint("TOPLEFT", 12 + (i - 1) * 109, -28)
    logUI.tabs[kind] = b
  end
  local clear = makeButton(nil, L("Очистить"), 80, function() db().log[logTab] = {}; fillLog() end, logUI)
  clear:SetPoint("TOPRIGHT", -12, -28)
  local copy = makeButton(nil, L("Копировать"), 90, toggleCopy, logUI)
  copy:SetPoint("TOPRIGHT", -96, -28)

  local cb = CreateFrame("CheckButton", nil, logUI, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", 10, -52)
  cb:SetScript("OnClick", function(self) db().debug = self:GetChecked() and true or false end)
  local cbText = logUI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  cbText:SetPoint("LEFT", cb, "RIGHT", 0, 0)
  cbText:SetText(L("Писать отладку: каждый запрос к аукциону и ответ сервера"))
  logUI.debugCheck = cb

  logUI.msgs = CreateFrame("ScrollingMessageFrame", nil, logUI)
  logUI.msgs:SetPoint("TOPLEFT", 14, -80)
  logUI.msgs:SetPoint("BOTTOMRIGHT", -14, 12)
  logUI.msgs:SetFontObject(GameFontHighlightSmall)
  logUI.msgs:SetJustifyH("LEFT")
  logUI.msgs:SetFading(false)
  logUI.msgs:SetMaxLines(LOG_MAX)
  logUI.msgs:EnableMouseWheel(true)
  logUI.msgs:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
  end)

  logUI.copy = CreateFrame("ScrollFrame", nil, logUI, "UIPanelScrollFrameTemplate")
  logUI.copy:SetPoint("TOPLEFT", 14, -80)
  logUI.copy:SetPoint("BOTTOMRIGHT", -32, 12)
  logUI.copyBox = CreateFrame("EditBox", nil, logUI.copy)
  logUI.copyBox:SetMultiLine(true)
  logUI.copyBox:SetAutoFocus(false)
  logUI.copyBox:SetFontObject(GameFontHighlightSmall)
  logUI.copyBox:SetWidth(480)
  logUI.copyBox:SetScript("OnEscapePressed", function() fillLog() end)
  logUI.copy:SetScrollChild(logUI.copyBox)
  logUI.copy:Hide()
  logUI:Hide()
end

function ns.showLog(kind)
  if not logUI then buildLog() end
  if kind then logTab = kind end
  logUI:Show()
  fillLog()
end

function ns.toggleLog()
  if logUI and logUI:IsShown() then return logUI:Hide() end
  ns.showLog()
end

refreshList = function()
  local ids, sel = sortedItems(db().items), db().itemID
  local shown = db().rows * ROW_ITEMS
  for i, b in ipairs(ui.list) do
    local id = i <= shown and ids[i] or nil
    b.id = id
    if id then
      b.icon:SetTexture(C_Item.GetItemIconByID(id) or "Interface\\Icons\\INV_Misc_QuestionMark")
      b.mark:SetShown(id == sel)
      b:Show()
    else
      b:Hide()
    end
  end
end

-- Shift+click on an item link while the ID box has focus selects that item.
-- hooksecurefunc only (never replace: taint). Name differs between clients, so guard both.
local function onInsertLink(link)
  if ui and ui.idBox:HasFocus() and type(link) == "string" then
    local id = tonumber(link:match("item:(%d+)"))
    if id then
      ui.idBox:SetText(tostring(id))
      ui.idBox:ClearFocus() -- OnEditFocusLost -> selectItem
    end
  end
end
if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", onInsertLink) end
if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink) end

---------------------------------------------------------------- wheel binding
local function bindWheel()
  if not ui or not db().wheel or InCombatLockdown() then return end
  SetOverrideBindingClick(ui, true, "CTRL-MOUSEWHEELUP", "FlipPanelBuyButton")
  SetOverrideBindingClick(ui, true, "CTRL-MOUSEWHEELDOWN", "FlipPanelBuyButton")
end

local function unbindWheel()
  if ui and not InCombatLockdown() then ClearOverrideBindings(ui) end
end
ns.bindWheel, ns.unbindWheel = bindWheel, unbindWheel

SLASH_FLIPPANEL1 = "/flip"
SlashCmdList["FLIPPANEL"] = function(text)
  text = (text or ""):lower():match("^%s*(.-)%s*$")
  if text == "" then -- only a bare /flip shows or hides the panel
    if ui then ui:SetShown(not ui:IsShown()) else msg(L("Открой аукцион, панель появится рядом с ним")) end
  elseif text == "wheel" then
    db().wheel = not db().wheel
    msg(L("Ctrl+колесо: ") .. (db().wheel and L("вкл") or L("выкл")))
    if ahOpen then if db().wheel then bindWheel() else unbindWheel() end end
  elseif text == "reset" then
    ns.resetStats()
  elseif text == "resetpos" then
    db().pos = nil
    if ui then placeUI() end
  elseif text == "debug" then
    db().debug = not db().debug
    msg(L("Отладка: ") .. (db().debug and L("вкл") or L("выкл")))
    if db().debug then ns.showLog("debug") elseif logUI then fillLog() end
  elseif text == "log" then
    ns.toggleLog()
  elseif text == "fast" then
    db().fast = not db().fast
    msg(L("Быстрый режим (цена не подошла — следующее нажатие сразу запрашивает новую, без отмены): ")
      .. (db().fast and L("вкл") or L("выкл")))
  else -- unknown command: show help, never touch the panel
    msg(L("/flip — показать/скрыть, /flip log, /flip debug, /flip fast, /flip wheel, /flip reset, /flip resetpos"))
  end
end

---------------------------------------------------------------- events
local f = CreateFrame("Frame")
local EVENTS = {
  "ADDON_LOADED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "PLAYER_REGEN_ENABLED",
  "AUCTION_HOUSE_POST_WARNING", "AUCTION_HOUSE_AUCTION_CREATED",
  "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE",
  "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED",
  "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
  "AUCTION_HOUSE_SHOW_ERROR", "AUCTION_HOUSE_POST_ERROR", "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED",
  -- only written to the debug log: they show what the client throttles and for how long
  "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT", "AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED",
  "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
}
for _, e in ipairs(EVENTS) do pcall(f.RegisterEvent, f, e) end -- tolerate events missing on Forever

local function onEvent(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= "FlipPanel" then return end
    FlipPanelDB = FlipPanelDB or {}
    local d = FlipPanelDB
    d.items = d.items or {}
    if d.itemID and not d.items[d.itemID] then -- migrate the old single-item settings
      d.items[d.itemID] = { priceText = d.priceText or "", qty = d.qty or 10, last = time() }
    end
    d.priceText, d.price, d.qty = nil, nil, nil
    for _, item in pairs(d.items) do item.sellText = item.sellText or "" end -- sell price is separate since v3
    if d.wheel == nil then d.wheel = true end
    d.twoPress = nil -- auto-confirm mode was removed: two presses is the only way
    if d.sound == nil then d.sound = true end
    d.autoCancel = nil -- auto-cancel was removed: a cancel is a press too
    d.autoConfirm = nil -- the "1 click" mode was removed: a purchase always takes two presses
    d.log = d.log or {}
    d.log.buys, d.log.errors, d.log.debug = d.log.buys or {}, d.log.errors or {}, d.log.debug or {}
    d.postQty = d.postQty or 1
    d.postDur = d.postDur or 1 -- 1 = shortest
    d.rows = math.min(math.max(tonumber(d.rows) or 1, 1), MAX_ROWS)
    d.customQty = d.customQty or 100

  elseif event == "AUCTION_HOUSE_SHOW" then
    ahOpen = true
    if not ui then buildUI() end
    bindWheel()

  elseif event == "PLAYER_REGEN_ENABLED" then
    if ahOpen then bindWheel() end -- AH opened during combat: bind now

  elseif event == "AUCTION_HOUSE_CLOSED" then
    ahOpen = false
    -- No request here: a quote that may still exist waits for your press after reopening
    local open = state == "quoting" or state == "ready" or state == "cancel"
    if open then
      state = "cancel"
      setStatus(L("Окно закрыто: жми «ОТМЕНИТЬ котировку»"))
      refreshBuyButton()
    else
      toIdle()
    end
    postTry = nil
    resetPost()
    unbindWheel()

  elseif event == "AUCTION_HOUSE_POST_WARNING" then
    -- Fallback in case PostCommodity didn't return needsConfirmation on this client
    if postTry and not pendingPost and ui then
      pendingPost = postTry
      refreshPost()
      setPostStatus(L("Игра предупреждает о цене, нажми ещё раз"))
    end

  elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
    if postTry then
      local text = (L("Выставлено %d %s по %s (%s)")):format(postTry.qty, C_Item.GetItemNameByID(db().itemID) or "",
        money(postTry.price), durText(postTry.dur))
      setPostStatus(text)
      log("buys", text)
    end
    postTry = nil
    resetPost()

  elseif event == "COMMODITY_PRICE_UPDATED" then
    -- The server may send a new price for a quote that is already open (Blizzard's dialog handles that too):
    -- a ready quote is checked again, so what you confirm is always the last price the server gave
    if (state ~= "quoting" and state ~= "ready") or not pending then return end -- not our quote
    local _, totalPrice = ...
    pending.total, pending.quotedAt = totalPrice, GetTime()
    if pending.stale then
      toCancel(L("Настройки изменились, пока сервер отвечал"))
    elseif totalPrice > pending.qty * pending.maxUnit then
      toCancel((L("Дорого: %d за %s (макс. %s)")):format(pending.qty, money(totalPrice),
        money(pending.qty * pending.maxUnit)))
    elseif totalPrice > GetMoney() then
      toCancel((L("Не хватает золота: нужно %s")):format(money(totalPrice)))
    else
      toReady()
    end

  elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
    if state == "quoting" or state == "ready" then toCancel((L("Нет в продаже %d шт.")):format(pending.qty)) end

  elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
    if state == "confirming" and pending then
      local s = stats.byItem[pending.itemID] or { bought = 0, spent = 0 }
      stats.byItem[pending.itemID] = s
      s.bought, s.spent = s.bought + pending.qty, s.spent + (pending.total or 0)
      play("LOOT_WINDOW_COIN_SOUND")
      local name = C_Item.GetItemNameByID(pending.itemID) or ("item " .. pending.itemID)
      log("buys", (L("Куплено %d %s за %s (ср. %s)")):format(pending.qty, name, money(pending.total),
        money(math.floor((pending.total or 0) / pending.qty))))
      toIdle((L("Куплено %d шт. за %s")):format(pending.qty, money(pending.total)))
    end

  elseif event == "COMMODITY_PURCHASE_FAILED" then
    if state == "confirming" then
      log("errors", L("Покупка не прошла (сервер отказал)"))
      holdUntil = pending.sentAt + FAIL_HOLD
      toIdle(L("Покупка не прошла"))
    end

  elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
    local err = ...
    log("errors", L("Аукцион: ") .. ahErrorText(err) .. " (#" .. tostring(err) .. ", " .. state .. ")")
    if pending and state == "confirming" then
      -- Usually someone bought those units first (or the quote went stale): back to "Купить" right away,
      -- so the next press simply asks for a fresh price. The purchase was already sent: nothing to cancel.
      holdUntil = pending.sentAt + FAIL_HOLD
      toIdle(L("Не успел: покупка не прошла (ошибка аукциона). Жми, чтобы узнать цену заново"))
    elseif pending and state == "quoting" then
      -- The server refused the price request (seen right after a failed purchase): no quote was opened,
      -- so there is nothing to cancel. Back to "Купить": the next press asks again.
      toIdle(L("Ошибка аукциона. Жми, чтобы узнать цену заново"))
    end

  elseif event == "AUCTION_HOUSE_POST_ERROR" then
    log("errors", L("Ошибка выставления"))

  elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" then
    log("errors", L("Сервер отбросил запрос: превышен лимит"))

  elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    local addon, func = ...
    if addon == "FlipPanel" then
      log("errors", L("Игра заблокировала вызов ") .. tostring(func))
    end
  end
end

-- Lua errors in event handling also go to the error log; BugSack still gets them
f:SetScript("OnEvent", function(self, event, ...)
  if FlipPanelDB and FlipPanelDB.debug and event ~= "ADDON_LOADED" and event ~= "PLAYER_REGEN_ENABLED" then
    local args = {}
    for i = 1, select("#", ...) do args[i] = tostring((select(i, ...))) end
    dbg(("<- %s %s (state=%s)"):format(event, table.concat(args, " "), state))
  end
  local ok, err = pcall(onEvent, self, event, ...)
  if not ok then
    log("errors", L("Ошибка Lua: ") .. tostring(err))
    geterrorhandler()(err)
  end
end)
