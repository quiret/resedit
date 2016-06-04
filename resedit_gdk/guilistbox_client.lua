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

local listboxes = {};
local function addEvents(elem)
	elem.addEvent("onListBoxSelect");
	elem.addEvent("onListBoxConfirm");
end
addEvents(dxRoot);

function createListBox(parent)
    local listbox = createDXElement("listbox", parent);
    
    if not (listbox) then return false; end;
    
    local scrollpane = createScrollPane(listbox);
    local columns = {};
	local bgColor = {};
    local numRows = 0;
    local selection = {};
    local selectList = {};
    local areaWidth = 0;
    local font = "sans";
    local fontScale = 1;
    local fontHeight = dxGetFontHeight(fontScale, font);
    local rowHeight = fontHeight + 4;
	local gbgColor;
	local gbg_r, gbg_g, gbg_b;
	local textColor;
	local text_r, text_g, text_b;
	local headerColor;
	local header_r, header_g, header_b;
	local activeHeaderColor;
	local aheader_r, aheader_g, aheader_b;
    local row1color;
	local row1r, row1g, row1b;
    local row2color;
	local row2r, row2g, row2b;
	local selectionColor;
	local select_r, select_g, select_b;
    scrollpane.setScrollHeight(rowHeight);
    scrollpane.setPosition(0, fontHeight + 2);
	
	-- Add events locally
	addEvents(listbox);
    
    local function recalculate()
        return scrollpane.setAreaSize(
            areaWidth,
            numRows * (fontHeight + 4)
        );
    end
    
    local function recalculateWidth()
        local m,n;
        
        areaWidth = 0;
        
        if not (#columns == 0) then
            for m,n in ipairs(columns) do
                areaWidth = areaWidth + n.getWidth();
            end
            
            areaWidth = areaWidth + (#columns - 1) * 3;
        end
        
        return recalculate();
    end
    
    function listbox.setSize(w, h)
        if not (super(w, h)) then return false; end;
        
        return scrollpane.setSize(w, h - (fontHeight + 2));
    end
    
    function listbox.setFont(f)
        if (f == font) then return true; end;
        
        font = f;
        
        fontHeight = dxGetFontHeight(fontScale, f);
        rowHeight = fontHeight + 4;
        scrollpane.setScrollHeight(rowHeight);
        scrollpane.setPosition(0, fontHeight + 2);
        return recalculateWidth();
    end
    
    function listbox.setFontScale(s)
        if (s == fontScale) then return true; end;
        
        fontScale = s;
        
        fontHeight = dxGetFontHeight(s, font);
        rowHeight = fontHeight + 4;
        scrollpane.setScrollHeight(rowHeight);
        scrollpane.setPosition(0, fontHeight + 2);
        return recalculateWidth();
    end
	
	function listbox.getPane()
		return scrollpane;
	end
	
	function listbox.setBackgroundColor(r, g, b)
		gbgColor = tocolor(r, g, b, 255);
		
		gbg_r, gbg_b, gbg_g = r, g, b;
		
		scrollpane.update();
		return true;
	end
	
	function listbox.resetBackgroundColor()
		setBackgroundColor(0, 0, 0);
	end
	listbox.resetBackgroundColor();
	
	function listbox.getBackgroundColor()
		return gbg_r, gbg_b, gbg_g;
	end
	
	function listbox.setTextColor(r, g, b)
		textColor = tocolor(r, g, b, 255);
		
		text_r, text_g, text_b = r, g, b;
		
		scrollpane.update();
		return true;
	end
	
	function listbox.resetTextColor()
		setTextColor(0xFF, 0xFF, 0xFF);
	end
	listbox.resetTextColor();
	
	function listbox.getTextColor()
		return text_r, text_g, text_b;
	end
	
	function listbox.setHeaderColor(r, g, b)
		headerColor = tocolor(r, g, b, 255);
		
		header_r, header_g, header_b = r, g, b;
		
		scrollpane.update();
		return true;
	end
	
	function listbox.resetHeaderColor()
		setHeaderColor(0x00, 0x36, 0x90);
	end
	listbox.resetHeaderColor();
	
	function listbox.getHeaderColor()
		return header_r, header_g, header_b;
	end
	
	function listbox.setActiveHeaderColor(r, g, b)
		activeHeaderColor = tocolor(r, g, b, 255);
		
		aheader_r, aheader_g, aheader_b = r, g, b;
		
		scrollpane.update();
		return true;
	end
	
	function listbox.resetActiveHeaderColor()
		setActiveHeaderColor(0x00, 0x58, 0xB0);
	end
	listbox.resetActiveHeaderColor();
	
	function listbox.getActiveHeaderColor()
		return aheader_r, aheader_g, aheader_b;
	end
	
	function listbox.setSelectionColor(r, g, b)
		selectionColor = tocolor(r, g, b, 0x40);
		
		scrollpane.update();
		return true;
	end
	
	function listbox.resetSelectionColor()
		setSelectionColor(0xFF, 0xFF, 0xFF);
	end
	listbox.resetSelectionColor();
	
	function listbox.setRow1Color(r, g, b)
		row1color = tocolor(r, g, b, 255);
		
		row1r, row1g, row1b = r, g, b;
		
		scrollpane.update();
		return true;
	end
	
	function listbox.resetRow1Color()
		setRow1Color(0x00, 0x15, 0x35);
	end
	listbox.resetRow1Color();
	
	function listbox.getRow1Color()
		return row1r, row1g, row1b;
	end
	
	function listbox.setRow2Color(r, g, b)
		row2color = tocolor(r, g, b, 255);
		
		row2r, row2g, row2b = r, g, b;
		
		scrollpane.update();
		return true;
	end
	
	function listbox.resetRow2Color()
		setRow2Color(0x08, 0x30, 0x60);
	end
	listbox.resetRow2Color();
	
	function listbox.getRow2Color()
		return row2r, row2g, row2b;
	end
    
    function listbox.addColumn()
        local column = {};
        local width = 0;
        local items = {};
        local name = "";
        
        function column.addRow()
            table.insert(items, {
				text = "",
				color = false
			});
            return true;
        end
        
        function column.removeRow(id)
            table.remove(items, id);
            return true;
        end
        
        function column.setName(text)
            name = text;
            return true;
        end
        
        function column.getName()
            return name;
        end
        
        function column.setText(row, text)
            if (row < 1) or (row > numRows) then return false; end;
            
            items[row].text = text;
            
            recalculate();
            return true;
        end
        
        function column.getText(row)
			if (row < 1) or (row > numRows) then return false; end;
		
            return items[row].text;
        end
		
		function column.clear()
			items = {};
			return true;
		end
		
		function column.setColor(row, r, g, b)
			if (row < 1) or (row > numRows) then return false; end;
			
			items[row].color = tocolor(r, g, b, 255);
			
			scrollpane.update();
			return true;
		end
		
		function column.getColor(row)
			if (row < 1) or (row > numRows) then return false; end;
			
			local color = items[row].color;
			
			if not (color) then
				return textColor;
			end
			
			return color;
		end
        
        function column.setWidth(w)
            width = w;
            
            recalculateWidth();
            return true;
        end
        
        function column.getWidth()
            return width;
        end
        
        function column.getMinimumWidth()
            local m,n;
            local textWidth = 0;
            
            for m,n in ipairs(items) do
                local width = dxGetTextWidth(n.text, fontScale, font);
                
                if (textWidth < width) then
                    textWidth = width;
                end
            end
            
            return textWidth;
        end
        
        table.insert(columns, column);
        return #columns;
    end
    
    function listbox.getNumColumns()
        return #columns;
    end
    
    function listbox.setColumnName(id, name)
        local column = columns[id];
        
        if not (column) then return false; end;
        
        return column.setName(name);
    end
    
    function listbox.getColumnName(id)
        local column = columns[id];
        
        if not (column) then return ""; end;
        
        return column.getName();
    end

    function listbox.setColumnWidth(id, w)
        local column = columns[id];
        
        if not (column) then return false; end;
        
        return column.setWidth(w);
    end
    
    function listbox.getColumnWidth(id)
        local column = columns(id);
        
        if not (column) then return 0; end;
        
        return column.getWidth();
    end
    
    function listbox.getMinimumColumnWidth(id)
        local column = columns[id];
        
        if not (column) then return 0; end;
        
        return column.getMinimumWidth();
    end
    
    function listbox.addRow()
        local m,n;
        
        for m,n in ipairs(columns) do
            n.addRow();
        end
        
        numRows = numRows + 1;
        
        recalculate();
        return numRows;
    end
    
    function listbox.getNumRows()
        return numRows;
    end
    
    function listbox.setItemText(c, r, text)
        local column = columns[c];
        
        if not (column) then return false; end;
        
        return column.setText(r, text);
    end
    
    function listbox.getItemText(c, r)
        local column = columns[c];
        
        if not (column) then return false; end;
        
        return column.getText(r);
    end
	
	function listbox.setItemColor(c, row, r, g, b)
		local column = columns[c];
		
		if not (column) then return false; end;
		
		return column.setColor(row, r, g, b);
	end
	
	function listbox.getItemColor(c, r)
		local column = columns[c];
		
		if not (column) then return false; end;
		
		return column.getColor(r);
	end
    
    function listbox.clearRow(id)
        if (id < 1) or (id > numRows) then return false; end;
        
         local m,n;
        
        for m,n in ipairs(columns) do
            n.setText(id, "");
        end
        
        return true;
    end
    
    function listbox.removeRow(id)
        if not (id) then
            if (numRows == 0) then return false; end;
            
            id = numRows;
        elseif (id < 1) or (id > numRows) then
            return false;
        end
        
        for m,n in ipairs(columns) do
            n.removeRow(id);
        end
        
        setRowSelected(id, false);
        
        numRows = numRows - 1;
        return true;
    end

    function listbox.removeColumn(id)
        if (id < 1) or (id > #columns) then return false; end;
        
        table.remove(columns, id);
        return true;
    end
    
    function listbox.setRowSelected(id, select)
        if (id < 1) or (id > numRows) then return false; end;
        
        if (select) then
            selection[id] = true;
            
            table.insert(selectList, id);
        else
            selection[id] = nil;
            
            table.delete(selectList, id);
        end
        
        scrollpane.update();
        return true;
    end
    
    function listbox.isRowSelected(id)
        if (id < 1) or (id > numRows) then return false; end;
        
        return selection[id];
    end
    
    function listbox.getSelection()
        return selectList;
    end
	
	function listbox.setRowBackgroundColor(row, r, g, b)
		if (row < 1) or (row > numRows) then return false; end;
		
		bgColor[row] = tocolor(r, g, b, 255);
		return true;
	end
	
	function listbox.getRowBackgroundColor(row)
		return bgColor[row];
	end
    
    function listbox.clearSelection()
        selection = {};
        selectList = {};
        
        scrollpane.update();
        return true;
    end
	
	function listbox.clearRows()
		local m,n;
		
		for m,n in ipairs(columns) do
			n.clear();
		end
	
		bgColor = {};
		numRows = 0;
		clearSelection();
		
		recalculate();
		return true;
	end
    
    function listbox.clear()
        columns = {};
		bgColor = {};
        numRows = 0;
        clearSelection();
        
        areaWidth = 0;
        
        recalculate();
        return true;
    end
    
    function listbox.giveScrollFocus()
        scrollpane.giveFocus();
        return true;
    end
    
    function listbox.isHit(x, y)
        return (y <= 20);
    end
    
    function listbox.render()
        dxDrawRectangle(0, 0, width, 20, headerColor);
        
        local viewX = scrollpane.getViewOffset();
        local n = 1;
        local offset = -viewX;
        
        while (n <= #columns) do
            local column = columns[n];
            
            dxDrawRectangle(offset, 0, column.getWidth() + 2, fontHeight + 2, activeHeaderColor);
            dxDrawText(column.getName(), offset + 6, 1, offset + column.getWidth() + 2, fontHeight, textColor, fontScale, font, "left", "top", true);
            
            offset = offset + column.getWidth() + 3;
            n = n + 1;
        end
        
        return super();
    end
    
    function scrollpane.mouseclick(button, state, x, y)
        if not (button == "left") or not (state) then return true; end;
        
        local viewX, viewY = getViewOffset();
        local n = math.floor((y + viewY) / rowHeight) + 1;
        local hierarchy = getHierarchy();
        
        if (hierarchy.getKeyState("lctrl")) or (hierarchy.getKeyState("rctrl")) then
            listbox.setRowSelected(n, not listbox.isRowSelected(n));
            return true;
        end
        
        listbox.clearSelection();

        if (listbox.setRowSelected(n, true)) then
            listbox.triggerEvent("onListBoxSelect", n);
        end
        
        return true;
    end
	
	function scrollpane.mousedoubleclick(button, x, y)
		if not (button == "left") then return; end;
        
        local hierarchy = getHierarchy();
        
		if (hierarchy.getKeyState("lctrl")) or (hierarchy.getKeyState("rctrl")) then return; end;
	
		listbox.triggerEvent("onListBoxConfirm");
	end
    
    function scrollpane.renderArea()
        local viewX, viewY = getViewOffset();
        local rend_width, rend_height = getRenderSize();
        local y = -(viewY % rowHeight);
        local n = math.floor(viewY / rowHeight) + 1;
        local width, height = getRenderSize();
        local maxRender = math.min(numRows, n + math.floor(rend_height / rowHeight) + 1);
        
        dxDrawRectangle(0, 0, width, height, gbgColor);
        
        while (n <= maxRender) do
            local j,k;
            local offset = -viewX;
            local rowcolor = bgColor[n];
            
			if not (rowcolor) then
				if ((n % 2) == 0) then
					rowcolor = row1color;
				else
					rowcolor = row2color;
				end
			end
            
            for j,k in ipairs(columns) do
                if (j == #columns) then
                    dxDrawRectangle(offset, y, rend_width + viewX, rowHeight, rowcolor);
                else
                    dxDrawRectangle(offset, y, k.getWidth() + 2, rowHeight, rowcolor);
                end
                
                dxDrawText(k.getText(n), offset + 2, y + 2, offset + k.getWidth() + 2, y + 2 + fontHeight, k.getColor(n), fontScale, font, "left", "top", true);
                    
                offset = offset + k.getWidth() + 3;
            end
            
            if (selection[n]) then
                dxDrawRectangle(0, y, rend_width, rowHeight, selectionColor);
            end
            
            y = y + rowHeight;
            n = n + 1;
        end
        
        return super();
    end
    
    function listbox.destroy()
        columns = nil;
        selection = nil;
        
        listboxes[listbox] = nil;
    end
    
    listboxes[listbox] = true;
    return listbox;
end

function isListBox(element)
    return not (listboxes[element] == nil);
end