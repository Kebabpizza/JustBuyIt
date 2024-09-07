local initialized = false
local listenToCommoditiesEvents = false

local buyUnits = 0
local buyId = 0
local maxPrice = 0

local moneyInput = nil
local buyButton = nil
local text = nil

local f = CreateFrame("Frame", "JustBuyItFrame", UIParent)
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("COMMODITY_PRICE_UPDATED")
f:RegisterEvent("COMMODITY_PURCHASE_FAILED")
f:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")


f:SetScript("OnEvent", function(self, eventName, ...)
    if (eventName == "AUCTION_HOUSE_SHOW") then
        if (initialized) then
            return
        end

        initialized = true

        moneyInput = CreateFrame("Frame", nil, AuctionHouseFrame.CommoditiesBuyFrame, "MoneyInputFrameTemplate")
        moneyInput.hideCopper = true
        moneyInput:SetPoint("CENTER", AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.BuyButton, 0, -30)
        MoneyInputFrame_SetCopperShown(moneyInput, false)
        moneyInput:Show()

        buyButton = CreateFrame("Button", "JustBuyIt.BuyButton", AuctionHouseFrame.CommoditiesBuyFrame, "UIPanelButtonTemplate");
        buyButton:SetPoint("CENTER", AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.BuyButton, 0, -60)
        buyButton:SetFrameStrata("FULLSCREEN")
        buyButton:SetWidth(196)
        
        buyButton:SetText("Just Buy It")
        buyButton:SetEnabled(true)
        buyButton:SetScript("OnClick", function()
            buyButton:SetEnabled(false)
            buyUnits = AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.QuantityInput:GetQuantity()
            buyId = AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.ItemDisplay:GetItemID()
            maxPrice = MoneyInputFrame_GetCopper(moneyInput)

            text:SetText("...")
            C_AuctionHouse.StartCommoditiesPurchase(buyId, buyUnits)
            listenToCommoditiesEvents = true
        end)

        local textFrame = CreateFrame("Frame", nil, AuctionHouseFrame.CommoditiesBuyFrame)
        textFrame:SetSize(200, 100)
        textFrame:SetPoint("CENTER", AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay.BuyButton, 0, -90)
        text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER", textFrame, "CENTER")
    end

    _G["JusyBuyIt.BuyButton"] = buyButton

    if (listenToCommoditiesEvents == false) then
        return
    end

    if (eventName == "COMMODITY_PRICE_UPDATED") then
        local unitPrice, totalPrice = ...
        
        local averageUnitPrice = totalPrice / buyUnits

        if (averageUnitPrice > maxPrice) then
            listenToCommoditiesEvents = false
            text:SetText("Too expensive (" .. formatMoney(averageUnitPrice) .. ")")
            C_AuctionHouse.CancelCommoditiesPurchase()
            buyButton:SetEnabled(true)
        else
            C_AuctionHouse.ConfirmCommoditiesPurchase(buyId, buyUnits)
        end
    end

    if (eventName == "COMMODITY_PURCHASE_FAILED") then
        listenToCommoditiesEvents = false
        text:SetText("Failed")
        buyButton:SetEnabled(true)
    end

    if (eventName == "COMMODITY_PURCHASE_SUCCEEDED") then
        listenToCommoditiesEvents = false
        text:SetText("Success")
        buyButton:SetEnabled(true)
    end
end)

function formatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    return string.format("%dg%02ds", gold, silver)
end

