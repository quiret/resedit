-- Optimizations
local dxGetFontHeight = dxGetFontHeight;
local dxGetTextWidth = dxGetTextWidth;
local dxDrawText = dxDrawText;
local dxDrawRectangle = dxDrawRectangle;
local tocolor = tocolor;
local ipairs = ipairs;
local pairs = pairs;

local checkboxes = {};
local checkTex = gdkLoadTexture("images/check.png");

function createCheckBox(parent)
	local checkbox = createDXElement("checkbox", parent);
	
	if not (checkbox) then return false; end;
	
	local checked = false;
	local text = "";
	local font, fontScale = "sans", 1;
	local fontHeight = dxGetFontHeight(fontScale, font);
	local text_r, text_g, text_b;
	local textColor;
	local bg_r, bg_g, bg_b;
	local bgColor;
	local hover_r, hover_g, hover_b;
	local hoverColor;
	
	checkbox.supportAlpha(true);
	
	function checkbox.setChecked(enabled)
		if (checked == enabled) then return true; end;
		
		checked = enabled;
		
		update();
		return true;
	end
	
	function checkbox.isChecked()
		return checked;
	end
	
	function checkbox.setText(buf)
		text = buf;
		
		update();
		return true;
	end
	
	function checkbox.getText()
		return text;
	end
	
	function checkbox.setFont(scale, type)
		fontScale, font = scale, type;
		
		fontHeight = dxGetFontHeight(fontScale, font);
		
		update();
		return true;
	end
	
	function checkbox.getFont()
		return fontScale, font;
	end
	
	function checkbox.setTextColor(r, g, b)
		textColor = tocolor(r, g, b, 255);
	
		text_r, text_g, text_b = r, g, b;
		
		update();
		return true;
	end
	
	function checkbox.resetTextColor()
		setTextColor(0xFF, 0xFF, 0xFF);
	end
	checkbox.resetTextColor();
	
	function checkbox.getTextColor()
		return text_r, text_g, text_b;
	end
	
	function checkbox.setBackgroundColor(r, g, b)
		bgColor = tocolor(r, g, b, 255);
		
		bg_r, bg_g, bg_b = r, g, b;
		
		update();
		return true;
	end
	
	function checkbox.resetBackgroundColor()
		setBackgroundColor(0xFF, 0xFF, 0xFF);
	end
	checkbox.resetBackgroundColor();
	
	function checkbox.getBackgroundColor()
		return bg_r, bg_g, bg_b;
	end
	
	function checkbox.setHoverColor(r, g, b)
		hoverColor = tocolor(r, g, b, 255);
		
		hover_r, hover_g, hover_b = r, g, b;
		
		update();
		return true;
	end
	
	function checkbox.resetHoverColor()
		setHoverColor(0xC0, 0xC0, 0xC0);
	end
	checkbox.resetHoverColor();
	
	function checkbox.getHoverColor()
		return hover_r, hover_g, hover_b;
	end
	
	function checkbox.mouseenter()
		update();
	end
	
	function checkbox.mouseleave()
		update();
	end
	
	function checkbox.mouseclick(button, state)
		if (isDisabled()) then return; end;
		if not (button == "left") or not (state) then return; end;
		
		checked = not checked;
		
		update();
	end
	
	function checkbox.render()
		local imgDim = fontHeight + 1;
		local color;
		
		if (isMouseActive()) then
			color = hoverColor;
		else
			color = bgColor;
		end
		
		dxDrawRectangle(0, 0, imgDim, imgDim, color);
		
		if (checked) then
            if (checkTex) then
                dxDrawImage(1, 1, imgDim - 2, imgDim - 2, checkTex);
            else
                -- Improvise! We failed to load the texture, tho the user must know
                -- Whether we are checked.
                dxDrawRectangle(2, 2, imgDim - 2, imgDim - 2, tocolor(0, 0, 0, 0x20));
            end
		end
		
		dxDrawText(text, imgDim + 10, 0, 0, 0, textColor, fontScale, font);
		return super();
	end
	
	function checkbox.destroy()
		checkboxes[checkbox] = nil;
	end
	
	checkboxes[checkbox] = true;
	return checkbox;
end

function isCheckBox(element)
	return not (checkboxes[element] == nil);
end