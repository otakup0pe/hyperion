module("hyperion_ambience", package.seeall)

local ez_vera = require("ez_vera")
local hyperion_util = require("hyperion_util")
local log = hyperion_util.log
local cfg_get = hyperion_util.cfg_get

function twilight_ambience(hyperion_id, device_id)
   log(hyperion_id, "debug", "Twilight Ambience")
   local sunset_grace = cfg_get(hyperion_id, "SunsetGrace", "900")
   local now = os.time()
   local sunset = luup.sunset()
   local twilight = sunset - sunset_grace
   local twilight_remaining = sunset - now
   log(hyperion_id, "debug", "twilight dist " .. sunset_grace .. " remaining " .. twilight_remaining)
   local twilight_percent
   if twilight_remaining <= sunset_grace then
      twilight_percent = (twilight_remaining / sunset_grace) * 100
   else
      twilight_percent = 100
   end
   dim = math.floor((twilight_percent/100) * hyperion_util.dim_get(hyperion_id))
   ez_vera.dim_actuate(device_id, dim)
end

function night_ambience(hyperion_id, device_id)
   log(hyperion_id, "debug", "Night Ambience")
   -- configs
   local night_time = tonumber(cfg_get(hyperion_id, "NightTime", "22"))
   local night_temp = tonumber(cfg_get(hyperion_id, "NightTemp", "1500"))
   local evening_temp = tonumber(cfg_get(hyperion_id, "EveningTemp", "4500"))
   -- start by calculating time to bed time
   local now = os.time()
   -- after bedtime we should be at our warmest
   local temp = 0
   local sunrise = luup.sunrise()
   local past_sunrise = now - sunrise < 86400
   local sunrise_hour = os.date("%H", sunrise)
   local now_hour = os.date("%H", now)
   local past_night_time = tonumber(os.date("%H", now)) >= night_time
   log(hyperion_id, "debug", "ambient_night past_sunrise:" .. tostring(past_sunrise) .. " past_night_time:" .. tostring(past_night_time))
   if ( past_sunrise and past_night_time ) or ( past_sunrise and now_hour <= sunrise_hour ) then
      temp = night_temp;
   else
      local night_secs =  os.time{day=os.date("%d", now),
                                  month=os.date("%m", now),
                                  year=os.date("%Y", now),
                                  hour=night_time,
                                  min=00,
                                  sec=00}
      log(hyperion_id, "debug", "night_secs:" .. night_secs)
      -- tomorrow is close enough to today
      local l_sunset = luup.sunset()
      local sunset = l_sunset - 86400
      log(hyperion_id, "debug", "sunset:" .. sunset .. " now:" .. now .. " l_sunset:" .. l_sunset)
      -- determine total seconds between sunset and bedtime
      local evening_secs = night_secs - sunset
      log(hyperion_id, "debug", "evening_secs:" .. evening_secs)
      -- determine total distance between evening and night temperature
      local temp_dist = evening_temp - night_temp
      log(hyperion_id, "debug", "temp_dist:" .. temp_dist)
      -- get appropriate temp
      local time_to_night = night_secs - now
      log(hyperion_id, "debug", "ttn:" .. time_to_night)
      -- convert to what is expected
      temp = math.floor(night_temp + ( ( time_to_night / evening_secs ) * temp_dist ))
   end
   log(hyperion_id, "debug", "setting temp to " .. temp)
   if ( temp >= 2000 ) then
      ez_vera.hue_temp(device_id + 1, temp)
   else
      local hue_start = 12521
      local sat_start = 225
      local hue_end = 10000
      local sat_end = 235
      local hue_diff = hue_start - hue_end
      local sat_diff = sat_start - sat_end
      local hue_scaled = hue_end + math.floor(hue_diff * (temp - 1000) / 500)
      local sat_scaled = sat_end + math.floor(sat_diff * (temp - 1000) / 500)
      ez_vera.hue_colour(device_id + 1, hue_scaled, sat_scaled)
   end
end

