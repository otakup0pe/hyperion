module("hyperion_ambience", package.seeall)

local ez_vera = require("ez_vera")
local hyperion_util = require("hyperion_util")
local log = hyperion_util.log
local cfg_get = hyperion_util.cfg_get

function dawn_ambience(hyperion_id, device_id)
   log(hyperion_id, "debug", "Dawn Ambience")
   local evening_temp = tonumber(cfg_get(hyperion_id, "EveningTemp", "4500"))
   local morning_time = tonumber(cfg_get(hyperion_id, "MorningTime", "07"))
   local day_temp = tonumber(cfg_get(hyperion_id, "DayTemp", "5500"))
   local sunrise_grace = tonumber(cfg_get(hyperion_id, "SunriseGrace", "1800"))
   local now = os.time()
   local morning_secs =  os.time{day=os.date("%d", now),
                               month=os.date("%m", now),
                               year=os.date("%Y", now),
                               hour=morning_time,
                               min=00,
                               sec=00}
   local sunrise = luup.sunrise()
   local dim = 0
   if luup.is_night() then
      local dawn_percent = ( ( now - sunrise ) / ( sunrise - morning_secs ) ) * 100
      dim = math.floor((dawn_percent /100) * hyperion_util.dim_get(hyperion_id))
      if ez_vera.is_hue(device_id) then
         ez_vera.hue_temp(device_id, evening_temp)
      end
   else
      if ez_vera.is_hue(device_id) then
         ez_vera.hue_temp(device_id, day_temp)
      end
   end
   ez_vera.dim_actuate(device_id, dim)
end

function dusk_ambience(hyperion_id, device_id)
   log(hyperion_id, "debug", "Dusk Ambience")
   local sunset_grace = tonumber(cfg_get(hyperion_id, "SunsetGrace", "900"))
   local now = os.time()
   local sunset = luup.sunset()
   local dusk = sunset - sunset_grace
   local dusk_remaining = sunset - now
   local dusk_percent
   if dusk_remaining <= sunset_grace then
      dusk_percent = (dusk_remaining / sunset_grace) * 100
   else
      dusk_percent = 100
   end
   dim = math.floor((dusk_percent/100) * hyperion_util.dim_get(hyperion_id))
   log(hyperion_id, "debug", "dusk remaining " .. dusk_remaining .. " percent " .. dusk_percent .. " dim " .. dim)
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
   ez_vera.hue_temp(device_id + 1, temp)
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
   local sunset_grace = tonumber(cfg_get(hyperion_id, "SunsetGrace", "900"))
   local sunrise_grace = tonumber(cfg_get(hyperion_id, "SunriseGrace", "1800"))
   local morning_time = tonumber(cfg_get(hyperion_id, "MorningTime", "07"))
   local day_temp = tonumber(cfg_get(hyperion_id, "DayTemp", "5500"))
   local now = os.time()
   local time_to_sunset = 0 - (now - luup.sunset())
   local time_past_sunrise = now - (luup.sunrise() - 86400)
   local past_dawn = tonumber(os.date("%H", now)) >= morning_time;
   local op = nil
   log(hyperion_id, 'debug', "Time to sunset " .. time_to_sunset .. " Past dawn " .. tostring(past_dawn) .. " Time past sunrise " .. time_past_sunrise)
   if time_to_sunset >= 0 and (time_to_sunset <= sunset_grace) then
      op = 'dusk'
   elseif time_past_sunrise >= 0 and post_dawn and ( time_past_sunrise <= sunrise_grace ) then
      op = 'dawn'
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
      elseif ( op == 'dusk' ) then
         dusk_ambience(hyperion_id, device_id)
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
      elseif op == 'dawn' then
         dawn_ambience(hyperion_id, device_id)
      end
   end
   dim_group(hyperion_id, lights, cb)
end

function update_preset(hyperion_id, lights)
   local preset = tonumber(hyperion_util.cfg_get(hyperion_id, 'Preset', 3250))
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
