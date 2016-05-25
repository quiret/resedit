-- Optimizations
local dxGetFontHeight = dxGetFontHeight;
local dxGetTextWidth = dxGetTextWidth;
local dxDrawText = dxDrawText;
local dxDrawRectangle = dxDrawRectangle;
local tocolor = tocolor;
local strlen = string.len;
local ipairs = ipairs;
local pairs = pairs;
local collectgarbage = collectgarbage;

local comboboxes = {};
dxRoot.addEvent("onComboBoxSelect");
local arrow_d = gdkLoadTexture("images/arrow_d.png");

function createComboBox(parent)
    local combo = createDXElement("combobox", parent);
    
    if not (combo) then return false; end;
    
    local selectArea = createDXElement("comboarea", combo);
    selectArea.setOutbreakMode(true);
    selectArea.setVisible(false);
    local font = "sans";
    local fontSize = 1;
    local fontHeight = dxGetFontHeight(fontSize, font);
    local rowHeight = fontHeight + 4;
    local items = {};
    local hover = false;
    local selected = false;
	local bgColor;
	local bg_r, bg_g, bg_b;
	local dbgColor;
	local dbg_r, dbg_g, dbg_b;
	local frameColor;
	local frame_r, frame_g, frame_b;
	local textColor;
	local text_r, text_g, text_b;
	local selectedColor;
	local select_r, select_g, select_b;
	
	-- Add event locally
	combo.addEvent("onComboBoxSelect");
	
	function combo.setBackgroundColor(r, g, b)
		bgColor = tocolor(r, g, b, 255);
		
		bg_r, bg_g, bg_b = r, g, b;
		
		update();
		return true;
	end
	
	function combo.resetBackgroundColor()
		setBackgroundColor(0, 0, 0);
	end
	combo.resetBackgroundColor();
	
	function combo.getBackgroundColor()
		return bg_r, bg_g, bg_b;
	end
	
	function combo.setDisabledBackgroundColor(r, g, b)
		dbgColor = tocolor(r, g, b, 255);
		
		dbg_r, dbg_g, dbg_b = r, g, b;
		
		update();
		return true;
	end
	
	function combo.resetDisabledBackgroundColor()
		setDisabledBackgroundColor(0xC0, 0xC0, 0xC0);
	end
	combo.resetDisabledBackgroundColor();
	
	function combo.getDisabledBackgroundColor()
		return dbg_r, dbg_g, dbg_b;
	end
	
	function combo.setFrameColor(r, g, b)
		frameColor = tocolor(r, g, b, 255);
		
		frame_r, frame_g, frame_b = r, g, b;
		
		update();
		return true;
	end
	
	function combo.resetFrameColor()
		setFrameColor(0x00, 0x40, 0xB0);
	end
	combo.resetFrameColor();
	
	function combo.getFrameColor()
		return frame_r, frame_g, frame_b;
	end
	
	function combo.setTextColor(r, g, b)
		textColor = tocolor(r, g, b, 255);
		
		text_r, text_g, text_b = r, g, b;
		
		selectArea.update();
		return true;
	end
	
	function combo.resetTextColor()
		setTextColor(0xFF, 0xFF, 0xFF);
	end
	combo.resetTextColor();
	
	function combo.getTextColor()
		return text_r, text_g, text_b;
	end
	
	function combo.setSelectedTextColor(r, g, b)
		selectedColor = tocolor(r, g, b, 255);
		
		selected_r, selected_g, selected_b = r, g, b;
		
		selectArea.update();
		return true;
	end
	
	function combo.resetSelectedTextColor()
		setSelectedTextColor(0xFF, 0xFF, 0x00);
	end
	combo.resetSelectedTextColor();
	
	function combo.getSelectedTextColor()
		return selected_r, selected_g, selected_b;
	end
    
    local function recalculateArea()
        return selectArea.setHeight(#items * rowHeight);
    end
    
    function combo.events.onSize(w, h)
		selectArea.setPosition(0, h);
		selectArea.setWidth(w);
    end
    
    function combo.addItem(text)
        table.insert(items, text);
        
        recalculateArea();
        return #items;
    end
    
    function combo.getNumItems()
        return #items;
    end
    
    function combo.getItem(id)
        return items[id];
    end
    
    function combo.removeItem(id)
        if (id < 1) or (id > #items) then return false; end;
        
        if (selected) then
            if (id == selected) then
                selected = false;
            elseif (id < selected) then
                selected = selected - 1;
            end
        end
        
        table.remove(items, id);
        
        if (#items == 0) then
            selectArea.setVisible(false);
        else
            recalculateArea();
        end
        
        return true;
    end
    
    function combo.clear()
        selected = false;
        hover = false;
        items = {};
        
        selectArea.setVisible(false);
        return true;
    end
    
    function combo.setFont(f)
        if (font == f) then return true; end;
        
        font = f;
        
        fontHeight = dxGetFontHeight(fontSize, font);
        rowHeight = fontHeight + 4;
        
        recalculateArea();
        return true;
    end
    
    function combo.setFontSize(s)
        fontSize = s;
        
        fontHeight = dxGetFontHeight(fontSize, font);
        rowHeight = fontHeight + 4;
        
        recalculateArea();
        return true;
    end
    
    function combo.getFont()
        return fontSize, font;
    end
    
    function combo.getSelectArea()
        return selectArea;
    end
    
    function combo.setSelected(id)
        if (id < 1) or (id > #items) then return false; end;
        if not (triggerEvent("onComboBoxSelect", id)) then return false; end;
        
        selected = id;
        
        update();
        return true;
    end
    
    function combo.selectItem(t)
        local m,n;
        
        update();
        
        for m,n in ipairs(items) do
            if (n == t) then
                selected = m;
                return true;
            end
        end
        
        selected = false;
        return false;
    end
    
    function combo.getSelected()
        return selected;
    end
    
    function combo.getItemAtOffset(x, y)
        return math.floor(y / rowHeight) + 1;
    end
    
    function combo.mouseclick(button, state)
        if not (button == "left") or not (state) then return true; end;
        if (#items == 0) then return true; end;
		
        if not (selectArea.visible) then
            selectArea.setVisible(true);
            
            selectArea.moveToFront();
            return true;
        end
		
        selectArea.setVisible(false);
        return true;
    end
    
    function selectArea.blur()
		if (combo.isMouseActive()) then return; end;
	
        hover = false;
        
        setVisible(false);
    end
    
    function combo.render()
        local notiSize = height - 2;
        local notiOffset = width - notiSize - 1;
        
        dxDrawRectangle(0, 0, width, height, frameColor);
        dxDrawRectangle(1, 1, width - 2, height - 2, bgColor);
        
        if (selected) then
            dxDrawText(items[selected], 2, 2, notiOffset - 1, height - 2, textColor, fontSize, font, "left", "top", true);
        end
        
        dxDrawRectangle(notiOffset, 1, notiSize, notiSize, tocolor(0x00, 0x15, 0x28, 0xFF));
        dxDrawRectangle(notiOffset + 1, 2, notiSize - 2, notiSize - 2, tocolor(0x00, 0x30, 0x60, 0xFF));
        dxDrawImage(notiOffset + 4, 5, notiSize - 8, notiSize - 8, arrow_d);
        return super();
    end
    
    function selectArea.mousemove(x, y)
        local id = combo.getItemAtOffset(x, y);
        
        if not (id) or (hover == id) then return true; end;
        
        hover = id;
        
        update();
        return true;
    end
    
    function selectArea.mouseclick(button, state, x, y)
        if not (button == "left") or not (state) then return true; end;
        
        combo.setSelected(combo.getItemAtOffset(x, y));
        
        setVisible(false);
        return true;
    end
    
    function selectArea.mouseleave()
        hover = false;
        
        update();
    end
    
    function selectArea.render()
        local row1color = tocolor(0x00, 0x10, 0x30, 0xFF);
        local row2color = tocolor(0x00, 0x06, 0x15, 0xFF);
        local m,n;
        local y = 2;
        
        for m,n in ipairs(items) do
            local color;
            
            -- Draw background
            if (m % 2 == 0) then
                color = row1color;
            else
                color = row2color;
            end
            
            dxDrawRectangle(0, y - 2, width, rowHeight, color);
            
            -- Draw text
            if (hover == m) then
                color = selectedColor;
            else
                color = textColor;
            end
            
            dxDrawText(n, 5, y, 0, 0, color, fontSize, font);
            
            y = y + rowHeight;
        end
        
        return super();
    end
    
    function combo.destroy()
        comboboxes[combo] = nil;
    end
    
    comboboxes[combo] = true;
    return combo;
end

function isComboBox(element)
    return not (comboBoxes[element] == nil);
end