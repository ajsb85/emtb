using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Application;
using Application.Properties as applicationProperties;
using Application.Storage as applicationStorage;

//class emtbView extends WatchUi.DataField
//DataField.initialize();
//
// This version is easier for testing/developing and for displaying (multiple) long strings
class baseView2 extends WatchUi.DataField
{
	var displayString = "";
	
    function initialize()
    {
        DataField.initialize();
    }

    function setLabelInInitialize(s)
    {
    	// do nothing - must be drawn by subclass
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc)
    {
		//var obscurityFlags = DataField.getObscurityFlags();
		//if (obscurityFlags == (OBSCURE_TOP | OBSCURE_LEFT))
		//{
		//}
		//else if (obscurityFlags == (OBSCURE_TOP | OBSCURE_RIGHT))
		//{
		//}
		//else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_LEFT))
		//{
		//}
		//else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_RIGHT))
		//{
		//}
		//else
		//{
		//}

        return true;
    }

	// This method is called once per second and automatically provides Activity.Info to the DataField object for display or additional computation.
    function compute(info)
    {
    	// do nothing
   	}

    // Display the value you computed here. This will be called once a second when the data field is visible.
    function onUpdate(dc)
    {
        dc.setColor(Graphics.COLOR_TRANSPARENT, getBackgroundColor());
        dc.clear();

        dc.setColor((getBackgroundColor()==Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);

		var s = Graphics.fitTextToArea(displayString, Graphics.FONT_SYSTEM_XTINY, 200, 240, true);
        dc.drawText(120, 120, Graphics.FONT_SYSTEM_XTINY, s, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

//
// or use
//

//class emtbView extends WatchUi.SimpleDataField
//SimpleDataField.initialize();
//label = "some string";
//
// No onLayout() and onUpdate()
// Just return a value from compute() which will be displayed for us ... 
//
// This version is easier for a release version as we don't need to worry about all display formats for all devices
class baseView extends WatchUi.SimpleDataField
{
	var displayString = "";
	
    function initialize()
    {
        SimpleDataField.initialize();

    	//label = "Wheee";		// seems this has to be set in initialize() and can't be changed later
    }
    
    function setLabelInInitialize(s)
    {
    	label = s;
    }

	// This method is called once per second and automatically provides Activity.Info to the DataField object for display or additional computation.
    function compute(info)
    {
    	return displayString;
   	}
}

class emtbView extends baseView
{
	var thisView;
	var bleHandler;
	
	var showList = [0, 0, 0];
	var lastLock = false;
	var lastMAC = "";

	var batteryValue = -1;
	var modeValue = -1;

	const secondsWaitBattery = 15;
	var secondsSinceReadBattery = secondsWaitBattery;

	var modeNames = [
		"Off",
		"Eco",
		"Trail",
		"Boost",
		"Walk",
	];

	var modeLetters = [
		"O",
		"E",
		"T",
		"B",
		"W",
	];

	var connectCounter = 0;
	
	function propertiesGetBoolean(p)
	{
		var v = applicationProperties.getValue(p);
		if ((v == null) || !(v instanceof Boolean))
		{
			v = false;
		}
		return v;
	}
	
	function propertiesGetString(p)
	{	
		var v = applicationProperties.getValue(p);
		if (v == null)
		{
			v = "";
		}
		else if (!(v instanceof String))
		{
			v = v.toString();
		}
		return v;
	}

	function getSettings()
	{
    	showList[0] = propertiesGetBoolean("Item1");
    	showList[1] = propertiesGetBoolean("Item2");
    	showList[2] = propertiesGetBoolean("Item3");
    	
		lastLock = propertiesGetBoolean("LastLock");
		lastMAC = propertiesGetString("LastMAC");
		
		// if lastLock or lastMAC get changed dynamically while the field is running
		// then should really handle it in some way - but we don't for now!
	}

    function initialize()
    {
        baseView.initialize();
        
		// label can only be set in initialize so don't bother storing it
		setLabelInInitialize(propertiesGetString("Label"));

		getSettings();
    }

	// called by app when settings change
	function onSettingsChanged()
	{
		getSettings();
	
    	WatchUi.requestUpdate();   // update the view to reflect changes
	}

	function setSelf(theView)
	{
		thisView = theView;

        setupBle();
	}
	
	function setupBle()
	{
    	bleHandler = new emtbDelegate(thisView);
		Ble.setDelegate(bleHandler);
	}

	// This method is called once per second and automatically provides Activity.Info to the DataField object for display or additional computation.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no guarantee that compute() will be called before onUpdate().
    function compute(info)
    {
    	var showBattery = (showList[0]==1 || showList[1]==1 || showList[2]==2);
    	if (showBattery)
    	{
	    	// only read battery value every 15 seconds once we have a value
	    	secondsSinceReadBattery++;
	    	if (batteryValue<0 || secondsSinceReadBattery>=secondsWaitBattery)
	    	{
	    		secondsSinceReadBattery = 0;
	    		bleHandler.requestReadBattery();
	    	}
		}
		    
    	var showMode = (showList[0]>=2 || showList[1]>=2 || showList[2]>=2);
    	bleHandler.requestNotifyMode(showMode && bleHandler.isConnected());		// set whether we want mode or not (continuously)
    
		bleHandler.compute();
		
		// create the string to display to user
   		displayString = "";

		// could show status of scanning & pairing if we wanted
		if (bleHandler.isConnecting())
		{
			connectCounter++;
			
			displayString = "Scan " + connectCounter;
		}
		else
		{
			connectCounter = 0;

			for (var i=0; i<showList.size(); i++)
			{
				switch (showList[i])
				{
					case 0:		// off
					{
						break;
					}

					case 1:		// battery
					{
	    				displayString += ((displayString.length()>0)?" ":"") + ((batteryValue>=0) ? batteryValue.toNumber() : "--") + "%";
						break;
					}

					case 2:		// mode name
					{
	    				displayString += ((displayString.length()>0)?" ":"") + ((modeValue>=0 && modeValue<modeNames.size()) ? modeNames[modeValue] : "----");
						break;
					}

					case 3:		// mode letter
					{
	    				displayString += ((displayString.length()>0)?" ":"") + ((modeValue>=0 && modeValue<modeLetters.size()) ? modeLetters[modeValue] : "-");
						break;
					}

					case 4:		// mode number
					{
	    				displayString += ((displayString.length()>0)?" ":"") + ((modeValue>=0) ? modeValue.toNumber() : "-");
						break;
					}
				}
			}
		}
				       
		return baseView.compute(info);	// if a SimpleDataField then this will return the string/value to display
    }
}

class emtbDelegate extends Ble.BleDelegate
{
	var mainView;

	enum
	{
		State_Init,
		State_Connecting,
		State_Idle,
		State_Disconnected,
	}
	
	var state = State_Init;

	var wantStartScanning = false;

	function startConnect()
	{
		mainView.batteryValue = -1;
		mainView.modeValue = -1;

		state = State_Connecting;
		wantStartScanning = true;
	}

	function isConnecting()
	{
		return (state==State_Connecting);
	}
	
	function isConnected()
	{
		return (state==State_Idle);
	}
	
	function completeConnect()
	{
		state = State_Idle;
		Ble.setScanState(Ble.SCAN_STATE_OFF);	// Ble.SCAN_STATE_OFF, Ble.SCAN_STATE_SCANNING
	}
	
	var wantReadBattery = false;
	var waitingRead = false;
	
	function requestReadBattery()
	{
		wantReadBattery = true;
	}
	
	var currentNotifyMode = false;
	var wantNotifyMode = false;
	var waitingWrite = false;
	var writingNotifyMode = false;
	
   	function requestNotifyMode(wantMode)
   	{
   		wantNotifyMode = wantMode;
   	}
   	
    function initialize(theView)
    {
        mainView = theView;

        BleDelegate.initialize();

   		bleInitProfiles();
   		
   		startConnect();
    }
    
    // called from compute of mainView
    function compute()
    {
    	switch (state)
    	{
			case State_Connecting:		// scanning & pairing until we connect to the bike
			{
				if (wantStartScanning)
				{
        			Ble.setScanState(Ble.SCAN_STATE_SCANNING);	// Ble.SCAN_STATE_OFF, Ble.SCAN_STATE_SCANNING
				}

				// waiting for onScanResults() to be called
				// and for it to decide to pair to something
				//
    			// if scanning takes too long, then cancel it and try again in "a while"?
    			// When View.onShow() is next called? (If user can switch between different pages ...)
				break;
			}
			
			case State_Idle:	// connected, so now reading data as needed
			{
				if (!waitingRead && !waitingWrite)
				{
					if (wantReadBattery)
					{
						if (bleReadBattery())
						{
							wantReadBattery = false;
							waitingRead = true;
						}
						else
						{
				    		mainView.batteryValue = -1;		// read wouldn't start for some reason ...
						}
					}
					else if (wantNotifyMode!=currentNotifyMode)
					{
						writingNotifyMode = wantNotifyMode;
	    				if (bleWriteNotifications(writingNotifyMode))
	    				{
	    					waitingWrite = true;
	    				}
					}
				}
				break;
			}
			
			case State_Disconnected:
			{				
    			startConnect();		// start scanning to connect again
				break;
			}
    	}
    }
    
	// 2 service ids are advertised (by EW-EN100)
	var advertised1ServiceUuid = Ble.stringToUuid("000018ff-5348-494d-414e-4f5f424c4500");	// we don't use this service (no idea what the data is)
	// lightblue phone app says the following service uuid is being advertised
	// but CIQ doesn't list it in the returned scan results, only the one above
	//var advertised2ServiceUuid = Ble.stringToUuid("000018ef-5348-494d-414e-4f5f424c4500");	// this service we also use to get notifications for mode
	
	var batteryServiceUuid = Ble.stringToUuid("0000180f-0000-1000-8000-00805f9b34fb");
	var batteryCharacteristicUuid = Ble.stringToUuid("00002a19-0000-1000-8000-00805f9b34fb");
	
	var modeServiceUuid = Ble.stringToUuid("000018ef-5348-494d-414e-4f5f424c4500");		// also used in advertising
	var modeCharacteristicUuid = Ble.stringToUuid("00002ac1-5348-494d-414e-4f5f424c4500");
	
	var MACServiceUuid = Ble.stringToUuid("000018fe-1212-efde-1523-785feabcd123");
	var MACCharacteristicUuid = Ble.stringToUuid("00002ae3-1212-efde-1523-785feabcd123");
	
    // set up the ble profiles we will use (CIQ allows up to 3 luckily ...) 
    function bleInitProfiles()
    {
		// read - battery
		var profile = {
			:uuid => batteryServiceUuid,
			:characteristics => [
				{
					:uuid => batteryCharacteristicUuid,
				}
			]
		};
		
		// notifications - mode, gear
		// is speed, distance, range, cadence anywhere in the data?
		// get 3 notifications continuously:
		// 1 = 02 XX 00 00 00 00 CB 28 00 00 (XX=02 is mode)
		// 2 = 03 B6 5A 36 00 B6 5A 36 00 CC 00 AC 02 2F 00 47 00 60 00
		// 3 = 00 00 00 FF FF YY 0B 80 80 80 0C F0 10 FF FF 0A 00 (YY=03 is gear if remember correctly)
		// Mode is 00=off 01=eco 02=trail 03=boost 04=walk 
		var profile2 = {
			:uuid => modeServiceUuid,
			:characteristics => [
				{
					:uuid => modeCharacteristicUuid,
					:descriptors => [Ble.cccdUuid()]	// for requesting notifications set to [1,0]?
				}
			]
		};
		
		// light blue displays MAC address as: C3 FC 37 79 B7 C2
		// which happens to match this!:
		// 000018fe-1212-efde-1523-785feabcd123
		// 00002ae3-1212-efde-1523-785feabcd123
		// C2 b7 79 37 fc c3
		// read - mac address
		var profile3 = {
			:uuid => MACServiceUuid,
			:characteristics => [
				{
					:uuid => MACCharacteristicUuid,
				}
			]
		};

		try
		{
    		Ble.registerProfile(profile);
    		Ble.registerProfile(profile2);
    		Ble.registerProfile(profile3);
		}
		catch (e instanceof Lang.Exception)
		{
		    //System.println("catch = " + e.getErrorMessage());
		    //mainView.displayString = "err";
		}
    }
    
    function bleWriteNotifications(wantOn)
    {
       	var startedWrite = false;
    
    	// get first device (since we only connect to one) and check it is connected
		var d = Ble.getPairedDevices().next();
		if (d!=null && d.isConnected())
		{
			try
			{
				var ds = d.getService(modeServiceUuid);
				if (ds!=null)
				{
					var dsc = ds.getCharacteristic(modeCharacteristicUuid);
					if (dsc!=null)
					{
						var cccd = dsc.getDescriptor(Ble.cccdUuid());
						cccd.requestWrite([(wantOn?0x01:0x00), 0x00]b);
						startedWrite = true;
					}
				}
			}
			catch (e instanceof Lang.Exception)
			{
			    //System.println("catch = " + e.getErrorMessage());			    
			}
		}
		
		return startedWrite;
	}
	
    function bleReadBattery()
    {
    	var startedRead = false;
    
    	// don't know if we can just keep calling requestRead() as often as we like without waiting for onCharacteristicRead() in between
    	// but it seems to work ...
    	// ... or maybe it doesn't, as always get a crash trying to call requestRead() after power off bike
    	// After adding code to wait for the read to finish before starting a new one, then the crash doesn't happen. 
    
    	// get first device (since we only connect to one) and check it is connected
		var d = Ble.getPairedDevices().next();
		if (d!=null && d.isConnected())
		{
			try
			{
				var ds = d.getService(batteryServiceUuid);
				if (ds!=null)
				{
					var dsc = ds.getCharacteristic(batteryCharacteristicUuid);
					if (dsc!=null)
					{
						dsc.requestRead();	// had one exception from this when turned off bike, and now a symbol not found error 'Failed invoking <symbol>'
						startedRead = true;
					}
				}
			}
			catch (e instanceof Lang.Exception)
			{
			    //System.println("catch = " + e.getErrorMessage());			    
			}
		}

		return startedRead;
    }
    
	function onProfileRegister(uuid, status)
	{
    	//System.println("onProfileRegister status=" + status);
       	//mainView.displayString = "reg" + status;
	}

    function onScanStateChange(scanState, status)
    {
    	//System.println("onScanStateChange scanState=" + scanState + " status=" + status);
    	if (state==Ble.SCAN_STATE_SCANNING)
    	{
    		wantStartScanning = false;
    	}
    }
    
//    var rList = [];
    
    private function iterContains(iter, obj)
    {
        for (var uuid=iter.next(); uuid!=null; uuid=iter.next())
        {
            if (uuid.equals(obj))
            {
                return true;
            }
        }

        return false;
    }

    function onScanResults(scanResults)
    {
    	//System.println("onScanResults");
    
    	for (;;)
    	{
    		var r = scanResults.next();
    		if (r==null)
    		{
    			break;
    		}

			// check the advertised uuids to see if right sort of device
      		if (iterContains(r.getServiceUuids(), advertised1ServiceUuid))
      		{
      			var d = Ble.pairDevice(r);
      			if (d!=null)
      			{
      				// it seems that sometimes after pairing onConnectedStateChanged() is not always called
      				// - checking isConnected() here immediately seems to avoid that case happening.
      				if (d.isConnected())
      				{
      					completeConnect();
      				}
      				
     				//mainView.displayString = "paired " + d.getName();
      			}
      			else
      			{
     				//mainView.displayString = "not";
    				state = State_Connecting;
      			}
      			
      			break;
      		}
    	}
    	
//    	for (;;)
//    	{
//    		var r = scanResults.next();
//    		if (r==null)
//    		{
//    			break;
//    		}
//    		
//    		var rNew = true;
//    		for (var i=0; i<rList.size(); i++)
//    		{
//    			if (r.isSameDevice(rList[i]))
//    			{
//    				rList[i] = r;
//    				rNew = false;
//    				break;
//    			}
//    		}
//    		
//    		if (rNew)
//    		{
//    			rList.add(r);
//    		}
//       	}
//
//		var bestI = -1;
//		var bestRssi = -999;
//		
//    	for (var i=0; i<rList.size(); i++)
//    	{
//    		var rssi = rList[i].getRssi();
//    		if (bestI<0 || rssi>bestRssi)
//    		{
//   				bestI = i;
//   				bestRssi = rssi;
//   			}
//   		}
//
//		if (bestI>=0)
//		{
//			mainView.displayString = "" + rList.size() + " " + rList[bestI].getRssi();
//
//    		var s = rList[bestI].getDeviceName();
//    		if (s!=null)
//    		{
//    			mainView.displayString += s;
//    		}
//    		
////    		var iter = rList[bestI].getServiceUuids();
////    		if (iter!=null)
////    		{
////    			var u = iter.next();
////    			if (u!=null)
////    			{
////    				mainView.displayString += u.toString();
////    			}
////    		}    		
//    		
////    		//var data = rList[bestI].getManufacturerSpecificData(1098);		// [1, 0]
////    		var data = rList[bestI].getRawData();			// [3, 25, 128, 4, 2, 1, 5, 17, 6, 0, 69, 76, 66, 95, 79, 78, 65, 77, 73, 72, 83, 255, 24, 0, 0, 5, 255, 74, 4, 1, 0]
////    														// 3, 25, 128, 4, (25=appearance) 0x8004
////    														// 2, 1, 5, (1=flags)
////    														// 17, 6, 0, 69, 76, 66, 95, 79, 78, 65, 77, 73, 72, 83, 255, 24, 0, 0, (6=Incomplete List of 128-bit Service Class UUIDs)
////    														// 5, 255, 74, 4, 1, 0 (255=Manufacturer Specific Data) (74 4 == Shimano)
////    		if (data!=null)
////    		{
////   				mainView.displayString += data.toString();
////    		}
//		}
//		else
//		{
//			mainView.displayString = "none";
//		}
    }

	// After pairing a device this will be called after the connection is made.
	// (But seemingly not sometimes ... maybe if still connected from previous run of datafield?)
	function onConnectedStateChanged(device, connectionState)
	{
		if (connectionState==Ble.CONNECTION_STATE_CONNECTED)
		{
			completeConnect();
		}
		else if (connectionState==Ble.CONNECTION_STATE_DISCONNECTED)
		{
			state = State_Disconnected;
		}
	}
	
	// After requesting a read operation on a characteristic using Characteristic.requestRead() this function will be called when the operation is completed.
	function onCharacteristicRead(characteristic, status, value)
	{
		if (characteristic.getUuid().equals(batteryCharacteristicUuid))
		{
			if (value!=null && value.size()>0)		// (had this return a zero length array once ...)
			{
				mainView.batteryValue = value[0].toNumber();	// value is a byte array
			}
		}
		
		waitingRead = false;
	}

	// After requesting a write operation on a descriptor using Descriptor.requestWrite() this function will be called when the operation is completed.
	function onDescriptorWrite(descriptor, status)
	{ 
		var cd = descriptor.getCharacteristic();
		if (cd!=null && cd.getUuid().equals(modeCharacteristicUuid))
		{
			if (status==Ble.STATUS_SUCCESS)
			{
				currentNotifyMode = writingNotifyMode;
			}
		}
		
		waitingWrite = false;
	}

	// After enabling notifications or indications on a characteristic (by enabling the appropriate bit of the CCCD of the characteristic)
	// this function will be called after every change to the characteristic.
	function onCharacteristicChanged(characteristic, value)
	{
		if (characteristic.getUuid().equals(modeCharacteristicUuid))
		{
			if (value!=null)
			{
				// value is a byte array
				if (value.size()==10)	// we want the one which is 10 bytes long (out of the 3 that Shimano seem to spam ...)
				{
					mainView.modeValue = value[1].toNumber();	// and it is the 2nd byte of the array
				}
//				else if (value.size()==17)
//				{
//					mainView.gearValue = value[5].toNumber();
//				}
			}
		}
	}
}
