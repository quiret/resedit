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

local straightResizeCursor = gdkLoadTexture("images/straight_resize.png");
local diagResizeCursor = gdkLoadTexture("images/diag_resize.png");

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
    
    -- Dragging margin stuff.
    local resizeDragMarginSize = 6;
    local allowCursorResize = false;
    local didSetRenderFunctor = false;
    
    -- Resize states.
    local resizeStateTop = false;
    local resizeStateLeft = false;
    local resizeStateBottom = false;
    local resizeStateRight = false;
    local doResize = false;
    local resizeCursorStartX, resizeCursorStartY;
    local resizeMetricPosX, resizeMetricPosY;
    local resizeMetricWidth, resizeMetricHeight;
	
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
		return drag or doResize;
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
    
    function window.setAllowCursorResize(enable)
        if (enable) then
            setExtraMargin(
                resizeDragMarginSize,
                resizeDragMarginSize,
                resizeDragMarginSize,
                resizeDragMarginSize
            );
        
            allowCursorResize = true;
        else
            setExtraMargin(0, 0, 0, 0);
            
            allowCursorResize = false;
            
            -- Disable any pending resize.
            resizeStateTop = false;
            resizeStateLeft = false;
            resizeStateBottom = false;
            resizeStateRight = false;
            doResize = false;
        end
        
        return true;
    end
    
    function window.getAllowCursorResize()
        return allowCursorResize;
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
    
    local function dispatchResizeQuantors(
        localX, localY, width, height,
        leftSide, rightSide, topSide, bottomSide,
        topLeftSide, bottomLeftSide,
        topRightSide, bottomRightSide
    )
        if (localY >= 0) and (localY <= height) then
            if (localX < 0) then
                -- Left side.
                leftSide();
            elseif (localX >= width) then
                -- Right side.
                rightSide();
            end
        elseif (localX >= 0) and (localX <= width) then
            if (localY < 0) then
                -- Top side.
                topSide();
            elseif (localY >= height) then
                -- Bottom side.
                bottomSide();
            end
        elseif (localX < 0) then
            if (localY < 0) then
                -- Top left.
                topLeftSide();
            elseif (localY >= height) then
                -- Bottom left.
                bottomLeftSide();
            end
        elseif (localX >= width) then
            if (localY < 0) then
                -- Top right,
                topRightSide();
            elseif (localY >= height) then
                -- Bottom right.
                bottomRightSide();
            end
        end
    end
	
	function window.mouseclick(button, state, x, y)
		if not (button == "left") then return true; end;
		
        if (movable) then
            if (state) then
                -- Check if we should move the window around.
                if (y <= headerHeight + 2) and (y >= 0) and (x >= 0) and (x <= width) then
                    drag = true;
                    dOffX, dOffY = x, y;
                else
                    -- Check if we should resize the window.
                    dispatchResizeQuantors(
                        x, y, width, height,
                        function()
                            -- Left.
                            resizeStateLeft = true;
                        end,
                        function()
                            -- Right.
                            resizeStateRight = true;
                        end,
                        function()
                            -- Top.
                            resizeStateTop = true;
                        end,
                        function()
                            -- Bottom.
                            resizeStateBottom = true;
                        end,
                        function()
                            -- Top left.
                            resizeStateTop = true;
                            resizeStateLeft = true;
                        end,
                        function()
                            -- Bottom left.
                            resizeStateBottom = true;
                            resizeStateLeft = true;
                        end,
                        function()
                            -- Top right.
                            resizeStateTop = true;
                            resizeStateRight = true;
                        end,
                        function()
                            -- Bottom right.
                            resizeStateBottom = true;
                            resizeStateRight = true;
                        end
                    );
                    
                    if (resizeStateTop) or (resizeStateBottom) or (resizeStateLeft) or (resizeStateRight) then
                        resizeCursorStartX, resizeCursorStartY = getParent().getMousePosition();
                        resizeMetricPosX, resizeMetricPosY = getPosition();
                        resizeMetricWidth = width;
                        resizeMetricHeight = height;
                        doResize = true;
                    end
                end
            else
                -- Disable any occuring drag.
                drag = false;
                
                -- Disable any occuring resize.
                resizeStateTop = false;
                resizeStateLeft = false;
                resizeStateBottom = false;
                resizeStateRight = false;
                doResize = false;
            end
        end
        
		return true;
	end
	
	function window.mousemove(localX, localY)
        local _x, _y = getParent().getMousePosition();
        
		if (drag) then
            if (didSetRenderFunctor) then
                setMouseRenderFunctor(false);
                
                didSetRenderFunctor = false;
            end
            
            if (_x) then
                setPosition(_x - dOffX, _y - dOffY);
            end
            
            return true;
        end
        
        -- Update metrics.
        if (resizeStateTop) or (resizeStateBottom) then
            local cursorOffY = ( _y - resizeCursorStartY );
        
            if (resizeStateTop) then                
                local newHeight = math.max( headerHeight + 10, resizeMetricHeight - cursorOffY );
                
                setHeight( newHeight );
                
                local newY = ( resizeMetricPosY + resizeMetricHeight - window.height );
                
                setPosition( x, newY );
            elseif (resizeStateBottom) then
                local newHeight = math.max( headerHeight + 10, resizeMetricHeight + cursorOffY );
                
                setHeight( newHeight );
            end
        end
        
        if (resizeStateLeft) or (resizeStateRight) then
            local cursorOffX = ( _x - resizeCursorStartX );
            
            if (resizeStateLeft) then
                local newWidth = math.max( headerHeight + 10, resizeMetricWidth - cursorOffX );
                
                setWidth( newWidth );
                
                local newX = ( resizeMetricPosX + resizeMetricWidth - window.width );
                
                setPosition( newX, y );
            elseif (resizeStateRight) then
                local newWidth = math.max( headerHeight + 10, resizeMetricWidth + cursorOffX );
                
                setWidth( newWidth );
            end
        end
        
        -- Detect if we are on the margin, if we allow resizing.
        -- Then we want to show a special mouse cursor.
        local renderFunctor = false;
        local renderFunctorWidth, renderFunctorHeight;
        
        local cursorLongDimm = 23;
        
        local doShowRightCursor = false;
        local doShowTopCursor = false;
        local doShowLeftCursor = false;
        local doShowBottomCursor = false;
        local doShowDiagTopLeftCursor = false;
        local doShowDiagTopRightCursor = false;
        local doShowDiagBottomLeftCursor = false;
        local doShowDiagBottomRightCursor = false;
        local hasCursor = false;
        
        -- First show cursor depending on resize state.
        if (resizeStateTop) then
            if (resizeStateLeft) then
                doShowDiagTopLeftCursor = true;
            elseif (resizeStateRight) then
                doShowDiagTopRightCursor = true;
            else
                doShowTopCursor = true;
            end
            
            hasCursor = true;
        elseif (resizeStateBottom) then
            if (resizeStateLeft) then
                doShowDiagBottomLeftCursor = true;
            elseif (resizeStateRight) then
                doShowDiagBottomRightCursor = true;
            else
                doShowBottomCursor = true;
            end
            
            hasCursor = true;
        else
            if (resizeStateLeft) then   
                doShowLeftCursor = true;
                hasCursor = true;
            elseif (resizeStateRight) then
                doShowRightCursor = true;
                hasCursor = true;
            end
        end
        
        if not (hasCursor) then
            if (allowCursorResize) then
                dispatchResizeQuantors(
                    localX, localY, width, height,
                    function()
                        -- Left side.
                        doShowLeftCursor = true;
                        hasCursor = true;
                    end,
                    function()
                        -- Right side.
                        doShowRightCursor = true;
                        hasCursor = true;
                    end,
                    function()
                        -- Top side.
                        doShowTopCursor = true;
                        hasCursor = true;
                    end,
                    function()
                        -- Bottom side.
                        doShowBottomCursor = true;
                        hasCursor = true;
                    end,
                    function()
                        -- Top left.
                        doShowDiagTopLeftCursor = true;
                        hasCursor = true;
                    end,
                    function()
                        -- Bottom left.
                        doShowDiagBottomLeftCursor = true;
                        hasCursor = true;
                    end,
                    function()
                        -- Top right,
                        doShowDiagTopRightCursor = true;
                        hasCursor = true;
                    end,
                    function()
                        -- Bottom right.
                        doShowDiagBottomRightCursor = true;
                        hasCursor = true;
                    end
                );
            end
        end
        
        if (doShowLeftCursor) then
            renderFunctor = function(x, y, width, height)
                dxDrawImage(
                    x + 3, y, width, height, straightResizeCursor,
                    90, 0, 0, tocolor(255, 255, 255, 255), true
                );
            end
            
            renderFunctorWidth = cursorLongDimm / 2;
            renderFunctorHeight = cursorLongDimm;
        elseif (doShowRightCursor) then
            renderFunctor = function(x, y, width, height)
                dxDrawImage(
                    x - 3, y, width, height, straightResizeCursor,
                    90, 0, 0, tocolor(255, 255, 255, 255), true
                );
            end
            
            renderFunctorWidth = cursorLongDimm / 2;
            renderFunctorHeight = cursorLongDimm;
        elseif (doShowTopCursor) then
            renderFunctor = function(x, y, width, height)
                dxDrawImage(
                    x, y + 3, width, height, straightResizeCursor,
                    0, 0, 0, tocolor(255, 255, 255, 255), true
                );
            end
            
            renderFunctorWidth = cursorLongDimm / 2;
            renderFunctorHeight = cursorLongDimm;
        elseif (doShowBottomCursor) then
            renderFunctor = function(x, y, width, height)
                dxDrawImage(
                    x, y - 3, width, height, straightResizeCursor,
                    0, 0, 0, tocolor(255, 255, 255, 255), true
                );
            end
            
            renderFunctorWidth = cursorLongDimm / 2;
            renderFunctorHeight = cursorLongDimm;
        elseif (doShowDiagTopLeftCursor) then
            renderFunctor = function(x, y, width, height)
                dxDrawImage(
                    x + 3, y + 3, width, height, diagResizeCursor,
                    90, 0, 0, tocolor(255, 255, 255, 255), true
                );
            end
            
            renderFunctorWidth = cursorLongDimm;
            renderFunctorHeight = cursorLongDimm;
        elseif (doShowDiagBottomLeftCursor) then
            renderFunctor = function(x, y, width, height)
                dxDrawImage(
                    x + 3, y - 3, width, height, diagResizeCursor,
                    0, 0, 0, tocolor(255, 255, 255, 255), true
                );
            end
            
            renderFunctorWidth = cursorLongDimm;
            renderFunctorHeight = cursorLongDimm;
        elseif (doShowDiagTopRightCursor) then
            renderFunctor = function(x, y, width, height)
                dxDrawImage(
                    x - 3, y + 3, width, height, diagResizeCursor,
                    0, 0, 0, tocolor(255, 255, 255, 255), true
                );
            end
            
            renderFunctorWidth = cursorLongDimm;
            renderFunctorHeight = cursorLongDimm;
        elseif (doShowDiagBottomRightCursor) then
            renderFunctor = function(x, y, width, height)
                dxDrawImage(
                    x - 3, y - 3, width, height, diagResizeCursor,
                    90, 0, 0, tocolor(255, 255, 255, 255), true
                );
            end
            
            renderFunctorWidth = cursorLongDimm;
            renderFunctorHeight = cursorLongDimm;
        end
        
        if (renderFunctor) then
            setMouseRenderFunctor(renderFunctor, renderFunctorWidth, renderFunctorHeight);
            
            didSetRenderFunctor = true;
        elseif (didSetRenderFunctor) then
            setMouseRenderFunctor(false);
            
            didSetRenderFunctor = false;
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