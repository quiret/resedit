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
local max = math.max;

local buttons = {};

-- Register the events
local function addEvents(elem)
    elem.addEvent("onPress");
end
addEvents(dxRoot);

function createButton(parent)
    local button = createDXElement("button", parent);
    local hover = false;
    local press = false;
    local text = "";
	local bgColor;
	local bg_r, bg_g, bg_b;
	local downBgColor;
	local dbgColor;
	local dbg_r, dbg_g, dbg_b;
	local textColor;
	local text_r, text_b, text_g;
	local dtextColor;
	local dtext_r, dtext_b, dtext_g;
	local hoverColor;
	local hover_r, hover_g, hover_b;
    
    if not (button) then return false; end;
	
	-- Add event locally
	addEvents(button);
	
	function button.setBackgroundColor(r, g, b)
		bgColor = tocolor(r, g, b, 255);
		downBgColor = tocolor(max(r - 0x10, 0), max(g - 0x10, 0), max(b - 0x10, 0), 255);
		
		bg_r, bg_g, bg_b = r, g, b;
		
		update();
		return true;
	end
	
	function button.resetBackgroundColor()
		setBackgroundColor(0x30, 0x50, 0xA0);
	end
	button.resetBackgroundColor();
	
	function button.getBackgroundColor()
		return bg_r, bg_g, bg_b;
	end
	
	function button.setDisabledBackgroundColor(r, g, b)
		dbgColor = tocolor(r, g, b, 255);
		
		dbg_r, dbg_g, dbg_b = r, g, b;
		
		update();
		return true;
	end
	
	function button.resetDisabledBackgroundColor()
		setDisabledBackgroundColor(0x90, 0x90, 0x90);
	end
	button.resetDisabledBackgroundColor();
	
	function button.getDisabledBackgroundColor()
		return dbg_r, dbg_g, dbg_b;
	end
	
	function button.setTextColor(r, g, b)
		textColor = tocolor(r, g, b, 255);
		
		text_r, text_g, text_b = r, g, b;
		
		update();
		return true;
	end
	
	function button.resetTextColor()
		setTextColor(0xFF, 0xFF, 0xFF);
	end
	button.resetTextColor();
	
	function button.getTextColor()
		return text_r, text_g, text_b;
	end
	
	function button.setDisabledTextColor(r, g, b)
		dtextColor = tocolor(r, g, b, 255);
		
		dtext_r, dtext_g, dtext_b = r, g, b;
		
		update();
		return true;
	end
	
	function button.resetDisabledTextColor()
		setDisabledTextColor(0x20, 0x20, 0x20);
	end
	button.resetDisabledTextColor();
	
	function button.getDisabledTextColor()
		return dtext_r, dtext_g, dtext_b;
	end
	
	function button.setHoverColor(r, g, b)
		hoverColor = tocolor(r, g, b, 0x20);
		
		hover_r, hover_g, hover_b = r, g, b;
		
		update();
		return true;
	end
	
	function button.resetHoverColor()
		setHoverColor(0xA0, 0xA0, 0xA0);
	end
	button.resetHoverColor();
	
	function button.getHoverColor()
		return hover_r, hover_g, hover_b;
	end
    
    function button.mouseenter()
        update();
        
        hover = true;
        return true;
    end
    
    function button.mouseleave()
        update();
        
        hover = false;
        press = false;
        return true;
    end
    
    function button.blur()
        press = false;
        
        update();
        return true;
    end
	
	function button.enable()
		update();
	end
	
	function button.disable()
		press = false;
	
		update();
	end
    
    function button.keyInput(key, state)
		if (isDisabled()) then return true; end;
	
        if (key == "enter") then
            if not (state) then return true; end;
            
            triggerEvent("onPress");
        elseif (isMouseActive()) then
			if (key == "mouse1") then
				press = state;
				
				update();
			end
        end
        
        return true;
    end
    
    function button.mouseclick(button, state)
		if (isDisabled()) then return true; end;
        if not (button == "left") or (state) then return true; end;
        if not (press) then return true; end;
        
        triggerEvent("onPress");
        return true;
    end
    
    function button.setText(msg)
        text = msg;
        return true;
    end
    
    function button.getText()
        return text;
    end
    
    function button.getTextArea()
        if (press) then
            return 3, 3, width - 7, height - 5;
        end
        
        return 2, 2, width - 3, height - 3;
    end
    
    function button.drawDefault()
        local tx, ty, tw, th = getTextArea();
        
        dxDrawRectangle(0, 0, width, height, tocolor(0xC0, 0xC0, 0xC0, 0xFF));
        dxDrawRectangle(1, 1, width - 1, height - 1, tocolor(0x40, 0x40, 0x40, 0xFF));
        dxDrawRectangle(tx, ty, tw, th, bgColor);
    end
    
    function button.render()
        super();
        
        local tx, ty, tw, th = getTextArea();
		local _textColor;
        
		if (isDisabled()) then
			dxDrawRectangle(0, 0, width, height, tocolor(0xC0, 0xC0, 0xC0, 0xFF));
			dxDrawRectangle(1, 1, width - 1, height - 1, dbgColor);
			
			_textColor = dtextColor;
		else
			if (hover) then
				if (press) then
					dxDrawRectangle(0, 0, width, height, tocolor(0x40, 0x40, 0x40, 0xFF));
					dxDrawRectangle(1, 1, width - 1, height - 1, tocolor(0x10, 0x10, 0x10, 0xFF));
					dxDrawRectangle(1, 2, width, height - 1, tocolor(0x15, 0x15, 0x15, 0xFF));
					dxDrawRectangle(3, 3, width - 4, height - 4, downBgColor);
				else
					drawDefault();
					dxDrawRectangle(tx, ty, tw, th, hoverColor);
				end
			else
				drawDefault();
			end
			
			_textColor = textColor;
        end
        
        dxDrawText(text, tx, ty, tx + tw, ty + th, _textColor, 1, "sans", "center", "center", true, true)
        return true;
    end
    
    function button.destroy()
        buttons[button] = nil;
    end
    
    buttons[button] = true;
    return button;
end

function isButton(element)
    return not (buttons[element] == nil);
end