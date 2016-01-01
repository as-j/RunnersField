using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;

//! @author Konrad Paumann
class RunnersField extends App.AppBase {
	var view;
	
	function initialize() {
		return App.AppBase.initialize();
	}
	
    function getInitialView() {
        view = new RunnersView();
        return [ view ];
    }

    function onSettingsChanged() {
    	view.updateSettings();
   	}
}

//! A DataField that shows some infos.
//!
//! @author Konrad Paumann
class RunnersView extends Ui.DataField {

    hidden const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    hidden const HEADER_FONT = Graphics.FONT_XTINY;
    hidden const VALUE_FONT = Graphics.FONT_NUMBER_MEDIUM;
    hidden const VALUE_SMALL_FONT = Graphics.FONT_NUMBER_MILD;
    hidden const ZERO_TIME = "0:00";
    hidden const ZERO_DISTANCE = "0.00";
    
    hidden var kmOrMileInMeters = 1000;
    hidden var mOrFeet = 1;
    hidden var is24Hour = true;
    hidden var distanceUnits = System.UNIT_METRIC;
    hidden var textColor = Graphics.COLOR_BLACK;
    hidden var inverseTextColor = Graphics.COLOR_WHITE;
    hidden var backgroundColor = Graphics.COLOR_WHITE;
    hidden var inverseBackgroundColor = Graphics.COLOR_BLACK;
    hidden var inactiveGpsBackground = Graphics.COLOR_LT_GRAY;
    hidden var batteryBackground = Graphics.COLOR_WHITE;
    hidden var batteryColor1 = Graphics.COLOR_GREEN;
    hidden var hrColor = Graphics.COLOR_RED;
    hidden var headerColor = Graphics.COLOR_DK_GRAY;
    hidden var paceSlowColor = Graphics.COLOR_RED;
        
    hidden var paceStr, avgPaceStr, hrStr, distanceStr, durationStr;
    
    hidden var paceAvgLen = 1; //Application.getApp().getProperty("paceAveraging");
    hidden var paceData;
    
    hidden var paceDataLongAverageLen = 5; //(Application.getApp().getProperty("paceAveragingLong")/30).toNumber();
    hidden var paceDataLongAverage = new [paceDataLongAverageLen];
    hidden var paceDataLongLastTime = -30000; 
    hidden var paceDataLongPos = 0;
	//hidden var longAvg = new[Application.getApp().getProperty("paceAveragingLong")];

	hidden var doneLayout = 0;
	hidden var doUpdates = 0;

    hidden var avgSpeed= 0;
    hidden var hr = 0;
    hidden var distance = 0;
    hidden var elapsedTime = 0;
    hidden var gpsSignal = 0;
    hidden var altitude = 0;
	hidden var maxHeartRate = 0;
	hidden var averageHeartRate = 0;
	hidden var lastTime = 0;
	
	hidden var currentCadence = 0;
	hidden var averageCadence = 0;
	hidden var maxCadence = 0;
	
	hidden var hrZones = [ 122,134,149,163,182 ];
    
    hidden var hasBackgroundColorOption = false;
    
    function initialize() {
     	paceData = DataQueueInit(paceAvgLen);
        System.println("-->dataField: " + System.getSystemStats().usedMemory);
        
        paceDataLongAverageLen = 5; //(Application.getApp().getProperty("paceAveragingLong")/30).toNumber();
    	paceDataLongAverage = new [paceDataLongAverageLen];
        
        if (paceAvgLen == null ||
        	paceAvgLen == 0) {
        	paceAvgLen = 10;
        }
        var str = Application.getApp().getProperty("hrZones");
        var loc = str.find(",");
        var zones = [ 0, 0, 0, 0 ];
        var i = 0;
        try {
        	for(i = 0; i <= 3; i++) {
        		loc = str.find(",");
        		if (loc == null) {
        			loc = str.length();
        		}
        		var substr = str.substring(0, loc);
        		if (substr.length() < 2) {
        			throw new Exception();
        		}
        		zones[i] = substr.toNumber();
        		str = str.substring(loc+1, str.length());
        	}
        }
        catch (ex) {
        }
        finally {
        	if (i >= 4) {
        		hrZones = zones;
        	}
        }
        DataField.initialize();
    }

