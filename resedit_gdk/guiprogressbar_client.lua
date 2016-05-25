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

function createProgressBar(parent)
	local bar = createDXElement("progressbar", parent);
	
	if not (bar) then return false; end;
	
	local progress = 0;
	local bg_r, bg_g, bg_b;
	local bgColor;
	local outline_r, outline_g, outline_b;
	local outlineColor;
	
	function bar.setBackgroundColor(r, g, b)
		if (bg_r == r) and (bg_g == g) and (bg_b == b) then return true; end;
		
		bg_r, bg_g, bg_b = r, g, b;
		bgColor = tocolor(r, g, b);
		
		update();
		return true;
	end
	bar.setBackgroundColor(0, 0, 0);
	
	function bar.getBackgroundColor()
		return bg_r, bg_g, bg_b;
	end
	
	function bar.setOutlineColor(r, g, b)
		if (outline_r == r) and (outline_g == g) and (outline_b == b) then return true; end;
		
		outline_r, outline_g, outline_b = r, g, b;
		outlineColor = tocolor(r, g, b);
		
		update();
		return true;
	end
	bar.setOutlineColor(255, 255, 255);
	
	function bar.getOutlineColor()
		return outline_r, outline_g, outline_b;
	end
	
	function bar.setProgress(perc)
		if (progress == perc) then return true; end;
		
		progress = math.min(1, math.max(0, perc));
		
		update();
		return true;
	end
	
	function bar.getProgress()
		return progress;
	end
	
	function bar.render()
		dxDrawRectangle(0, 0, width, height, outlineColor);
		dxDrawRectangle(1, 1, width - 2, height - 2, bgColor);
		
		dxDrawRectangle(2, 2, (width - 4) * progress, height - 4, outlineColor);
		return super();
	end
	
	return bar;
end