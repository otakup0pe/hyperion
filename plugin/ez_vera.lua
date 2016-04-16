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
   local parent = tonumber(luup.devices[device_id].device_num_parent)
   if ( parent ~= 0 ) then
      if ( luup.device_supports_service(const.SID_HUEHUB, parent) ) then
         return true
      end
   end
   return false
end

function hue_temp(device_id, p_temp)
   if ( p_temp <= 2000 ) then
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
      local temp = 100 - math.floor(100 * ( ( p_temp - 2000 ) / ( 6500 - 2000 ) ) )
      local current = luup.variable_get(const.SID_HUEBULB, "ColorTemperature", device_id)
      if type(current) == 'string' then
         current = tonumber(current)
      elseif type(current) == 'int' then
         current = current
      else
         current = 0
      end
      if temp ~= current then
         luup.call_action(const.SID_HUEBULB,"SetColorTemperature", {newColorTemperature=temp}, device_id)
      end
   end
end

function hue_colour(device_id, hue, sat)
   local current_hue = luup.variable_get(const.SID_HUEBULB, "Hue", device_id)
   local current_sat = luup.variable_get(const.SID_HUEBULB, "Saturation", device_id)
   local desired_hue = math.floor(100 * ( hue / 65535 ))
   local desired_sat = math.floor(100 * ( sat / 254 ))
   if current_hue ~= desired_hue or current_sat ~= desired_sat then
      luup.call_action(const.SID_HUEBULB, "SetHueSaturation", {newHue=desired_hue, newSaturation=desired_sat}, device_id)
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
   luup.call_action(const.SID_SPOWER, "SetTarget", {newTargetValue = distill_target(target)}, device_id)
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
   luup.call_action(const.SID_DIMMABLE, "SetLoadLevelTarget", {newLoadlevelTarget = dim}, device_id)
end

function sonos_favorite(device_id, favorite)
   luup.call_action(const.SID_SONOS, "PlayURI",
                    {URIToPlay="SF:" .. favorite},
                    device_id)
end

function sonos_group(primary, members)
   luup.call_action(const.SID_SONOS, "UpdateGroupMembers",
                    {Zones=table.concat(members, ",")},
                     primary)
end

function sonos_volume(device, volume)
   luup.call_action(const.SID_RENDERING, "SetVolume",
                    {InstanceID="0",DesiredVolume=tostring(volume),Channel="Master"},
                    device)
end

function sonos_volume_down(device, inc)
   local current = luup.variable_get(const.SID_RENDERING, "Volume", device)
   local new = 0
   if ( current - inc > 0 ) then
      new = current - inc
   end
   if current ~= new then
      sonos_volume(device, new)
   end
end

function sonos_volume_up(device, inc, max)
   local current = luup.variable_get(const.SID_RENDERING, "Volume", device)
   local new = max
   if ( current + inc < max ) then
      new = current + inc
   end
   if current ~= new then
      sonos_volume(device, new)
   end
end

function sonos_id(zone_name)
   for id, dev in pairs(luup.devices) do
      if luup.device_supports_service(const.SID_PROPS, id) then
         local this_zone_name = luup.variable_get(const.SID_PROPS, "ZoneName", id)
         luup.log("AAAAAAA " .. this_zone_name .. " vs " .. zone_name)
         if this_zone_name == zone_name then
            return id
         end
      end
   end
   return nil
end

function sonos_toggle(device)
   local state = luup.variable_get(const.SID_AV,  "TransportState", device)
   local action = nil
   if ( state == "STOPPED" ) then
      action = "Play"
   elseif ( state == "PLAYING" ) or ( state == "TRANSITIONING" ) then
      action = "Stop"
   else
      return
   end
   luup.call_action(const.SID_AV, action, {}, device)
end

function sonos_next(device)
   luup.call_action(const.SID_AV, "Next", {}, device)
end
