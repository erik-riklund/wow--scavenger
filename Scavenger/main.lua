--  ____                                            
-- / ___|  ___ __ ___   _____ _ __   __ _  ___ _ __ 
-- \___ \ / __/ _` \ \ / / _ \ '_ \ / _` |/ _ \ '__|
--  ___) | (_| (_| |\ V /  __/ | | | (_| |  __/ |   
-- |____/ \___\__,_| \_/ \___|_| |_|\__, |\___|_|   
--                                  |___/           
--                                    version 0.1.0
--
-- github.com/erik-riklund/wow--scavenger (2026)

local event_frame = CreateFrame("Frame")

event_frame:RegisterEvent("LOOT_READY")
event_frame:RegisterEvent("LOOT_OPENED")
event_frame:RegisterEvent("LOOT_SLOT_CLEARED")
event_frame:RegisterEvent("LOOT_CLOSED")

--
-- Initialization of the public API
--

Scavenger = {
  GetItemData = function (item)
    local data = {}

    data.name,
    data.link,
    data.quality,
    data.base_item_level,
    data.required_level,
    data.localized_type,
    data.localized_subtype,
    data.stack_count,
    data.equip_location,
    data.texture_id,
    data.value,
    data.type_id,
    data.subtype_id,
    data.bind_type,
    data.expansion_id,
    data.set_id,
    data.is_reagent = C_Item.GetItemInfo(item)

    if data.link ~= nil then
      data.id = string.match(data.link, 'item:(%d+)')
      data.item_level = C_Item.GetDetailedItemLevelInfo(data.link)
      data.is_collected = C_TransmogCollection.PlayerHasTransmogByItemInfo(item)
    end

    return data
  end,
  
  GetLootSlotData = function (slot)
    local data = {}

    data.icon,
    data.name,
    data.quantity,
    data.currency_id,
    data.quality,
    data.is_locked,
    data.is_quest_item,
    data.quest_id,
    data.is_active_quest = GetLootSlotInfo(slot)
    
    data.type = GetLootSlotType(slot)
    local item_link = GetLootSlotLink(slot)
  
    if item_link then
      data.item = Scavenger.GetItemData(item_link)
    end

    if data.type == Enum.LootSlotType.Money then
      local cash = { string.split('\n', data.name) }
      data.money = { gold = 0, silver = 0, copper = 0 }
    
      for _, raw_value in ipairs(cash) do
        local amount, value = string.split(' ', raw_value)
        data.money[string.lower(value)] = tonumber(amount) or 0
      end
    end

    return data
  end
}

--
-- Loot rule helpers
--

local to_copper = function (amount)
  if type(amount) ~= "table" then
    error("Expected `amount` to be a table, got "..type(amount), 2)
  end
  
  local gold = tonumber(amount['gold']) or 0
  local silver = tonumber(amount['silver']) or 0
  local copper = tonumber(amount['copper']) or 0
  
  return copper + (silver * 100) + (gold * 10000)
end

local create_helper = function (data)
  if data.type == Enum.LootSlotType.Item then
    return {
      is_quest_item = function ()
        return data.is_quest_item == true
      end,
      
      is_quality = function (quality)
        if type(quality) ~= 'table' then
          return data.quality == Enum.ItemQuality[quality]
        end
        
        local min_quality = quality['min'] or Enum.ItemQuality.Poor
        local max_quality = quality['max'] or Enum.ItemQuality.WoWToken
        return data.quality >= min_quality and data.quality <= max_quality
      end,
      
      is_type = function (type_key)
        return data.item['type_id'] == Enum.ItemClass[type_key]
      end,
      
      has_bind_type = function (bind_type)
        return data.item['bind_type'] == Enum.ItemBind[bind_type]
      end,
      
      has_value = function (range)
        if type(range) ~= 'table' then
          error('Expected `range` to be a table, got '..type(range), 2)
        end
        local lower_limit = range.min == nil
                         or data.item['value'] >= to_copper(range.min)
        local upper_limit = range.max == nil
                         or data.item['value'] <= to_copper(range.max)
                            
        return lower_limit == true and upper_limit == true
      end
    }
  elseif data.type == Enum.LootSlotType.Currency then
    return {
      -- not implemented yet.
    }
  elseif data.type == Enum.LootSlotType.Money then
    return {
      is_amount = function (range)
        if type(range) ~= 'table' then
          error('Expected `range` to be a table, got '..type(range), 2)
        end
        
        local amount = to_copper(data.money)
        local lower_limit = range.min == nil
                         or amount >= to_copper(range.min)
        local upper_limit = range.max == nil
                         or amount <= to_copper(range.max)
                            
        return lower_limit == true and upper_limit == true
      end
    }
  end
end

--
-- Loot rule controller
--

local rules = {
  filters = {},  -- Highest priority. Should contain quick list lookups only.
  specific = {}, -- Mid-high priority (e.g., rules for specific items).
  groups = {},   -- Mid-low priority (e.g., rules for all items of a certain type).
  general = {}   -- Lowest priority (e.g., catch-all rules).
}
local identifiers = {}

local register_identifier = function (name)
  if identifiers[string.lower(name)] then
    error('Failed to register rule: "'..name..'" already exists', 2)
  end
  identifiers[string.lower(name)] = true
end

local register_rule = function (rule_type, name, callback)
  register_identifier(name)
  local rule = { name = name, callback = callback }
  table.insert(rules[rule_type], rule)
  
  return function () -- cleanup function to enable removal of rules.
    local filtered_rules = {}
    for index, current_rule in ipairs(rules[rule_type]) do
      if current_rule.name ~= rule.name then
        table.insert(filtered_rules, current_rule)
      end
    end
    rules[rule_type] = filtered_rules
  end
end

--
-- Loot rule registration (API)
--

Scavenger.RegisterFilter = function (rule_name, callback)
  return register_rule('filters', rule_name, callback)
end

Scavenger.RegisterSpecificItemRule = function (item_id, rule_name, callback)
  local wrapper = function (helper, data, context)
    if data.type == Enum.LootSlotType.Item and data.item['id'] == item_id then
      return callback(helper, data, context)
    end
  end
  return register_rule('specific', rule_name, wrapper)
end

Scavenger.RegisterSpecificCurrencyRule = function (currency_id, rule_name, callback)
  local wrapper = function (helper, data, context)
    if data.type == Enum.LootSlotType.Currency and data.currency_id == currency_id then
      return callback(helper, data, context)
    end
  end
  return register_rule('specific', rule_name, wrapper)
end

Scavenger.RegisterItemRule = function (rule_name, callback)
  local wrapper = function (helper, data, context)
    if data.type == Enum.LootSlotType.Item then
      return callback(helper, data, context)
    end
  end
  return register_rule('groups', rule_name, wrapper)
end

Scavenger.RegisterCurrencyRule = function (rule_name, callback)
  local wrapper = function (helper, data, context)
    if data.type == Enum.LootSlotType.Currency then
      return callback(helper, data, context)
    end
  end
  return register_rule('groups', rule_name, wrapper)
end

Scavenger.RegisterMoneyRule = function (rule_name, callback)
  local wrapper = function (helper, data, context)
    if data.type == Enum.LootSlotType.Money then
      return callback(helper, data, context)
    end
  end
  return register_rule('groups', rule_name, wrapper)
end

Scavenger.RegisterGeneralRule = function (rule_name, callback)
  return register_rule('general', rule_name, callback)
end

--
-- Loot claiming logic
--

local current_loot = nil

local evaluate = function (data, context)
  local order = {
    'filters','specific','groups','general'
  }
  local helper = create_helper(data)
  
  for _, rule_type in ipairs(order) do
    for _, rule in ipairs(rules[rule_type]) do
      local success, result = pcall(
        rule.callback, helper, data, context
      )
      if not success then
        print(result) -- todo: implement error reporting for failed rules.
      end
      if success and type(result) == 'boolean' then
        return result -- short-circuit the rest of the pipeline.
      end
    end
  end
end

event_frame:SetScript(
  "OnEvent", function (_, event_name, ...)
    --
    -- Loot processing
    --
    if event_name == "LOOT_READY" then
      local slots = {}
      local slot_count = GetNumLootItems()
      
      for index = 1, slot_count do
        local data = Scavenger.GetLootSlotData(index)
        if not data.is_locked and data.type ~= Enum.LootSlotType.None then
          table.insert(slots, { index = index, data = data })
        end
      end
      
      local context = {
        slot_count = slot_count
      }
      for _, slot in ipairs(slots) do
        slot.claim = evaluate(slot.data, context)
      end
      
      current_loot = slots
    
    --
    -- Actual claiming of loot
    --
    elseif event_name == "LOOT_OPENED" then
      while current_loot == nil do
      -- delay if the processing is not completed yet.
      end
      
      slots_cleared = {}
      for _, slot in ipairs(current_loot) do
        if slot.claim == true then LootSlot(slot.index) end
      end
      
    --
    -- ?
    --
    elseif event_name == "LOOT_SLOT_CLEARED" then
    
    --
    -- ?
    --
    elseif event_name == "LOOT_CLOSED" then
      current_loot = nil -- reset the stored loot information.
    end
  end
)