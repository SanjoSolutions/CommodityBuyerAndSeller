CommodityBuyerAndSeller = {}
local _ = {}

local INFINITY = 1 / 0

local tasks = {}

local remainingQuantitiesToSell = {}
local sellTasks = {}
local purchaseTasks = {}

--- Adds a buy and sell task for an item.
--- @param itemID number The item ID.
--- @param maximumUnitPriceToBuyFor number The maximum unit price to buy for in gold.
--- @param maximumTotalQuantityToPutIntoAuctionHouse number The maximum total quantity to put into the auction house.
--- @param maximumQuantityToPutIntoAuctionHouseAtATime number The maximum quantity to put into the auction house at a time.
--- @param minimumSellPricePerUnit number The minimum sell price per unit.
function CommodityBuyerAndSeller.buyAndSell(itemID, maximumUnitPriceToBuyFor, maximumTotalQuantityToPutIntoAuctionHouse,
  maximumQuantityToPutIntoAuctionHouseAtATime, minimumSellPricePerUnit)
  _.setBuyTask(itemID, maximumTotalQuantityToPutIntoAuctionHouse, maximumQuantityToPutIntoAuctionHouseAtATime,
    minimumSellPricePerUnit)
  _.setSellTask(itemID, maximumUnitPriceToBuyFor)
  _.runLoop()
end

--- Adds a buy task for an item.
--- @param itemID number The item ID.
--- @param maximumUnitPriceToBuyFor number The maximum unit price to buy for in gold.
function CommodityBuyerAndSeller.buy(itemID, maximumUnitPriceToBuyFor)
  _.setSellTask(itemID, maximumUnitPriceToBuyFor)
  _.runLoop()
end

--- Adds a sell task for an item.
--- @param itemID number The item ID.
--- @param maximumTotalQuantityToPutIntoAuctionHouse number The maximum total quantity to put into the auction house.
--- @param maximumQuantityToPutIntoAuctionHouseAtATime number The maximum quantity to put into the auction house at a time.
--- @param minimumSellPricePerUnit number The minimum sell price per unit.
function CommodityBuyerAndSeller.sell(itemID, maximumTotalQuantityToPutIntoAuctionHouse,
  maximumQuantityToPutIntoAuctionHouseAtATime, minimumSellPricePerUnit)
  _.setBuyTask(itemID, maximumTotalQuantityToPutIntoAuctionHouse, maximumQuantityToPutIntoAuctionHouseAtATime,
    minimumSellPricePerUnit)
  _.runLoop()
end

--- Returns the item ID of an item.
--- @param itemIdentifier string | number An item identifier. Can be an item name or item link. If it's an item name, it seems required that the item was in the bags in the session.
--- @return number The item ID.
function CommodityBuyerAndSeller.retrieveItemID(itemIdentifier)
  local itemID = GetItemInfoInstant(itemIdentifier)
  return itemID
end

local sorts = {
  {
    sortOrder = Enum.AuctionHouseSortOrder.Price,
    reverseSort = false
  }
}

function CommodityBuyerAndSeller.cancelAuctions()
  Coroutine.runAsCoroutineImmediately(function()
    _.cancelAuctions()

    print('Auctions have been cancelled.')
  end)
end

