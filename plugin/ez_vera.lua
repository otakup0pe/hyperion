module("ez_vera", package.seeall)

local const = require("vera_constants")

function toggle(device_id)
   local current = switch_get(device_id)
   if current then
      switch_actuate(device_id, false)
   else
      switch_actuate(device_id, true)
   end
end

function is_hue(device_id)
   return luup.device_supports_service(const.SID_HUEBULB, device_id)
end

function hue_val(device_id, key)
   local val = luup.variable_get(const.SID_HUEBULB, "LampValues", device_id)
   
   for val_element in string.gmatch(val, "([^;]+)") do
      local element_bit = {string.gmatch(val, "([^=]+)")}
      if element_bit[0] == key then
         return element_bit[1]
      end
   end
   return nil
end

function is_color(device_id)
   local model = luup.variable_get(const.SID_HUEBULB, "BulbModelID", device_id)
   if model == "LTW011" then
      return false
   else
      return true
   end
end

function hue_temp(device_id, p_temp)
   if ( p_temp <= 2000 ) then
      if is_color(device_id) then
         local hue_start = 12000
         local sat_start = 227
         local hue_end = 10000
         local sat_end = 235
         local hue_diff = hue_start - hue_end
         local sat_diff = sat_start - sat_end
         local hue_scaled = hue_end + math.floor(hue_diff * (p_temp - 1000) / 500)
         local sat_scaled = sat_end + math.floor(sat_diff * (p_temp - 1000) / 500)
         hue_colour(device_id, hue_scaled, sat_scaled)
      else
         hue_temp(device_id, 2001)
      end
   else
      -- kelvin to mired
      local temp = math.floor(1000000 / p_temp)
      local current = hue_val(device_id, "ct")
      if type(current) == 'string' then
         current = tonumber(current)
      elseif type(current) == 'int' then
         current = current
      else
         current = 0
      end
      if temp ~= current then
         luup.call_action(const.SID_HUEBULB,"SetColorTemperature", {ColorTemperature=temp, Transitiontime=10, action="SetColorTemperature", serviceId=const.SID_HUEBULB, DeviceNum=device_id}, device_id)
      end
   end
end

function hue_colour(device_id, hue, sat)
   local current_hue = hue_val(device_id, "hue")
   local current_sat = hue_val(device_id, "sat")
   if current_hue ~= hue or current_sat ~= sat then
      luup.call_action(const.SID_HUEBULB, "SetHueAndSaturation", {Hue=hue, Saturation=sat, Effect="none", Transitiontime=10, rand=math.random(), action="SetHueAndSaturation", serviceId=const.SID_HUEBULB, DeviceNum=device_id}, device_id)
   end
end

function switch_get(switch)
   local v = nil
   if luup.device_supports_service(const.SID_VSWITCH, switch) then
      v = luup.variable_get(const.SID_VSWITCH,"Status", switch)
   else
      v = luup.variable_get(const.SID_SPOWER,"Status", switch)
   end
   if v == "1" then
      return true
   else
      return false
   end
end

function distill_target(target)
   local p_target = "0"
   if type(target) == 'string' then
      p_target = target
   else
      if target then
         p_target = "1"
      end
   end
   return p_target
end

function switch_set(device_id, target)
   if luup.device_supports_service(const.SID_VSWITCH, device_id) then
      luup.variable_set(const.SID_VSWITCH,"Status", distill_target(target), device_id)
   else
      luup.variable_set(const.SID_SPOWER,"Status", distill_target(target), device_id)
   end
end

function switch_actuate(device_id, target)
   local d_target = distill_target(target)
   local d_existing = distill_target(switch_get(device_id))
   if d_target == d_existing then
      return
   end
   luup.call_action(const.SID_SPOWER, "SetTarget", {newTargetValue = d_target}, device_id)
end

function any_on(devices)
   local active = false
   for i, switch in _G.ipairs(devices) do
      if luup.device_supports_service(const.SID_VSWITCH, device_id) or
         luup.device_supports_service(const.SID_SPOWER, device_id) then
            if ( switch_get(switch) ) then
               active = true
               break
            end
      end
   end
   return active
end

function dim_get(device_id)
   local dim = luup.variable_get(const.SID_DIMMABLE, "LoadLevelStatus", device_id)
   if dim == nil then
      return 0
   else
      return tonumber(dim)
   end
end

function dim_set(device_id, target)
   luup.variable_set(const.SID_DIMMABLE, "LoadLevelStatus", target, device_id)
end

function dim_actuate(device_id, dim)
   local d_existing = dim_get(device_id)
   if dim == d_existing then
      return
   end
   if d_target == "0" then
      switch_actuate(device_id, 0)
   else
      luup.call_action(const.SID_DIMMABLE, "SetLoadLevelTarget", {newLoadlevelTarget = dim}, device_id)
   end      
end

function sonos_favorite(device_id, favorite, volume)
   luup.call_action("urn:micasaverde-com:serviceId:Sonos1", "PlayURI",
                    {URIToPlay="SF:" .. favorite, Volume=volume},
                    device_id)
end
