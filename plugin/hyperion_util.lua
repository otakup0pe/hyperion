module("hyperion_util", package.seeall)

local ez_vera = require("ez_vera")
local const = require("vera_constants")

local default_log_level = 'debug';

function log(device_id, level, message)
   local c_level = cfg_get(device_id, 'LogLevel', default_log_level)
   if ( c_level ~= 'debug' or c_level ~= 'info' or c_level ~= 'error' ) then
      c_level = default_log_level
   end
   if ( c_level == 'debug' ) or
      ( c_level == 'info' and ( level == 'info' or level == 'error' ) ) or
      ( c_level == 'warn' and ( level == 'warn' or level == 'error' ) ) or
      ( c_level == 'error' and level == 'error' ) then
         luup.log("HYPERION #" .. device_id .. " " .. level .. " " .. message)
   end
end

function cfg_get(device_id, key, default)
   local val = luup.variable_get(const.SID_HYPERION, key, device_id)
   if val then
      return val
   else
      cfg_set(device_id, key, default)
      return default
   end
end

function cfg_set(device_id, key, val)
   luup.variable_set(const.SID_HYPERION, key, val, device_id)
end

function device_list(device_id, key)
   local val = cfg_get(device_id, key, "")
   local devices = {}
   for device in string.gmatch(val, "([^,]+)") do
      table.insert(devices, tonumber(device))
   end
   return devices
end

function dim_get(hyperion_id)
   local dim = ez_vera.dim_get(get_child(hyperion_id, 'dimmer'))
   if not dim then
      dim = "0"
      dim_set(hyperion_id, dim)
   end
   return dim
end

function dim_set(hyperion_id, target)
   local child_id = get_child(hyperion_id, 'dimmer')
   local p_target = "1"
   if target == "0" then
      p_target = target
   end
   ez_vera.dim_set(child_id, target)
   ez_vera.switch_set(child_id, p_target)
   log(hyperion_id, 'info', "Dimmer set to " .. target)
end

function get_child(hyperion_id, flavor)
   for k, v in pairs(luup.devices) do 
      if v.device_num_parent == hyperion_id and luup.attr_get('altid', k) == flavor .. hyperion_id then
         return k
      end
   end
   return nil
end

function ensure_parent(device_id)
   if string.sub(luup.attr_get('altid', device_id), 1, 6) == 'dimmer' or
   string.sub(luup.attr_get('altid', device_id), 1, 8) == 'ambience' or
   string.sub(luup.attr_get('altid', device_id), 1, 4) == 'temp' then
      return luup.devices[device_id].device_num_parent
   else
      return device_id
   end
end

function weather_condition(hyperion_id)
   local weather_id = cfg_get(hyperion_id, 'WeatherDevice', '')
   if weather_id then
      if luup.device_supports_service(const.SID_WEATHER, weather_id) then
         local condition = luup.variable_get(const.SID_WEATHER, "ConditionGroup", weather_id)
         log(hyperion_id, 'debug', "Weather #" .. weather_id .. " condition is " .. condition)
         return condition
      else
         log(hyperion_id, 'warn', "Invalid Weather #" .. weather_id)
      end
   else
      log(hyperion_id, 'debug', "Skipping weather")
   end
   return nil
end