function _.cancelAuctions()
  local auctions = C_AuctionHouse.GetOwnedAuctions()
  local itemIDs = Set.create()
  Array.forEach(auctions, function(auction)
    local itemID = auction.itemKey.itemID
    itemIDs:add(itemID)
  end)

  for itemID in itemIDs:iterator() do
    local amountSoldPerDay = TSM_API.GetCustomPriceValue('dbregionsoldperday',
      'i:' .. itemID) -- TODO: Add item level for items with different item levels
    if amountSoldPerDay then
      local itemKey = { itemID = itemID }
      C_AuctionHouse.SendSearchQuery(
        itemKey,
        sorts,
        true
      )
      local wasSuccessful, event, argument1 = Events.waitForOneOfEventsAndCondition({ 'COMMODITY_SEARCH_RESULTS_UPDATED', 'AUCTION_HOUSE_SHOW_ERROR' },
        function(self, event, argument1)
          if event == 'COMMODITY_SEARCH_RESULTS_UPDATED' then
            local itemID = argument1
            return itemID == itemKey.itemID
          elseif event == 'AUCTION_HOUSE_SHOW_ERROR' then
            return true
          end
        end, 3)
      if event == 'AUCTION_HOUSE_SHOW_ERROR' and argument1 == 10 then
        Events.waitForEvent('AUCTION_HOUSE_THROTTLED_SYSTEM_READY')
      end
      if event == 'COMMODITY_SEARCH_RESULTS_UPDATED' then
        local numberOfCommoditySearchResults = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
        local results = {}
        for index = 1, numberOfCommoditySearchResults do
          local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
          if result then
            table.insert(results, result)
          end
        end

        local quantity = 0
        Array.forEach(results, function(result)
          if result.containsOwnerItem then
            local estimatedAmountThatSellsUntilTheAuctionRunsOut = amountSoldPerDay * (result.timeLeftSeconds / (24 * 60 * 60))
            if quantity > estimatedAmountThatSellsUntilTheAuctionRunsOut then
              C_AuctionHouse.CancelAuction(result.auctionID)
              Events.waitForEventCondition('AUCTION_CANCELED', function(self, event, auctionID)
                return auctionID == result.auctionID
              end)
            end
          end
          quantity = quantity + result.quantity
        end)
      end
    end
  end
end

function _.setBuyTask(itemID, maximumTotalQuantityToPutIntoAuctionHouse, maximumQuantityToPutIntoAuctionHouseAtATime,
  minimumSellPricePerUnit)
  minimumSellPricePerUnit = minimumSellPricePerUnit * 10000

  if not remainingQuantitiesToSell[itemID] then
    remainingQuantitiesToSell[itemID] = 0
  end
  remainingQuantitiesToSell[itemID] = maximumTotalQuantityToPutIntoAuctionHouse

  local task = {
    type = 'sell',
    itemID = itemID,
    maximumTotalQuantityToPutIntoAuctionHouse = maximumTotalQuantityToPutIntoAuctionHouse,
    maximumQuantityToPutIntoAuctionHouseAtATime = maximumQuantityToPutIntoAuctionHouseAtATime,
    minimumSellPricePerUnit = minimumSellPricePerUnit,
  }
  _.setTask(task)
end

function _.setSellTask(itemID, maximumUnitPriceToBuyFor)
  local task = {
    type = 'buy',
    itemID = itemID,
    maximumUnitPriceToBuyFor = maximumUnitPriceToBuyFor * 10000
  }
  _.setTask(task)
end

function _.setTask(task)
  if not tasks[task.itemID] then
    tasks[task.itemID] = {}
  end

  tasks[task.itemID][task.type] = task
end

local isLoopRunning = false

