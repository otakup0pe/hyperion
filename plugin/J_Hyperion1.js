/* global set_panel_html, Ajax, command_url, api */

var hyperion = {
  SID_HYPERION: "urn:otakup0pe:serviceId:Hyperion1",
  SID_SPOWER: "urn:upnp-org:serviceId:SwitchPower1",
  SID_DIMMING: "urn:upnp-org:serviceId:Dimming1",
  SID_HUEBULB: "urn:intvelt-com:serviceId:HueColors1",
  SID_VSWITCH: "urn:upnp-org:serviceId:VSwitch1",
  SID_SSENSOR: "urn:micasaverde-com:serviceId:SecuritySensor1",
  SID_LSENSOR: "urn:micasaverde-com:serviceId:LightSensor1",
  SID_WEATHER: "urn:upnp-micasaverde-com:serviceId:Weather1"
};

function device_selection_callback(device_id) {
  var html = '';
  html += '<h1>Included Devices</h1>';
  html += render_device_selection(device_id, 'control');
  html += '<h1>Required Devices</h1>';
  html += render_device_selection(device_id, 'require');
  html += '<h1>Override Devices</h1>';
  html += render_device_selection(device_id, 'override');
  html += '<a href="https://github.com/otakup0pe/hyperion/wiki/Configuration#device-selection">Help</a>';
  set_panel_html(html);
}

function render_device_selection(device_id, device_type) {
  var setting = '';
  var callback = null;
  var inactive_select = '';
  var active_select = '';
  if ( device_type == 'control') {
    setting = 'include_devices';
    callback = validate_control_device;
  } else if ( device_type == 'require' ) {
    setting = 'require_devices';
    callback = validate_require_device;
  } else if ( device_type == 'override' ) {
    setting = 'override_devices';
    callback = validate_override_device;
  }
  var selected_device_ids = get_device_state(device_id, hyperion.SID_HYPERION, setting, 1).split(',');
  var selected_devices = selected_device_ids.map(function(id) {
    var room = api.getRoomObject(api.getDeviceAttribute(id, 'room'));
    var name = api.getDeviceAttribute(id, 'name');
    if ( room && room.name ) {
      name = room.name + ' - ' + name;
    }
    return {
      id: id,
      name: name
    };
  });
  var html = '<table>';
  html += '<tr><td>Available Devices</td><td></td><td>Selected Devices</td>';
  html += '<tr><td><select multiple size="10" id="available_' + device_type + '_devices">';
  for ( var i_devices = 0; i_devices < jsonp.ud.devices.length ; i_devices++ ) {
    var this_device = jsonp.ud.devices[i_devices];
    var this_device_name;
    if ( this_device.name ) {
      this_device_name = this_device.name;
    } else {
      this_device_name = 'Device #' + this_device.id;
    }
    
    var this_id = parseInt(this_device.id, 10);
    // check to see if it's an included device
    var valid = true;
    for ( var i_check = 0 ; i_check < selected_device_ids.length ; i_check++ ) {
      if ( parseInt(selected_device_ids[i_check], 10) == this_id ) {
        valid = false;
        break;
      }
    }
    if ( valid ) {
      var these_services = device_services(this_id);
      valid = false;
      // check if it's a device we can use
      if ( these_services.length > 0 ) {
        valid = callback(this_id, these_services);
      }
    }
    if ( valid ) {
      var room = api.getRoomObject(jsonp.ud.devices[i_devices].room);
      var name = this_device_name;
      if ( room && room.name ) {
        name = room.name + ' - ' + name;
      }
      html += '<option value="' + jsonp.ud.devices[i_devices].id + '">' + name + '</option>';
    }
  }
  html += '</select></td>';
  html += '<td>';
  html += '<button type="button" onclick="add_device(' + device_id + ', \'' + device_type + '\')">--&gt;</button><br>';
  html += '<button type="button" onclick="remove_device(' + device_id + ', \'' + device_type + '\')">&lt;--</button>';
  html += '</td>';
  html += '<td><select multiple size="10" id="active_' + device_type + '_devices">';
  for ( var i_idevices = 0 ; i_idevices < selected_devices.length ; i_idevices++ ) {
    var selected_device_name;
    if ( selected_devices[i_idevices].name ) {
      selected_device_name = selected_devices[i_idevices].name;
    } else {
      selected_device_name = 'Device #' + selected_devices[i_idevices].id;
    }
    html += '<option value="' + selected_devices[i_idevices].id + '">' + selected_device_name + '</option>';
  }
  html += '</select></td></tr></table>';
  return html;
}

