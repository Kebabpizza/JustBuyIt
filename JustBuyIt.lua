local initialized = false
local listenToCommoditiesEvents = false
local slowBuyNext = false

local buyUnits = 0
local buyId = 0
local maxPrice = 0

local moneyInput = nil
local buyButton = nil
local text = nil
local quantityInput = nil

local settingsCategory = nil

local f = CreateFrame("Frame", "JustBuyItFrame", UIParent)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("COMMODITY_PRICE_UPDATED")
f:RegisterEvent("COMMODITY_PURCHASE_FAILED")
f:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
f:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
f:RegisterEvent("COMMODITY_SEARCH_RESULTS_RECEIVED")
f:RegisterEvent("AUCTION_HOUSE_BROWSE_FAILURE")

f:SetScript("OnEvent", function(self, eventName, ...)

    if (eventName == "AUCTION_HOUSE_SHOW") then
        if (initialized) then
            return
        end

        initialized = true

        local quantityInputFrame = CreateFrame("Frame", nil, AuctionHouseFrame.CommoditiesBuyFrame)
        quantityInputFrame:SetSize(200, 100)
        quantityInputFrame:SetPoint("CENTER", AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.BuyButton, 0, 0)

        local quantityInputLabel = quantityInputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        quantityInputLabel:SetSize(93, 30)
        quantityInputLabel:SetJustifyH("RIGHT")
        quantityInputLabel:SetPoint("LEFT", AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.QuantityInput, "LEFT", 0, 0)
        quantityInputLabel:SetPoint("TOP", AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.BuyButton, "BOTTOM", 0, -10)
        quantityInputLabel:SetText(AUCTION_HOUSE_QUANTITY_LABEL)

        quantityInput = CreateFrame("EditBox", nil, quantityInputFrame, "AuctionHouseQuantityInputEditBoxTemplate")
        quantityInput:SetPoint("LEFT", quantityInputLabel, "RIGHT", 18, 0)
        quantityInput:Show()

        quantityInput:SetScript("OnTextChanged", function(self, value)
            local quantity = self:GetNumber()
            if (quantity <= 0) then
                buyButton:SetEnabled(false)
            elseif (listenToCommoditiesEvents == false) then
                buyButton:SetEnabled(true)
            end
            resetSlowBuy()
        end)

        local moneyInputFrame = CreateFrame("Frame", nil, AuctionHouseFrame.CommoditiesBuyFrame)
        moneyInputFrame:SetSize(200, 100)
        moneyInputFrame:SetPoint("CENTER", AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.BuyButton, 0, 0)

        local moneyInputLabel = moneyInputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        moneyInputLabel:SetSize(93, 30)
        moneyInputLabel:SetJustifyH("RIGHT")
        moneyInputLabel:SetPoint("LEFT", AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.QuantityInput, "LEFT", 0, 0)
        moneyInputLabel:SetPoint("TOP", quantityInput, "BOTTOM", 0, 0)
        moneyInputLabel:SetText(AUCTION_HOUSE_UNIT_PRICE_LABEL)

        moneyInput = CreateFrame("Frame", "JustBuyIt.MoneyInput", moneyInputFrame, "MoneyInputFrameTemplate")
        if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
            MoneyInputFrame_SetCopperShown(moneyInput, false)
        end
        moneyInput:SetPoint("LEFT", moneyInputLabel, "RIGHT", 23, 0)
        MoneyInputFrame_SetOnValueChangedFunc(moneyInput, function()
            if (slowBuyNext) then
                resetSlowBuy()
            end
        end)
        moneyInput:Show()

        buyButton = CreateFrame("Button", "JustBuyIt.BuyButton", AuctionHouseFrame.CommoditiesBuyFrame, "UIPanelButtonTemplate");
        buyButton:SetPoint("LEFT", AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.BuyButton, 0, 0)
        buyButton:SetPoint("TOP", moneyInput, "BOTTOM", 0, -10)
        buyButton:SetFrameStrata("FULLSCREEN")
        buyButton:SetWidth(196)

        buyButton:SetText("Just Buy It")
        buyButton:SetEnabled(true)
        buyButton:SetScript("OnClick", function()
            buyButton:SetEnabled(false)
            text:SetText("...")

            if (slowBuyNext) then
                slowBuyNext = false
                C_AuctionHouse.StartCommoditiesPurchase(buyId, buyUnits)
                return
            end

            buyUnits = quantityInput:GetNumber()
            buyId = AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.ItemDisplay:GetItemID()
            maxPrice = MoneyInputFrame_GetCopper(moneyInput)

            listenToCommoditiesEvents = true
            if (JustBuyItDB["buyMode"] == 0) then
                -- "fast"
                C_AuctionHouse.StartCommoditiesPurchase(buyId, buyUnits)
            else
                -- "slow"
                local itemKey = C_AuctionHouse.MakeItemKey(buyId)
                C_AuctionHouse.SendSearchQuery(itemKey, {}, false)
            end
        end)

        local settingsButton = CreateFrame("Button", nil, AuctionHouseFrame.CommoditiesBuyFrame, nil)
        settingsButton:SetSize(24, 24)
        settingsButton:SetPoint("LEFT", buyButton, "RIGHT", 12, 0)
        if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
            settingsButton:SetNormalAtlas("mechagon-projects")
            settingsButton:SetHighlightAtlas("mechagon-projects")
        else
            settingsButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
            settingsButton:SetPushedTexture("Interface\\Icons\\INV_Misc_Gear_01")
            settingsButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        end
        settingsButton:SetFrameStrata("FULLSCREEN")
        settingsButton:SetScript("OnClick", function()
            Settings.OpenToCategory(settingsCategory:GetID())
        end)

        settingsButton:Show()

        local textFrame = CreateFrame("Frame", nil, AuctionHouseFrame.CommoditiesBuyFrame)
        textFrame:SetSize(200, 24)
        textFrame:SetPoint("CENTER", buyButton, 0, 0)
        textFrame:SetPoint("TOP", buyButton, "BOTTOM", 0, -2)
        text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER", textFrame, "CENTER")
    end

    _G["JustBuyIt.BuyButton"] = buyButton

    if (listenToCommoditiesEvents == false) then
        return
    end

    if (eventName == "AUCTION_HOUSE_BROWSE_FAILURE") then
        listenToCommoditiesEvents = false
        text:SetText("Failed")
        buyButton:SetEnabled(true)
        refreshListings()
    end

    if (eventName == "COMMODITY_SEARCH_RESULTS_UPDATED") then
        local id = ...
        if (id ~= buyId) then
            resetSlowBuy()
        end
    end

    if (eventName == "COMMODITY_SEARCH_RESULTS_RECEIVED") then
        local availableQuantity = 0
        for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(buyId) do
            local result = C_AuctionHouse.GetCommoditySearchResultInfo(buyId, i)
            if (result.unitPrice > maxPrice) then
                if (availableQuantity == 0) then
                    text:SetText("Too expensive (" .. formatMoney(result.unitPrice) .. ")")
                end
                break
            end

            availableQuantity = availableQuantity + result.quantity
        end

        if (availableQuantity > 0) then
            slowBuyNext = true
            buyUnits = math.min(buyUnits, availableQuantity)
            text:SetText("Found " .. availableQuantity .. " items, buy " .. buyUnits .. "?")
        else
            listenToCommoditiesEvents = false
        end

        buyButton:SetEnabled(true)
    end

    if (eventName == "COMMODITY_PRICE_UPDATED") then
        local unitPrice, totalPrice = ...

        local averageUnitPrice = totalPrice / buyUnits

        if (averageUnitPrice > maxPrice) then
            listenToCommoditiesEvents = false
            text:SetText("Too expensive (" .. formatMoney(averageUnitPrice) .. ")")
            C_AuctionHouse.CancelCommoditiesPurchase()
            buyButton:SetEnabled(true)
            refreshListings()
        else
            resetQuantity = true
            C_AuctionHouse.ConfirmCommoditiesPurchase(buyId, buyUnits)
        end
    end

    if (eventName == "COMMODITY_PURCHASE_FAILED") then
        listenToCommoditiesEvents = false
        resetQuantity = false
        text:SetText("Failed")
        buyButton:SetEnabled(true)
        refreshListings()
    end

    if (eventName == "COMMODITY_PURCHASE_SUCCEEDED") then
        if (JustBuyItDB["reduceQuantity"]) then
            local value = quantityInput:GetNumber()
            value = value - buyUnits
            quantityInput:SetNumber(value)
        end

        listenToCommoditiesEvents = false
        text:SetText("Success")
        buyButton:SetEnabled(true)
        refreshListings()
    end
end)

function formatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)

    if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
        return string.format("%dg%02ds", gold, silver)
    else
        local copper = copper % 100
        return string.format("%dg%02ds%02dc", gold, silver, copper)
    end
end

function refreshListings()
    AuctionHouseFrame.CommoditiesBuyFrame.ItemList.RefreshFrame.RefreshButton.OnClick(AuctionHouseFrame.CommoditiesBuyFrame.ItemList.RefreshFrame.RefreshButton)
end

function resetSlowBuy()
    slowBuyNext = false
    listenToCommoditiesEvents = false
    text:SetText("")
end

EventUtil.ContinueOnAddOnLoaded("JustBuyIt", function()
    if not JustBuyItDB then
        JustBuyItDB = {

        }
    end

    settingsCategory = Settings.RegisterVerticalLayoutCategory("Just Buy It")

    do
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            container:Add(0, "Fast")
            container:Add(1, "Slow")
            return container:GetData()
        end
        local setting = Settings.RegisterAddOnSetting(category, "JustBuyIt_BuyMode", "buyMode", JustBuyItDB, Settings.VarType.Number, "Buy Mode", 0)
        setting:SetValue(JustBuyItDB["buyMode"])
        Settings.CreateDropdown(settingsCategory, setting, GetOptions, "Slow requires two clicks and allows partial purchases, but there's a higher risk of someone else buying it. Fast requires one click and only allows exact purchases.")
    end

    do
        local reduceQuantity = Settings.RegisterAddOnSetting(category, "JustBuyIt_ReduceQuantity", "reduceQuantity", JustBuyItDB, Settings.VarType.Boolean, "Reduce Quantity", false)
        Settings.CreateCheckbox(settingsCategory, reduceQuantity, "Reduce quantity on successful purchase")
    end

    Settings.RegisterAddOnCategory(settingsCategory)
end)
