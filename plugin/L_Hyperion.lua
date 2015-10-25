local hyperion_util = require("hyperion_util")
local hyperion_ambience = require("hyperion_ambience")
local ez_vera = require("ez_vera")

local log = hyperion_util.log

function external_watch(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
   local my_id = tonumber(lul_device)
   if lul_variable ~= "Status" then
      return
   end
   for device_id, params in pairs(luup.devices) do
      if luup.device_supports_service("urn:otakup0pe:serviceId:Hyperion1", device_id) then
         local update = false
         for i, required_id in _G.ipairs(hyperion_util.device_list(device_id, 'required_devices')) do
            if required_id == my_id then
               log(device_id, 'info', "Updating due to required_device " .. required_id)
               update = true
            end
         end
         for i, override_id in _G.ipairs(hyperion_util.device_list(device_id, 'override_devices')) do
            if override_id == my_id then
               log(device_id, 'info', "Updating due to override_device " .. override_id)
               update = true
            end
         end
         if update then
            hyperion_ambience.update(device_id)
         end
      end
   end
end

function validate_device_list(hyperion_id, key)
   local valid_devs = {}
   for i, dev in _G.ipairs(hyperion_util.device_list(hyperion_id, key)) do
      local device_id = tonumber(dev)
      if luup.devices[device_id] then
         if luup.device_supports_service("urn:upnp-org:serviceId:SwitchPower1", device_id) then
            log(device_id, "debug", "Supported device " .. dev .. " found")
            luup.variable_watch("external_watch", "urn:upnp-org:serviceId:SwitchPower1", "Status", device_id)
            table.insert(valid_devs, device_id)
         elseif luup.device_supports_service("urn:upnp-org:serviceId:VSwitch1", device_id) then
            log(device_id, "debug", "Supported device " .. dev .. " found")
            luup.variable_watch("external_watch", "urn:upnp-org:serviceId:VSwitch1", "Status", device_id)
            table.insert(valid_devs, device_id)
         else
            log(device_id, "warn", "Dropping unsupported device " .. dev)
         end
      else
         log(device_id, "warn", "Dropping missing device " .. dev)
      end
   end
   local new_val = table.concat(valid_devs, ",")
   if ( val ~= new_val ) then
      hyperion_util.cfg_set(hyperion_id, key, new_val)
   end
   log(hyperion_id, "info", "Validated " .. tonumber(table.getn(valid_devs)) .. " devices for " .. key)
end

function tick(lul_device)
   local hyperion_id = tonumber(lul_device)
   log(hyperion_id, 'debug', "TICK")
   hyperion_ambience.update(hyperion_id)
end

function ensure_children(hyperion_id)
   local rootdev = luup.chdev.start(hyperion_id)
   local created = false
   -- create dimmer
   local dim_child =  hyperion_util.get_child(hyperion_id, 'dimmer')
   if ( dim_child ) then
      luup.variable_watch("child_watch", "urn:upnp-org:serviceId:DimmableLight1", "LoadLevelStatus", dim_child)
      if not ez_vera.dim_get(dim_child) then
         ez_vera.dim_set(dim_child, "0")
      end
   else
      luup.chdev.append(hyperion_id, rootdev, 'dimmer' .. hyperion_id, "Hyperion #" .. hyperion_id .. " Dimmer",  "urn:schemas-upnp-org:device:DimmableLight:1", "D_DimmableLight1.xml", "", "", false, false)
      created = true
   end
   -- create ambience control
   local ambience_child =  hyperion_util.get_child(hyperion_id, 'ambience')
   if ( ambience_child ) then
      luup.variable_watch("child_watch", "urn:upnp-org:serviceId:SwitchPower1", "Status", ambience_child)
      if not ez_vera.switch_get(ambience_child) then
         ez_vera.switch_set(ambience_child, false)
      end
   else
      luup.chdev.append(hyperion_id, rootdev, 'ambience' .. hyperion_id, "Hyperion #" .. hyperion_id .. " Ambience",  "urn:schemas-upnp-org:device:BinaryLight:1", "D_BinaryLight1.xml", "", "", false, false)
      created = true
   end
   -- create temp control
   local temp_child =  hyperion_util.get_child(hyperion_id, 'temp')
   if ( temp_child ) then
      luup.variable_watch("child_watch", "urn:upnp-org:serviceId:SwitchPower1", "Status", temp_child)
      if not ez_vera.switch_get(temp_child) then
         ez_vera.switch_set(temp_child, false)
      end
   else
      luup.chdev.append(hyperion_id, rootdev, 'temp' .. hyperion_id, "Hyperion #" .. hyperion_id .. " Cold Preset",  "urn:schemas-upnp-org:device:BinaryLight:1", "D_BinaryLight1.xml", "", "", false, false)
      created = true
   end
   if created then
      luup.chdev.sync(hyperion_id, rootdev)
   end
end

function startup(lul_device)
   hyperion_id = tonumber(lul_device)
   parent_id = hyperion_util.ensure_parent(hyperion_id)
   if ( parent_id ~= hyperion_id ) then
      log(parent_id, "debug", "Child " .. hyperion_id .. " startup!")
      return
   end
   log(hyperion_id, "info", "Startup!")
   validate_device_list(hyperion_id, 'require_devices', '')
   validate_device_list(hyperion_id, 'override_devices', '')
   validate_device_list(hyperion_id, 'include_devices', '')
   ensure_children(hyperion_id)
   hyperion_ambience.update(hyperion_id)
   luup.call_timer("tick", 1, "30s", "", hyperion_id)
end

function do_dim(hyperion_id, target)
   hyperion_util.dim_set(hyperion_id, target)
   hyperion_ambience.update(hyperion_id)
end

function do_switch(hyperion_id, target)
   local current_dim = hyperion_util.dim_get(hyperion_id)
   if current_dim > 0 and target == "0" then
      hyperion_util.cfg_set(hyperion_id, 'LastDim', current_dim)
   end
   local val = "0"
   if target == "1" then
      val = hyperion_util.cfg_get(hyperion_id, 'LastDim', "100")
   end
   local current_dim = hyperion_util.dim_get(hyperion_id)
   hyperion_util.dim_set(hyperion_id, val)
   ez_vera.switch_set(hyperion_util.get_child(hyperion_id, 'dimmer'), target)
end

function do_ambience(hyperion_id, target)
   hyperion_util.cfg_set(hyperion_id, 'Ambience', target)
   ez_vera.switch_set(hyperion_util.get_child(hyperion_id, 'ambience'), target)
end

function do_temp(hyperion_id, target)
   local val = "3250"
   if target == "1" then
      val = "5000"
   end
   hyperion_util.cfg_set(hyperion_id, 'Preset', val)
   ez_vera.switch_set(hyperion_util.get_child(hyperion_id, 'temp'), target)
end

function light_dim(lul_device, target)
   local device_id = tonumber(lul_device)
   local hyperion_id = hyperion_util.ensure_parent(device_id)
   if hyperion_util.get_child(hyperion_id, 'dimmer') == device_id then
      do_dim(hyperion_id, target)
      return true
   end
end

function child_watch(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
   local device_id = tonumber(lul_device)
   local hyperion_id = hyperion_util.ensure_parent(device_id)
   if hyperion_util.get_child(hyperion_id, 'dimmer') == device_id then
      if lul_service == "urn:upnp-org:serviceId:Dimming1" and lul_variable == "LoadLevelStatus"  then
         do_dim(hyperion_id, lul_value_new)
      elseif lul_service == "urn:upnp-org:serviceId:SwitchPower1" and lul_variable == "Status" then
         do_switch(hyperion_id, lul_value_new)
      end
   elseif hyperion_util.get_child(hyperion_id, 'ambience') == device_id then
      if lul_service == "urn:upnp-org:serviceId:SwitchPower1" and lul_variable == "Status" then
         do_ambience(hyperion_id, lul_value_new)
      end
   elseif hyperion_util.get_child(hyperion_id, 'temp') == device_id then
      if lul_service == "urn:upnp-org:serviceId:SwitchPower1" and lul_variable == "Status" then
         do_temp(hyperion_id, lul_value_new)
      end
   end
end

function light_switch(lul_device, target)
   local device_id = tonumber(lul_device)
   local hyperion_id = hyperion_util.ensure_parent(lul_device)
   if device_id ~= hyperion_id then
      if hyperion_util.get_child(hyperion_id, 'ambience') == device_id then
         do_ambience(hyperion_id, target)
      elseif hyperion_util.get_child(hyperion_id, 'dimmer') == device_id then
         do_switch(hyperion_id, target)
      elseif hyperion_util.get_child(hyperion_id, 'temp') == device_id then
         do_temp(hyperion_id, target)
      end
   else
      ez_vera.switch_set(hyperion_id, target)
   end
   hyperion_ambience.update(hyperion_id)
   return true
end

function cfg_set(lul_device, key, value)
   hyperion_id = tonumber(lul_device)
   hyperion_util.cfg_set(hyperion_id, key, value)
   hyperion_ambience.update(hyperion_id)
   return true
end

function temp_set(lul_device, name, temp)
   local hyperion_id = tonumber(lul_device)
   local child_id = hyperion_util.get_child(hyperion_id, 'temp')
   hyperion_util.cfg_set(hyperion_id, name, temp)
   if temp == "3250" then
      ez_vera.switch_set(child_id, false)
   else
      ez_vera.switch_set(child_id, true)
   end
   hyperion_ambience.update(hyperion_id)
   return true
end

function ambience_set(lul_device, enabled)
   local hyperion_id = tonumber(lul_device)
   local child_id = hyperion_util.get_child(hyperion_id, 'ambience')
   hyperion_util.cfg_set(hyperion_id, 'Ambience', enabled)
   ez_vera.switch_set(child_id, enabled)
   hyperion_ambience.update(hyperion_id)
   return true
end