function _.runLoop()
  if not isLoopRunning then
    isLoopRunning = true

    local isAuctionHouseOpen = AuctionHouseFrame:IsShown()

    local onAuctionHouseShowListener = Events.listenForEvent('AUCTION_HOUSE_SHOW', function()
      isAuctionHouseOpen = true
    end)

    local onAuctionHouseClosedListener = Events.listenForEvent('AUCTION_HOUSE_CLOSED', function()
      isAuctionHouseOpen = false
    end)

    Coroutine.runAsCoroutine(function()
      while isAuctionHouseOpen and Object.hasEntries(tasks) do
        for itemID, __ in pairs(tasks) do
          local itemKey = { itemID = itemID }
          C_AuctionHouse.SendSearchQuery(
            itemKey,
            sorts,
            true
          )
          local wasSuccessful, event, argument1 = Events.waitForOneOfEventsAndCondition({ 'COMMODITY_SEARCH_RESULTS_UPDATED', 'AUCTION_HOUSE_SHOW_ERROR' },
            function(self, event, argument1)
              if event == 'COMMODITY_SEARCH_RESULTS_UPDATED' then
                local itemID = argument1
                return itemID == itemKey.itemID
              elseif event == 'AUCTION_HOUSE_SHOW_ERROR' then
                return true
              end
            end, 3)
          if event == 'AUCTION_HOUSE_SHOW_ERROR' and argument1 == 10 then
            Events.waitForEvent('AUCTION_HOUSE_THROTTLED_SYSTEM_READY')
          end
          if event == 'COMMODITY_SEARCH_RESULTS_UPDATED' then
            local buyTask = tasks[itemID].buy
            if buyTask then
              local maximumUnitPriceToBuyFor = buyTask.maximumUnitPriceToBuyFor

              local numberOfCommoditySearchResults = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
              local quantity = 0
              local moneyLeft = GetMoney()
              for index = 1, numberOfCommoditySearchResults do
                local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
                if result.unitPrice <= maximumUnitPriceToBuyFor then
                  local buyableQuantity = math.min(result.quantity, math.floor(moneyLeft / result.unitPrice))
                  quantity = quantity + buyableQuantity
                  moneyLeft = moneyLeft - buyableQuantity * result.unitPrice
                  if moneyLeft < maximumUnitPriceToBuyFor then
                    break
                  end
                else
                  break
                end
              end
              if quantity >= 1 then
                local purchaseTask = {
                  itemID = itemID,
                  quantity = quantity,
                  maximumUnitPriceToBuyFor = maximumUnitPriceToBuyFor
                }
                table.insert(purchaseTasks, purchaseTask)
                _.workThroughPurchaseTasks()
              end
            end

            local sellTask = tasks[itemID].sell
            if sellTask then
              if not Bags.hasItem(itemID) then
                tasks[itemID].sell = nil
              end

              local maximumQuantityToPutIntoAuctionHouseAtATime = sellTask.maximumQuantityToPutIntoAuctionHouseAtATime
              local minimumSellPricePerUnit = sellTask.minimumSellPricePerUnit

              local unitPrice = _.determineUnitPrice(itemID)
              if unitPrice and unitPrice >= minimumSellPricePerUnit then
                local quantityAlreadyOnTopInAuctionHouse = _.determineQuantityAlreadyOnTopInAuctionHouse(sellTask)
                _.queueSellTaskAndWorkThroughSellTasks(sellTask, unitPrice, quantityAlreadyOnTopInAuctionHouse)
                if remainingQuantitiesToSell[itemID] == 0 or not Bags.hasItem(itemID) then
                  print('removing sell task', remainingQuantitiesToSell[itemID] == 0, not Bags.hasItem(itemID))
                  tasks[itemID].sell = nil
                end
              end
            end
          end
        end

        -- _.cancelAuctions()

        Coroutine.yieldAndResume()
      end

      tasks = {}
      sellTasks = {}
      purchaseTasks = {}
      onAuctionHouseShowListener:stopListening()
      onAuctionHouseClosedListener:stopListening()
      isLoopRunning = false
    end)
  end
end

function _.determineUnitPrice(itemID)
  local numberOfCommoditySearchResults = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
  if numberOfCommoditySearchResults >= 1 then
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
    if result then
      return result.unitPrice
    end
  end

  return nil
end

function _.determineQuantityAlreadyOnTopInAuctionHouse(task)
  local itemID = task.itemID
  local quantity = 0
  local numberOfCommoditySearchResults = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
  for index = 1, numberOfCommoditySearchResults do
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
    if result.numOwnerItems == 0 then
      break
    end
    quantity = quantity + result.numOwnerItems
  end
  return quantity
end

function _.queueSellTaskAndWorkThroughSellTasks(task, unitPrice, quantityAlreadyOnTopInAuctionHouse)
  local itemID = task.itemID
  local quantityLeftToPutIntoAuctionHouse = math.min(remainingQuantitiesToSell[itemID], Bags.countItem(itemID),
    task.maximumQuantityToPutIntoAuctionHouseAtATime - quantityAlreadyOnTopInAuctionHouse)
  if quantityLeftToPutIntoAuctionHouse >= 1 then
    local sellTask = {
      itemID = itemID,
      quantity = quantityLeftToPutIntoAuctionHouse,
      unitPrice = unitPrice
    }
    table.insert(sellTasks, sellTask)
    _.workThroughSellTasks()
  end
end

