module("hyperion_config", package.seeall)

local hyperion_util = require("hyperion_util")
local cfg_get = hyperion_util.cfg_get

function evening_temp()
   return tonumber(cfg_get(hyperion_id, "EveningTemp", "4500"))
end

function morning_time()
   return tonumber(cfg_get(hyperion_id, "MorningTime", "07"))
end

function day_temp()
   return tonumber(cfg_get(hyperion_id, "DayTemp", "5500"))
end

function sunrise_grace()
   return tonumber(cfg_get(hyperion_id, "SunriseGrace", "1800"))
end

function sunset_grace()
   return tonumber(cfg_get(hyperion_id, "SunsetGrace", "900"))
end

function night_time()
   return tonumber(cfg_get(hyperion_id, "NightTime", "00"))
end

function night_temp()
   return tonumber(cfg_get(hyperion_id, "NightTemp", "1500"))
end

function evening_temp()
   return tonumber(cfg_get(hyperion_id, "EveningTemp", "4500"))
end

function preset()
   return tonumber(cfg_get(hyperion_id, 'Preset', 3250))
end

function ambience()
   return cfg_get(hyperion_id, 'Ambience', "0")
end
