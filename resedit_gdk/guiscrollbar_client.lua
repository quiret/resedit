-- Optimizations
local dxGetFontHeight = dxGetFontHeight;
local dxGetTextWidth = dxGetTextWidth;
local dxDrawText = dxDrawText;
local dxDrawRectangle = dxDrawRectangle;
local tocolor = tocolor;
local strlen = string.len;
local math = math;
local max = math.max;
local min = math.min;
local ipairs = ipairs;
local pairs = pairs;
local collectgarbage = collectgarbage;

local scrollbars = {};
local function addEvents(elem)
	elem.addEvent("onScroll");
	elem.addEvent("onScrollEnd");
end
addEvents(dxRoot);

-- Check for file existance to prevent warnings.
-- If you install this dx GUI element, make sure you place
-- the arrow texture properly (in the root folder of the resource).
local gdkLoadTexture = gdkLoadTexture;

-- The arrow textures may not exist; then these variables are set to false.
-- Rendering has to take that into account!
local arrow_u = gdkLoadTexture("images/arrow_u.png");
local arrow_r = gdkLoadTexture("images/arrow_r.png");
local arrow_d = gdkLoadTexture("images/arrow_d.png");
local arrow_l = gdkLoadTexture("images/arrow_l.png");

local function createScrollbar(parent)
	local scrollbar = createDXElement("scrollbar", parent);
	local bg_r, bg_g, bg_b;
	local bgColor;
	local frame_r, frame_g, frame_b;
	local frameColor;
	local drag_r, drag_g, drag_b;
	local dragColor;
	local slider_r, slider_g, slider_b;
	local sliderColor;
	local bBg_r, bBg_g, bBg_b;
	local buttonBgColor;
	local button_r, button_g, button_b;
	local buttonColor;
	local buttonDownColor;
	
	if not (scrollbar) then return false; end;
	
	-- Add events locally
	addEvents(scrollbar);
	
	function scrollbar.setBackgroundColor(r, g, b)
		bgColor = tocolor(r, g, b, 255);
		
		bg_r, bg_g, bg_b = r, g, b;
		
		update();
		return true;
	end
	
	function scrollbar.resetBackgroundColor()
		setBackgroundColor(0x10, 0x10, 0x25);
	end
	scrollbar.resetBackgroundColor();
	
	function scrollbar.getBackgroundColor()
		return bg_r, bg_g, bg_b;
	end
	
	function scrollbar.setFrameColor(r, g, b)
		frameColor = tocolor(r, g, b, 255);
		
		frame_r, frame_g, frame_b = r, g, b;
		
		update();
		return true;
	end
	
	function scrollbar.resetFrameColor()
		setFrameColor(0x00, 0x20, 0x70);
	end
	scrollbar.resetFrameColor();
	
	function scrollbar.getFrameColor()
		return frame_r, frame_g, frame_b;
	end
	
	function scrollbar.setSliderColor(r, g, b)
		sliderColor = tocolor(r, g, b, 255);
		
		slider_r, slider_g, slider_b = r, g, b;
		
		update();
		return true;
	end
	
	function scrollbar.resetSliderColor()
		setSliderColor(0x30, 0x60, 0xC0);
	end
	scrollbar.resetSliderColor();
	
	function scrollbar.getSliderColor()
		return slider_r, slider_g, slider_b;
	end
	
	function scrollbar.setSliderDraggingColor(r, g, b)
		dragColor = tocolor(r, g, b, 255);
		
		drag_r, drag_g, drag_b = r, g, b;
		
		update();
		return true;
	end
	
	function scrollbar.resetSliderDraggingColor()
		setSliderDraggingColor(0x20, 0x50, 0xB0);
	end
	scrollbar.resetSliderDraggingColor();
	
	function scrollbar.getSliderDraggingColor()
		return drag_r, drag_g, drag_b;
	end
	
	function scrollbar.setButtonBackgroundColor(r, g, b)
		buttonBgColor = tocolor(r, g, b, 255);
		
		bBg_r, bBg_g, bBg_b = r, g, b;
		
		update();
		return true;
	end
	
	function scrollbar.resetButtonBackgroundColor()
		setButtonBackgroundColor(0x00, 0x15, 0x60);
	end
	scrollbar.resetButtonBackgroundColor();
	
	function scrollbar.getButtonBackgroundColor()
		return bBg_r, bBg_g, bBg_b;
	end
	
	function scrollbar.setButtonColor(r, g, b)
		buttonColor = tocolor(r, g, b, 255);
		buttonDownColor = tocolor(r / 2, g / 2, b / 2, 255);
		
		button_r, button_g, button_b = r, g, b;
		
		update();
		return true;
	end
	
	function scrollbar.resetButtonColor()
		setButtonColor(0x00, 0x30, 0x80);
	end
	scrollbar.resetButtonColor();
	
	function scrollbar.getButtonColor()
		return button_r, button_g, button_b;
	end
	
	function scrollbar.getRenderingColor()
		return buttonBgColor, buttonColor, buttonDownColor;
	end
	
	function scrollbar.renderFrame()
        local color;
        
        dxDrawRectangle(0, 0, width, height, frameColor);
        dxDrawRectangle(1, 1, width - 2, height - 2, bgColor);
        
        -- Render slide
        local _x, _y, _w, _h = getSliderArea();
        
        if (isDragging()) then
            color = dragColor;
        else
            color = sliderColor;
        end
        
        dxDrawRectangle(_x, _y, _w, _h, color);
	end
	
	function scrollbar.destroy()
		scrollbars[scrollbar] = nil;
	end
	
	scrollbars[scrollbar] = true;
	return scrollbar;