    //! The given info object contains all the current workout
    function compute(info) {
		//System.println("-->compute(" + System.getSystemStats().usedMemory + ") " + 
		//info.timerTime + " elapse " + info.elapsedTime + " eD " + info.elapsedDistance );
        if (info.currentSpeed != null) {
        	if (lastTime != info.timerTime) {
        		lastTime = info.timerTime;
            	DataQueueAdd(paceData, info.currentSpeed);
            }
        } else {
        	//System.println("-->compute: resetting pace data");
            DataQueueReset(paceData);
            paceDataLongPos = 0;
            paceDataLongLastTime = -30000;
            paceDataLongAverage = new [paceDataLongAverageLen];
        }
        
        // If we have more than 30s of data
        if((info.timerTime != null) && (info.elapsedDistance != null)) {
           if((info.timerTime - paceDataLongLastTime) >= 30000) {
             //System.println("Adding; " + [ info.elapsedDistance, info.timerTime ] + " " + paceDataLongPos + "/" + paceDataLongAverageLen + "/" + paceDataLongAverage.size());
             if(paceDataLongPos >= paceDataLongAverage.size()) {
             	paceDataLongPos = paceDataLongAverage.size()-1;
             	for(var i = 0; i < paceDataLongAverage.size()-1; i++) {
             		paceDataLongAverage[i] = paceDataLongAverage[i+1]; 
             	}
             }
        	 paceDataLongAverage[paceDataLongPos] = [ info.elapsedDistance, info.timerTime ];
        	 paceDataLongLastTime = info.timerTime;             
        	 paceDataLongPos += 1;
          }
        }
        
        avgSpeed = info.averageSpeed != null ? info.averageSpeed : 0;
        elapsedTime = info.timerTime != null ? info.timerTime : 0;
        hr = info.currentHeartRate != null ? info.currentHeartRate : 0;
        distance = info.elapsedDistance != null ? info.elapsedDistance : 0;
        gpsSignal = info.currentLocationAccuracy;
        altitude = info.totalAscent != null ? info.totalAscent : 0;
		maxHeartRate = info.maxHeartRate != null ? info.maxHeartRate : 0;
		averageHeartRate = info.averageHeartRate != null ? info.averageHeartRate : 0;
		maxCadence = info.maxCadence != null ? info.maxCadence : 0;
		averageCadence = info.averageCadence != null ? info.averageCadence : 0;
		currentCadence = info.currentCadence != null ? info.currentCadence : 0;
		
		//if (info.timerTime == 0) {
		//    DataQueueReset(paceData);
        //    DataQueueReset(paceDataOneMinute);
		//}
		
    }
    
    function onLayout(dc) {
    	//System.println("-->onLayout: " + System.getSystemStats().usedMemory);
		if (doneLayout == 1) {
			return;
		}
			
		doneLayout = 1;
    	setDeviceSettingsDependentVariables();
        //onUpdate(dc);
    }
    
    function onShow() {
    	//System.println("-->onShow");
    	doUpdates = true;
    	return true;
    }
    
    function onHide() {
    	doUpdates = false;
    }
    
    function onUpdate(dc) {
    	//System.println("-->onUpdate");
    	
    	if(doUpdates == false) {
    		return;
    	}
    	
        setColors();
        // reset background
        dc.setColor(backgroundColor, backgroundColor);
        dc.fillRectangle(0, 0, 218, 218);
        
        drawValues(dc);
    }

    function setDeviceSettingsDependentVariables() {
        hasBackgroundColorOption = (self has :getBackgroundColor);
        
        distanceUnits = System.getDeviceSettings().distanceUnits;
        if (distanceUnits == System.UNIT_METRIC) {
            kmOrMileInMeters = 1000;
            mOrFeet = 1;
        } else {
            kmOrMileInMeters = 1610;
            mOrFeet = 3.281;
        }
        is24Hour = System.getDeviceSettings().is24Hour;
        
        paceStr = "PACE"; //Ui.loadResource(Rez.Strings.pace);
        avgPaceStr = "AVG PACE"; //Ui.loadResource(Rez.Strings.avgpace);
        hrStr = "HR"; //Ui.loadResource(Rez.Strings.hr);
        distanceStr = "DIST"; // Ui.loadResource(Rez.Strings.distance);
        durationStr = "DURATION"; //Ui.loadResource(Rez.Strings.duration);
    }
    