function ambience_gate(hyperion_id)
   if ( ez_vera.any_on(hyperion_util.device_list(hyperion_id, 'override_devices')) ) then
      log(hyperion_id, 'info', "Ambience disabled by override")
      return false
   end
   if ( not ez_vera.any_on(hyperion_util.device_list(hyperion_id, 'require_devices')) ) then
      log(hyperion_id, 'debug', 'Ambience disabled via lack of required switch')
      return false
   end
   return true
end

function dim_group(hyperion_id, lights, cb)
   local dim = hyperion_util.dim_get(hyperion_id)
   local dim_lights = math.ceil((dim / 100) * table.getn(lights))
   log(hyperion_id, "debug", "Grouping " .. dim_lights .. " of " .. table.getn(lights) .. " lights")
   for i, device_id in _G.ipairs(lights) do
      if ( i <= dim_lights ) then
         log(hyperion_id, "debug", "Adjusting device #" .. i .. "(" .. device_id .. ")")
         cb(hyperion_id, device_id)
      else
         log(hyperion_id, "debug", "Skipping device #" .. i .. "(" .. device_id .. ")")
         ez_vera.switch_actuate(device_id, false)
      end
      luup.sleep(100)
   end
end

function update_ambient(hyperion_id, lights)
   local sunset_grace = cfg_get(hyperion_id, "SunsetGrace", "900")
   local day_temp = cfg_get(hyperion_id, "DayTemp", "5500")
   local time_to_sunset = (os.time() - luup.sunset())
   local op = nil
   log(hyperion_id, 'debug', "Time to sunset " .. time_to_sunset)
   if (time_to_sunset >= (0 - sunset_grace)) and time_to_sunset <= 0 then
      op = 'twilight'
   elseif luup.is_night() then
      op = 'night'
   else
      op = 'day'
   end
   local dim = hyperion_util.dim_get(hyperion_id)
   local cb = function(hyperion_id, device_id)
      if ( op == 'night' ) then
         if ( ez_vera.is_hue(device_id) ) then
            night_ambience(hyperion_id, device_id)
         end
         ez_vera.dim_actuate(device_id, dim)
      elseif ( op == 'twilight' ) then
         twilight_ambience(hyperion_id, device_id)
         if ( ez_vera.is_hue(device_id) ) then
            ez_vera.hue_temp(device_id + 1, day_temp)
         end
      elseif op == 'day' then
         log(hyperion_id, "debug", "Daytime Ambience")
         local condition =  hyperion_util.weather_condition(hyperion_id)
         if condition == "cloudy" or
            condition == "fog" or
         condition == "rain" then
            ez_vera.dim_actuate(device_id, dim)
            if ( ez_vera.is_hue(device_id) ) then
               ez_vera.hue_temp(device_id + 1, day_temp)
            end
         else
            ez_vera.switch_actuate(device_id, false)
         end
      end
   end
   dim_group(hyperion_id, lights, cb)
end

function update_preset(hyperion_id, lights)
   local preset = hyperion_util.cfg_get(hyperion_id, 'Preset', 3250)
   local dim = hyperion_util.dim_get(hyperion_id)
   log(hyperion_id, 'debug', 'Updating preset ' .. preset)
   local cb = function(hyperion_id, device_id)
      ez_vera.dim_actuate(device_id, dim)
      if ez_vera.is_hue(device_id) then
         ez_vera.hue_temp(device_id + 1, preset)
      end
   end
   dim_group(hyperion_id, lights, cb)
end

function disable_lights(hyperion_id, lights)
   if ez_vera.any_on(lights) then
      log(hyperion_id, "debug", "Disabling straggling lights")
      for i, device_id in _G.ipairs(lights) do
         ez_vera.dim_actuate(device_id, "0")
      end
      return
   end
end

function update(hyperion_id)
   local lights = hyperion_util.device_list(hyperion_id, 'include_devices')
   if not ez_vera.switch_get(hyperion_id) then
      log(hyperion_id, "debug", "This switch is disabled")
   else
      if hyperion_util.cfg_get(hyperion_id, 'Ambience', "0") == "0" then
         update_preset(hyperion_id, lights)
      else
         if not ambience_gate(hyperion_id) then
            disable_lights(hyperion_id, lights)
         else
            update_ambient(hyperion_id, lights)
         end
      end
   end
end