end

function createVerticalScrollbar(parent)
    local scrollbar = createScrollbar(parent);
    local upress = false;
    local dpress = false;
    local prec = 0;
    local slidersize = 0.2;
    local offset;
    local drag = false;
    
    if not (scrollbar) then return false; end;
	
	function scrollbar.getType()
		return "vscrollbar";
	end
    
    function scrollbar.blur()
        upress = false;
        dpress = false;
        drag = false;
        
        update();
        return true;
    end
    
    function scrollbar.isDragging()
        return drag;
    end
    
    function scrollbar.setSliderPosition(off)
        local adv = max(0, math.min(1, off));
        
        if (adv == prec) then return true; end;
        
        prec = adv;
        
        triggerEvent("onScroll", prec);
        
        update();
        return true;
    end
    
    function scrollbar.getSliderPosition()
        return prec;
    end
    
    function scrollbar.getSliderRoom()
        return height - width - width;
    end
    
    function scrollbar.setSliderSize(size)
        slidersize = max(0.05, min(1, size));
        
        update();
        return true;
    end
    
    function scrollbar.getSliderSize()
        return slidersize;
    end
    
    function scrollbar.getSliderArea()
        local sliderroom = getSliderRoom();
        local hslider = sliderroom * slidersize;
        
        return 1, width + (sliderroom - hslider) * prec, width - 2, hslider;
    end
    
    function scrollbar.mouseclick(button, state, px, py)
        if not (button == "left") then return true; end;
        
        if not (state) then
            upress = false;
            dpress = false;
			
			if (drag) then
				triggerEvent("onScrollEnd");
				drag = false;
			end
        else
            if (py < width) then
                upress = true;
                
                setSliderPosition(prec - 0.01);
            elseif (py > height - width) then
                dpress = true;
                
                setSliderPosition(prec + 0.01);
            else
                local x, y, w, h = getSliderArea();
                
                if (py >= y) and (py <= y + h) then
                    offset = py - y + width;
                    
                    drag = true;
                end
            end
        end
        
        update();
        return true;
    end
    
    function scrollbar.mousemove(px, py)
        if not (drag) then return true; end;
        
        local h = getSliderRoom();
        local sh = h * slidersize;
        
        setSliderPosition((py - offset) / (h - sh));
        return true;
    end
    
    function scrollbar.render()
		renderFrame();
	
        local color;
		local buttonBgColor, buttonColor, buttonDownColor = getRenderingColor();

        -- Render top
        dxDrawRectangle(0, 0, width, width, buttonBgColor);
        
        if not (upress) then
            color = buttonColor;
        else
            color = buttonDownColor;
        end
        
        dxDrawRectangle(1, 1, width - 2, width - 2, color);
        if (arrow_u) then
            dxDrawImage(4, 4, width - 8, width - 8, arrow_u);
        end
        
        -- Render bottom
        dxDrawRectangle(0, height - width, width, width, buttonBgColor);
        
        if not (dpress) then
            color = buttonColor;
        else
            color = buttonDownColor;
        end
        
        dxDrawRectangle(1, height - width + 1, width - 2, width - 2, color);
        if (arrow_d) then
            dxDrawImage(4, height - width + 4, width - 8, width - 8, arrow_d);
        end
        return super();
    end
    
    return scrollbar;
