# Hyperion

__Of Hyperion we are told that he was the first to understand, by diligent attention and observation, the movement of both the sun and the moon and the other stars, and the seasons as well...__

------

This plugin is for the [MiOS](http://www.mios.com/) home automation platform. It allows collections of devices to act as one, and the ability to have ambient light patterns simply happen. If you have devices such as the [Hue](http://www2.meethue.com/en-us/), color temperature will be changed throughout the evening to correspond with circadian cues. The net effect is similar to the [f.lux](https://justgetflux.com/), however for your house. More information on the pattern is available [here](https://github.com/otakup0pe/hyperion/wiki/Ambient-Lighting-Patterns).

It probably only works with UI7. It has been tested on a [Vera 3](http://getvera.com/controllers/vera3/) because that is what I have.

Installation
------------

As of now, this plugin is not in the MiOS app store. That should happen soon, but until then you may (relatively) install it from GitHub. If you are new to this kind of thing, just download this [zip](https://github.com/otakup0pe/hyperion/archive/master.zip) file. Extract the contents somewhere comfortable on your file system.

You can now either upload the contents of the `plugin` directory via SCP or the 'LuuP Files' section of the MiOS UI. The Vera should restart, and then you should be able to manually add a device from the `D_Hyperion1.xml` definition.

At the very least, you must add devices to be controlled by the plugin. Find your device in the list, and then open it's 'Device Selection' tab. Under the 'Control Devices' section, select the devices you wish to see controlled.

Basic Operation
---------------

Each Hyperion device will create three child devices. While you may use the parent Hyperion device for some basic interactions, this device will often not show up on mobile applications. To work around this, the child devices expose standard uPnP interfaces to ensure mobile compatability. Child devices are created for the dimming, ambient/preset selection, and preset color temporature selection.

When the Hyperion device is set to `Off`, nothing occurs. You may use your controlled devices as you would normally, or via external apps. When the Hyperion device is set to `On`, it will be constantly adjusting your devices, thus rendering manual control quite difficult.

The Hyperion plugin can operate in either ambient lighting or preset mode. In ambient mode, the lights will be adjusted as described [here](https://github.com/otakup0pe/hyperion/wiki/Ambient-Lighting-Patterns), albeit capped at their dimmer level In preset mode, the lights will simply be left at their dimmer level.

Dimming Semantics
------------------

As the Hyperion device controls a group of lights, the dimming semantics are slightly different. A portion of devices in the group will be enabled depending on the dimmer level. Those devices, if they support dimming, will also be set according to the dimmer level.

Development
-----------

There is a scene integration [API](https://github.com/otakup0pe/hyperion/wiki/Scene-Integration-API). This API, and the uPnP interface, should remain consistent. Other functionality may be added. Random other LUA functions are likely to change.

Pull requests welcome! If you are doing local hacking, then the two included scripts may be useful.

Author
------
[Jonathan Freedman](http://jonathanfreedman.bio/)
