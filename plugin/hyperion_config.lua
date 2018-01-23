module("hyperion_config", package.seeall)

local hyperion_util = require("hyperion_util")
local const = require('vera_constants')

function get(device_id, key, default)
   local val = luup.variable_get(const.SID_HYPERION, key, device_id)
   if val ~= nil then
      return val
   else
      set(device_id, key, default)
      return default
   end
end

function set(device_id, key, val)
   luup.variable_set(const.SID_HYPERION, key, val, device_id)
end

function evening_temp(hyperion_id)
   return tonumber(get(hyperion_id, "EveningTemp", "4500"))
end

function morning_hour(hyperion_id)
   return tonumber(get(hyperion_id, "MorningHour", "07"))
end

function morning_minute(hyperion_id)
   return tonumber(get(hyperion_id, "MorningMinute", "00"))
end

function day_temp(hyperion_id)
   return tonumber(get(hyperion_id, "DayTemp", "5500"))
end

function sunrise_grace(hyperion_id)
   return tonumber(get(hyperion_id, "SunriseGrace", "1800"))
end

function sunset_grace(hyperion_id)
   return tonumber(get(hyperion_id, "SunsetGrace", "900"))
end

function night_hour(hyperion_id)
   return tonumber(get(hyperion_id, "NightHour", "00"))
end

function night_minute(hyperion_id)
   return tonumber(get(hyperion_id, "NightMinute", "00"))
end

function night_temp(hyperion_id)
   return tonumber(get(hyperion_id, "NightTemp", "1500"))
end

function evening_temp(hyperion_id)
   return tonumber(get(hyperion_id, "EveningTemp", "4500"))
end

function to_bool(str)
   ret = false
   if str == '1' then
      ret = true
   end
   return ret
end

function ambience(hyperion_id)
   return to_bool(get(hyperion_id, 'Ambience', "0"))
end

function ambient_day(hyperion_id)
   return to_bool(get(hyperion_id, 'AmbientDaytime', '1'))
end

function ambient_dusk(hyperion_id)
   return to_bool(get(hyperion_id, 'AmbientDusk', '1'))
end

function ambient_night(hyperion_id)
   return to_bool(get(hyperion_id, 'AmbientNight', '1'))
end

function ambient_dawn(hyperion_id)
   return to_bool(get(hyperion_id, 'AmbientDawn', '1'))
end

function dim_increment(hyperion_id)
   return tonumber(get(hyperion_id, 'DimIncrement', '10'))
end

function dim_up_min(hyperion_id)
   return tonumber(get(hyperion_id, 'DimUpMin', '50'))
end

function preset_one(hyperion_id)
   return tonumber(get(hyperion_id, 'PresetOne', '5500'))
end

function preset_two(hyperion_id)
   return tonumber(get(hyperion_id, 'PresetTwo', '3250'))
end

function preset(hyperion_id)
   return to_bool(get(hyperion_id, 'Preset', "1"))
end

function motion_timeout(hyperion_id)
   return tonumber(get(hyperion_id, 'MotionTimeout', '300'))
end

function inactive_dim(hyperion_id)
   return to_bool(get(hyperion_id, 'InactiveDim', '1'))
end

function lux_threshold(hyperion_id)
   return tonumber(get(hyperion_id, 'LuxThreshold', '30'))
end