end

function createHorizontalScrollbar(parent)
    local scrollbar = createScrollbar(parent);
    local lpress = false;
    local rpress = false;
    local prec = 0;
    local slidersize = 0.2;
    local offset;
    local drag = false;
    
    if not (scrollbar) then return false; end;
	
	function scrollbar.getType()
		return "hscrollbar";
	end
    
    function scrollbar.blur()
        lpress = false;
        rpress = false;
        drag = false;
        
        update();
        return true;
    end
    
    function scrollbar.isDragging()
        return drag;
    end
    
    function scrollbar.setSliderPosition(off)
        local adv = max(0, min(1, off));
        
        if (adv == prec) then return true; end;
        
        prec = adv;
        
        triggerEvent("onScroll", prec);
        
        update();
        return true;
    end
    
    function scrollbar.getSliderPosition()
        return prec;
    end
    
    function scrollbar.getSliderRoom()
        return width - height - height;
    end
    
    function scrollbar.setSliderSize(size)
        slidersize = max(0.05, min(1, size));
        
        update();
        return true;
    end
    
    function scrollbar.getSliderSize()
        return slidersize;
    end
    
    function scrollbar.getSliderArea()
        local sliderroom = getSliderRoom();
        local wslider = sliderroom * slidersize;
        
        return height + (sliderroom - wslider) * prec, 1, wslider, height - 2;
    end
    
    function scrollbar.mouseclick(button, state, px, py)
        if not (button == "left") then return true; end;
        
        if not (state) then
            lpress = false;
            rpress = false;
			
			if (drag) then
				triggerEvent("onScrollEnd");
				drag = false;
			end
        else
            if (px < height) then
                lpress = true;
                
                setSliderPosition(prec - 0.01);
            elseif (px > width - height) then
                rpress = true;
                
                setSliderPosition(prec + 0.01);
            else
                local x, y, w, h = getSliderArea();
                
                if (px >= x) and (px <= x + w) then
                    offset = px - x + height;
                    
                    drag = true;
                end
            end
        end
        
        update();
        return true;
    end
    
    function scrollbar.mousemove(px, py)
        if not (drag) then return true; end;
        
        local w = getSliderRoom();
        local sw = w * slidersize;
        
        setSliderPosition((px - offset) / (w - sw));
        return true;
    end
    
    function scrollbar.render()
		renderFrame();
		
        local color;
		local buttonBgColor, buttonColor, buttonDownColor = getRenderingColor();
        
        -- Render left
        dxDrawRectangle(0, 0, height, height, buttonBgColor);
        
        if not (lpress) then
            color = buttonColor;
        else
            color = buttonDownColor;
        end
        
        dxDrawRectangle(1, 1, height - 2, height - 2, color);
        if (arrow_l) then
            dxDrawImage(4, 4, height - 8, height - 8, arrow_l);
        end
        
        -- Render right
        dxDrawRectangle(width - height, 0, height, height, buttonBgColor);
        
        if not (rpress) then
            color = buttonColor;
        else
            color = buttonDownColor;
        end
        
        dxDrawRectangle(width - height + 1, 1, height - 2, height - 2, color);
        if (arrow_r) then
            dxDrawImage(width - height + 4, 4, height - 8, height - 8, arrow_r);
        end
        return super();
    end

    return scrollbar;
end

function isScrollbar(element)
    return not (scrollbars[element] == nil);
end