function time_settings_callback(device_id) {
  var html = '';
  html += 'Daytime starts at <select id="morning_hour" onchange="save_hour(' + device_id + ', \'Morning\')">';
  var morning_hour = get_device_state(device_id, hyperion.SID_HYPERION, 'MorningHour', 1);
  var morning_minute = get_device_state(device_id, hyperion.SID_HYPERION, 'MorningMinute', 1);
  var sunrise_grace = get_device_state(device_id, hyperion.SID_HYPERION, 'SunriseGrace', 1);
  for ( var i_day_hour = 0 ; i_day_hour < 24 ; i_day_hour++ ) {
    var day_hour_selected = false;
    var s_day_hour = i_day_hour.toString();
    if ( i_day_hour == morning_hour ) {
      day_hour_selected = true;
    }
    html += '<option';
    if ( day_hour_selected ) {
      html += ' selected';
    }
    html += ' value="' + s_day_hour + '">' + s_day_hour + '</option>';
  }
  html += '</select>:<select id="morning_minute" onchange="save_minute(' + device_id + ', \'Morning\')">';
  for ( var i_day_minute = 0 ; i_day_minute < 60 ; i_day_minute++ ) {
    var day_minute_selected = false;
    var s_day_minute = i_day_minute.toString();
    if ( i_day_minute == morning_minute ) {
      day_minute_selected = true;
    }
    html += '<option';
    if ( day_minute_selected ) {
      html += ' selected';
    }
    html += ' value="' + s_day_minute + '">' + s_day_minute + '</option>';
  }
  html += '</select> with a dawn grace period of ';
  html += '<input id="sunrise_grace" type="text" onchange="save_grace(' + device_id + ', \'Sunrise\')" value="' + sunrise_grace + '" style="width: 100px"/> seconds.';
  html += "<p/>";
  var night_hour = get_device_state(device_id, hyperion.SID_HYPERION, 'NightHour', 1);
  var night_minute = get_device_state(device_id, hyperion.SID_HYPERION, 'NightMinute', 1);
  var sunset_grace = get_device_state(device_id, hyperion.SID_HYPERION, 'SunsetGrace', 1);
  html += 'Nighttime starts at <select id="night_hour" onchange="save_hour(' + device_id + ', \'Night\')">';
  for ( var i_night_hour = 0 ; i_night_hour < 24 ; i_night_hour++ ) {
    var night_hour_selected = false;
    var s_night_hour = i_night_hour.toString();
    if ( i_night_hour == night_hour ) {
      night_hour_selected = true;
    }
    html += '<option';
    if ( night_hour_selected ) {
      html += ' selected';
    }
    html += ' value="' + s_night_hour + '">' + s_night_hour + '</option>';
  }
  html += '</select>:<select id="night_minute" onchange="save_minute(' + device_id + ', \'Night\');">';
  for ( var i_night_minute = 0 ; i_night_minute < 60 ; i_night_minute++ ) {
    var night_minute_selected = false;
    var s_night_minute = i_night_minute.toString();
    if ( i_night_minute == night_minute ) {
      night_minute_selected = true;
    }
    html += '<option';
    if ( night_minute_selected ) {
      html += ' selected';
    }
    html += ' value="' + s_night_minute + '">' + s_night_minute + '</option>';
  }
  html += '</select> with a dusk grace period of ';
  html += '<input id="sunset_grace" type="text" value="' + sunset_grace + '" onchange="save_grace(' + device_id + ', \'Sunset\');" style="width: 100px"/> seconds.';
  html += '<a href="https://github.com/otakup0pe/hyperion/wiki/Configuration#time-settings">Help</a>';
  set_panel_html(html);
}

