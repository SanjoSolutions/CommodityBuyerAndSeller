# Commodities Buyer and Seller

An add-on for buying and selling commodities in the auction house. This can help players to increase their efficiency.

## Features

* Buying low price commodities.
* Selling commodities.
  * Putting only a maximum amount per commodity into the auction house at a time.
  * Putting more of a commodity into the auction house, so that one of your auctions is on top of the list (first purchased).
* Cancelling auctions that are estimated to run out (requires TradeSkillMaster as data source).

What to buy and sell and with what parameters can be configured. After starting the process it's only required to
confirm posts and purchases by clicking a "Confirm" button that appears at the center of the viewport when a "Confirm"
action is required.

It's also possible to bind a key and press the key instead of clicking the button.

## How to use

### Installation

Download the [latest release](https://github.com/SanjoSolutions/CommodityBuyerAndSeller/releases) and extract the folders into the AddOns folder.

The add-on is also available on [CurseForge](https://www.curseforge.com/wow/addons/commodities-buyer-and-seller/files).

### Configuring what to buy and sell

What is bought and sold can be configured by calling APIs with an additional add-on that the user can provide.

You can download a template for such add-on [here](https://github.com/SanjoSolutions/CommodityBuyerAndSellerData.git).

In line 4 of [CommoditiesBuyerAndSellerData.lua](https://github.com/SanjoSolutions/CommodityBuyerAndSellerData/blob/b2281afd256ae4b02b03ae00def7da82890de2c5/CommodityBuyerAndSellerData.lua), you can add API calls.

The APIs that are available can be found in [CommodityBuyerAndSeller.lua](https://github.com/SanjoSolutions/CommodityBuyerAndSeller/blob/main/CommodityBuyerAndSeller/CommodityBuyerAndSeller.lua).

### Starting the process

Open the auction house.

Then run: `/run CommodityBuyerAndSellerData.doConfigured()` (if the add-on template has been used).

This command can also be put into a macro.

## Support

You can support me on [Patreon](https://www.patreon.com/addons_by_sanjo).
