module("hyperion_scene", package.seeall)
local const = require("vera_constants")
local ez_vera = require("ez_vera")
local hyperion_util = require("hyperion_util")
local cfg = require("hyperion_config")
local hyperion_ambience = require("hyperion_ambience")

function problem(message)
   luup.log("Hyperion Scene problem " .. message)
end

function dim_down(hyperion_id)
   if not luup.device_supports_service(const.SID_HYPERION, hyperion_id) then
      problem("Non hyperion device!")
      return
   end
   if not ez_vera.switch_get(hyperion_id) then
      ez_vera.switch_set(hyperion_id, true)
   end
   local dim_increment = cfg.dim_increment(hyperion_id)
   local child_id = hyperion_util.get_child(hyperion_id, 'dimmer')
   local current = ez_vera.dim_get(child_id)
   local dim
   if current - dim_increment > 0 then
      dim = current - dim_increment
   elseif current == 0 then
      dim = cfg.get(hyperion_id, 'LastDim', '100')
   else
      dim = 0
   end
   ez_vera.dim_actuate(child_id, dim)
end

function dim_up(hyperion_id)
   if not luup.device_supports_service(const.SID_HYPERION, hyperion_id) then
      problem("Non hyperion device!")
      return
   end
   if not ez_vera.switch_get(hyperion_id) then
      ez_vera.switch_set(hyperion_id, true)
   end
   local dim_increment = cfg.dim_increment(hyperion_id)
   local dim_up_min = cfg.dim_up_min(hyperion_id)      
   local child_id = hyperion_util.get_child(hyperion_id, 'dimmer')
   if hyperion_ambience.operating_mode(hyperion_id) ~= 'night' then
      local ambience_id = hyperion_util.get_child(hyperion_id, 'ambience')
      ez_vera.switch_actuate(ambience_id, false)
   end
   local current = ez_vera.dim_get(child_id)
   local dim
   if current == 0 then
      local last = tonumber(cfg.get(hyperion_id, 'LastDim', '100'))
      if last >= dim_up_min then
         dim = last
      else
         dim = dim_up_min
      end
   elseif current + dim_increment < 100 then
      dim = current + dim_increment
   else
      dim = 100
   end
   ez_vera.dim_actuate(child_id, dim)
end

function temp_toggle(hyperion_id)
   if not luup.device_supports_service(const.SID_HYPERION, hyperion_id) then
      problem("Non hyperion device!")
      return
   end
   if not ez_vera.switch_get(hyperion_id) then
      ez_vera.switch_set(hyperion_id, true)
   end

   local ambience_id = hyperion_util.get_child(hyperion_id, 'ambience')
   local dim_id = hyperion_util.get_child(hyperion_id, 'dimmer')
   if not ez_vera.switch_get(dim_id) then
      ez_vera.switch_actuate(ambience_id, false)
      ez_vera.switch_actuate(dim_id, true)
   elseif ez_vera.switch_get(ambience_id) then
      ez_vera.switch_actuate(ambience_id, false)
   else
      ez_vera.toggle(hyperion_util.get_child(hyperion_id, 'temp'))
   end
end

function mode_toggle(hyperion_id)
   if not luup.device_supports_service(const.SID_HYPERION, hyperion_id) then
      problem("Non hyperion device!")
      return
   end
   if not ez_vera.switch_get(hyperion_id) then
      ez_vera.switch_set(hyperion_id, true)
   end

   local ambience_id = hyperion_util.get_child(hyperion_id, 'ambience')
   local dim_id = hyperion_util.get_child(hyperion_id, 'dimmer')
   local current = ez_vera.switch_get(dim_id)
   local current_mode = ez_vera.switch_get(ambience_id)
   if current then
      if current_mode then
         ez_vera.switch_actuate(dim_id, false)
      else
         ez_vera.switch_actuate(ambience_id, true)
      end
   else
      ez_vera.switch_actuate(dim_id, true)
      ez_vera.switch_actuate(ambience_id, false)
   end
end

function global_control(switch, devices)
   local power = ez_vera.switch_get(switch)

   for i, hyperion in _G.ipairs(devices) do
      ez_vera.switch_actuate(hyperion, power)
   end
end

PRIMARY="Living Room"
ZONES={
   {Name="Living Room", Max=70, Inc=15},
   {Name="Media Room", Max=60,  Inc=10},
   {Name="Bathroom", Max=50, Inc=10},
   {Name="Kitchen", Max=50, Inc=15},
   {Name="Bedroom", Max=70, Inc=15}
}
STATIONS={
   "beefsgiving",
   "chill"
}

function zone_names()
   local z = {}
   for i, obj in _G.ipairs(ZONES) do
      table.insert(z, obj.Name)
   end
   return z
end

function ensure_group()
   ez_vera.sonos_group(ez_vera.sonos_id(PRIMARY), zone_names())
end

function volume_up()
   ensure_group()
   for i, obj in _G.ipairs(ZONES) do
      ez_vera.sonos_volume_up(ez_vera.sonos_id(obj.Name), obj.Inc, obj.Max)
   end
end

function volume_down()
   ensure_group()
   for i, obj in _G.ipairs(ZONES) do
      ez_vera.sonos_volume_down(ez_vera.sonos_id(obj.Name), obj.Inc)
   end
end

function sonos_toggle()
   ensure_group()
   ez_vera.sonos_toggle(ez_vera.sonos_id(PRIMARY))
end

function sonos_station(station)
   if table.getn(STATIONS) < station then
      return
   end
   local fav = STATIONS[station]
   ez_vera.sonos_favorite(ez_vera.sonos_id(PRIMARY), fav)
end

function sonos_next()
   ez_vera.sonos_next(ez_vera.sonos_id(PRIMARY), fav)
end

function ipad_dim()
   local now = os.time()
   local last = luup.variable_get(const.SID_SSENSOR, "LastTrip", 295)
   local tripped = false
   if last_trip ~= nil then
      if now - tonumber(last_trip) < 15 then
         tripped = true
      end
   end
   local current = ez_vera.switch_get(112)
   luup.log("ipad_dim is_dim " .. tostring(current) .. " any " .. tostring(tripped))
   if any and current then
      ez_vera.switch_actuate(112, false)
   elseif not any and not current then
      ez_vera.switch_actuate(112, true)
   end
end

function light_on_door(aaa)
   local current = ez_vera.switch_get(325)
   local last = luup.variable_get(const.SID_SSENSOR, "LastTrip", 249)
   local tripped = (luup.variable_get(const.SID_SSENSOR, "Tripped", 249) == 1)
   local now = os.time()
   if last ~= nil and tripped ~= nil then
      if tripped then
         local elapsed = (now - tonumber(last)) < 5
         if elapsed and not current then
            ez_vera.switch_actuate(325, true)
         elseif not elapsed and current then
            ez_vera.switch_actuate(325, false)
         end
      else
         if ( now - tonumber(last) < 5 ) then
            luup.call_timer("light_on_door", 1, "5", "", nil)
         end
      end
   end
end