function save_hour(device_id, name)
{
  var obj = {
    'Name': name
  };
  if ( name == 'Morning' ) {
    obj.Hour = jQuery('#morning_hour').val();
  } else {
    obj.Hour = jQuery('#night_hour').val();
  }
  call_action(device_id, hyperion.SID_HYPERION, 'SetHour', obj);
}

function save_minute(device_id, name)
{
  var obj = {
    'Name': name
  };
  if ( name == 'Morning' ) {
    obj.Minute = jQuery('#morning_minute').val();
  } else {
    obj.Minute = jQuery('#night_minute').val();
  }
  call_action(device_id, hyperion.SID_HYPERION, 'SetMinute', obj);
}

function save_grace(device_id, name)
{
  var obj = {
    'Name': name + 'Grace'
  };
  if ( name == 'Sunrise' ) {
    obj.Time = jQuery('#sunrise_grace').val();
  } else {
    obj.Time = jQuery('#sunset_grace').val();
  }
  call_action(device_id, hyperion.SID_HYPERION, 'SetTimeout', obj);
}

function call_action(device_id, sid, action, args) {
  var o = {
    'id': 'lu_action',
    'output_format':'json',
    'DeviceNum':device_id,
    'serviceId': sid,
    'action': action
  };
  var k;
  for (k in args ) {
    o[k] = args[k];
  };
  new Ajax.Request(command_url + '/data_request', {
    method: 'get',
    parameters: o
  });
}

function device_services(device_id) {
  var device = jsonp.ud.devices[api.getDeviceIndex(device_id)];
  var services = [];
  if ( device.ControlURLs ) {
    for ( var key in device.ControlURLs ) {
      services.push(device.ControlURLs[key].service);
    }
  }
  return services;
}

function is_hyperion(device_id) {
  var device = jsonp.ud.devices[api.getDeviceIndex(device_id)];
  if ( device.id_parent ) {
    var parent_services = device_services(device.id_parent);
    return parent_services.indexOf(hyperion.SID_HYPERION) >= 0;
  }
  return false;
}

function add_device(device_id, device_type) {
  var devices = $('#available_' + device_type + '_devices option:selected');
  devices.selected()
    .each(function(i, obj) {
      var action = {
        'Id': obj.value,
        'Type': device_type
      };
      call_action(device_id, hyperion.SID_HYPERION, 'AddIncludedDevice', action);
    });
  devices.remove().appendTo('#active_' + device_type + '_devices').removeAttr('selected');
}

function remove_device(device_id, device_type) {
  var devices = $('#active_' + device_type + '_devices option:selected');
  devices.selected()
    .each(function(i, obj) {
      var action = {
        'Id': obj.value,
        'Type': device_type
      };
      call_action(device_id, hyperion.SID_HYPERION, 'RemoveIncludedDevice', action);
    });
  devices.remove().appendTo('#available_' + device_type + '_devices').removeAttr('selected');
}

function validate_control_device(device_id, device_services) {
  var valid = false;
  if ( device_services.indexOf(hyperion.SID_SPOWER) >= 0 ||
       device_services.indexOf(hyperion.SID_DIMMING) >= 0 ) {
    valid = ( device_services.indexOf(hyperion.SID_HUEBULB) == -1 &&
              ! is_hyperion(device_id) &&
              device_services.indexOf(hyperion.SID_VSWITCH) == -1 );
  }
  return valid;
}

function validate_override_device(device_id, device_services) {
  return device_services.indexOf(hyperion.SID_VSWITCH) >= 0;
}

function validate_require_device(device_id, device_services) {
  return device_services.indexOf(hyperion.SID_VSWITCH) >= 0 ||
    device_services.indexOf(hyperion.SID_SSENSOR) >= 0 ||
    device_services.indexOf(hyperion.SID_WEATHER) >= 0 ||
    device_services.indexOf(hyperion.SID_LSENSOR) >= 0;
}
