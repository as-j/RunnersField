using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;

//! @author Konrad Paumann
class RunnersField extends App.AppBase {
	var view;
	
    function initialize() {
    	AppBase.initialize();
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
    
    hidden var paceAvgLen = Application.getApp().getProperty("paceAveraging");
    hidden var paceData;
    
    hidden var paceAvgLongLen = Application.getApp().getProperty("paceAveragingLong");
    hidden var paceDataOneMinute;
	hidden var doUpdates = 0;

    hidden var avgSpeed= 0;
    hidden var hr = 0;
    hidden var distance = 0;
    hidden var elapsedTime = 0;
    hidden var gpsSignal = 0;
    hidden var altitude = 0;
    
    hidden var hasBackgroundColorOption = false;
    
    function initialize() {
        DataField.initialize();
     	paceData = DataQueueInit(paceAvgLen);
     	paceDataOneMinute = DataQueueInit(paceAvgLongLen);
        if (paceAvgLen == null ||
        	paceAvgLen == 0) {
        	paceAvgLen = 10;
        }
    }

    //! The given info object contains all the current workout
    function compute(info) {

        if (info.currentSpeed != null) {
            DataQueueAdd(paceData, info.currentSpeed);
            DataQueueAdd(paceDataOneMinute, info.currentSpeed);
        } else {
            DataQueueReset(paceData);
            DataQueueReset(paceDataOneMinute);
        }
        
        avgSpeed = info.averageSpeed != null ? info.averageSpeed : 0;
        elapsedTime = info.elapsedTime != null ? info.elapsedTime : 0;
        hr = info.currentHeartRate != null ? info.currentHeartRate : 0;
        distance = info.elapsedDistance != null ? info.elapsedDistance : 0;
        gpsSignal = info.currentLocationAccuracy;
        altitude = info.altitude != null ? info.altitude : 0;
    }
    
    function onLayout(dc) {
        setDeviceSettingsDependentVariables();
        //onUpdate(dc);
    }
    
    function onShow() {
    	doUpdates = true;
    	return true;
    }
    
    function onHide() {
    	doUpdates = false;
    }
    
    function onUpdate(dc) {
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
        
        paceStr = Ui.loadResource(Rez.Strings.pace);
        avgPaceStr = Ui.loadResource(Rez.Strings.avgpace);
        hrStr = Ui.loadResource(Rez.Strings.hr);
        distanceStr = Ui.loadResource(Rez.Strings.distance);
        durationStr = Ui.loadResource(Rez.Strings.duration);
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
		var oneMinuteAvgSpeed = computeAverageSpeed(paceDataOneMinute);
		var shortAvgSpeed = computeAverageSpeed(paceData);
		
		if (shortAvgSpeed < oneMinuteAvgSpeed) {
			paceColor = paceSlowColor;
		} 
        dc.setColor(paceColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(50, 70, VALUE_FONT, getMinutesPerKmOrMile(shortAvgSpeed), CENTER);
        
        //hr
        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(109, 70, VALUE_FONT, hr.format("%d"), CENTER);
        
        // altitude
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        if (altitude > 99) {
        	dc.drawText(109, 130, VALUE_SMALL_FONT, (mOrFeet*altitude).format("%.1f"), CENTER);
        }
        else {
        	dc.drawText(112, 130, VALUE_FONT, (mOrFeet*altitude).format("%2.1f"), CENTER);
		}        
        
        //apace
		paceColor = textColor;
		if (oneMinuteAvgSpeed < avgSpeed) {
			paceColor = paceSlowColor;
		}
        dc.setColor(paceColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(50, 130, VALUE_FONT, getMinutesPerKmOrMile(avgSpeed), CENTER);
        
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
        dc.drawText(170 , 70, VALUE_FONT, distStr, CENTER);
        
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
        dc.drawText(170, 130, VALUE_FONT, duration, CENTER);
        
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
        dc.drawText(50, 38, HEADER_FONT, paceStr, CENTER);
        dc.drawText(57, 165, HEADER_FONT, avgPaceStr, CENTER);
        dc.drawText(109, 38, HEADER_FONT, hrStr, CENTER); 
        dc.drawText(170, 38, HEADER_FONT, distanceStr, CENTER);
        dc.drawText(158, 165, HEADER_FONT, durationStr, CENTER);
        
        //grid
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, 104, dc.getWidth(), 104);
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
		paceAvgLen = Application.getApp().getProperty("paceAveraging");
		paceData = new DataQueue(paceAvgLen);

		paceAvgLongLen = Application.getApp().getProperty("paceAveragingLong");
    	paceDateOneMinute = new DataQueue(paceAvgLongLen);   	
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
