/* global set_panel_html, Ajax, command_url */

var hyperion = {
  SID_HYPERION: "urn:otakup0pe:serviceId:Hyperion1"
};

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
  html += '</select> with a pre-sunrise grace period of ';
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
  html += '</select> with a pre-sunset grace period of ';
  html += '<input id="sunset_grace" type="text" value="' + sunset_grace + '" onchange="save_grace(' + device_id + ', \'Sunset\');" style="width: 100px"/> seconds.';  

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
    'Name': name
  };
  if ( name == 'Sunrise' ) {
    obj.Time = jQuery('#sunrise_grace').val();
  } else {
    obj.Time = jQuery('#sunset_grace').val();
  }
  call_action(device_id, hyperion.SID_HYPERION, 'SetGrace', obj);
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

