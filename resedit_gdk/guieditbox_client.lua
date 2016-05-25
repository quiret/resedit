-- Optimizations
local math = math;
local dxGetFontHeight = dxGetFontHeight;
local dxGetTextWidth = dxGetTextWidth;
local dxDrawText = dxDrawText;
local dxDrawRectangle = dxDrawRectangle;
local tocolor = tocolor;
local strsub = string.sub;
local ipairs = ipairs;
local pairs = pairs;
local collectgarbage = collectgarbage;

local edits = {};
local function addEvents(elem)
	elem.addEvent("onAccept");
	elem.addEvent("onEditBoxChanged");
end
addEvents(dxRoot);

function createEditBox(parent)
    local edit = createDXElement("edit", parent);
    local text = "";
	local font = "sans";
	local fontScale = 1;
    local cursor = 1;
    local offset = 0;
    local cursorTime = getTickCount();
    local cursorWidth = 0;
	local bgColor;
	local bg_r, bg_g, bg_b;
	local dbgColor;
	local dbg_r, dbg_g, dbg_b;
	local frameColor;
	local frame_r, frame_g, frame_b;
	local textColor;
	local text_r, text_g, text_b;
    
    if not (edit) then return false; end;
	
	-- Add events locally
	addEvents(edit);
	
	function edit.setBackgroundColor(r, g, b)
		bgColor = tocolor(r, g, b, 255);
		
		bg_r, bg_g, bg_b = r, g, b;
		
		update();
		return true;
	end
	
	function edit.resetBackgroundColor()
		setBackgroundColor(0xFF, 0xFF, 0xFF);
	end
	edit.resetBackgroundColor();
	
	function edit.getBackgroundColor()
		return bg_r, bg_g, bg_b;
	end
	
	function edit.setDisabledBackgroundColor(r, g, b)
		dbgColor = tocolor(r, g, b, 255);
		
		dbg_r, dbg_g, dbg_b = r, g, b;
		
		update();
		return true;
	end
	
	function edit.resetDisabledBackgroundColor()
		setDisabledBackgroundColor(0xC0, 0xC0, 0xC0);
	end
	edit.resetDisabledBackgroundColor();
	
	function edit.getDisabledBackgroundColor()
		return dbg_r, dbg_g, dbg_b;
	end
	
	function edit.setFrameColor(r, g, b)
		frameColor = tocolor(r, g, b, 255);
		
		frame_r, frame_g, frame_b = r, g, b;
		
		update();
		return true;
	end
	
	function edit.resetFrameColor()
		setFrameColor(0x20, 0x10, 0x50);
	end
	edit.resetFrameColor();
	
	function edit.getFrameColor()
		return frame_r, frame_g, frame_b;
	end
	
	function edit.setTextColor(r, g, b)
		textColor = tocolor(r, g, b, 255);
		
		text_r, text_g, text_b = r, g, b;
		
		update();
		return true;
	end
	
	function edit.resetTextColor()
		setTextColor(0, 0, 0);
	end
	edit.resetTextColor();
	
	function edit.getTextColor()
		return text_r, text_g, text_b;
	end
    
    function edit.setText(t)
        text = t;
        cursor = #text + 1;
        
		triggerEvent("onEditBoxChanged");
        updateCursor();
        return true;
    end
    
    function edit.getText()
        return text;
    end
	
	function edit.setFont(scale, type)
		if not (type) then
			type = font;
		end
	
		if (scale == fontScale) and (type == font) then return true; end;
		
		fontScale, font = scale, type;
		
		update();
		return true;
	end
	
	function edit.getFont()
		return fontScale, font;
	end
    
    function edit.acceptInput()
        return true;
    end
    
    function edit.getCursorOffset()
        return dxGetTextWidth(strsub(text, 1, cursor), fontScale, font);
    end
    
    function edit.scanCursor()
        local w = getCursorOffset() - offset;
        
        if (w > width - 5) then
            offset = offset + (w - width + 5);
        elseif (w < 0) then
            offset = offset + w;
        end
        
        return true;
    end
    
    function edit.updateCursor()
        cursorWidth = dxGetTextWidth(strsub(text, 1, cursor - 1), fontScale, font);
        
        cursorTime = getTickCount()
        return true;
    end
    
    function edit.keyInput(key, state)
        if (isDisabled()) then return true; end;
        if not (state) then return true; end;
        
        if (key == "backspace") then
            if (cursor == 1) then return true; end;
            
            text = strsub(text, 1, cursor - 2) .. strsub(text, cursor, #text);
            cursor = cursor - 1;
            
			triggerEvent("onEditBoxChanged");
            updateCursor();
        elseif (key == "arrow_l") then
            if (cursor == 1) then return true; end;
            
            cursor = cursor - 1;
            
            updateCursor();
        elseif (key == "arrow_r") then
            if (cursor == #text + 1) then return true; end;
            
            cursor = cursor + 1;
            
            updateCursor();
        elseif (key == "enter") then
            triggerEvent("onAccept");
        end
        
        scanCursor();
        return true;
    end
    
    function edit.input(i)
        if (isDisabled()) then return true; end;
        
        text = strsub(text, 1, cursor - 1) .. i .. strsub(text, cursor, #text);
        cursor = cursor + 1;
        
        cursorTime = getTickCount();
        cursorWidth = cursorWidth + dxGetTextWidth(i, fontScale, font);
		
		triggerEvent("onEditBoxChanged");
        return true;
    end
    
    function edit.mouseclick(button, state, x, y)
        if (isDisabled()) then return true; end;
        if not (button == "left") or not (state) then return true; end;
        
        cursor, cursorWidth = getTextLogicalOffset(text, x + offset - 2, fontScale, font);
        
        cursorTime = getTickCount();
        return true;
    end
    
    function edit.render()
        super();
        
        local now = getTickCount();
        
        local _bgColor;
	
        if (isDisabled()) then
            _bgColor = dbgColor;
        else
            _bgColor = bgColor;
        end
        
        dxDrawRectangle(0, 0, width, height, frameColor);
        dxDrawRectangle(1, 1, width - 2, height - 2, _bgColor);
        dxDrawText(text, 2 - offset, 2, width, height, textColor, fontScale, font, "left", "top", true);
        
        if not (isDisabled()) and (isActive()) and (math.floor(((now - cursorTime) / 667) % 2) == 0) then
            local width = cursorWidth - offset;
            dxDrawLine(width + 2, 3, width + 2, height - 3, textColor);
        end
        
        update();
        return true;
    end
    
    function edit.destroy()
        edits[edit] = nil;
    end
    
    edits[edit] = true;
    return edit;
end

function isEditBox(element)
    return not (edits[element] == nil);
end