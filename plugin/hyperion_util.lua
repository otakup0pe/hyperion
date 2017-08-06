module("hyperion_util", package.seeall)

local ez_vera = require("ez_vera")
local const = require("vera_constants")
local cfg = require("hyperion_config")
local default_log_level = 'warn';

function log(device_id, level, message)
   local c_level = cfg.get(device_id, 'LogLevel', default_log_level)
   if ( c_level ~= 'debug' and c_level ~= 'info' and c_level ~= 'error' and c_level ~= 'warn' ) then
      c_level = default_log_level
   end
   if ( c_level == 'debug' ) or
      ( c_level == 'info' and ( level == 'info' or level == 'warn' or level == 'error' ) ) or
      ( c_level == 'warn' and ( level == 'warn' or level == 'error' ) ) or
   ( c_level == 'error' and level == 'error' ) then
      luup.log("HYPERION #" .. device_id .. " " .. level .. " " .. message)
   end
end

function device_list(device_id, key)
   local val = cfg.get(device_id, key, "")
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

function weather_condition(weather_id)
   local condition = luup.variable_get(const.SID_WEATHER, "ConditionGroup", weather_id)
   log(hyperion_id, 'debug', "Weather #" .. weather_id .. " condition is " .. condition)
   return condition
end

local house_mode_id = 0

function house_mode()
   if house_mode_id == 0 then
      for device_id, obj in pairs(luup.devices) do
         if luup.device_supports_service(const.SID_HOUSEMODE, device_id) then
            house_mode_id = device_id
            break
         end
      end
      if house_mode_id == 0 then
         house_mode_id = -1
      end
   end
   if house_mode_id == -1 then
      return
   end
   local hmode = tonumber(luup.variable_get(const.SID_HOUSEMODE, "HMode", house_mode_id), 10)

   if hmode == 1 then
      return const.HM_HOME
   elseif hmode == 2 then
      return const.HM_AWAY
   elseif hmode == 3 then
      return const.HM_NIGHT
   elseif hmode == 4 then
      return const.HM_VACATION
   end
end

function get_sensors(hyperion_id, sid)
   local require_devices = hyperion_util.device_list(hyperion_id, 'require_devices')
   local sensors = {}
   for i, device_id in _G.ipairs(require_devices) do
      if luup.device_supports_service(sid, device_id) then
         table.insert(sensors, device_id)
      end
   end
   return sensors
end

function any_tripped(sensors)
   local now = os.time()
   for i, device_id in _G.ipairs(sensors) do
      local last_trip = luup.variable_get(const.SID_SSENSOR, "LastTrip", device_id)
      if last_trip == nil then
         log(hyperion_id, 'warn', 'Sensor ' .. tostring(device_id) .. ' has null LastTrip')
         last_trip = 0
      end
      local tripped = now - tonumber(last_trip)
      if tripped <= cfg.motion_timeout(hyperion_id) then
         log(hyperion_id, 'debug', 'Sensor ' .. tostring(device_id) .. ' tripped ' .. tostring(tripped) .. ' ago')
         return true
      else
         log(hyperion_id, 'debug', 'Sensor ' .. tostring(device_id) .. ' will trip '  .. tostring(0 - (now  - tonumber(last_trip))))
      end
   end
   return false
end

function operating_mode(hyperion_id)
   local evening_temp = cfg.evening_temp(hyperion_id)
   local now = os.time()
   local time_to_sunset = 0 - (now - luup.sunset())
   local time_past_sunrise = now - (luup.sunrise() - 86400)
   local is_night = luup.is_night();
   local op = nil
   if cfg.ambient_dusk(hyperion_id) and is_dusk(hyperion_id) then
      op = 'dusk'
   elseif cfg.ambient_dawn(hyperion_id) and is_dawn(hyperion_id) then
      op = 'dawn'
   elseif cfg.ambient_night(hyperion_id) and is_night then
      op = 'night'
   elseif cfg.ambient_day(hyperion_id) then
      op = 'day'
   end
   return op
end

function stormy_weather(hyperion_id)
   local require_devices = hyperion_util.device_list(hyperion_id, 'require_devices')
   if table.getn(require_devices) > 0 then
      for i, device_id in _G.ipairs(require_devices) do
         if luup.device_supports_service(const.SID_WEATHER) then
            local condition = hyperion_util.weather_condition(device_id)
            log(hyperion_id, 'debug', 'Weather ' .. device_id .. ' condition group ' .. condition)
            if condition == "cloudy" or condition == "fog" or condition == "rain" then
               return true
            end
         end
      end
   end
   return false
end

function dim_room(hyperion_id)
   local sensors = hyperion_util.get_sensors(hyperion_id, const.SID_LSENSOR)
   if table.getn(sensors) > 0 then
      for i, device_id in _G.ipairs(sensors) do
         local lux_str = luup.variable_get(const.SID_LSENSOR, 'CurrentLevel', device_id)
         log(hyperion_id, 'debug', 'LightSensor ' .. tostring(device_id) .. ' CurrentLevel ' .. lux_str)
         local lux = tonumber(lux_str)
         if lux == nil then
            return false
         else
            local lux_threshold = cfg.lux_threshold()
            if lux <= lux_threshold then
               log(hyperion_id, 'debug', 'LightSensor ' .. tostring(device_id) .. ' under threshold of ' .. tostring(lux_threshold))
               return true
            end
         end
      end
   end
   return false
end

function active_room(hyperion_id)
   local sensors = hyperion_util.get_sensors(hyperion_id, const.SID_SSENSOR)
   if table.getn(sensors) > 0 then
      return hyperion_util.any_tripped(sensors)
   else
      return false
   end
end

function time_past_sunrise()
   local now = os.time()
   return now - (luup.sunrise() - 86400)
end

function is_dusk(hyperion_id)
   local sunset_grace = cfg.sunset_grace(hyperion_id)
   local now = os.time()
   local time_to_sunset = 0 - (now - luup.sunset())
   log(hyperion_id, 'debug', "to sunset " .. time_to_sunset)
   return ((time_to_sunset >= 0 and (time_to_sunset <= sunset_grace)) or ((time_to_sunset > -120) and time_to_sunset <= 0))
end

function is_dawn(hyperion_id)
   local morning_hour = cfg.morning_hour(hyperion_id)
   local morning_minute = cfg.morning_minute(hyperion_id)
   local sunrise_grace = cfg.sunrise_grace(hyperion_id)
   local now = os.time()
   local time_past_sunrise = time_past_sunrise()
   local past_dawn = tonumber(os.date("%H", now)) >= morning_hour and tonumber(os.date("%M", now)) >= morning_minute;
   log(hyperion_id, 'debug', 'Past dawn ' .. tostring(past_dawn) .. " past sunrise " .. time_past_sunrise)
   return time_past_sunrise >= 0 and past_dawn and ( time_past_sunrise <= sunrise_grace )
end

