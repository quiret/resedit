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

-- Set up events
local function addEvents(elem)
	elem.addEvent("onMenuHighlight");
	elem.addEvent("onMenuSelect");
end
addEvents(dxRoot);
local menus = {};

function createMenu(parent)
	local menu = createDXElement("menu", parent);
	local items = {};
	local offset = 0;
	local activeDropDown = false;
	local currentSelection = false;
	local bgColor;
	local bg_r, bg_g, bg_b;
	local textColor;
	local text_r, text_g, text_b;
	local selectionColor;
	local select_r, select_g, select_b;
	
	if not (menu) then return false; end;
	
	-- Add events locally
	addEvents(menu);
	
	-- Specify the dimensions
	menu.setSize(menu.getScreenSize(), 20);
	
	function menu.setBackgroundColor(r, g, b)
		bgColor = tocolor(r, g, b, 255);
		
		bg_r, bg_g, bg_b = r, g, b;
		
		update();
		return true;
	end
	
	function menu.resetBackgroundColor()
		setBackgroundColor(45, 45, 45);
	end
	menu.resetBackgroundColor();
	
	function menu.getBackgroundColor()
		return bg_r, bg_g, bg_b;
	end
	
	function menu.setTextColor(r, g, b)
		textColor = tocolor(r, g, b, 255);
		
		text_r, text_g, text_b = r, g, b;
		
		update();
		return true;
	end
	
	function menu.resetTextColor()
		setTextColor(0xFF, 0xFF, 0xFF);
	end
	menu.resetTextColor();
	
	function menu.getTextColor()
		return text_r, text_g, text_b;
	end
	
	function menu.setSelectionColor(r, g, b)
		selectionColor = tocolor(r, g, b, 255);
		
		select_r, select_g, select_b = r, g, b;
		
		update();
		return true;
	end
	
	function menu.resetSelectionColor()
		setSelectionColor(80, 200, 40);
	end
	menu.resetSelectionColor();
	
	function menu.getSelectionColor()
		return select_r, select_g, select_b;
	end
	
	local function getItemAtOffset(off)
		local m,n;
		
		if (off >= offset) then
			if (#items == 0) then return false; end;
			
			return #items;
		end
		
		for m,n in ipairs(items) do
			if (off < n.offset + n.width + 10) then
				return m;
			end
		end
		
		return false;
	end
	
	function menu.openDropDown(id)
		if (id < 1) or (id > #items) then return false; end;
		
		activeDropDown = items[id].dropDown;
		
		update();
		
		if not (activeDropDown.setVisible(true)) then
			activeDropDown = false;
			return false;
		end
		
		return true;
	end
	
	function menu.closeDropDown()
		if not (activeDropDown) then return true; end;
		
		activeDropDown.setVisible(false);
		
		activeDropDown = false;
		
		update();
		return true;
	end
	
	function menu.addItem(text)
		local dropDown = createDropDown(menu);
		local width = dxGetTextWidth(text);
	
		table.insert(items, {
			offset = offset,
			width = width,
			text = text,
			dropDown = dropDown
		});
		
		-- Cache the dropDown
		dropDown.setVisible(false);
		dropDown.setPosition(offset, 20);
		
		dropDown.addEventHandler("onHide", function()
				local mouseX, mouseY = getMousePosition();
				local width, height = getSize();
		
				if (mouseX < 0) or (mouseY < 0) or
					(mouseX >= width) or (mouseY >= height) or (mouseX >= offset) then
					currentSelection = false;
				end
		
				activeDropDown = false;
				
				update();
			end, false
		);
		
		offset = offset + width + 10;
		
		update();
		return dropDown, #items;
	end
	
	function menu.removeItem(id)
		if (id < 1) or (id > #items) then return false; end;
		
		offset = offset - dxGetTextWidth(items[id].text) - 10;
		
		table.remove(items, id);
		return true;
	end
	
	function menu.setVisible(show)
		if not (super(show)) then return false; end;
		
		if not (show) then
			if (activeDropDown) then
				activeDropDown.setVisible(false);
				
				activeDropDown = false;
			end
		
			currentSelection = false;
		end
		
		return true;
	end
	
	function menu.render()
		local offset = 0;
		local m,n;
		
		dxDrawRectangle(0, 0, width, height, bgColor);
		
		for m,n in ipairs(items) do
			if (currentSelection == m) then
				dxDrawRectangle(n.offset, 0, n.width + 10, height, selectionColor);
			end
			
			dxDrawText(n.text, n.offset + 5, 3, 0, 0, textColor);
		end
		
		return super();
	end
	
	function menu.isInArea(posX, posY)
		local x, y = getPosition();
	
		return (posX >= x) and (posY >= y) and (posX <= x + width) and (posY <= y + height);
	end
	
	function menu.blur()
		if (activeDropDown) then return true; end;
		
		closeDropDown();
		
		currentSelection = false;
		
		update();
	end
	
	function menu.mouseclick(button, state, offX, offY)
		if not (button == "left") or not (state) then return true; end;
		
		if (offX >= offset) then
			closeDropDown();
		
			currentSelection = false;
			
			update();
			return;
		elseif (activeDropDown) then return; end;
		
		local item = getItemAtOffset(offX);
		
		if not (item) then
			closeDropDown();
			return;
		end
		
		openDropDown(item);
	end
	
	function menu.mouseleave()
		if not (currentSelection) or (activeDropDown) then return true; end; 
		
		currentSelection = false;
		
		update();
	end
	
	function menu.mousemove(offX, offY)	
		local id = getItemAtOffset(offX);
		
		if not (activeDropDown) and (offX >= offset) then
			if (currentSelection) then
				currentSelection = false;
				
				update();
			end
			
			return;
		end
		
		if not (currentSelection == id) then
			currentSelection = id;
		
			if (activeDropDown) then
				local dropDown = items[id].dropDown;
				
				if not (dropDown == activeDropDown) then
					activeDropDown.setVisible(false);
				
					activeDropDown = dropDown;
					activeDropDown.setVisible(true);
				end
			end
			
			update();
		end
	end
	
	function menu.destroy()
		menus[menu] = nil;
	end
	
	menus[menu] = menu;
	return menu;
end

function isMenu(element)
	return not (menus[element] == nil);
end