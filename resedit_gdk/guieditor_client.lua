--[[
	I hope you realize the power of Lua.
	
		The_GTA
]]

-- Optimizations
local dxGetFontHeight = dxGetFontHeight;
local dxGetTextWidth = dxGetTextWidth;
local dxDrawText = dxDrawText;
local dxDrawRectangle = dxDrawRectangle;

local string = string;
local math = math;
local table = table;
local strsub = string.sub;
local strbyte = string.byte;
local strchar = string.char;
local strlen = string.len;
local strfind = string.find;
local strrep = string.rep;
local ipairs = ipairs;
local pairs = pairs;
local getNextItem = getNextItem;

local editors = {};

function createEditor(parent)
	local editor = createDXElement("editor", parent);
	local bufferWidth, bufferHeight = 0, 0;
	local textWidth, textHeight = 0, 0;
	local lineNumbers = false;
	local lineBarOffset = 0;
	local lineBarWidth = 0;
	local lineBarTarget = false;
	local lineBarChanged = true;
	local buffer = "";
	local lineInfo = {};
	local itemData = {};
	local colorData = {};
	local editActions = {};
	local isHighlight = false;
	local isHighlighting = false;
	local highlightStart, highlightEnd = 0, 0;
	local cursor = 1;
	local cursorWidthOffset;
	local cursorLine;
	local cursorArrangementWidth;
	local cursorMoveTime = getTickCount();
	local currentEditAction = 0;
	local charScale = 1;
	local charFont = "sans";
	local lexicCheck = false;
	local highlightArea = createDXElement("highlight_area", editor);
	local highlightColor;
	local scrollpane = createScrollPane(editor);
	local hScroll = scrollpane.getHorizontalScroll();
	local vScroll = scrollpane.getVerticalScroll();
	local lastScrollHorizontal = 0;
	local lastScrollVertical = 0;
	local scrollTimer = 30;
	local fontHeight = dxGetFontHeight(charScale, charFont);
	local enableColors = false;
	local getColorFromToken;
	local lexicalHinting = false;
	local lexicHint = false;
	local getLexicalDefinition;
	local automaticIndentation = false;
	local textColor;
	local bgColor;
	local bg_r, bg_g, bg_b;
	local disableBgColor;
	local dBg_r, dBg_g, dBg_b;
	
	if not (editor) then return false; end;
	
	-- Set up the scrollpane
	scrollpane.enableKeyScrolling(false);
	
	-- Draw highlighting on top of the text
	highlightArea.setAlwaysOnTop(true);
	highlightArea.supportAlpha(true);
	
	function highlightArea.isHit()
		return false;
	end
	
	local function getViewOffset()
		local viewX, viewY = scrollpane.getViewOffset();
		
		return viewX, viewY - math.mod(viewY, fontHeight);
	end
	
	local function updateView()
		lineBarChanged = true;
		return true;
	end
	
	local function updateLineBarTarget()
		-- Update the buffer target
		if (lineBarTarget) then
			destroyElement(lineBarTarget);
		end
		
		local _, height = scrollpane.getRenderSize();
		
		if not (lineNumbers) or (lineBarWidth == 0) or (height == 0) then
			lineBarTarget = false;
			return true;
		end

		lineBarTarget = dxCreateRenderTarget(lineBarWidth, bufferHeight, false);
		
		assert(lineBarTarget, "failed to create lineBar renderTarget");
	
		lineBarChanged = true;
		return true;
	end
	
	function editor.updateRenderTarget()
		updateLineBarTarget();
		return true;
	end
	
	local function adjust()
		viewY = viewY - math.mod(viewY, fontHeight);
		return true;
	end
	
	function editor.calculate()
		local bufferOffsetX, bufferOffsetY;
	
		if (lineNumbers) then
			lineBarWidth = math.max(40, dxGetTextWidth(tostring(#lineInfo), charScale, charFont) + 20);
			
			bufferWidth = width - lineBarWidth;
			bufferHeight = height;
			
			bufferOffsetX = lineBarWidth;
		else
			lineBarWidth = 0;
			
			bufferWidth, bufferHeight = width, height;
			
			bufferOffsetX = 0;
		end
		
		-- Adjust the rendering
		scrollpane.setPosition(bufferOffsetX, 0);
		scrollpane.setSize(bufferWidth, height);
		scrollpane.setAreaSize(textWidth, textHeight);
		highlightArea.setPosition(bufferOffsetX, 0);
		highlightArea.setSize(scrollpane.getRenderSize());
		
		-- Set a correct step and page size for the scrollbars
		scrollpane.setScrollHeight(fontHeight * 3);
		
		-- Reinstantiate our render targets
		updateRenderTarget();
		return true;
	end
	
	function scrollpane.recalculate()
		super();
		
		-- Adjust the horizontal scroll per hook
		if (hScroll.visible) and (lineNumbers) then
			local w, h = hScroll.getSize();
			hScroll.setSize(w + lineBarWidth, h);
		end

		return true;
	end
	
	function vScroll.events.onScroll()
		updateView();
		return true;
	end
	
	function editor.setVisible(show)
		if not (super(show)) then return false; end;
		
		if (show) then
			calculate();
		end
		
		return true;
	end
	
	function editor.setText(text)
		buffer = parseScript(text);
		
		-- Cache the text
		parseCode();
		calculate();
		
		-- Reset the view
		scrollpane.setViewOffset(0, 0);
		
		-- Reset scriptEdit
		cursor = 1;
		cursorWidthOffset = 0;
		cursorLine = 1;
		cursorArrangementWidth = 0;
		isHighlight = false;
		isHighlighting = false;
		
		editActions = {};
		currentEditAction = 0;
		return true;
	end
	
	function editor.getText()
		return buffer;
	end
	
	function editor.setFont(scale, font)
		if (scale == charScale) and (font == charFont) then return true; end;
	
		charFont = font;
		charScale = scale;
		
		-- Update properties
		fontHeight = dxGetFontHeight(charScale, charFont);
		
		parseCode();
		calculate();
		return true;
	end
	
	function editor.getFont()
		return charScale, charFont;
	end
	
	function editor.setBackgroundColor(r, g, b)
		bgColor = tocolor(r, g, b, 255);
		
		bg_r, bg_g, bg_b = r, g, b;
		
		scrollpane.update();
		return true;
	end
	
	function editor.resetBackgroundColor()
		setBackgroundColor(0xFF, 0xFF, 0xFF);
	end
	editor.resetBackgroundColor();
	
	function editor.getBackgroundColor()
		return bg_r, bg_g, bg_b;
	end
	
	function editor.setDisabledBackgroundColor(r, g, b)
		disableBgColor = tocolor(r, g, b, 255);
		
		dBg_r, dBg_g, dBg_b = r, g, b;
		
		scrollpane.update();
		return true;
	end
	
	function editor.resetDisabledBackgroundColor()
		setDisabledBackgroundColor(0xE0, 0xE0, 0xE0);
	end
	editor.resetDisabledBackgroundColor();
	
	function editor.getDisabledBackgroundColor()
		return dBg_r, dBg_g, dBg_b;
	end
	
	function editor.getScrollBuffer()
		return scrollpane;
	end
	
	function editor.setHighlightColor(r, g, b, a)
		highlightColor = tocolor(r, g, b, a);
		return true;
	end
	
	function editor.resetHighlightColor()
		setHighlightColor(0, 0, 0, 0x7F);
	end
	editor.resetHighlightColor();
	
	function editor.showLineNumbers(show)
		if (lineNumbers == show) then return true; end;
	
		lineNumbers = show;
		
		calculate();
		
		-- Adjust horizontal scroll
		hScroll.setPosition(hScroll.x - lineBarWidth, hScroll.y);
		return true;
	end
	
	function editor.lineNumbersShowing()
		return lineNumbers;
	end
	
	function editor.getLineBarWidth()
		if not (lineNumbers) then return 0; end;
	
		return lineBarWidth;
	end
	
	function scrollpane.setSize(w, h)
		if not (super(w, h)) then return false; end;
		
		hScroll.setPosition(hScroll.x - lineBarWidth, hScroll.y);
		return true;
	end
	
	function editor.setPosition(x, y)
		super(x, y);
		return true;
	end
	
	function editor.setSize(w, h)
		super(w, h);
		
		calculate();
		return true;
	end

	function editor.scanCursor()
		-- Check whether cursor is out of sight and get the view back on it
		local viewX, viewY = getViewOffset();
		local curLine = 1 + viewY / fontHeight;
		local maxLine = (viewY + bufferHeight) / fontHeight;
		
		if (cursorLine < curLine) then
			scrollpane.setViewOffset(viewX, viewY - fontHeight * (curLine - cursorLine));

			updateView();
		elseif (cursorLine > maxLine) then
			scrollpane.setViewOffset(viewX, viewY + fontHeight * (cursorLine - maxLine + 2)); -- 2 == discrepancy factor
			
			updateView();
		end
		
		local info = lineInfo[cursorLine];
		local cursorWidth = dxGetTextWidth(strsub(buffer, info.offset, cursor), charScale, charFont);
		
		if (viewX > cursorWidth) then
			scrollpane.setViewOffset(cursorWidth, viewY);
			
			scrollpane.update();
		elseif (viewX + bufferWidth < cursorWidth) then
			scrollpane.setViewOffset(cursorWidth - bufferWidth, viewY);

			scrollpane.update();
		end
	end
	
	function editor.getCursorAtOffset(x, y)
		local line, info;
		local offset, widthOffset;
		local viewX, viewY = getViewOffset();
		
		-- Calculate the cursor
		line = math.min(math.max(1 + math.floor((viewY + y) / fontHeight), 1), #lineInfo);
		info = lineInfo[line];
		
		-- Get the offset of the line
		offset, widthOffset = getTextLogicalOffset(strsub(buffer, info.offset, info.offsetEnd), x + viewX, charScale, charFont);
		offset = offset + info.offset - 1;
		
		return offset, widthOffset, line;
	end
	
	function scrollpane.mousemove()
		if (lexicHint) then return true; end;
	
		lexicCheck = false;
		return true;
	end
	
	function scrollpane.events.onPresent()
		local x, y = getScreenPosition();
		local now = getTickCount();
		local offset, token, begin;
		local mouseOffset, widthOffset, line;
		local n = 2;
		local viewX, viewY = getViewOffset();

		if not (editor.getLexicalHintingActive()) or not (isMouseActive()) then return true; end;
		
		if (lexicCheck) or (now - mouseMoveTime <= 500) then return true; end;
		
		-- Do lexical logic
        local mouseX, mouseY = getMousePosition();
        
        if not (mouseX) then return false; end;
        
		if (mouseY > (textHeight - viewY)) then return true; end;
        
		mouseOffset, widthOffset, line = editor.getCursorAtOffset(mouseX, mouseY);
		
		item = itemData[1];
		
		while (item) do
			if (item.offsetEnd + 1 > mouseOffset) then
				if (item.offset <= mouseOffset) then
					if not (isName(strbyte(buffer, item.offset))) then return true; end;
					if (mouseX > lineInfo[line].width + x) then return true; end;
				
					local token = item.token;
					local text = getLexicalDefinition(token);
					
					if not (text) then return true; end;
                    
					local tokenWidth = dxGetTextWidth(token, charScale, charFont);
					local tokenX = x + dxGetTextWidth(strsub(buffer, lineInfo[line].offset, item.offset - 1), charScale, charFont) - viewX;
					local tokenY = y - viewY + line * fontHeight;
					lexicHint = showHint(tokenX, tokenY, text);
					
					function lexicHint.cbUpdate()
						if (mouseX < tokenX) or (mouseY < tokenY - fontHeight) or (mouseX > tokenX + tokenWidth) or (mouseY > tokenY) then
							destroy();
							return false;
						end
					
						return true;
					end
					
					function lexicHint.destroy()
						lexicHint = false;
						lexicCheck = false;
						return true;
					end
					
					break;
				end
			end
			
			item = itemData[n];
			n = n + 1;
		end
	
		lexicCheck = true;
	end

	function scrollpane.events.onPresent()
		if not (isHighlighting) then return true; end;
		
		local now = getTickCount();
		local x, y = getPosition();
		local mouseX, mouseY = getMousePosition();
        
        if not (mouseX) then return true; end;
        
		local viewX, viewY = getViewOffset();
		
		-- Set cursor
		cursor, cursorWidthOffset, cursorLine = editor.getCursorAtOffset(mouseX, mouseY);
		cursorArrangementWidth = cursorWidthOffset;
		
		highlightEnd = cursor;
		
		cursorMoveTime = now;
		
		-- Move view
		if (mouseY < y + fontHeight) then
			if (now - lastScrollVertical >= scrollTimer) then
				viewY = viewY - fontHeight;
				
				updateView();
				
				lastScrollVertical = now;
			end
		elseif (mouseY > y + bufferHeight - fontHeight) then
			if (textHeight > bufferHeight) then
				if (now - lastScrollVertical >= scrollTimer) then
					viewY = viewY + fontHeight;
					
					updateView();
					
					lastScrollVertical = now;
				end
			end
		end
		
		-- Now to left and right
		if (mouseX < x + 10) then
			if (now - lastScrollHorizontal >= scrollTimer) then
				viewX = viewX - 5;
				
				lastScrollHorizontal = cursorMoveTime;
			end
		elseif (mouseX > x + bufferWidth - 10) then
			if (textWidth > bufferWidth) then
				if (now - lastScrollHorizontal >= scrollTimer) then
					viewX = viewX + 5;
					
					lastScrollHorizontal = cursorMoveTime;
				end
			end
		end
		
		setViewOffset(viewX, viewY);
		return true;
	end
	
	function scrollpane.blur()
		isHighlighting = false;
	end

	function scrollpane.mouseclick(button, state, offX, offY)
		if not (button == "left") then return true; end;
		
		if (state) then
			cursor, cursorWidthOffset, cursorLine = editor.getCursorAtOffset(offX, offY);
			cursorArrangementWidth = cursorWidthOffset;
			
			isHighlight = true;
			isHighlighting = true;
			
			highlightStart = cursor;
			highlightEnd = cursor;
			
			cursorMoveTime = getTickCount();
			return true;
		end
		
		if (highlightStart == highlightEnd) then
			isHighlight = false;
		end
	
		isHighlighting = false;
		return true;
	end
	
	function editor.mouseclick(button, state, x, y)
		local _x, _y = scrollpane.getPosition();
		return scrollpane.mouseclick(button, state, x - _x, y - _y);
	end
	
	function editor.isHit(x, y)
		return x < getLineBarWidth();
	end
	
	function editor.setLexicalHintingEnabled(enabled)
		if (lexicalHinting == enabled) then return true; end;
		
		lexicalHinting = enabled;
		return true;
	end
	
	function editor.getLexicalHintingEnabled()
		return lexicalHinting;
	end
	
	function editor.setLexicalTokenHandler(handler)
		getLexicalDefinition = handler;
		return true;
	end
	
	function editor.getLexicalHintingActive()
		if not (lexicalHinting) then return false; end;
		
		return not (getLexicalDefinition == nil);
	end
	
	function editor.setAutoIndentEnabled(enabled)
		automaticIndentation = enabled;
		return true;
	end
	
	function editor.getAutoIndentEnabled()
		return automaticIndentation;
	end
	
	function editor.setColorTokenHandler(handler)
		getColorFromToken = handler;
		
		parseColor();
		return true;
	end
	
	function editor.setColorEnabled(enabled)
		if (enabled == enableColors) then return true; end;
	
		enableColors = enabled;
		
		parseColor();
		return true;
	end
	
	function editor.getColorEnabled()
		return enableColors;
	end
	
	function editor.getColorActive()
		if not (enableColors) then return false; end;
	
		return not (getColorFromToken == nil);
	end
	
	local colorId;
	local itemId;
	local start, term, begin;
	
	local function generateItems()
		local size = strlen(buffer);
		local newOffset, token, errStart;
		
        local tinsert = table.insert;
        local tremove = table.remove;
        local mmax = math.max;
		
		newOffset, token, begin, errStart = getNextItem(buffer, start);
		
		while (true) do
            local new_tok_beg, new_tok_end;
            
            if (newOffset == false) then
                if not (token) then
                    return false;
                end
            
                new_tok_beg = errStart;
                new_tok_end = begin;
            elseif (begin <= term) then
                new_tok_beg = begin;
                new_tok_end = newOffset - 1;
            else
                return true;
            end
        
            while (itemData[itemId]) and (itemData[itemId].offset <= new_tok_end) do
                local tokitem = itemData[itemId];
            
                tremove(itemData, itemId);
                
                term = mmax(term, tokitem.offsetEnd);
            end
            
            if (newOffset == false) then
                tinsert(itemData, itemId, {
                    offset = new_tok_beg,
                    offsetEnd = new_tok_end,
                    token = token
                });
            else
                tinsert(itemData, itemId, {
                    offset = new_tok_beg,
                    offsetEnd = new_tok_end,
                    token = token
                });
            end
            itemId = itemId + 1;
				
            if (newOffset == false) then
				if (begin == size) then
					return true;
				end
				
				newOffset = begin + 1;
            end
			
			newOffset, token, begin, errStart = getNextItem(buffer, newOffset);
		end
	end
	
	local function handleColorToken(token)
		local textColor, backColor = getColorFromToken(token);
		
		if not (textColor) then return false; end;
	
		local color = {
			offset = begin,
			offsetEnd = begin + strlen(token) - 1,
			textColor = textColor,
			backColor = backColor
		};
		
		table.insert(colorData, colorId, color);
		
		colorId = colorId + 1;
		return color;
	end

	local function generateColors()
		local size = strlen(buffer);
		local curColor;
		local newOffset, token, errStart;
        
        local tinsert = table.insert;
        local tremove = table.remove;
        local mmax = math.max;
		
		newOffset, token, begin, errStart = getNextItem(buffer, start);
		
		while (true) do
            local new_tok_beg, new_tok_end;
            
            if (newOffset == false) then
                if not (token) then
                    return false;
                end
            
                new_tok_beg = errStart;
                new_tok_end = begin;
            elseif (begin <= term) then
                new_tok_beg = begin;
                new_tok_end = newOffset - 1;
            else
                return true;
            end
        
            while (itemData[itemId]) and (itemData[itemId].offset <= new_tok_end) do
                local tokitem = itemData[itemId];
            
                if (tokitem.color) then
                    tremove(colorData, colorId);
                    
                    term = mmax(term, tokitem.color.offsetEnd);
                end
            
                tremove(itemData, itemId);
                
                term = mmax(term, tokitem.offsetEnd);
            end
            
            if (newOffset == false) then
                tinsert(itemData, itemId, {
                    offset = new_tok_beg,
                    offsetEnd = new_tok_end,
                    token = token
                });
            else
                tinsert(itemData, itemId, {
                    offset = new_tok_beg,
                    offsetEnd = new_tok_end,
                    token = token,
                    
                    color = handleColorToken(token)
                });
            end
            itemId = itemId + 1;
				
            if (newOffset == false) then
				if (begin == size) then
					return true;
				end
				
				newOffset = begin + 1;
            end
			
			newOffset, token, begin, errStart = getNextItem(buffer, newOffset);
		end
	end
	
	function editor.setBackgroundColor(r, g, b)
		bgColor = tocolor(r, g, b, 255);
		
		scrollpane.update();
		return true;
	end
	
	function editor.getBackgroundColor()
		return bgColor;
	end
	
	function editor.setTextColor(r, g, b)
		textColor = tocolor(r, g, b, 255);
		
		scrollpane.update();
		return true;
	end
	
	function editor.resetTextColor()
		setTextColor(0, 0, 0);
	end
	editor.resetTextColor();
	
	function editor.getTextColor()
		return textColor;
	end

	function editor.parseColor()
		-- Mark it for update all the time
		scrollpane.update();
		
		colorData = {};
	
		if not (getColorActive()) then	return false; end;
		
		itemData = {};

		colorId = 1;
		itemId = 1;
		start = 1;
		term = strlen(buffer);
		
		generateColors();
		return true;
	end

	function editor.parseCode()
		local newCount = strlen(buffer);
		local lastBreak = 1;
		local info;
		local start;

		lineInfo = {};

		textWidth = 0;
		textHeight = fontHeight;
		
		if (getColorActive()) then
			-- Do the color
			parseColor();
		else
			-- Just do the tokens
			itemData = {};
			
			itemId = 1;
			start = 1;
			term = strlen(buffer);
			
			generateItems();
			
			scrollpane.update();
		end
		
		info = {};
		info.offset = 1;
		table.insert(lineInfo, info);
		
		-- Expand on lineInfo
		start = strfind(buffer, "\n", 1);
	
		while (start) do
			local len = dxGetTextWidth(strsub(buffer, lastBreak, start-1), charScale, charFont);
			
			if (len > textWidth) then
				textWidth = len;
			end
			lastBreak = start+1;
			
			info.offsetEnd = start-1;
			info.width = len;
			
			info = {};
			info.offset = lastBreak;
			table.insert(lineInfo, info);
			
			start = strfind(buffer, "\n", start+1);
		end
		
		textHeight = fontHeight * (#lineInfo + 1);
		
		local len = dxGetTextWidth(strsub(buffer, lastBreak, newCount), charScale, charFont);
		
		if (len > textWidth) then
			textWidth = len;
		end
		
		info.offsetEnd = newCount;
		info.width = len;
		return true;
	end
	
	-- Internal
	local function insertText(text, offset)
		local m,n;
		local len = strlen(text);
		local curColor;
		local lastBreak;
		
		-- Insert text into buffer
		buffer = strsub(buffer, 1, offset - 1) .. text .. strsub(buffer, offset, strlen(buffer));
		
		if (enableColors) then
			local found = false;
		
			itemId = 1;
			colorId = 0;
			
			while (itemId <= #itemData) do
				n = itemData[itemId];
				curColor = n.color;
				
				if (curColor) then
					colorId = colorId + 1;
				end
				
				if (n.offset <= offset) then
					if (n.offsetEnd+1 >= offset) then
						start = n.offset;
						term = math.max(n.offsetEnd + len, offset);
						
						if (curColor) then
							table.remove(colorData, colorId);
						else
							colorId = colorId + 1;
						end
						
						table.remove(itemData, itemId);
						
						found = true;
						break;
					else
						itemId = itemId + 1;
					end
				else
					if not (curColor) then
						colorId = colorId + 1;
					end
					
					start = offset;
					term = offset - 1 + len;
					break;
				end
			end
			
			if (found == false) and (itemId > #itemData) then
				start = offset;
				term = strlen(buffer);
				
				colorId = colorId + 1;
			end
			
			m = itemId;
			
			while (m <= #itemData) do
				n = itemData[m];
				
				n.offset = n.offset + len;
				n.offsetEnd = n.offsetEnd + len;
				
				curColor = n.color;
				
				if (curColor) then
					curColor.offset = curColor.offset + len;
					curColor.offsetEnd = curColor.offsetEnd + len;
				end
				
				m = m + 1;
			end
			
			generateColors();
		else
			local found = false;
		
			itemId = 1;
			
			while (itemId <= #itemData) do
				n = itemData[itemId];
				
				if (n.offset <= offset) then
					if (n.offsetEnd+1 >= offset) then
						start = n.offset;
						term = math.max(n.offsetEnd + len, offset);
						
						table.remove(itemData, itemId);
						
						found = true;
						break;
					else
						itemId = itemId + 1;
					end
				else
					start = offset;
					term = offset - 1 + len;
					break;
				end
			end
			
			if (found == false) and (itemId > #itemData) then
				start = offset;
				term = strlen(buffer);
			end
			
			m = itemId;
			
			while (m <= #itemData) do
				n = itemData[m];
				
				n.offset = n.offset + len;
				n.offsetEnd = n.offsetEnd + len;
				
				m = m + 1;
			end
			
			generateItems();
		end
		
		n = lineInfo[1];
		m = 2;
		
		while (m <= #lineInfo) do
			if (n.offsetEnd + 1 >= offset) then
				break;
			end
			
			n = lineInfo[m];
			m = m + 1;
		end
		
		-- Reset the width
		n.width = 0;
		
		start = n.offsetEnd + len;
		term = offset - 1 + len;
		
		lastBreak = n.offset;
		
		-- Expand on lineInfo
		while (true) do
			offset = strfind(buffer, "\n", lastBreak);
			
			if not (offset) or (offset > term) then
				break;
			end
			
			n.width = dxGetTextWidth(strsub(buffer, lastBreak, offset-1), charScale, charFont);
			
			if (n.width > textWidth) then
				textWidth = n.width;
			end
			lastBreak = offset+1;
			
			n.offsetEnd = offset-1;
			
			n = {};
			n.offset = lastBreak;
			n.offsetEnd = start;
			table.insert(lineInfo, m, n);
			
			m = m + 1;
			
			textHeight = textHeight + fontHeight;
		end
		
		-- Finish it off
		n.width = dxGetTextWidth(strsub(buffer, lastBreak, start), charScale, charFont);
		
		if (n.width > textWidth) then
			textWidth = n.width;
		end
		
		n.offsetEnd = start;
		
		-- Now increment the rest of em
		while (m <= #lineInfo) do
			n = lineInfo[m];
		
			n.offset = n.offset + len;
			
			n.offsetEnd = n.offsetEnd + len;
			
			m = m + 1;
		end
		
		-- Recalculate the view
		editor.calculate();
		return true;
	end
	
	local function editEntryAdd(text, offset, time)
		local lastEntry = editActions[currentEditAction];
		
		if (lastEntry) and (lastEntry.type == "add") and not (time == 0) and (time - lastEntry.time <= 1000) then
			lastEntry.text = lastEntry.text .. text;
			lastEntry.time = time;
		else
			local m;
		
			currentEditAction = currentEditAction + 1;
			
			while (editActions[currentEditAction]) do
				table.remove(editActions, currentEditAction);
			end
		
			table.insert(editActions, currentEditAction, {
				type = "add",
				text = text,
				offset = offset,
				time = time
			});
		end
	end

	local function editEntryRemove(offset, text, time)
		local lastEntry = editActions[currentEditAction];
		
		if (lastEntry) and (lastEntry.type == "remove") and not (time == 0) and (time - lastEntry.time <= 1000) then
			lastEntry.text = text .. lastEntry.text;
			lastEntry.offset = offset;
			lastEntry.time = time;
		else
			local m;
		
			currentEditAction = currentEditAction + 1;
		
			while (editActions[currentEditAction]) do
				table.remove(editActions, currentEditAction);
			end

			table.insert(editActions, {
				type = "remove",
				offset = offset,
				text = text,
				time = time
			});
		end
	end
	
	local function updateCursor()
		cursorLine = editor.getLineFromOffset(cursor);
		
		cursorWidthOffset = dxGetTextWidth(strsub(buffer, lineInfo[cursorLine].offset, cursor - 1), charScale, charFont);
		cursorArrangementWidth = cursorWidthOffset;
		
		cursorMoveTime = getTickCount();
		return true;
	end
	
	function editor.insertText(text, offset)
		editEntryAdd(text, offset, 0);
		
		insertText(text, offset);
		return true;
	end

	-- Internal
	local function removeText(offset, len)
		local m,n;
		local curColor;
		local quit;
		local found;
		
		offset = math.max(1, offset);
		len = math.min(len, strlen(buffer) - (offset - 1));
		
		quit = offset - 1 + len;
		
		-- We have to update lines here
		n = lineInfo[1];
		m = 2;
		
		while (m <= #lineInfo) do
			if (n.offsetEnd + 1 >= offset) then
				break;
			end

			n = lineInfo[m];
			m = m + 1;
		end
		
		if (n.offsetEnd >= quit) then
			n.offsetEnd = n.offsetEnd - len;
			n.width = n.width - dxGetTextWidth(strsub(buffer, offset, quit), charScale, charFont);
		else
			local appLine = n;

			while (m <= #lineInfo) do
				if (n.offsetEnd >= quit) then
					break;
				end
				
				n = lineInfo[m];
			
				table.remove(lineInfo, m);
			end
		
			appLine.offsetEnd = n.offsetEnd - len;
			appLine.width = appLine.width - dxGetTextWidth(strsub(buffer, offset, appLine.offsetEnd), charScale, charFont) + dxGetTextWidth(strsub(buffer, quit + 1, n.offsetEnd), charScale, charFont);
		end
		
		while (m <= #lineInfo) do
			n = lineInfo[m];
			m = m + 1;
		
			n.offset = n.offset - len;
			n.offsetEnd = n.offsetEnd - len;
		end
		
		-- Calculate the text dimensions
		textHeight = (#lineInfo + 1) * fontHeight;
		textWidth = 0;
		
		for m=1,#lineInfo do
			n = lineInfo[m];
			
			if (n.width > textWidth) then
				textWidth = n.width;
			end
		end
		
		-- Calculate the viewport
		editor.calculate();
		
		-- Now remove stuff
		buffer = strsub(buffer, 1, offset - 1) .. strsub(buffer, quit + 1, strlen(buffer));
		
        -- Update tokens.
        itemId = 1;
        
		if (enableColors) then
			colorId = 0;
        end

        -- Do the colors and items
        start = offset;
        term = quit;
        
        found = false;
        
        while (itemId <= #itemData) do
            n = itemData[itemId];
            curColor = n.color;
            
            if (n.offset - 1 <= quit) then
                if (curColor) then
                    colorId = colorId + 1;
                end
            
                if (n.offsetEnd + 1 >= offset) then
                    if (curColor) then
                        table.remove(colorData, colorId);
                        colorId = colorId - 1;
                    end
                    
                    table.remove(itemData, itemId);
                    
                    if (found == false) then
                        start = math.min(n.offset, offset);
                        
                        if (n.offsetEnd + 1 >= quit) then
                            term = n.offsetEnd + 1 - len;
                            break;
                        end
                        
                        found = true;
                    elseif (n.offsetEnd + 1 >= quit) then
                        term = n.offsetEnd - len;
                        break;
                    else
                        term = n.offsetEnd - len;
                    end
                else
                    itemId = itemId + 1;
                end
            elseif (found) then
                break;
            else
                start = 0;
                term = 0;
                break;
            end
        end
        
        m = itemId;
        
        while (m <= #itemData) do
            n = itemData[m];
            
            n.offset = n.offset - len;
            n.offsetEnd = n.offsetEnd - len;
            
            curColor = n.color;
            
            if (curColor) then
                curColor.offset = curColor.offset - len;
                curColor.offsetEnd = curColor.offsetEnd - len;
            end
            
            m = m + 1;
        end
			
        if (enableColors) then
            colorId = colorId + 1;
        
			generateColors();
		else
            generateItems();
        end
		
		return true;
	end
	
	function editor.removeText(off, len)
		if (off < 0) or (len < 0) then return false; end;
	
		local text = strsub(buffer, off, off + len - 1);
	
		editEntryRemove(off, text, 0);
		removeText(off, len);
		
		if (#buffer < cursor - 1) then
			cursor = #buffer + 1;
			
			updateCursor();
		end
		
		return true;
	end
	
	function editor.getIndentAtOffset(max)
		local token = itemData[1];
		local id = 1;
		local iTab = 0;
		local offset;
		
		while (id <= #itemData) and (token.offset < max) do
			local name = token.token;
		
			if (name == "function")
				or (name == "if")
				or (name == "do")
				or (name == "repeat") then
				
				iTab = iTab + 1;
			elseif (name == "end")
				or (name == "until") then
				iTab = iTab - 1;
			else
				if (name == "(") or (name == "[") or (name == "{") then
					iTab = iTab + 1;
				elseif (name == ")") or (name == "]") or (name == "}") then
					iTab = iTab - 1;
				end
			end
			
			id = id + 1;
			token = itemData[id];
		end
		
		return iTab, id;
	end
	
	function editor.setHighlight(offset, offsetEnd)
		if not (offset) then
			isHighlight = false;
			return true;
		end
	
		highlightStart, highlightEnd = offset, offsetEnd;
		
		isHighlight = true;
		return true;
	end
	
	function editor.getHighlight()
		if not (isHighlight) then return false; end;
	
		if (highlightStart > highlightEnd) then
			return highlightEnd, highlightStart - 1;
		elseif (highlightEnd > highlightStart) then
			return highlightStart, highlightEnd - 1;
		end
		
		return false;
	end

	local function tabOutLine(line, len)
		insertText(string.rep(" ", len), lineInfo[line].offset);
		return len;
	end

	function editor.scopeTabOut(start, term)
		local edit = {
			type = "multi_tabOut",
			time = 0,
			
			entries = {}
		};

		while (start <= term) do
			if (tabOutLine(start, 4)) then
				table.insert(edit.entries, {
					line = start,
					num = 4
				});
			end
			
			start = start + 1;
		end
		
		currentEditAction = currentEditAction + 1;
		
		while (editActions[currentEditAction]) do
			table.remove(editActions, currentEditAction);
		end
		
		table.insert(editActions, currentEditAction, edit);
	end

	local function tabInLine(line, len)
		local info = lineInfo[line];
		
		if (info.offset > info.offsetEnd) then return false; end;
		
		local m = strfind(buffer, "[^%s]", info.offset);
		
		if not (m) then return false; end;
		
		local n = math.min(len, m - info.offset);
		
		if (n == 0) then return false; end;

		removeText(info.offset, n);
		return n;
	end

	function editor.scopeTabIn(start, term)
		local edit = {
			type = "multi_tabIn",
			time = 0,
			
			entries = {}
		};
		
		while (start <= term) do
			local n = tabInLine(start, 4);
		
			if (n) then
				table.insert(edit.entries, {
					line = start,
					num = n
				});
			end
			
			start = start + 1;
		end
		
		currentEditAction = currentEditAction + 1;
		
		while (editActions[currentEditAction]) do
			table.remove(editActions, currentEditAction);
		end
		
		table.insert(editActions, currentEditAction, edit);
	end

	function editor.removeSpaces(pos, num)
		local rem, newPos;
		local m = 0;
		
		while (m < num) do
			if not (strbyte(buffer, pos - m - 1) == 32) then break; end;
			
			m = m + 1;
		end
		
		if (m == 0) then return false; end;
		
		newPos = pos - m;
		
		rem = strsub(buffer, pos, newPos - 1);
		
		editEntryRemove(newPos, rem, 0);
		removeText(newPos, m);
		return m;
	end
	
	function editor.getLineFromOffset(offset)
		local m,n;
		
		for m,n in ipairs(lineInfo) do
			if (n.offset <= offset) and (offset <= n.offsetEnd + 1) then
				return m;
			end
		end
		
		return false;
	end
	
	function editor.getLine(line)
		if (line < 1) or (line > #lineInfo) then return false; end;
		
		local info = lineInfo[line];
		
		return info.offset, info.offsetEnd, info.width;
	end
	
	function editor.setCursor(offset)
		cursor = math.max(1, math.min(#buffer + 1, offset));
		
		updateCursor();
		scanCursor();
		return true;
	end
	
	function editor.getCursor()
		return cursor;
	end
	
	-- Inline function for quick deletion
	local function deleteSelected()
		if (highlightStart > highlightEnd) then
			editEntryRemove(cursor, strsub(buffer, highlightEnd, highlightStart - 1), 0);
			removeText(cursor, highlightStart - highlightEnd);
		else
			cursor = highlightStart;
			
			updateCursor();
			
			editEntryRemove(cursor, strsub(buffer, highlightStart, highlightEnd - 1), 0);
			removeText(cursor, highlightEnd - highlightStart);
		end
		
		isHighlight = false;
	end
	
	function scrollpane.acceptInput()
		return true;
	end
	
	function scrollpane.keyInput(button, state)
		if not (state) then return true; end;
	
		local len = strlen(buffer);
		local n=1;
		local m;
		local lastBreak=1;
        
        local hierarchy = getHierarchy();
        
		if (button == "enter") then
			if (isDisabled()) then return false; end;
		
			destroyHint();
		
			if (isHighlight) then
				deleteSelected();
			end
		
			if (automaticIndentation) then
				local text;
				local tabCount = editor.getIndentAtOffset(cursor);
				
				text = "\n" .. string.rep("    ", tabCount);
				
				editEntryAdd(text, cursor, 0);
				
				insertText(text, cursor);
				
				cursor = cursor + strlen(text);
				
				updateCursor();
			else
				-- Add a edit entry
				editEntryAdd("\n", cursor, 0);
				
				insertText("\n", cursor);
				
				cursorLine = cursorLine + 1;
				cursorWidthOffset = 0;
				cursorArrangementWidth = 0;
				
				cursor = cursor + 1;
			end
			
			editor.scanCursor();
			cursorMoveTime = getTickCount();
		elseif (button == "backspace") then
			if (isDisabled()) then return false; end;
		
			destroyHint();
		
			if (isHighlight) then
				deleteSelected();
			else
				if (cursor == 1) then return true; end;
				
				local info = lineInfo[cursorLine];
				
				if (cursor == info.offset) then
					cursorLine = cursorLine - 1;
					
					info = lineInfo[cursorLine];
					
					cursor = info.offsetEnd + 1;
					
					cursorWidthOffset = info.width;
					cursorArrangementWidth = cursorWidthOffset;
					
					editEntryRemove(cursor, strsub(buffer, cursor, cursor), getTickCount());
					removeText(cursor, 1);
					
					editor.scanCursor();
					cursorMoveTime = getTickCount();
					return;
				end
				
				if (automaticIndentation) and (math.mod(cursor - info.offset, 4) == 0) and (strbyte(buffer, cursor - 1) == 32) then
					local n = 0;
					
					cursor = cursor - 1;
				
					while (n < 3) and (strbyte(buffer, cursor - 1) == 32) do
						n = n + 1;
						
						cursor = cursor - 1;
					end
					
					local rem = strsub(buffer, cursor, cursor + n);
					
					cursorWidthOffset = cursorWidthOffset - dxGetTextWidth(rem, charScale, charFont);
					cursorArrangementWidth = cursorWidthOffset;
					
					editEntryRemove(cursor, rem, getTickCount());
					removeText(cursor, strlen(rem));
					
					editor.scanCursor();
					cursorMoveTime = getTickCount();
					return;
				else
					cursor = cursor - 1;
				
					cursorWidthOffset = cursorWidthOffset - dxGetTextWidth(strsub(buffer, cursor, cursor), charScale, charFont);
					cursorArrangementWidth = cursorWidthOffset;
				end
				
				editEntryRemove(cursor, strsub(buffer, cursor, cursor), getTickCount());
				removeText(cursor, 1);
				
				editor.scanCursor();
			end
			
			cursorMoveTime = getTickCount();
		elseif (button == "tab") then
			if (isDisabled()) then return false; end;
		
			local info = lineInfo[cursorLine];
			
			destroyHint();
            
            -- Try handling a highlighting.
            do
                local hstart, hterm = editor.getHighlight();
                
                if (hstart) then
                    local lineStart = editor.getLineFromOffset(hstart);
                    local lineEnd = editor.getLineFromOffset(hterm);
                    
                    if (lineStart == lineEnd) then
                        if (hierarchy.getKeyState("lshift")) or (hierarchy.getKeyState("rshift")) then return true; end;
                    
                        removeText(start, hterm - hstart);
                        editEntryRemove(cursor, strsub(buffer, hstart, hterm), 0);
                        
                        editEntryAdd("    ", cursor, 0);
                        insertText("    ", cursor);
                        
                        cursor = hstart + 4;
                        
                        updateCursor();
                        editor.scanCursor();
                        
                        isHighlight = false;
                        return true;
                    end
                    
                    -- Update the highlight
                    highlightStart = lineInfo[lineStart].offset;
                    
                    if (hierarchy.getKeyState("lshift")) or (hierarchy.getKeyState("rshift")) then
                        editor.scopeTabIn(lineStart, lineEnd);
                    else
                        editor.scopeTabOut(lineStart, lineEnd);
                    end
                    
                    highlightEnd = lineInfo[lineEnd].offsetEnd + 1;
                    return true;
                end
            end
			
			local m = math.mod(cursor - info.offset, 4);
			
			if (m == 0) then
				if (hierarchy.getKeyState("lshift")) or (hierarchy.getKeyState("rshift")) then
					m = editor.removeSpaces(cursor, 4);
				
					if not (m) then return true; end;
					
					cursorWidthOffset = cursorWidthOffset - dxGetTextWidth(strrep(" ", m), charScale, charFont);
					cursorArrangementWidth = cursorWidthOffset;
					
					cursor = cursor - m;
				else
					editEntryAdd("    ", cursor, 0);
					insertText("    ", cursor);
					
					cursorWidthOffset = cursorWidthOffset + dxGetTextWidth("    ", charScale, charFont);
					cursorArrangementWidth = cursorWidthOffset;
					
					cursor = cursor + 4;
				end
			else
				if (hierarchy.getKeyState("lshift")) or (hierarchy.getKeyState("rshift")) then
					m = editor.removeSpaces(cursor, m);
					
					if not (m) then return true; end;
					
					cursorWidthOffset = cursorWidthOffset - dxGetTextWidth(strrep(" ", m), charScale, charFont);
					cursorArrangementWidth = cursorWidthOffset;
					
					cursor = cursor - m;
				else
					local addString = strrep(" ", 4 - m);
					
					editEntryAdd(addString, cursor, 0);
					insertText(addString, cursor);
					
					cursorWidthOffset = cursorWidthOffset + dxGetTextWidth(addString, charScale, charFont);
					cursorArrangementWidth = cursorWidthOffset;
					
					cursor = cursor + strlen(addString);
				end
			end
		
			editor.scanCursor();
			cursorMoveTime = getTickCount();
		elseif (button == "arrow_l") then
			destroyHint();
            
            isHighlight = false;
		
			cursorMoveTime = getTickCount();
		
			if (cursor == 1) then return true; end;
			
			local info = lineInfo[cursorLine];
			
			if (info.offset == cursor) then
				cursorLine = cursorLine - 1;
				
				info = lineInfo[cursorLine];
				
				cursor = info.offsetEnd + 1;
				
				cursorWidthOffset = info.width;
				cursorArrangementWidth = cursorWidthOffset;
			else
				cursor = cursor - 1;
			
				cursorWidthOffset = cursorWidthOffset - dxGetTextWidth(strsub(buffer, cursor, cursor), charScale, charFont);
				cursorArrangementWidth = cursorWidthOffset;
			end
			
			editor.scanCursor();
		elseif (button == "arrow_r") then
			cursorMoveTime = getTickCount();
		
			destroyHint();
            
            isHighlight = false;
			
			if (cursor == strlen(buffer) + 1) then return true; end;
			
			local info = lineInfo[cursorLine];
			
			if (cursor == info.offsetEnd + 1) then
				cursorLine = cursorLine + 1;
				
				cursorWidthOffset = 0;
				cursorArrangementWidth = 0;
				
				cursor = lineInfo[cursorLine].offset;
			else
				cursorWidthOffset = cursorWidthOffset + dxGetTextWidth(strsub(buffer, cursor, cursor), charScale, charFont);
				cursorArrangementWidth = cursorWidthOffset;
				
				cursor = cursor + 1;
			end
			
			editor.scanCursor();
		elseif (button == "arrow_u") then
			cursorMoveTime = getTickCount();
			
			destroyHint();
            
            isHighlight = false;
		
			if (cursorLine == 1) then
				cursor = 1;
				
				cursorWidthOffset = 0;
				cursorArrangementWidth = 0;
			else
				local offset;
				local info;
			
				cursorLine = cursorLine - 1;
				info = lineInfo[cursorLine];
				
				offset, cursorWidthOffset = getTextLogicalOffset(strsub(buffer, info.offset, info.offsetEnd), cursorArrangementWidth, charScale, charFont);
				
				cursor = info.offset + offset - 1;
			end
		
			editor.scanCursor();
		elseif (button == "arrow_d") then
			cursorMoveTime = getTickCount();
			
			destroyHint();

            isHighlight = false;
		
			if (cursorLine == #lineInfo) then
				local info = lineInfo[cursorLine];
			
				cursor = info.offsetEnd + 1;
				
				cursorWidthOffset = info.width;
				cursorArrangementWidth = cursorWidthOffset;
			else
				local offset;
				local info;
				
				cursorLine = cursorLine + 1;
				info = lineInfo[cursorLine];
				
				offset, cursorWidthOffset = getTextLogicalOffset(strsub(buffer, info.offset, info.offsetEnd), cursorArrangementWidth, charScale, charFont);
				
				cursor = info.offset + offset - 1;
			end
		
			editor.scanCursor();
		elseif (button == "insert") then
			if (isDisabled()) then return false; end;
		
			local text = parseScript(getClipboard());
			
			if (strlen(text) == 0) then return true; end;
			
			if (isHighlight) then
				deleteSelected();
			end
			
			insertText(text, cursor);
			
			editEntryAdd(text, cursor, 0);
			
			cursor = cursor + strlen(text);
			
			updateCursor();
		elseif (button == "delete") then
			if (isDisabled()) then return false; end;
		
			if (isHighlight) then
				deleteSelected();
				
				updateCursor();
			elseif not (cursor == strlen(buffer) + 1) then
				editEntryRemove(cursor, strsub(buffer, cursor, cursor), getTickCount());
			
				removeText(cursor, 1);
				
				cursorMoveTime = getTickCount();
			end
			
			editor.scanCursor();
		elseif (hierarchy.getKeyState("lctrl")) or (hierarchy.getKeyState("rctrl")) then
			if (button == "z") then
				if (isDisabled()) then return false; end;
				if (#editActions == 0) then return true; end
				if (currentEditAction == 0) then return false; end;
				
				local action = editActions[currentEditAction];
				currentEditAction = currentEditAction - 1;
				
				if (action.type == "add") then
					removeText(action.offset, strlen(action.text));
					
					cursor = action.offset;
				elseif (action.type == "remove") then
					insertText(action.text, action.offset);
					
					cursor = action.offset + strlen(action.text);
				elseif (action.type == "multi_tabOut") then
					local m,n;
					
					for m,n in ipairs(action.entries) do
						tabInLine(n.line, n.num);
					end
				elseif (action.type == "multi_tabIn") then
					local m,n;
					
					for m,n in ipairs(action.entries) do
						tabOutLine(n.line, n.num);
					end
				end
				
				-- I do not mess around with the highlight yet
				isHighlight = false;
				
				-- Update cursor
				updateCursor();
				
				editor.scanCursor();
			elseif (button == "y") then
				if (isDisabled()) then return false; end;
				if (#editActions == 0) then return true; end
				if (currentEditAction == #editActions) then return false; end
				
				currentEditAction = currentEditAction + 1;
				local action = editActions[currentEditAction];
				
				if (action.type == "add") then
					insertText(action.text, action.offset);
					
					cursor = action.offset + strlen(action.text);
				elseif (action.type == "remove") then
					removeText(action.offset, strlen(action.text));
					
					cursor = action.offset;
				elseif (action.type == "multi_tabOut") then
					local m,n;
					
					for m,n in ipairs(action.entries) do
						tabOutLine(n.line, n.num);
					end
				elseif (action.type == "multi_tabIn") then
					local m,n;
					
					for m,n in ipairs(action.entries) do
						tabInLine(n.line, n.num);
					end
				end
				
				-- I do not mess around with the highlight yet
				isHighlight = false;
				
				-- Update cursor
				updateCursor();
				
				editor.scanCursor();
			elseif (button == "a") then
				if (isHighlighting) then return false; end;
				
				highlightStart = 1;
				highlightEnd = strlen(buffer) + 1;
				
				isHighlight = true;
			elseif (button == "c") then
				if not (isHighlight) then return false; end;
			
				setClipboard(strsub(buffer, editor.getHighlight()));
			elseif (button == "v") then
				if (isDisabled()) then return false; end;
			
				local text = parseScript(getClipboard());
				
				if (strlen(text) == 0) then return true; end;
				
				if (isHighlight) then
					deleteSelected();
				end
				
				insertText(text, cursor);
				
				editEntryAdd(text, cursor, 0);
				
				cursor = cursor + strlen(text);
				
				updateCursor();
			elseif (button == "p") then
				if (isDisabled()) then return false; end;
			
				showPasteGUI(true, editor);
			elseif (button == "x") then
				if (isDisabled()) then return false; end;
				if not (isHighlight) then return true; end;
				
				setClipboard(strsub(buffer, editor.getHighlight()));
				
				deleteSelected();
				
				cursorMoveTime = getTickCount();
			elseif (button == "d") then
				outputDebugString([[
					Debug Info
					Colors: ]] .. #colorData .. "\n" .. [[
					Items: ]] .. #itemData .. "\n" .. [[
				]]);
			elseif (button == "l") then
				local line = editor.getLineFromOffset(cursor);
				local begin, term = editor.getLine(line);
				local str = strsub(buffer, begin, term);

				outputDebugString("(" .. line .. "): " .. str .. "(" .. begin .. ", " .. term .. ")");
				
				local lchr = strbyte(str, #str);
				
				if (lchr) then
					outputDebugString("lchr: " .. lchr);
				end
			elseif (button == "home") then
				setViewOffset(0, 0);
				
				cursor = 1;
				
				cursorLine = 1;
				cursorWidthOffset = 0;
				cursorArrangementWidth = 0;
				
				cursorMoveTime = getTickCount();
			elseif (button == "end") then
				local viewX, viewY = scrollpane.getViewOffset();
				setViewOffset(viewX, textHeight - height);
				
				cursor = strlen(buffer) + 1;
				
				cursorLine = #lineInfo;
				cursorWidthOffset = lineInfo[cursorLine].width;
				cursorArrangementWidth = cursorWidthOffset;
				
				cursorMoveTime = getTickCount();
			end
		elseif (button == "home") then
			local info = lineInfo[cursorLine];
		
			cursor = strfind(buffer, "[^%s]", info.offset);
			
			if not (cursor) or (cursor == info.offsetEnd + 1) then
				cursor = info.offset;
			end
			
			cursorWidthOffset = dxGetTextWidth(strsub(buffer, info.offset, cursor - 1), charScale, charFont);
			cursorArrangementWidth = cursorWidthOffset;
			
			editor.scanCursor();
			cursorMoveTime = getTickCount();
		elseif (button == "end") then
			local info = lineInfo[cursorLine];
			
			cursor = info.offsetEnd + 1;
			
			cursorWidthOffset = info.width;
			cursorArrangementWidth = cursorWidthOffset;
			
			editor.scanCursor();
			cursorMoveTime = getTickCount();
		end
		
		return true;
	end
	
	function editor.keyInput(...)
		return scrollpane.keyInput(...);
	end
	
	function scrollpane.input(char)
		if (isDisabled()) then return; end;
	
		if (isHighlight) then
			deleteSelected();
		end
		
		editEntryAdd(char, cursor, getTickCount());
		insertText(char, cursor);
		
		if (automaticIndentation) then
			local n = 1;
			local info = lineInfo[cursorLine];
			local iTab, id = editor.getIndentAtOffset(info.offset);
			local item = itemData[id];

            if (item) then
                if (iTab > 0) and (item.offsetEnd == cursor) then
                    local token = item.token;
                    
                    if ((token == "end") or
                        (token == ")") or
                        (token == "}") or
                        (token == "]")) or
                        (token == "until") then
                        
                        local offset = item.offset - info.offset - (iTab - 1) * 4;
                        
                        if (offset > 0) then
                            local rem = strrep(" ", offset);
                        
                            removeText(info.offset, offset);
                            editEntryRemove(info.offset, rem, 0);
                            
                            cursorWidthOffset = cursorWidthOffset - dxGetTextWidth(rem, charScale, charFont);
                        elseif (offset < 0) then
                            local insert = strrep(" ", -offset);
                        
                            insertText(insert, info.offset);
                            editEntryAdd(insert, info.offset, 0);
                            
                            cursorWidthOffset = cursorWidthOffset + dxGetTextWidth(insert, charScale, charFont);
                        end
                        
                        cursor = cursor - offset;
                    end
                end
            end
		end
		
		cursor = cursor + 1;
		
		cursorWidthOffset = cursorWidthOffset + dxGetTextWidth(char, charScale, charFont);
		cursorArrangementWidth = cursorWidthOffset;
		
		cursorMoveTime = getTickCount();
		
		-- Readjust
		editor.scanCursor();
		return true;
	end
	
	function editor.input(...)
		return scrollpane.input(...);
	end
	
	function editor.render()
		local offY;
		local line;
	
		dxDrawRectangle(0, 0, width, height, tocolor(70, 70, 70, 255));

		if not (lineNumbers) then return super(); end;
		
		if (lineBarChanged) then
			local viewX, viewY = getViewOffset();
			local maxLine = math.min(1 + (viewY + height) / fontHeight, #lineInfo);
		
			dxSetRenderTarget(lineBarTarget);
		
			-- Render the line bar
			dxDrawRectangle(0, 0, lineBarWidth, height, tocolor(120, 120, 120, 255));
			
			offY = 0;
			line = 1 + viewY / fontHeight;
			
			while (line <= maxLine) do
				local drawString = tostring(line);

				dxDrawText(drawString, lineBarWidth - dxGetTextWidth(drawString, charScale, charFont) - 10, offY, 0, 0, tocolor(255, 255, 255, 255), charScale, charFont);
			
				offY = offY + fontHeight;
				line = line + 1;
			end
			
			resetRenderTarget();
			
			lineBarChanged = false;
		end
	
		dxDrawImage(0, 0, lineBarWidth, height, lineBarTarget);
		return super();
	end
	
	function highlightArea.render()
		local offY;
		local viewX, viewY = getViewOffset();
		local start, term = editor.getHighlight();
		local maxLine = math.min(1 + (viewY + height) / fontHeight, #lineInfo);
	
		-- Do that highlighting
		if (start) then
			local line = 1 + viewY / fontHeight;
			local info = lineInfo[line];
			
			offY = 0;
		
			while (line < maxLine) do
				if (info.offsetEnd + 1 >= start) then
					break;
				end
				
				line = line + 1;
				info = lineInfo[line];
				
				offY = offY + fontHeight;
			end
			
            if (term >= info.offset) then
                if (term >= info.offsetEnd + 1) then
                    local width = dxGetTextWidth(strsub(buffer, start, info.offsetEnd), charScale, charFont);
                
                    dxDrawRectangle(info.width - width - viewX, offY, width + 8, fontHeight, highlightColor);
                    
                    line = line + 1;
                    offY = offY + fontHeight;
                    
                    info = lineInfo[line];
                    
                    while (line < maxLine) and (term > info.offsetEnd) do
                        dxDrawRectangle(-viewX, offY, info.width + 8, fontHeight, highlightColor);
                        
                        line = line + 1;
                        info = lineInfo[line];
                        
                        offY = offY + fontHeight;
                    end
                    
                    dxDrawRectangle(-viewX, offY, dxGetTextWidth(strsub(buffer, info.offset, term), charScale, charFont), fontHeight, highlightColor);
                else
                    dxDrawRectangle(
                        dxGetTextWidth(strsub(buffer, info.offset, start - 1), charScale, charFont) - viewX,
                        offY,
                        dxGetTextWidth(strsub(buffer, math.max(start, info.offset), term), charScale, charFont),
                        fontHeight, highlightColor
                    );
                end
            end
		end
		
		-- Determine whether we render the cursor
		if (math.mod(math.floor((getTickCount() - cursorMoveTime) / 500), 2) == 0) then
			offY = (cursorLine - (1 + viewY / fontHeight)) * fontHeight;
			
			dxDrawLine(cursorWidthOffset - viewX, offY,  cursorWidthOffset - viewX, offY + fontHeight, textColor);
		end
		
		super();
		update();
		return true;
	end
	
	function scrollpane.enable()
		scrollpane.update();
	end
	
	function scrollpane.disable()
		scrollpane.update();
	end
	
	function scrollpane.renderArea()
		local offY = 0;
		local viewX, viewY = getViewOffset();
		local curLine = 1 + viewY / fontHeight;
		local maxLine = math.min(1 + (viewY + height) / fontHeight, #lineInfo);
		local len = #buffer;
		local line = curLine;
		local renderCursor;
		local cinfo = colorData[1];
		local curColor = 1;
        local buffer = buffer;
        local strsub = strsub;
        local dxDrawText = dxDrawText;
        local dxDrawRectangle = dxDrawRectangle;
        local dxGetTextWidth = dxGetTextWidth;
		
		if (isDisabled()) then
			dxDrawRectangle(0, 0, width, height, disableBgColor);
		else
			dxDrawRectangle(0, 0, width, height, bgColor);
		end
		
		-- Walk colors until we reach the first one in sight
		while (cinfo) and (cinfo.offsetEnd < lineInfo[line].offset) do
			curColor = curColor + 1;
			
			cinfo = colorData[curColor];
		end
        
		-- Render text
		while (line <= maxLine) do
			-- Render the line here
			local info = lineInfo[line];
			local lineStart = info.offset;
			local lineEnd = info.offsetEnd;
			
			if (cinfo) then
				if (cinfo.offsetEnd > lineEnd) then
					if (cinfo.offset <= lineEnd) then
						if (cinfo.offset <= lineStart) then
							if (cinfo.backColor) then
								dxDrawRectangle(-viewX, offY, textWidth + width, fontHeight, cinfo.backColor);
							end
							dxDrawText(strsub(buffer, lineStart, lineEnd), -viewX, offY, 0, 0, cinfo.textColor, charScale, charFont);
						else
							local renderLine = strsub(buffer, lineStart, cinfo.offset-1);
							local offset = dxGetTextWidth(renderLine, charScale, charFont);
							
							dxDrawText(renderLine, -viewX, offY, 0, 0, textColor, charScale, charFont);
							
							renderLine = strsub(buffer, cinfo.offset, lineEnd);
							
							if (cinfo.backColor) then
								dxDrawRectangle(offset - viewX, offY, textWidth + width, fontHeight, cinfo.backColor);
							end
							dxDrawText(renderLine, offset - viewX, offY, 0, 0, cinfo.textColor, charScale, charFont);
						end
					else
						dxDrawText(strsub(buffer, lineStart, lineEnd), -viewX, offY, 0, 0, textColor, charScale, charFont);
					end
				else
					local colorOffset;
					local renderLine;
					
					if (cinfo.offset < lineStart) then
						renderLine = strsub(buffer, lineStart, cinfo.offsetEnd);
						
						if (cinfo.backColor) then
							local width = dxGetTextWidth(renderLine, charScale, charFont);
						
							dxDrawRectangle(-viewX, offY, width, fontHeight, cinfo.backColor);
							dxDrawText(renderLine, -viewX, offY, 0, 0, cinfo.textColor, charScale, charFont);
							
							colorOffset = width;
						else
							dxDrawText(renderLine, -viewX, offY, 0, 0, cinfo.textColor, charScale, charFont);
							
							colorOffset = dxGetTextWidth(renderLine, charScale, charFont);
						end
						
						if (curColor == #colorData) then
							if not (cinfo.offsetEnd == lineEnd) then
								dxDrawText(strsub(buffer, cinfo.offsetEnd+1, lineEnd), colorOffset - viewX, offY, 0, 0, textColor, charScale, charFont);
							end
							
							cinfo = false;
						else
							curColor = curColor + 1;
						
							local newInfo = colorData[curColor];
							
							while (newInfo.offsetEnd <= lineEnd) do
								if not (cinfo.offsetEnd+1 == newInfo.offset) then
									renderLine = strsub(buffer, cinfo.offsetEnd+1, newInfo.offset-1);
									
									dxDrawText(renderLine, colorOffset - viewX, offY, 0, 0, textColor, charScale, charFont);
									colorOffset = colorOffset + dxGetTextWidth(renderLine, charScale, charFont);
								end
								
								renderLine = strsub(buffer, newInfo.offset, newInfo.offsetEnd);
								
								if (newInfo.backColor) then
									local width = dxGetTextWidth(renderLine, charScale, charFont);
								
									dxDrawRectangle(colorOffset - viewX, offY, width, fontHeight, newInfo.backColor);
									dxDrawText(renderLine, colorOffset - viewX, offY, 0, 0, newInfo.textColor, charScale, charFont);
									
									colorOffset = colorOffset + width;
								else
									dxDrawText(renderLine, colorOffset - viewX, offY, 0, 0, newInfo.textColor, charScale, charFont);
									
									colorOffset = colorOffset + dxGetTextWidth(renderLine, charScale, charFont);
								end
								
								if (curColor == #colorData) then
									if not (newInfo.offsetEnd == lineEnd) then
										dxDrawText(strsub(buffer, newInfo.offsetEnd+1, lineEnd), colorOffset - viewX, offY, 0, 0, textColor, charScale, charFont);
									end
								
									cinfo = false;
									newInfo = false;
									break;
								end
								
								curColor = curColor + 1;
								
								cinfo = newInfo;
								newInfo = colorData[curColor];
							end
							
							if (cinfo) and not (cinfo.offsetEnd == lineEnd) then
								if (newInfo.offset < lineEnd) then
									if not (cinfo.offsetEnd == newInfo.offset+1) then
										renderLine = strsub(buffer, cinfo.offsetEnd+1, newInfo.offset-1);
									
										dxDrawText(renderLine, colorOffset - viewX, offY, 0, 0, textColor, charScale, charFont);
										
										colorOffset = colorOffset + dxGetTextWidth(renderLine, charScale, charFont);
									end
									
									renderLine = strsub(buffer, newInfo.offset, lineEnd);
									
									if (newInfo.backColor) then
										dxDrawRectangle(colorOffset - viewX, offY, dxGetTextWidth(renderLine, charScale, charFont), fontHeight, newInfo.backColor);
									end
									
									dxDrawText(renderLine, colorOffset - viewX, offY, 0, 0, newInfo.textColor, charScale, charFont);
								else
									dxDrawText(strsub(buffer, cinfo.offsetEnd+1, lineEnd), colorOffset - viewX, offY, nil, nil, textColor, charScale, charFont);
								end
							end
							
							cinfo = newInfo;
						end
					elseif (cinfo.offset > lineEnd) then
						dxDrawText(strsub(buffer, lineStart, lineEnd), -viewX, offY, 0, 0, textColor, charScale, charFont);
					else
						local n = lineStart;
						colorOffset = 0;
						
						repeat
							if not (n == cinfo.offset) then
								renderLine = strsub(buffer, n, cinfo.offset-1);
								
								dxDrawText(renderLine, colorOffset - viewX, offY, 0, 0, textColor, charScale, charFont);
								colorOffset = colorOffset + dxGetTextWidth(renderLine, charScale, charFont);
							end
							
							renderLine = strsub(buffer, cinfo.offset, cinfo.offsetEnd);
							
							if (cinfo.backColor) then
								local width = dxGetTextWidth(renderLine, charScale, charFont);
							
								dxDrawRectangle(colorOffset - viewX, offY, width, fontHeight, cinfo.backColor);
								dxDrawText(renderLine, colorOffset - viewX, offY, 0, 0, cinfo.textColor, charScale, charFont);
								
								colorOffset = colorOffset + width;
							else
								dxDrawText(renderLine, colorOffset - viewX, offY, 0, 0, cinfo.textColor, charScale, charFont);
								
								colorOffset = colorOffset + dxGetTextWidth(renderLine, charScale, charFont);
							end
							
							if (curColor == #colorData) then
								if not (cinfo.offsetEnd == lineEnd) then
									dxDrawText(strsub(buffer, cinfo.offsetEnd+1, lineEnd), colorOffset - viewX, offY, 0, 0, textColor, charScale, charFont);
								end
							
								cinfo = false;
								break;
							end
							
							curColor = curColor + 1;
							
							n = cinfo.offsetEnd+1;
							cinfo = colorData[curColor];
						until (cinfo.offsetEnd > lineEnd);
						
						if (cinfo) and not (cinfo.offsetEnd == lineEnd) then
							if (cinfo.offset <= lineEnd) then
								if not (n == cinfo.offset) then
									renderLine = strsub(buffer, n, cinfo.offset-1);
								
									dxDrawText(renderLine, colorOffset - viewX, offY, 0, 0, textColor, charScale, charFont);
									
									colorOffset = colorOffset + dxGetTextWidth(renderLine, charScale, charFont);
								end
								
								renderLine = strsub(buffer, cinfo.offset, lineEnd);
								
								if (cinfo.backColor) then
									dxDrawRectangle(colorOffset - viewX, offY, dxGetTextWidth(renderLine, charScale, charFont), fontHeight, cinfo.backColor);
								end
								
								dxDrawText(renderLine, colorOffset - viewX, offY, 0, 0, cinfo.textColor, charScale, charFont);
							else
								dxDrawText(strsub(buffer, n, lineEnd), colorOffset - viewX, offY, 0, 0, textColor, charScale, charFont);
							end
						end
					end
				end
			else
				dxDrawText(strsub(buffer, lineStart, lineEnd), -viewX, offY, 0, 0, textColor, charScale, charFont);
			end
		
			offY = offY + fontHeight;
			line = line + 1;
		end
		
		return super();
	end
	
	function editor.events.onRender()
		update();
		return true;
	end
	
	function editor.invalidate()
		lineBarChanged = true;
	end
	
	function editor.destroy()
		editors[editor] = nil;
	end
	
	-- Setup the editor
	editor.setText("");
	
	editors[editor] = editor;
	return editor;
end

function isEditor(element)
	return not (editors[element] == nil);
end