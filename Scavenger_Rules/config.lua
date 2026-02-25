local addon = select(2, ...)

addon.config = {
  --
  -- ?
  --
  junk = {
    enabled = true,
    minimum_value = { copper = 1 },
    maximum_value = { gold = 4, silver = 99 }
  },
  
  --
  -- ?
  --
  quest_items = {
    enabled = true,
    loot_all = false
  },
  
  --
  -- ?
  --
  gear = {
    enabled = true,
    only_known = true
  },
  
  --
  -- ?
  --
  -- Reagent types:
  --
  --- Parts = 1
  --- Gems = 4
  --- Cloth = 5
  --- Leather = 6
  --- Mining = 7
  --- Cooking = 8
  --- Herbs = 9
  --- Elemental = 10
  --- Other = 11
  --- Dust = 12
  --- Pigments = 16

  --
  reagents = {
    enabled = true,
    quality_threshold = "Uncommon",
    
    lootable_types = {
      5,  -- Cloth
      6,  -- Leather
      7,  -- Mining
      8,  -- Cooking
      9,  -- Herbs
      10, -- Elemental
      12, -- Dust
      16, -- Pigments
    }
  },
  
  --
  -- ?
  --
  money = {
    enabled = true,
    minimum_value = { copper = 1 },
    maximum_value = { gold = 9, silver = 99 }
  },
  
  --
  -- ?
  --
  currency = {
    enabled = true,
    loot_all = false,
    
    lootable = {
      --{ id = 3252, label = "name of the currency" }
    },
    
    ignored = {
      --{ id = 3252, label = "name of the currency" }
    }
  }
}