-- Optimizations
local dxGetFontHeight = dxGetFontHeight;
local dxGetTextWidth = dxGetTextWidth;
local dxDrawText = dxDrawText;
local dxDrawRectangle = dxDrawRectangle;
local tocolor = tocolor;
local strlen = string.len;
local ipairs = ipairs;
local pairs = pairs;

local dropDowns = {};

-- Set up events
local function addEvents(elem)
	elem.addEvent("onDropDownAddItem");
	elem.addEvent("onDropDownHighlight");
	elem.addEvent("onDropDownSelect");
	elem.addEvent("onDropDownRemoveItem");
end
addEvents(dxRoot);
local arrowTexture = gdkLoadTexture("arrow.png");

function createDropDown(parent)
	local dropDown = createDXElement("dropDown", parent);
	
	if not (dropDown) then return false; end;
	
	local items = {};
	local textWidth = 0;
	local descriptionWidth = 0;
	local fontHeight;
	local currentSelection = false;
	local subDropDown = false;
	local subId = false;
	local selectionTime = 0;
	local numSubList = 0;
	local numDescription = 0;
	local charScale = 1;
	local charFont = "default";
	local selecting = false;
	local bgColor;
	local bg_r, bg_g, bg_b;
	local textColor;
	local text_r, text_g, text_b;
	local selectionColor;
	local select_r, select_g, select_b;
	
	-- Add events locally
	addEvents(dropDown);
	
	-- Make sure we stay on top
	dropDown.setOutbreakMode(true);
	
	fontHeight = dxGetFontHeight(charScale, charFont);
	
	function dropDown.setBackgroundColor(r, g, b)
		bgColor = tocolor(r, g, b, 255);
		
		bg_r, bg_g, bg_b = r, g, b;
		
		update();
		return true;
	end
	
	function dropDown.resetBackgroundColor()
		setBackgroundColor(0, 0, 0);
	end
	dropDown.resetBackgroundColor();
	
	function dropDown.getBackgroundColor()
		return bg_r, bg_g, bg_b;
	end
	
	function dropDown.setTextColor(r, g, b)
		textColor = tocolor(r, g, b, 255);
		
		text_r, text_g, text_b = r, g, b;
		
		update();
		return true;
	end
	
	function dropDown.resetTextColor()
		setTextColor(0xFF, 0xFF, 0xFF);
	end
	dropDown.resetTextColor();
	
	function dropDown.getTextColor()
		return text_r, text_g, text_b;
	end
	
	function dropDown.setSelectionColor(r, g, b)
		selectionColor = tocolor(r, g, b, 255);
		
		select_r, select_g, select_b = r, g, b;
		
		update();
		return true;
	end
	
	function dropDown.resetSelectionColor()
		setSelectionColor(20, 180, 50);
	end
	dropDown.resetSelectionColor();
	
	function dropDown.getSelectionColor()
		return select_r, select_g, select_b;
	end
	
	local function reorganize()
		local m,n;
		
		for m,n in ipairs(items) do
			if (n.type == "sublist") then
				n.menu.setPosition(dropDown.width, n.offset);
			end
		end
		
		dropDown.update();
		return true;
	end
	
	local function calculateWidth()
		local width = 40 + textWidth;
		
		if not (descriptionWidth == 0) then
			width = width + descriptionWidth + 10;
		end
		
		if not (numSubList == 0) then
			width = width + 20;
		end
		
		dropDown.setSize(width, dropDown.height);
		return true;
	end
	
	local function calculateTextWidth()
		local m,n;
		
		textWidth = 0;
		
		for m,n in ipairs(items) do
			if (n.type == "item") or (n.type == "sublist") then
				if (textWidth < n.output.width) then
					textWidth = n.output.width;
				end
			end
		end
		
		calculateWidth();
		return true;
	end
	
	local function calculateDescriptionWidth()
		local m,n;
		
		descriptionWidth = 0;
		
		for m,n in ipairs(items) do
			if (n.type == "item") or (n.type == "sublist") then
				if (descriptionWidth < n.description.width) then
					descriptionWidth = n.description.width;
				end
			end
		end
		
		calculateWidth();
		return true;
	end
	
	local function calculateOutput()
		local m,n;
		local screenW, screenH = guiGetScreenSize();
		
		for m,n in ipairs(items) do
			if (n.type == "item") or (n.type == "sublist") then
				n.output = structureString(n.text, screenW, screenW, charScale, charFont);
				
				if (n.description) then
					n.description = structureString(n.descText, screenW, screenW, charScale, charFont);
				end
			end
		end
		
		calculateTextWidth();
		return true;
	end
	
	function dropDown.setPosition(posX, posY)
		super(posX, posY);
		
		calculateOutput();
		return true;
	end
	
	function dropDown.setSize(w, h)
		super(w, h);
		
		reorganize();
		return true;
	end
	
	local function createItem(type, offset, handler)
		local item = createClass({
			type = type,
			offset = offset,
			handler = handler
		},
		{
			readjust = true
		});
		local r, g, b;
		
		function item.setColor(_r, _g, _b)
			r, g, b = _r, _g, _b;
			return true;
		end
		
		function item.getColor()
			if not (r) then
				return dropDown.getTextColor();
			end
			
			return r, g, b;
		end
		
		function item.readjust(id)
			return;
		end
		
		function item.orderHeightUpdate(id, offset)
			for m=id,#items do
				items[m].offset = items[m].offset + offset;
			end
			
			dropDown.setSize(dropDown.width, dropDown.height + offset);
		end
		
		function item.destroy()
            local tabitem = table.delete(items, item);
        
			readjust(tabitem);
		end
		
		table.insert(items, item);
		return item;
	end
	
	function dropDown.addItem(text, handler)
		if not (text) then return false; end;
		
		if not (triggerEvent("onDropDownAddItem", "item", text)) then return false; end;
		
		local screenW, screenH = guiGetScreenSize();
	
		local item = createItem("item", height, handler);
		item.text = text;
		item.output = structureString(text, screenW, screenW, charScale, charFont);
		
		function item.readjust(id)
			orderHeightUpdate(id, -item.output.height - 4);
		end
		
		-- Update the width
		if (textWidth < item.output.width) then
			textWidth = item.output.width;
			
			calculateWidth();
		end
		
		setSize(width, height + item.output.height + 4);
		return #items;
	end
	
	function dropDown.addSubList(text)
		if not (text) then return false; end;
		
		local screenW, screenH = guiGetScreenSize();
		local sub = createDropDown(dropDown);
		
		if not (triggerEvent("onDropDownAddItem", "submenu", text, sub)) then
			sub.destroy();
			return false;
		end
		
		-- Cache the dropDown
		sub.setVisible(false);
		
		sub.addEventHandler("onDropDownAddItem", function(type, text, menu)
				if not (type == "submenu") then return true; end;
				
				menu.addEventHandler("onHide", function()
						if (selecting) or not (visible) then return true; end;
						
						return not isMouseActive();
					end, false
				);
			end
		);
		
		sub.addEventHandler("onHide", function()
				if (selecting) or not (visible) then return true; end;
		
				if (isMouseActive()) then return false; end;
				
				subDropDown = false;
				subId = false;
		
				setVisible(false);
			end, false
		);
		
		local item = createItem("sublist", height);
		item.text = text;
		item.output = structureString(text, screenW - x, screenW - x, charScale, charFont);
		item.menu = sub;
		
		function item.readjust(id)
			orderHeightUpdate(id, -output.height - 4);
		end
		
		function item.destroy()
			-- Destroy the menu
			menu.destroy();
			
			numSubList = numSubList - 1;
		end

		-- Update the width
		if (textWidth < item.output.width) then
			textWidth = item.output.width;
			
			calculateWidth();
		end
		
		setSize(width, height + item.output.height + 4);
		
		numSubList = numSubList + 1;
		return sub, #items;
	end
	
	function dropDown.addBreak()
		if not (triggerEvent("onDropDownAddItem", "break")) then return false; end;
	
		local item = createItem("break", height);
		
		function item.readjust()
			dropDown.setSize(dropDown.width, dropDown.height - 5);
		end
		
		setSize(width, height + 5);
		return #items;
	end
	
	function dropDown.setItemText(id, text)
		reorganize();
		return true;
	end
	
	function dropDown.getItemText(id)
		if (id < 1) or (id > #items) then return false; end;
		
		return items[id].text;
	end
	
	function dropDown.setItemDescription(id, text)
		if (id < 1) or (id > #items) then return false; end;
		
		local screenW, screenH = guiGetScreenSize();
		local descOffset = textWidth + 30;
		
		items[id].description = structureString(text, screenW - descOffset, screenW - descOffset, charScale, charFont);
		
		calculateDescriptionWidth();
		return true;
	end
	
	function dropDown.getItemDescription(id)
		if (id < 1) or (id > #items) then return false; end;
		
		return items[id].description;
	end
	
	function dropDown.setItemColor(id, r, g, b)
		if (id < 1) or (id > #items) then return false; end;
		
		items[id].setColor(r, g, b);
		
		update();
		return true;
	end
	
	function dropDown.getItemColor(id)
		if (id < 1) or (id > #items) then return false; end;
		
		return items[id].getColor();
	end
	
	function dropDown.setItemHandler(id, handler)
		if (id < 1) or (id > #items) then return false; end;
		
		items[id].handler = handler;
		return true;
	end
	
	function dropDown.getNumItems()
		return #items;
	end
	
	function dropDown.removeItem(id)
		if (id < 1) or (id > #items) then return false; end;
		
		items[id].destroy();
	
		if (currentSelection) then
			local icount = #items;
		
			if (icount == 0) then
				currentSelection = false;
			elseif (icount < currentSelection) then
				currentSelection = icount;
			end
		end
		
		calculateTextWidth();
		
		reorganize();
		return true;
	end
	
	function dropDown.clear()
		while not (#items == 0) do
			dropDown.removeItem(1);
		end
		
		textWidth = 0;
		descriptionWidth = 0;
		
		calculateWidth();
		return true;
	end
	
	function dropDown.setVisible(show)
		if (show) and (#items == 0) then return false; end;
	
		if not (super(show)) then return false; end;

		if not (show) then
			if (subDropDown) then
				subDropDown.setVisible(false);
				
				subDropDown = false;
				subId = false;
			end
			
			currentSelection = false;
			return true;
		end

		moveToFront();
		return true;
	end
	
	function dropDown.preRender()
		if (#items == 0) then return false; end;
	
		if (currentSelection) then
			local item = items[currentSelection];
			
			selecting = true;
			
			if not (currentSelection == subId) and (getTickCount() - selectionTime > 500) then
				if (subDropDown) then
					subDropDown.setVisible(false);
				end
			
				if (item.type == "sublist") then
					subDropDown = item.menu;
					subId = currentSelection;
					
					if not (subDropDown.setVisible(true)) then
						subDropDown = false;
						subId = false;
						
						giveFocus();
					end
					
					update();
				else
					subDropDown = false;
					subId = false;
					
					giveFocus();
				end
			end
			
			selecting = false;
		end
		
		return super();
	end
		
	function dropDown.render()
		local m,n;
	
		dxDrawRectangle(0, 0, width, height, tocolor(50, 50, 50, 255));
		dxDrawRectangle(1, 1, width - 2, height - 2, bgColor);
		
		for m,n in ipairs(items) do
			if (n.type == "item") or (n.type == "sublist") then
				local j,k;
				local y = 0;
				local textColor;
				local descriptionColor;
				local r, g, b = n.getColor();
				
				if (m == currentSelection) or not (currentSelection) and (m == subId) then
					if (m == 1) then
						dxDrawRectangle(2, n.offset + 2, width - 4, n.output.height + 2, selectionColor);
					elseif (m == #items) then
						dxDrawRectangle(2, n.offset, width - 4, n.output.height + 2, selectionColor);
					else
						dxDrawRectangle(2, n.offset, width - 4, n.output.height + 4, selectionColor);
					end
					
					textColor = tocolor(r, g, b, 255);
					descriptionColor = tocolor(255, 255, 255, 255);
				else
					textColor = tocolor(math.max(0, r - 55), math.max(0, g - 55), math.max(0, b - 55), 255);
					descriptionColor = tocolor(200, 200, 200, 255);
				end
				
				for j,k in ipairs(n.output.lines) do
					dxDrawText(k, 20, n.offset + y + 2, 0, 0, textColor);
					
					y = y + fontHeight;
				end
				
				if (n.description) then
					y = 0;
				
					for j,k in ipairs(n.description.lines) do
						dxDrawText(k, 20 + textWidth + 10, n.offset + y + 2, 0, 0, descriptionColor);
						
						y = y + fontHeight;
					end
				end
				
				if (n.type == "sublist") and (arrowTexture) then
					dxDrawImage(width - 15, n.offset + (n.output.height - 2) / 2, 6, 6, arrowTexture, 0, 0, 0, descriptionColor);
				end
			elseif (n.type == "break") then
				dxDrawRectangle(1, n.offset + 1, width - 2, 1, bgColor);
				dxDrawRectangle(1, n.offset + 2, width - 2, 1, textColor);
			end
		end
		
		return super();
	end
	
	local function getItemAtOffset(off)
		local m,n;
		
		for m,n in ipairs(items) do
			if (n.type == "item") or (n.type == "sublist") then
				if (n.output.height + n.offset >= off) then
					return m;
				end
			elseif (n.type == "break") then
				if (n.offset + 4 >= off) then
					return m;
				end
			end
		end
	
		return false;
	end
	
	function dropDown.events.onFocus()
		return (subDropDown == false);
	end
	
	function dropDown.blur()
		if (selecting) then return true; end;
		
		if (subDropDown) then
			subDropDown.setVisible(false);
			
			subDropDown = false;
			subId = false;
		end
		
		setVisible(false);
		return true;
	end
	
	function dropDown.mouseclick(button, state, offX, offY)
		if not (button == "left") or not (state) then return true; end;
		
		local id = getItemAtOffset(offY);
		
		if not (id) then return false; end;
		
		if not (triggerEvent("onDropDownSelect", id)) then return false; end;
		
		local item = items[id];
		
		if (item.handler) then
			setVisible(false);
		
			return item.handler();
		elseif (item.type == "sublist") then
			selectionTime = 0;
		end
		
		return true;
	end
	
	function dropDown.mouseleave()
		update();
	
		if (subDropDown) then
			currentSelection = subId;
			return true;
		end
		
		currentSelection = false;
		return true;
	end
	
	function dropDown.mousemove(offX, offY)
		local id = getItemAtOffset(offY);
		
		if not (id == currentSelection) then
			currentSelection = id;
			
			selectionTime = getTickCount();
			
			update();
		end
		
		return true;
	end
	
	function dropDown.destroy()
		dropDowns[dropDown] = nil;
		return true;
	end

	dropDowns[dropDown] = dropDown;
	return dropDown;
end

function isDropDown(element)
	return not (dropDowns[element] == nil);
end