    function setColors() {
        if (hasBackgroundColorOption) {
            backgroundColor = getBackgroundColor();
            textColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
            inverseTextColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_WHITE;
            inverseBackgroundColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_DK_GRAY: Graphics.COLOR_BLACK;
            hrColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_BLUE : Graphics.COLOR_RED;
            headerColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY: Graphics.COLOR_DK_GRAY;
            batteryColor1 = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_GREEN;
            paceSlowColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_RED : Graphics.COLOR_RED;
        }
    }
        
    function drawValues(dc) {
    	//System.println("-->drawValues");
        //time
        var clockTime = System.getClockTime();
        var time, ampm;
        if (is24Hour) {
            time = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%.2d")]);
            ampm = "";
        } else {
            time = Lang.format("$1$:$2$", [computeHour(clockTime.hour), clockTime.min.format("%.2d")]);
            ampm = (clockTime.hour < 12) ? "am" : "pm";
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0,0,218,25);
        dc.setColor(inverseTextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(109, 12, Graphics.FONT_MEDIUM, time, CENTER);
        dc.drawText(148, 15, HEADER_FONT, ampm, CENTER);
        
        //pace
		var paceColor = textColor;
		var longAvgSpeed = 0;
		if(paceDataLongPos > 0) {
			var longAvgData = paceDataLongAverage[0];
			//System.println(paceDataLongPos + " " + distance +"/"+ longAvgData[0] +"/"+ elapsedTime +"/"+ longAvgData[1]);
			if(longAvgData != null) { 
				if ((elapsedTime - longAvgData[1]) > 1000) {
					longAvgSpeed = (distance-longAvgData[0])/((elapsedTime - longAvgData[1])/1000);
				}
			}
		}
		
		var shortAvgSpeed = computeAverageSpeed(paceData);
		
		if (shortAvgSpeed < longAvgSpeed) {
			paceColor = paceSlowColor;
		} 
        dc.setColor(paceColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(46, 70, VALUE_FONT, getMinutesPerKmOrMile(shortAvgSpeed), CENTER);
        
        //hr
        //dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        //dc.drawText(109, 70, VALUE_FONT, hr.format("%d"), CENTER);
        
        drawHRZone(dc, hr, 000, hrZones[0], Graphics.COLOR_LT_GRAY);
        drawHRZone(dc, hr, hrZones[0], hrZones[1], Graphics.COLOR_BLUE);
        drawHRZone(dc, hr, hrZones[1], hrZones[2], Graphics.COLOR_GREEN);
        drawHRZone(dc, hr, hrZones[2], hrZones[3], Graphics.COLOR_ORANGE);
        drawHRZone(dc, hr, hrZones[3], 250, Graphics.COLOR_RED);
        
        drawHRZone(dc, hr, maxHeartRate-0.5, maxHeartRate+0.5, Graphics.COLOR_WHITE);
        drawHRZone(dc, hr, averageHeartRate-0.5, averageHeartRate+0.5, Graphics.COLOR_DK_RED);
        drawHRZone(dc, hr, hr-0.5, hr+0.5, Graphics.COLOR_BLACK);
        
        drawCadenceZone(dc, currentCadence, 000, 164, Graphics.COLOR_ORANGE);
        drawCadenceZone(dc, currentCadence, 164, 174, Graphics.COLOR_GREEN);
        drawCadenceZone(dc, currentCadence, 174, 184, Graphics.COLOR_BLUE);
        drawCadenceZone(dc, currentCadence, 184, 300, 0x5500AA);
        
        drawCadenceZone(dc, currentCadence, maxCadence-0.5, maxCadence+0.5, Graphics.COLOR_WHITE);
        drawCadenceZone(dc, currentCadence, averageCadence-0.5, averageCadence+0.5, Graphics.COLOR_DK_RED);
        drawCadenceZone(dc, currentCadence, currentCadence-0.5, currentCadence+0.5, Graphics.COLOR_BLACK);
           
        // altitude
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);

        var alt = mOrFeet*altitude;
        var str_alt = alt > 99.9 ? alt.format("%d") : alt.format("%2.1f");
		dc.drawText(112, 130, VALUE_FONT, str_alt, CENTER);   
        
        // two minute pace
		dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
		dc.drawText(109, 70, VALUE_FONT, getMinutesPerKmOrMile(longAvgSpeed), CENTER);
        
        //apace
		paceColor = textColor;
		if (longAvgSpeed < avgSpeed) {
			paceColor = paceSlowColor;
		}
        dc.setColor(paceColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(46, 130, VALUE_FONT, getMinutesPerKmOrMile(avgSpeed), CENTER);
        
        //distance
        var distStr;
        if (distance > 0) {
            var distanceKmOrMiles = distance / kmOrMileInMeters;
            if (distanceKmOrMiles < 100) {
                distStr = distanceKmOrMiles.format("%.2f");
            } else {
                distStr = distanceKmOrMiles.format("%.1f");
            }
        } else {
            distStr = ZERO_DISTANCE;
        }
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(178 , 70, VALUE_FONT, distStr, CENTER);
        
        //duration
        var duration;
        if (elapsedTime != null && elapsedTime > 0) {
            var hours = null;
            var minutes = elapsedTime / 1000 / 60;
            var seconds = elapsedTime / 1000 % 60;
            
            if (minutes >= 60) {
                hours = minutes / 60;
                minutes = minutes % 60;
            }
            
            if (hours == null) {
                duration = minutes.format("%d") + ":" + seconds.format("%02d");
            } else {
                duration = hours.format("%d") + ":" + minutes.format("%02d") + ":" + seconds.format("%02d");
            }
        } else {
            duration = ZERO_TIME;
        } 
        dc.drawText(178, 130, VALUE_FONT, duration, CENTER);
        
        //signs background
        dc.setColor(inverseBackgroundColor, inverseBackgroundColor);
        dc.fillRectangle(0,180,218,38);
        
        // km/miles
        dc.setColor(inverseTextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(112, 207, HEADER_FONT, distanceUnits == System.UNIT_METRIC ? "(km)" : "(mi)", CENTER);
        
        drawBattery(System.getSystemStats().battery, dc, 64, 186, 25, 15);
        
        // gps 
        if (gpsSignal < 2) {
            drawGpsSign(dc, 136, 181, inactiveGpsBackground, inactiveGpsBackground, inactiveGpsBackground);
        } else if (gpsSignal == 2) {
            drawGpsSign(dc, 136, 181, batteryColor1, inactiveGpsBackground, inactiveGpsBackground);
        } else if (gpsSignal == 3) {          
            drawGpsSign(dc, 136, 181, batteryColor1, batteryColor1, inactiveGpsBackground);
        } else {
            drawGpsSign(dc, 136, 181, batteryColor1, batteryColor1, batteryColor1);
        }
        
        // headers:
        dc.setColor(headerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(50, 43, HEADER_FONT, paceStr, CENTER);
        dc.drawText(57, 160, HEADER_FONT, avgPaceStr, CENTER);
        dc.drawText(109, 43, HEADER_FONT, "APACE", CENTER);
        //dc.drawText(109, 38, HEADER_FONT, hrStr, CENTER); 
        dc.drawText(170, 43, HEADER_FONT, distanceStr, CENTER);
        dc.drawText(158, 160, HEADER_FONT, durationStr, CENTER);
        
        //grid
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, 104, dc.getWidth(), 104);
        
        //RKO Arc
//        var width = dc.getWidth();
//        var height = dc.getHeight();
//        drawZoneBarsArcs(dc, (height/2)+1, width/2, height/2, hr); //radius, center x, center y
    }
    
    function drawHRZone(dc, hr, hrBot, hrTop, color) {
    	var pixelPerBeat = 5;
    	var middle = dc.getWidth()/2;
    	
    	var x = middle-(hr-hrBot)*pixelPerBeat;
    	var x2 = middle-(hr-hrTop)*pixelPerBeat;
    	var y = 25;
    	var height = 12;
    	var width = x2-x;
    	
    	dc.setColor(color, Graphics.COLOR_TRANSPARENT);
   		dc.fillRectangle(x,y,width,height);
    }
    
    function drawCadenceZone(dc, cadence, cadenceBot, cadenceTop, color) {
    	var pixelPerCadence = 5;
    	var middle = dc.getWidth()/2;
    	
    	var x = middle-(cadence-cadenceBot)*pixelPerCadence;
    	var x2 = middle-(cadence-cadenceTop)*pixelPerCadence;
    	
    	var height = 12;
    	var y = 180-height;

    	var width = x2-x;
    	
    	dc.setColor(color, Graphics.COLOR_TRANSPARENT);
   		dc.fillRectangle(x,y,width,height);
    }
    
    function drawBattery(battery, dc, xStart, yStart, width, height) {                
        dc.setColor(batteryBackground, inactiveGpsBackground);
        dc.fillRectangle(xStart, yStart, width, height);
        if (battery < 10) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xStart+3 + width / 2, yStart + 6, HEADER_FONT, format("$1$%", [battery.format("%d")]), CENTER);
        }
        
        if (battery < 10) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        } else if (battery < 30) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(batteryColor1, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRectangle(xStart + 1, yStart + 1, (width-2) * battery / 100, height - 2);
            
        dc.setColor(batteryBackground, batteryBackground);
        dc.fillRectangle(xStart + width - 1, yStart + 3, 4, height - 6);
    }
    
    function drawGpsSign(dc, xStart, yStart, color1, color2, color3) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart - 1, yStart + 11, 8, 10);
        dc.setColor(color1, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart, yStart + 12, 6, 8);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart + 6, yStart + 7, 8, 14);
        dc.setColor(color2, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart + 7, yStart + 8, 6, 12);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart + 13, yStart + 3, 8, 18);
        dc.setColor(color3, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart + 14, yStart + 4, 6, 16);
    }
  
    function computeAverageSpeed(paceData) { 
       	//System.println("-->computeAverageSpeed");
        var size = 0;
        var data = DataQueueGetData(paceData);
        var sumOfData = 0.0;
        for (var i = 0; i < data.size(); i++) {
            if (data[i] != null) {
                sumOfData = sumOfData + data[i];
                size++;
            }
        }
        if (sumOfData > 0) {
            return sumOfData / size;
        }
        return 0.0;
    }

    function computeHour(hour) {
        if (hour < 1) {
            return hour + 12;
        }
        if (hour >  12) {
            return hour - 12;
        }
        return hour;      
    }
    
    //! convert to integer - round ceiling 
    function toNumberCeil(float) {
        var floor = float.toNumber();
        if (float - floor > 0) {
            return floor + 1;
        }
        return floor;
    }
    
    function getMinutesPerKmOrMile(speedMetersPerSecond) {
    	//System.println("-->getMinutesPerKmOrMile");
        if (speedMetersPerSecond != null && speedMetersPerSecond > 0.2) {
            var metersPerMinute = speedMetersPerSecond * 60.0;
            var minutesPerKmOrMilesDecimal = kmOrMileInMeters / metersPerMinute;
            var minutesPerKmOrMilesFloor = minutesPerKmOrMilesDecimal.toNumber();
            var seconds = (minutesPerKmOrMilesDecimal - minutesPerKmOrMilesFloor) * 60;
            return minutesPerKmOrMilesDecimal.format("%2d") + ":" + seconds.format("%02d");
        }
        return ZERO_TIME;
    }
    
    function updateSettings() {
		//paceAvgLen = Application.getApp().getProperty("paceAveraging");
		//paceData = new DataQueue(paceAvgLen);

		//paceAvgLongLen = Application.getApp().getProperty("paceAveragingLong");
    	//paceDateOneMinute = new DataQueue(paceAvgLongLen);   	
    }
     
    
    
//! A circular queue implementation.
//! @author Konrad Paumann
    
}

    //! precondition: size has to be >= 2
    function DataQueueInit(arraySize) {
    	var obj = [ new[arraySize],   // data 0
    			  arraySize,          // size 1
    			  0 ];                // pos  2
       	return obj;
    }
    
    //! Add an element to the queue.
    function DataQueueAdd(obj, element) {
        obj[0][obj[2]] = element;
        obj[2] = (obj[2] + 1) % obj[1];
    }
    
    //! Reset the queue to its initial state.
    function DataQueueReset(obj) {
        for (var i = 0; i < obj[0].size(); i++) {
            obj[0][i] = null;
        }
        obj[2] = 0;
    }
    
    //! Get the underlying data array.
    function DataQueueGetData(obj) {
        return obj[0];
    }