function _.workThroughSellTasks()
  while Array.hasElements(sellTasks) do
    local sellTask = table.remove(sellTasks, 1)
    local itemID = sellTask.itemID
    local quantity = sellTask.quantity
    local unitPrice = sellTask.unitPrice

    local containerIndex, slotIndex = Bags.findItem(itemID)
    if containerIndex and slotIndex then
      local item = ItemLocation:CreateFromBagAndSlot(containerIndex, slotIndex)
      local duration = 1
      -- TODO: Does it work if the item is distributed over multiple slots?
      local itemLink = C_Item.GetItemLink(item)
      print('Trying to put in ' .. quantity .. ' x ' .. itemLink .. ' (each for ' .. GetMoneyString(unitPrice) .. ').')
      _.showConfirmButton()
      local requiresConfirmation = C_AuctionHouse.PostCommodity(item, duration, quantity, unitPrice)
      if requiresConfirmation then
        C_AuctionHouse.ConfirmPostCommodity(item, duration, quantity, unitPrice)
      end
      -- TODO: Events for error?
      local wasSuccessful = Events.waitForEvent('AUCTION_HOUSE_AUCTION_CREATED', 3)
      if wasSuccessful then
        print('Have put in ' .. quantity .. ' x ' .. itemLink .. ' (each for ' .. GetMoneyString(unitPrice) .. ').')
        remainingQuantitiesToSell[itemID] = math.max(remainingQuantitiesToSell[itemID] - quantity, 0)
      else
        print('Error putting in ' .. quantity .. ' x ' .. itemLink .. '.')
      end
    end
  end
end

local confirmButton = CreateFrame('Button', nil, UIParent, 'UIPanelButtonTemplate')
confirmButton:SetSize(144, 48)
confirmButton:SetText('Confirm')
confirmButton:SetPoint('CENTER', 0, 0)
confirmButton:Hide()

function _.showConfirmButton()
  confirmButton:Show()
  local thread = coroutine.running()
  confirmButton:SetScript('OnClick', function()
    confirmButton:Hide()
    Coroutine.resumeWithShowingError(thread)
  end)
  coroutine.yield()
end

function _.workThroughPurchaseTasks()
  while Array.hasElements(purchaseTasks) do
    local purchaseTask = table.remove(purchaseTasks, 1)
    local itemID = purchaseTask.itemID
    local quantity = purchaseTask.quantity
    local maximumUnitPriceToBuyFor = purchaseTask.maximumUnitPriceToBuyFor

    _.loadItem(itemID)
    local itemLink = select(2, GetItemInfo(itemID))
    print('Trying to buy ' .. quantity .. ' x ' .. itemLink .. ' (for a maximum unit price of ' .. GetMoneyString(maximumUnitPriceToBuyFor) .. ').')
    _.showConfirmButton()
    C_AuctionHouse.StartCommoditiesPurchase(itemID, quantity)
    local wasSuccessful, event, unitPrice, totalPrice = Events.waitForOneOfEvents({ 'COMMODITY_PRICE_UPDATED', 'COMMODITY_PRICE_UNAVAILABLE' },
      3)
    if event == 'COMMODITY_PRICE_UPDATED' then
      if unitPrice <= maximumUnitPriceToBuyFor then
        C_AuctionHouse.ConfirmCommoditiesPurchase(itemID, quantity)
        local wasSuccessful, event = Events.waitForOneOfEvents({ 'COMMODITY_PURCHASE_SUCCEEDED', 'COMMODITY_PURCHASE_FAILED' }, 3)
        if wasSuccessful and event == 'COMMODITY_PURCHASE_SUCCEEDED' then
          print('Have bought ' .. quantity .. ' x ' .. itemLink .. ' (for a unit price of ' .. GetMoneyString(unitPrice) .. ').')
        end
      end
    end
  end
end

function _.loadItem(itemID)
  local item = Item:CreateFromItemID(itemID)
  if not item:IsItemDataCached() then
    local thread = coroutine.running()

    item:ContinueOnItemLoad(function()
      Coroutine.resumeWithShowingError(thread)
    end)

    coroutine.yield()
  end
end
