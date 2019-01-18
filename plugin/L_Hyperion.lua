local hyperion_util = require("hyperion_util")
local hyperion_ambience = require("hyperion_ambience")
local const = require("vera_constants")
local ez_vera = require("ez_vera")
local log = hyperion_util.log
local cfg = require("hyperion_config")

function external_update(hyperion_id, update)
   local mode = hyperion_util.house_mode()
   if update and (mode == const.HM_HOME) then
      hyperion_ambience.update(hyperion_id)
   end
end

function external_watch(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
   local my_id = tonumber(lul_device)
   for maybe_hyperion_id, params in pairs(luup.devices) do
      if luup.device_supports_service(const.SID_HYPERION, maybe_hyperion_id) then
         local update = false
         for i, required_id in _G.ipairs(hyperion_util.device_list(maybe_hyperion_id, 'require_devices')) do
            if required_id == my_id then
               log(maybe_hyperion_id, 'info', "Updating due to required_device " .. required_id)
               update = true
            end
         end
         for i, override_id in _G.ipairs(hyperion_util.device_list(maybe_hyperion_id, 'override_devices')) do
            if override_id == my_id then
               log(maybe_hyperion_id, 'info', "Updating due to override_device " .. override_id)
               update = true
            end
         end
         if lul_service == const.SID_HOUSEMODE then
            if tonumber(lul_value_old) == const.HM_HOME then
               if not ez_vera.switch_get(maybe_hyperion_id) then
                  log(maybe_hyperion_id, "debug", "This switch is disabled")
               else
                  log(maybe_hyperion_id, "debug", "Turning off lights for house mode " .. lul_value_new)
                  local lights = hyperion_util.device_list(maybe_hyperion_id, 'include_devices')
                  for i, device_id in _G.ipairs(lights) do
                     ez_vera.switch_actuate(device_id, false)
                  end
               end
            elseif tonumber(lul_value_new) == const.HM_HOME then
               update = true
            end
         end
         external_update(maybe_hyperion_id, update)
      end
   end
end

function validate_device_list(hyperion_id, key)
   local valid_devs = {}
   for i, dev in _G.ipairs(hyperion_util.device_list(hyperion_id, key)) do
      local device_id = tonumber(dev)
      if luup.devices[device_id] then
         if luup.device_supports_service(const.SID_VSWITCH, device_id) then
            log(hyperion_id, "debug", "Supported Switch " .. dev .. " found")
            luup.variable_watch("external_watch", const.SID_VSWITCH, "Status", device_id)
            table.insert(valid_devs, device_id)
         elseif luup.device_supports_service(const.SID_SPOWER, device_id) then
            log(hyperion_id, "debug", "Supported Switch " .. dev .. " found")
            luup.variable_watch("external_watch", const.SID_SPOWER, "Status", device_id)
            table.insert(valid_devs, device_id)
         elseif luup.device_supports_service(const.SID_SSENSOR, device_id) then
            log(hyperion_id, "debug", "Supported Security Sensor " .. dev .. " found")
            luup.variable_watch("external_watch", const.SID_SSENSOR, "Tripped", device_id)
            table.insert(valid_devs, device_id)
         elseif luup.device_supports_service(const.SID_LSENSOR, device_id) then
            log(hyperion_id, "debug", "Supported Light Sensor " .. dev .. " found")
            luup.variable_watch("external_watch", const.SID_LSENSOR, "CurrentLevel", device_id)
            table.insert(valid_devs, device_id)
         elseif luup.device_supports_service(const.SID_WEATHER, device_id) then
            log(hyperion_id, "debug", "Supported Weather Device " .. dev .. " found")
            luup.variable_watch("external_watch", const.SID_WEATHER, "ConditionGroup", device_id)
            table.insert(valid_devs, device_id)
         else
            log(hyperion_id, "warn", "Dropping unsupported device " .. dev)
         end
      else
         log(hyperion_id, "warn", "Dropping missing device " .. dev)
      end
   end
   local new_val = table.concat(valid_devs, ",")
   if ( val ~= new_val ) then
      cfg.set(hyperion_id, key, new_val)
   end
   log(hyperion_id, "info", "Validated " .. tonumber(table.getn(valid_devs)) .. " devices for " .. key)
end

function tick(lul_device)
   local hyperion_id = tonumber(lul_device)
   local mode = hyperion_util.house_mode()
   log(hyperion_id, 'debug', "TICK " .. hyperion_util.hm_str(mode))
   if mode == const.HM_HOME then
      hyperion_ambience.update(hyperion_id)
   end
   luup.call_timer("tick", 1, "60", "", hyperion_id)
   cfg.set(hyperion_id, "LastTick", os.time())
end

function ensure_children(hyperion_id)
   local rootdev = luup.chdev.start(hyperion_id)
   local created = false
   -- create dimmer
   local dim_child =  hyperion_util.get_child(hyperion_id, 'dimmer')
   if ( dim_child ) then
      luup.variable_watch("child_watch", const.SID_DIMMABLE, "LoadLevelStatus", dim_child)
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
      luup.variable_watch("child_watch", const.SID_SPOWER, "Status", ambience_child)
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
      luup.variable_watch("child_watch", const.SID_SPOWER, "Status", temp_child)
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
   local house_mode_id = hyperion_util.house_mode_id()
   if house_mode_id ~= -1 then
      luup.variable_watch("external_watch", const.SID_HOUSEMODE, "HMode", house_mode_id)
   end
   ensure_children(hyperion_id)
   hyperion_ambience.update(hyperion_id)
   luup.call_timer("tick", 1, "60", "", hyperion_id)
end

function ensure_active(hyperion_id)
   if not ez_vera.switch_get(hyperion_id) then
      ez_vera.switch_set(hyperion_id, true)
   end
   local op = hyperion_util.operating_mode(hyperion_id)
   local day = false;
   if op == 'day' then
      day = not hyperion_util.stormy_weather(hyperion_id) and not hyperion_util.dim_room(hyperion_id) and not hyperion_util.active_room(hyperion_id)
   end
   if op == 'night' or op == 'dusk' or op == 'dawn' or day then
      if not hyperion_util.dim_room(hyperion_id) and not hyperion_util.active_room(hyperion_id) then
         local ambience_id = hyperion_util.get_child(hyperion_id, 'ambience')
         if ez_vera.switch_get(ambience_id) then
            ez_vera.switch_actuate(ambience_id, false)
         end
      end
   end
end

function do_dim(hyperion_id, target)
   hyperion_util.dim_set(hyperion_id, target)
   hyperion_ambience.update(hyperion_id)
end

function do_switch(hyperion_id, target)
   local current_dim = hyperion_util.dim_get(hyperion_id)
   if current_dim > 0 and target == "0" then
      cfg.set(hyperion_id, 'LastDim', current_dim)
   end
   local val = "0"
   if target == "1" then
      val = cfg.get(hyperion_id, 'LastDim', "100")
   end
   local current_dim = hyperion_util.dim_get(hyperion_id)
   hyperion_util.dim_set(hyperion_id, val)
   ez_vera.switch_set(hyperion_util.get_child(hyperion_id, 'dimmer'), target)
end

function do_ambience(hyperion_id, target)
   if not ez_vera.switch_get(hyperion_id) then
      ez_vera.switch_set(hyperion_id, true)
   end
   cfg.set(hyperion_id, 'Ambience', target)
   ez_vera.switch_set(hyperion_util.get_child(hyperion_id, 'ambience'), target)
end

function do_temp(hyperion_id, target)
   if not ez_vera.switch_get(hyperion_id) then
      ez_vera.switch_set(hyperion_id, true)
   end
   cfg.set(hyperion_id, 'Preset', target)
   ez_vera.switch_set(hyperion_util.get_child(hyperion_id, 'temp'), target)
end

function light_dim(lul_device, target)
   local device_id = tonumber(lul_device)
   local hyperion_id = hyperion_util.ensure_parent(device_id)
   if hyperion_util.get_child(hyperion_id, 'dimmer') == device_id then
      ensure_active(hyperion_id)
   end
   do_dim(hyperion_id, target)
   return true
end

function child_watch(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
   local device_id = tonumber(lul_device)
   local hyperion_id = hyperion_util.ensure_parent(device_id)
   if hyperion_util.get_child(hyperion_id, 'dimmer') == device_id then
      if lul_service == const.SID_DIMMABLE and lul_variable == "LoadLevelStatus"  then
         ensure_active(hyperion_id)
         do_dim(hyperion_id, lul_value_new)
      elseif lul_service == const.SID_SPOWER and lul_variable == "Status" then
         ensure_active(hyperion_id)
         do_switch(hyperion_id, lul_value_new)
      end
   elseif hyperion_util.get_child(hyperion_id, 'ambience') == device_id then
      if lul_service == const.SID_SPOWER and lul_variable == "Status" then
         do_ambience(hyperion_id, lul_value_new)
      end
   elseif hyperion_util.get_child(hyperion_id, 'temp') == device_id then
      if lul_service == const.SID_SPOWER and lul_variable == "Status" then
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
         ensure_active(hyperion_id)
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
   cfg.set(hyperion_id, key, value)
   hyperion_ambience.update(hyperion_id)
   return true
end

function temp_set(lul_device, name, temp)
   local hyperion_id = tonumber(lul_device)
   cfg.set(hyperion_id, name, temp)
   hyperion_ambience.update(hyperion_id)
   return true
end

function ambience_set(lul_device, enabled)
   local hyperion_id = tonumber(lul_device)
   local child_id = hyperion_util.get_child(hyperion_id, 'ambience')
   cfg.set(hyperion_id, 'Ambience', enabled)
   ez_vera.switch_set(child_id, enabled)
   hyperion_ambience.update(hyperion_id)
   return true
end

function feature_set(lul_device, name, enabled)
   local hyperion_id = tonumber(lul_device)
   cfg.set(hyperion_id, name, enabled)
   hyperion_ambience.update(hyperion_id)
   return true
end

function set_hour(lul_device, name, hour)
   local hyperion_id = tonumber(lul_device)
   cfg.set(hyperion_id, name .. 'Hour', hour)
   hyperion_ambience.update(hyperion_id)
   return true
end

function set_minute(lul_device, name, minute)
   local hyperion_id = tonumber(lul_device)
   cfg.set(hyperion_id, name .. 'Minute', minute)
   hyperion_ambience.update(hyperion_id)
   return true
end

function set_timeout(lul_device, name, time)
   local hyperion_id = tonumber(lul_device)
   cfg.set(hyperion_id, name, time)
   hyperion_ambience.update(hyperion_id)
   return true
end

function set_preset(lul_device, preset)
   local hyperion_id = tonumber(lul_device)
   cfg.set(hyperion_id, 'Preset', preset)
   hyperion_ambience.update(hyperion_id)
   local child_id = hyperion_util.get_child(hyperion_id, 'temp')
   if preset == "1" then
      ez_vera.switch_set(child_id, true)
   else
      ez_vera.switch_set(child_id, false)
   end
   return true
end

function set_increment(lul_device, increment)
   local hyperion_id = tonumber(lul_device)
   cfg.set(hyperion_id, 'DimIncrement', increment)
   return true
end

function set_dim_min(lul_device, dim)
   local hyperion_id = tonumber(lul_device)
   cfg.set(hyperion_id, 'DimUpMin', dim)
   return true
end

function set_lux_threshold(lul_device, threshold)
   local hyperion_id = tonumber(lul_device)
   cfg.set(hyperion_id, 'LuxThreshold', threshold)
   return true
end

function add_included_device(lul_device, device_id, device_type)
   local hyperion_id = tonumber(lul_device)
   local setting = nil
   if ( device_type == 'control' ) then
      setting = 'include_devices'
   elseif ( device_type == 'require' ) then
      setting = 'require_devices'
   elseif ( device_type == 'override' ) then
      setting = 'override_devices'      
   end
   if ( setting == nil ) then
      return false
   end
   local existing = hyperion_util.device_list(hyperion_id, setting)
   local exists = false
   for i, dev in _G.ipairs(existing) do
      if ( device_id == dev ) then
         exists = true
         break
      end
   end
   if ( not exists ) then
      table.insert(existing, device_id)
      cfg.set(hyperion_id, setting, table.concat(existing, ','))
   end
   return true
end

function remove_included_device(lul_device, device_id, device_type)
   local hyperion_id = tonumber(lul_device)
   local setting = nil
   if ( device_type == 'control' ) then
      setting = 'include_devices'
   elseif ( device_type == 'require' ) then
      setting = 'require_devices';
   elseif ( device_type == 'override' ) then
      setting = 'override_devices';
   end

   if ( setting == nil ) then
      return false
   end
   local existing = hyperion_util.device_list(hyperion_id, setting)
   local exists = false
   for i, dev in _G.ipairs(existing) do
      if ( tonumber(device_id) == dev ) then
         exists = true
         break
      end
   end
   if ( exists ) then
      local new_value = {}
      for i, dev in _G.ipairs(existing) do
         if ( tonumber(device_id) ~= dev ) then
            table.insert(new_value, dev)
         end
      end
      cfg.set(hyperion_id, setting, table.concat(new_value, ','))
   end   
   return true
end
