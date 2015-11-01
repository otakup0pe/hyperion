module("hyperion_scene", package.seeall)
local ez_vera = require("ez_vera")
local hyperion_util = require("hyperion_util")

function problem(message)
   luup.log("hyperion_scene problem " .. message)
end

function dim_down(hyperion_id)
   if not luup.device_supports_service("urn:otakup0pe:serviceId:Hyperion1", hyperion_id) then
      problem("Non hyperion device!")
      return
   end
   local child_id = hyperion_util.get_child(hyperion_id, 'dimmer')
   local current = ez_vera.dim_get(child_id)
   local dim
   if current - 10 > 0 then
      dim = current - 10
   elseif current == 0 then
      dim = hyperion_util.cfg_get(hyperion_id, 'LastDim', '100')
   else
      dim = 0
   end
   ez_vera.dim_actuate(child_id, dim)
end

function dim_up(hyperion_id)
   if not luup.device_supports_service("urn:otakup0pe:serviceId:Hyperion1", hyperion_id) then
      problem("Non hyperion device!")
      return
   end
   local child_id = hyperion_util.get_child(hyperion_id, 'dimmer')
   local current = ez_vera.dim_get(child_id)
    
   local dim
   if current == 0 then
      local last = tonumber(hyperion_util.cfg_get(hyperion_id, 'LastDim', '100'))
      if last >= 50 then
         dim = last
      else
         dim = 50
      end
   elseif current + 10 < 100 then
      dim = current + 10
   else
      dim = 100
   end
   ez_vera.dim_actuate(child_id, 50)
end

function temp_toggle(hyperion_id)
   if not luup.device_supports_service("urn:otakup0pe:serviceId:Hyperion1", hyperion_id) then
      problem("Non hyperion device!")
      return
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
   if not luup.device_supports_service("urn:otakup0pe:serviceId:Hyperion1", hyperion_id) then
      problem("Non hyperion device!")
      return
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
