--  ____                                            
-- / ___|  ___ __ ___   _____ _ __   __ _  ___ _ __ 
-- \___ \ / __/ _` \ \ / / _ \ '_ \ / _` |/ _ \ '__|
--  ___) | (_| (_| |\ V /  __/ | | | (_| |  __/ |   
-- |____/ \___\__,_| \_/ \___|_| |_|\__, |\___|_|   
--                                  |___/           
--                                    version 0.1.0
--
-- github.com/erik-riklund/wow--scavenger (2026)

local addon = select(2, ...)
local config = addon.config

--
-- ?
--

local ignored_items = {}
for _, item_id in ipairs(addon.ignored_items) do
  ignored_items[tostring(item_id)] = true
end

Scavenger.RegisterFilter(
  "ignored items", function (_, data)
    if data.type == Enum.LootSlotType.Item then
      if ignored_items[tostring(data.item['id'])] == true then
        return false -- instruct the controller to ignore the item.
      end
    end
  end
)

--
-- ?
--

local lootable_items = {}
for _, item_id in ipairs(addon.lootable_items) do
  lootable_items[tostring(item_id)] = true
end

Scavenger.RegisterFilter(
  "lootable items", function (_, data)
    if data.type == Enum.LootSlotType.Item then
      if lootable_items[tostring(data.item['id'])] == true then
        return true -- instruct the controller to loot the item.
      end
    end
  end
)

--
-- ?
--

if config.junk["enabled"] then
  Scavenger.RegisterItemRule(
    "junk", function (item)
      local lootable = item.has_bind_type("None")
                   and item.is_quality("Poor")
                   and item.has_value({
                         min = config.junk["minimum_value"],
                         max = config.junk["maximum_value"]
                       })
                   
      if lootable then return true end
    end
  )
end

--
-- ?
--

if config.quest_items["enabled"] then
  Scavenger.RegisterItemRule(
    "quest items", function (item, data, context)
      local lootable = item.is_quest_item()
                   and (config.quest_items["loot_all"] or (
                          context.slot_count == 1 or data.item.stack_count > 1
                        ))
      
      if lootable then return true end
    end
  )
end

--
-- ?
--

if config.reagents["enabled"] then
  local lootable_types = {}
  for _, subtype_id in ipairs(config.reagents["lootable_types"]) do
    lootable_types[tostring(subtype_id)] = true
  end
  
  Scavenger.RegisterItemRule(
    "reagents", function (item, data)
      local lootable = item.is_type("Tradegoods")
                   and lootable_types[tostring(data.item["subtype_id"])] == true
                   and item.is_quality({
                         max = Enum.ItemQuality[config.reagents["quality_threshold"]]
                       })
      
      if lootable then return true end
    end
  )
end

--
-- ?
--

if config.money["enabled"] then
  Scavenger.RegisterMoneyRule(
    "money", function (money)
      local lootable = money.is_amount({
                         min = config.money["minimum_value"],
                         max = config.money["maximum_value"]
                       })
      
      if lootable then return true end
    end
  )
end

--
-- ?
--

if config.gear["enabled"] then
  -- not implemented yet.
end

--
-- ?
--

if config.currency["enabled"] then
  -- not implemented yet.
end