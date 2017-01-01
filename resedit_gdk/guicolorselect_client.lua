-- Optimizations
local dxGetFontHeight = dxGetFontHeight;
local dxGetTextWidth = dxGetTextWidth;
local dxDrawText = dxDrawText;
local dxDrawRectangle = dxDrawRectangle;
local tocolor = tocolor;
local strlen = string.len;
local ipairs = ipairs;
local pairs = pairs;
local math = math;
local abs = math.abs;
local floor = math.floor;

dxRoot.addEvent("onColorSelect");
local selects = {};

function createColorSelect(parent)
	local window = createWindow(parent);
	
	if not (window) then
		return false;
	end
	
	-- Add event locally
	window.addEvent("onColorSelect");
	
	local root = window.getRoot();
	window.setRootSize(180, 260);
	window.setText("Color Selection");

	function window.getType()
		return "colorSelect";
	end
	
	local tabPanel = createTabPanel(root);
	tabPanel.setPosition(10, 10);
	tabPanel.setSize(160, 160);
	
	function window.getHUETabPanel()
		return tabPanel;
	end
	
	local circleTab = tabPanel.addTab();
	circleTab.setText("Circle");
	
	local redEdit = createEditBox(root);
	redEdit.setSize(40, 20);
	redEdit.setPosition(20, 205);

	local greenEdit = createEditBox(root);
	greenEdit.setSize(40, 20);
	greenEdit.setPosition(65, 205);
	
	local blueEdit = createEditBox(root);
	blueEdit.setSize(40, 20);
	blueEdit.setPosition(110, 205);
	
	function window.getColorEditBoxes()
		return redEdit, greenEdit, blueEdit;
	end

	local function updateColor(r, g, b)
		window.triggerEvent("onColorSelect", r, g, b);
		
		redEdit.setText(tostring(r));
		greenEdit.setText(tostring(g));
		blueEdit.setText(tostring(b));
	end
	
	local curObject;
	local white = tocolor(255, 255, 255, 255);
	
	do
		local circlefx = gdkCreateShader("colorcircle.fx");
		
		if not (circlefx) then return false; end;
	
		local circle = createDXElement("circlerender", circleTab);
		circle.setSize(circleTab.width - 20, circleTab.height - 20);
		circle.setPosition(10, 10);
		circle.supportAlpha(true);
		
		local drag = false;
		local brightness = 1;
		local cx, cy = circle.width /2, circle.height / 2;
		local circleMiddle = createVector2D(0.5, 0.5);
		
		local function HUEtoRGB(H)
			local vec = createVector(
				abs(H * 6 - 3) - 1,
				2 - abs(H * 6 - 2),
				2 - abs(H * 6 - 4)
			);
			
			vec:saturate(0, 1);
			return vec;
		end
		
		local function _colorProt(x, y)
			local vec = createVector2D(x, y);
			vec[1] = vec[1] / circle.width;
			vec[2] = vec[2] / circle.height;
			
			local off = circleMiddle:clone();
			off:subtract(vec);
			
			local len = off:getLength();
			
			if (len > 0.5) then
				off:normalize();
				off:multiply(0.5);
				return false, off, 0.5;
			end
			
			return true, off, len;
		end
		
		local function isSelectable(x, y)
			local sel, off = _colorProt(x, y);
			
			off:multiply(-1);
			off:add(circleMiddle);
			off[1] = off[1] * circle.width;
			off[2] = off[2] * circle.height;
			return sel, off;
		end
		
		local function getColorFromOffset(x, y)
			local _, off, len = _colorProt(x, y);
			local angle = math.atan2(off[2], off[1]) / math.pi / 2;
			
			if (angle < 0) then
				angle = angle + 1;
			end
			
			local bvec = createVector(brightness, brightness, brightness);
			local huevec = HUEtoRGB(angle);
			huevec:multiply(len * 2 * brightness);
			bvec:subtract(huevec);
			
			return floor(bvec[1] * 255), floor(bvec[2] * 255), floor(bvec[3] * 255);
		end
		
		function circle.isDragging()
			return drag;
		end
		
		function circle.render()
			dxDrawImage(0, 0, width, height, circlefx);
			
			-- Render the selection marker
			dxDrawRectangle(cx - 2, cy - 2, 5, 5, tocolor(0x00, 0x00, 0x00, 0xFF));
			dxDrawRectangle(cx - 1, cy - 1, 3, 3, white);
			return super();
		end
		
		function circle.setBrightness(val)
			brightness = val;
			
			dxSetShaderValue(circlefx, "brightness", val);
			
			updateColor(getColorFromOffset(cx, cy));
			
			update();
			return true;
		end
		
		function circle.getBrightness()
			return brightness;
		end
		
		function circle.selectColor(brightness, vec)
			local low = vec:min();
			local delta = brightness - low;
			
			if (delta == 0) then
				cx, cy = circle.width / 2, circle.height / 2;
			else
				local hdelta = delta / 2;
				local saturation = delta / brightness;
				local hue;
				
				local deltar = ( ( ( brightness - vec[1] ) / 6 ) + hdelta ) / brightness;
				local deltag = ( ( ( brightness - vec[2] ) / 6 ) + hdelta ) / brightness;
				local deltab = ( ( ( brightness - vec[3] ) / 6 ) + hdelta ) / brightness;
				
				if (vec[1] == brightness) then
					hue = deltab - deltag;
				elseif (vec[2] ==brightness) then
					hue = 0.3333333333 + deltar - deltab;
				elseif (vec[3] == brightness) then
					hue = 0.6666666667 + deltag - deltar;
				end
				
				if (hue < 0) then
					hue = hue + 1;
				elseif (hue > 1) then
					hue = hue - 1;
				end
				
				local angle = hue * math.pi * 2;
				
				cx, cy =
					(math.cos(angle) * saturation * 0.5 + 0.5) * circle.width,
					(math.sin(angle) * saturation * 0.5 + 0.5) * circle.height;
			end
			
			update();
		end
		
		function window.getColor(x, y)
			return getColorFromOffset(x, y);
		end
		
		function circle.mouseclick(button, state, x, y)
			if not (button == "left") then return false; end;
			
			local inRange, off = isSelectable(x, y);
			
			if (state) then
				if not (inRange) then return false; end;
			elseif not (drag) then
				return false;
			end
			
			drag = state;
			
			cx, cy = off[1], off[2];
			
			updateColor(getColorFromOffset(cx, cy));
			
			update();
		end
		
		function circle.mousemove(x, y)
			if not (drag) then return false; end;
			
			local _, off = isSelectable(x, y);
			
			cx, cy = off[1], off[2];
			
			updateColor(getColorFromOffset(cx, cy));
			
			update();
		end
		
		function circle.destroy()
			destroyElement(circlefx);
		end
		
		curObject = circle;
	end
	
	--local hueTab = tabPanel.addTab();
	--hueTab.setText("HUE");
	
	local brightSlider = createHorizontalScrollbar(root);
	brightSlider.setSize(160, 10);
	brightSlider.setPosition(10, 190);
	
	function window.setSelectedColor(r, g, b)
		local vec = createVector(r, g, b);
		vec:divide(255);
		local brightness = vec:max();
	
		curObject.selectColor(brightness, vec);
		brightSlider.setSliderPosition(brightness);
	
		updateColor(r, g, b);
		return true;
	end
    
    local function adjustColorByInput()
        local redValue = tonumber(redEdit.getText());
        local greenValue = tonumber(greenEdit.getText());
        local blueValue = tonumber(blueEdit.getText());
        
        if not (redValue) or not (greenValue) or not (blueValue) then return; end;
        
        window.setSelectedColor(redValue, greenValue, blueValue);
    end
    
    function redEdit.events.onAccept()
        adjustColorByInput();
    end
    
    function greenEdit.events.onAccept()
        adjustColorByInput();
    end
    
    function blueEdit.events.onAccept()
        adjustColorByInput();
    end
	
	function root.render()
		dxDrawText("Brightness " .. math.floor(255 * brightSlider.getSliderPosition()), 10, 175, 0, 0, white, 1, "arial");
		return super();
	end
	
	local closeButton = createButton(root);
	closeButton.setSize(100, 20);
	closeButton.setPosition(40, 230);
	closeButton.setText("Close");
	
	function window.getCloseButton()
		return closeButton;
	end
	
	function closeButton.events.onPress()
		window.destroy();
	end
	
	function brightSlider.events.onScroll(brightness)
		curObject.setBrightness(brightness);
	end
	
	brightSlider.setSliderPosition(1);
	
	function window.destroy()
		selects[window] = nil;
	end
	
	selects[window] = true;
	return window;
end

function isColorSelect(element)
	return not (selects[element] == nil);
end