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
local gdkCreateShader = gdkCreateShader;    -- remember: load gdkutils_client.lua first!
local destroyElement = destroyElement;
local createDXElement = createDXElement;

local windows = {};

function createWindow(parent)
	local window = createDXElement("window", parent);
	
	if not (window) then return false; end;
	
	local hdlc = gdkCreateShader("wndres_hdlc.fx");
	
    -- It is perfectly legal to miss the shader resource.
    -- Make sure rendering takes this into account!
	
	local hdlc_lr, hdlc_lg, hdlc_lb;
	local hdlc_rr, hdlc_rg, hdlc_rb;
	
	local root = createDXElement("_root", window);
	root.supportAlpha(true);
	local closeButton = false;
	local heading = "";
	local font = "default";
	local fontScale = 1;
	local fontHeight = dxGetFontHeight(fontScale, font);
	local text_r, text_g, text_b;
	local fontColor;
	local headerHeight = fontHeight + 2;
	local menu = false;
	local bgColor;
	local bgR, bgG, bgB;
	local drag = false;
	local sizable = false;
	local movable = true;
	local dOffX, dOffY;
	
	window.setCaptiveMode(false);
	
	function root.destroy()
		root = false;
	end
	
	local function recalculate()
		window.update();
		
		local yoff = headerHeight + 2;
		local h = window.height - headerHeight - 4;
	
		if (menu) then
			yoff = yoff + menu.height;
			h = h - menu.height;
		end
		
		root.setPosition(2, yoff);
		root.setSize(window.width - 4, h);
	end
	
	function window.setSize(w, h)
		if not (super(w, h)) then return false; end;
		
		recalculate();
		return true;
	end
	
	function window.setRootSize(w, h)
		if (menu) then
			return setSize(4 + w, 4 + headerHeight + menu.height + h);
		end
		
		return setSize(4 + w, 4 + headerHeight + h);
	end
	
	function window.isDragging()
		return drag;
	end
	
	function window.setText(text)
		heading = text;
		
		update();
		return true;
	end
	
	function window.getText()
		return heading;
	end
	
	function window.setTextColor(r, g, b)
		fontColor = tocolor(r, g, b, 255);
		
		text_r, text_g, text_b = r, g, b;
		
		update();
		return true;
	end
	
	function window.resetTextColor()
		setTextColor(255, 255, 255);
	end
	window.resetTextColor();
	
	function window.getTextColor()
		return text_r, text_g, text_b;
	end
	
	function window.setFont(charScale, charFont)
		fontScale, font = charScale, charFont;
		
		recalculate();
		return true;
	end
	
	function window.getFont()
		return fontScale, font;
	end
	
	function window.setBackgroundColor(r, g, b)
		bgR, bgG, bgB = r, g, b;
	
		bgColor = tocolor(r, g, b, 255);
		
		update();
		return true;
	end
	
	function window.resetBackgroundColor()
		setBackgroundColor(0x00, 0x24, 0x80);
	end
	window.resetBackgroundColor();
	
	function window.getBackgroundColor()
		return bgR, bgG, bgB;
	end
	
	function window.setHeadingLeftColor(r, g, b)
		hdlc_lr, hdlc_lg, hdlc_lb = r, g, b;
		
		dxSetShaderValue(hdlc, "leftColor", r / 255, g / 255, b / 255);
		
		update();
		return true;
	end
	
	function window.resetHeadingLeftColor()
		setHeadingLeftColor(26, 154, 52);
	end
	window.resetHeadingLeftColor();
	
	function window.getHeadingLeftColor()
		return hdlc_lr, hdlc_lg, hdlc_lb;
	end
	
	function window.setHeadingRightColor(r, g, b)
		hdlc_rr, hdlc_rg, hdlc_rb = r, g, b;
		
		dxSetShaderValue(hdlc, "rightColor", r / 255, g / 255, b /255);
		
		update();
		return true;
	end
	
	function window.resetHeadingRightColor()
		setHeadingRightColor(13, 102, 38);
	end
	window.resetHeadingRightColor();
	
	function window.getHeadingRightColor()
		return hdlc_rr, hdlc_rg, hdlc_rb;
	end
	
	function window.getRoot()
		return root;
	end
	
	function window.doMenu()
		if (menu) then
			return menu;
		end
		
		menu = createMenu(window);
		menu.setPosition(2, headerHeight + 2);
		menu.setSize(width - 3, 20);
		
		function menu.destroy()
			menu = false;
			
			if (root) then
				recalculate();
			end
		end
		
		recalculate();
		return menu;
	end
	
	function window.setMovable(enable)
		if (movable == enable) then return true; end;
		
		movable = enable;
		
		if not (movable) then
			drag = false;
		end
		
		return true;
	end
	
	function window.isMovable()
		return movable;
	end
	
	function window.mouseclick(button, state, x, y)
		if not (button == "left") then return true; end;
		if not (movable) then return true; end;
		
		if (state) then
			if (y > headerHeight + 2) then return true; end;
			
			drag = true;
			dOffX, dOffY = x, y;
			return true;
		end
		
		drag = false;
		return true;
	end
	
	function window.mousemove()
		if not (drag) then return true; end;
		
		local _x, _y = getParent().getMousePosition();
		
        if (_x) then
            setPosition(_x - dOffX, _y - dOffY);
        end
        
		return true;
	end
	
	function window.render()
        dxDrawRectangle(0, 0, width, height, tocolor(0xC0, 0xC0, 0xC0, 0xFF));
        dxDrawRectangle(1, 1, width - 1, height - 1, tocolor(0x40, 0x40, 0x40, 0xFF));
		dxDrawRectangle(2, 2, width - 3, height - 3, bgColor);
		
        if (hdlc) then
            dxDrawImage(2, 2, width - 3, headerHeight, hdlc);
        else
            -- Since we do not have the shader, we render an approximation using a rectangle.
            dxDrawRectangle(2, 2, width - 3, headerHeight, tocolor((hdlc_lr + hdlc_rr) / 2, (hdlc_lg + hdlc_rg) / 2, (hdlc_lb + hdlc_rb) / 2, 0xFF));
        end
		dxDrawText(heading, 6, 4, 0, 0, fontColor, fontScale, font);
	
		super();
		
		return true;
	end
	
	function window.destroy()
        -- We are allowed to individually destroy the resource as we used a
        -- gdkCreate* function to load it. gdkLoad* may cache resources.
		destroyElement(hdlc);
		
		windows[window] = nil;
	end
	
	windows[window] = true;
	return window;
end
createDragableWindow = createWindow;	-- dragable by default

function isWindow(element)
	return not (windows[element] == nil);
end