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

local tabpanels = {};
local function addEvents(elem)
	elem.addEvent("onTabSelect");
end
addEvents(dxRoot);

function createTabPanel(parent)
    local tabpanel = createDXElement("tabpanel", parent);
    
    if not (tabpanel) then return false; end;
    
    local tabs = {};
    local selected = false;
	local selectedTab = false;
    local font = "sans";
    local fontSize = 1;
    local fontHeight = dxGetFontHeight(fontSize, font);
    local tabHeight = fontHeight + 4;
	local bgColor;
	local bg_r, bg_g, bg_b;
	local active_r, active_g, active_b;
	local activeTextColor;
	local deactive_r, deactive_g, deactive_b;
	local deactiveTextColor;
	
	-- Add events locally
	addEvents(tabpanel);
    
    tabpanel.supportAlpha(true);
	
	local function _selectTabID(id)
        if (selectedTab) then
            selectedTab.setVisible(false);
        end
	
        selected = id;
		selectedTab = tabs[id];
        
        selectedTab.setVisible(true);
        
        tabpanel.triggerEvent("onTabSelect", id);
	end
	
	local function _getTabID(tab)
		local n = 1;
		
		while (n <= #tabs) do
			if (tabs[n] == tab) then
				return n;
			end
			
			n = n + 1;
		end
		
		return false;
	end
	
	local function _selectTab(tab)
		_selectTabID(_getTabID(tab));
	end
    
    function tabpanel.addTab()
        local tab = createDXElement("tab", tabpanel);
        local title = "";
        local width = 10;
        
        if not (selected) then
            selected = 1;
			selectedTab = tab;
        else
            tab.setVisible(false);
        end
        
        -- Prepare the element
        tab.setPosition(1, tabHeight + 1);
        tab.setSize(tabpanel.width - 2, height - tabHeight - 2);
        tab.supportAlpha(true);
        
        function tab.recalculateWidth()
            width = dxGetTextWidth(title, fontSize, font);
        end
        
        function tab.setText(t)
            title = t;
            
            recalculateWidth();
            return true;
        end
        
        function tab.getText()
            return title;
        end
		
		function tab.select()
			_selectTab(tab);
			return true;
		end
        
        function tab.getWidth()
            return width;
        end
		
		function tab.getBackgroundColor()
			return bgColor;
		end
        
        function tab.isHit()
            return false;
        end
        
        function tab.destroy()
			if (selectedTab == tab) then
				if (#tabs == 1) then
					selected = false;
					selectedTab = false;
					
					table.delete(tabs, tab);
				else
					local id = _getTabID(tab);
					
					if not (id == #tabs) then
						table.delete(tabs, tab);
					
						_selectTabID(id);
					else
						_selectTabID(id - 1);
						
						table.delete(tabs, tab);
					end
				end
			else
				table.delete(tabs, tab);
			end
            
            tabpanel.update();
        end
        
        table.insert(tabs, tab);
        return tab;
    end
	
	function tabpanel.setSize(w, h)
		if not (super(w, h)) then return false; end;
		
		local m,n;
		
		for m,n in ipairs(tabs) do
			n.setSize(tabpanel.width - 2, height - tabHeight - 2);
		end
		
		return true;
	end
    
    function tabpanel.getTabHeight()
        return tabHeight;
    end
    
    function tabpanel.setFont(f)
        if (font == f) then return true; end;
        
        font = f;
        
        fontHeight = dxGetFontHeight(fontSize, font);
        tabHeight = fontHeight + 4;
        
        local m,n;
        
        for m,n in ipairs(tabs) do
            n.recalculateWidth();
        end
        
        return true;
    end
    
    function tabpanel.setFontSize(s)
        fontSize = s;
        
        fontHeight = dxGetFontHeight(fontSize, font);
        tabHeight = fontHeight + 4;
        
        local m,n;
        
        for m,n in ipairs(tabs) do
            n.recalculateWidth();
        end
        
        return true;
    end
    
    function tabpanel.getFont()
        return fontSize, font;
    end
	
	function tabpanel.setTextColor(r, g, b)
		activeTextColor = tocolor(r, g, b, 255);
		
		active_r, active_g, active_b = r, g, b;
		
		update();
		return true;
	end
	
	function tabpanel.resetTextColor()
		setTextColor(0xFF, 0xFF, 0xFF);
	end
	tabpanel.resetTextColor();
	
	function tabpanel.getTextColor()
		return active_r, active_g, active_b;
	end
	
	function tabpanel.setDeactiveTextColor(r, g, b)
		deactiveTextColor = tocolor(r, g, b, 255);
		
		deactive_r, deactive_g, deactive_b = r, g, b;
		
		update();
		return true;
	end
	
	function tabpanel.resetDeactiveTextColor()
		setDeactiveTextColor(0x90, 0x90, 0x90);
	end
	tabpanel.resetDeactiveTextColor();
	
	function tabpanel.getDeactiveTextColor()
		return deactive_r, deactive_g, deactive_b;
	end
	
	function tabpanel.setBackgroundColor(r, g, b)
		bgColor = tocolor(r, g, b, 255);
		
		bg_r, bg_g, bg_b = r, g, b;
		
		update();
		return true;
	end
	
	function tabpanel.resetBackgroundColor()
		setBackgroundColor(0x00, 0x24, 0x80);
	end
	tabpanel.resetBackgroundColor();
	
	function tabpanel.getBackgroundColor()
		return bgColor;
	end
    
    function tabpanel.getNumTabs()
        return #tabs;
    end
    
    function tabpanel.selectTab(id)
        if (id < 1) or (id > #tabs) then return false; end;
        
		_selectTabID(id);
        return true;
    end
    
    function tabpanel.getSelectedTab()
        return selected;
    end
    
    function tabpanel.getTabAtOffset(offX, offY)
        local m,n;
        local width = 3;
        
        if (offY >= tabHeight) then return false; end;
        
        for m,n in ipairs(tabs) do
            local w = n.getWidth();
            
            if (m == selected) then
                if (offX > width - 4) and (offX < width + w + 19) then
                    return m;
                end
                
                width = width + w + 18;
            else
                if (offX >= width) and (offX <= width + w + 10) and (offY > 1) then
                    return m;
                end
                
                width = width + w + 11;
            end
        end
        
        return false;
    end
    
    function tabpanel.isHit(x, y)
        return (y < tabHeight) and not (getTabAtOffset(x, y) == false);
    end
    
    function tabpanel.mouseclick(button, state, x, y)
        if not (state) then return true; end;
        
        local id = getTabAtOffset(x, y);
        
        if not (id) then return true; end;
        
        selectTab(id);
        return true;
    end
    
    function tabpanel.render()
        local shinyColor = tocolor(0xC0, 0xC0, 0xC0, 0xFF);
        
        dxDrawRectangle(0, tabHeight, width, height, shinyColor);
        dxDrawRectangle(1, 1 + tabHeight, width - 1, height - 1, tocolor(0x40, 0x40, 0x40, 0xFF));
        dxDrawRectangle(1, 1 + tabHeight, width - 2, height - tabHeight - 2, bgColor);
        
        local m,n;
        local offset = 3;
        
        for m,n in ipairs(tabs) do
            local w = n.getWidth();
            local tx, ty, tw, th;
            local tcolor;
            
            if (selected == m) then
                tx, ty, tw, th = -2 + offset, 1, w + 20, tabHeight;
                
                dxDrawRectangle(offset - 3, 0, w + 22, tabHeight, shinyColor);
                dxDrawRectangle(tx, ty, tw, th, n.getBackgroundColor());
                
                tcolor = activeTextColor;
                
                offset = offset + 17;
            else
                tx, ty, tw, th = 1 + offset, 3, w + 10, tabHeight - 3;
                
                dxDrawRectangle(offset, 2, w + 12, th + 2, shinyColor);
                dxDrawRectangle(tx, ty, tw, th, n.getBackgroundColor());
                
                tcolor = deactiveTextColor;
                
                offset = offset + 10;
            end
			
            dxDrawText(n.getText(), tx, ty, tx + tw, ty + th, tcolor, fontSize, font, "center", "center");
            
            offset = offset + w + 1;
        end
        
        return super();
    end
    
    function tabpanel.destroy()
		selectedTab = false;
		selected = false;
	
        tabpanels[tabpanel] = nil;
    end
    
    tabpanels[tabpanel] = true;
    return tabpanel;
end

function isTabPanel(element)
    return not (tabpanels[element] == nil);
end