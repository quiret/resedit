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
local _G = _G;

hint = false;

local function createHint(parent)
	destroyHint();

	hint = createDXElement("hint", parent);
	
	if not (hint) then return false; end;
	
	local text = "";
	local lineData;
	local fontScale = 1;
	local font = "default";
	local fontHeight;
	local fontColor;
	local font_r, font_g, font_b;
	local backgroundColor;
	local bg_r, bg_g, bg_b;
	
	-- Hints are always on top
	hint.setCaptiveMode(false);
	hint.setAlwaysOnTop(true);

	function hint.recalculate()
		local screenW, screenH = getScreenSize();
	
		lineData = structureString(text, screenW - x - 50, screenW - x - 50, fontScale, font);
	
		fontHeight = dxGetFontHeight(fontScale, font);
	
		setSize(lineData.width + 10, lineData.height + 10);
		return true;
	end
	hint.recalculate();
	
	function hint.setFont(scale, fontType)
		fontScale, font = scale, fontType;
		
		recalculate();
		update();
		return true;
	end
	
	function hint.getFont()
		return fontScale, font;
	end
	
	function hint.setTextColor(r, g, b)
		fontColor = tocolor(r, g, b, 0xFF);
		
		font_r, font_g, font_b = r, g, b;
		
		update();
		return true;
	end
	
	function hint.resetTextColor()
		setTextColor(0, 0, 0);
	end
	hint.resetTextColor();
	
	function hint.getTextColor()
		return font_r, font_g, font_b;
	end
	
	function hint.setBackgroundColor(r, g, b)
		backgroundColor = tocolor(r, g, b, 255);
		
		bg_r, bg_g, bg_b = r, g, b;
		
		update();
		return true;
	end
	
	function hint.resetBackgroundColor()
		setBackgroundColor(225, 225, 225);
	end
	hint.resetBackgroundColor();
	
	function hint.getBackgroundColor()
		return backgroundColor;
	end
	
	function hint.setPosition(x, y)
		if not (super(x, y)) then return false; end;
		
		recalculate();
		return true;
	end
	
	function hint.setText(t)
		text = t;
		
		recalculate();
		
		update();
		return true;
	end
	
	function hint.cbUpdate()
		return true;
	end
	
	function hint.hide()
		destroy();
	end
	
	function hint.render()
		local n, line;
		local y = 0;
		
		dxDrawRectangle(0, 0, width, height, tocolor(0x80, 0x80, 0x80, 0xFF));
		dxDrawRectangle(1, 1, width - 2, height - 2, backgroundColor);
		
		for n=1,#lineData.lines do
			line = lineData.lines[n];
			
			if not (strlen(line) == 0) then
				dxDrawText(line, 5, 5 + y, 0, 0, tocolor(0x00, 0x00, 0x00, 0xFF));
			end
			
			y = y + fontHeight;
		end
		
		return super();
	end
	
	function hint.present()
		cbUpdate();
		return super();
	end
	
	function hint.destroy()
		_G.hint = false;
		
		lineData = nil;
	end
	
	hint.setText("");
	return hint;
end

function destroyHint()
	if not (hint) then return true; end;
	
	hint.destroy();
	return true;
end

function showHint(x, y, text, charScale, charFont)
	destroyHint();
	
	if not (charScale) then
		charScale = 1;
	end
	
	if not (charFont) then
		charFont = "default";
	end
	
	hint = createHint();
	hint.setPosition(x, y);
	hint.setFont(charScale, charFont);
	hint.setText(text);
	
	function hint.mouseclick()
		destroy();
	end
	
	return hint;
end

function showCursorHint(text)
	local hint = showHint(mouseX + 1, mouseY + 1, text);
	local now = getTickCount();
	
	function hint.cbUpdate()
		if (getTickCount() - now > 2500) then
			destroy();
			return false;
		end
	
		setPosition(mouseX + 2, mouseY + 2);
		return true;
	end
	
	return true;
end