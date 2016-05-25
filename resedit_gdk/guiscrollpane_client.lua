-- Optimizations
local dxGetFontHeight = dxGetFontHeight;
local dxGetTextWidth = dxGetTextWidth;
local dxDrawText = dxDrawText;
local dxDrawRectangle = dxDrawRectangle;
local tocolor = tocolor;
local ipairs = ipairs;
local pairs = pairs;

local scrollpanes = {};

function createScrollPane(parent)
    local scrollpane = createDXElement("scrollpane", parent);
    
    if not (scrollpane) then return false; end;
    
    local area_width, area_height = 0, 0;
    local rend_width, rend_height = 0, 0;
    local viewX, viewY = 0, 0;
    local hScroll = createHorizontalScrollbar(scrollpane);
    hScroll.setVisible(false);
    hScroll.setCaptiveMode(false);
    local vScroll = createVerticalScrollbar(scrollpane);
    vScroll.setVisible(false);
    vScroll.setCaptiveMode(false);
    local target;
    local updateTarget = false;
    local scrollHeight = 0;
    local scrollSpacing = 10;
	local doKeyScrolling = true;
    
    function hScroll.events.onScroll(pos)
        viewX = (area_width - rend_width) * pos;
        return true;
    end
	
	function hScroll.events.onScrollEnd()
		scrollpane.moveToFront();
	end
    
    function vScroll.events.onScroll(pos)
        viewY = (area_height - rend_height) * pos;
        return true;
    end
	
	function vScroll.events.onScrollEnd()
		scrollpane.moveToFront();
	end
    
    function scrollpane.recalculate()        
        if (area_width > width) then
            rend_height = math.max(0, height - scrollSpacing);
            
            hScroll.setVisible(true);
            
            if (area_height > rend_height) then
                rend_width = math.max(0, width - scrollSpacing);
                
                vScroll.setSize(scrollSpacing, rend_height);
                vScroll.setSliderSize(rend_height / area_height);
                vScroll.setVisible(true);
            else
                vScroll.setVisible(false);
                rend_width = width;
                
                viewY = 0;
            end
            
            hScroll.setSize(rend_width, scrollSpacing);
            hScroll.setSliderSize(rend_width / area_width);
        elseif (area_height > height) then
            rend_width = math.max(0, width - scrollSpacing);
            
            vScroll.setVisible(true);
            
            if (area_width > rend_width) then
                rend_height = math.max(0, height - scrollSpacing);
                
                hScroll.setSize(rend_width, scrollSpacing);
                hScroll.setSliderSize(rend_width / area_width);
                hScroll.setVisible(true);
            else
                hScroll.setVisible(false);
                rend_height = height;
                
                viewX = 0;
            end
            
            vScroll.setSize(scrollSpacing, rend_height);
            vScroll.setSliderSize(rend_height / area_height);
        else
            rend_width = width;
            rend_height = height;
            
            viewX, viewY = 0, 0;
            
            hScroll.setVisible(false);
            vScroll.setVisible(false);
        end
		
        -- Update our view
        setViewOffset(viewX, viewY);
		
        updateTarget = true;
        update();
        return true;
    end
	
	function scrollpane.getHorizontalScroll()
		return hScroll;
	end
	
	function scrollpane.getVerticalScroll()
		return vScroll;
	end
    
    function scrollpane.setScrollHeight(h)
        scrollHeight = h;
        return true;
    end
    
    function scrollpane.getScrollHeight()
        return scrollHeight;
    end
    
    function scrollpane.setScrollSpacing(s)
        if (s < 1) then return false; end;
        
        scrollSpacing = s;
        
        recalculate();
        return true;
    end
    
    function scrollpane.getScrollSpacing()
        return scrollSpacing;
    end
	
	function scrollpane.enableKeyScrolling(enable)
		doKeyScrolling = enable;
		return true;
	end
	
	function scrollpane.isKeyScrollingEnabled()
		return doKeyScrolling;
	end
    
    function scrollpane.setSize(w, h)
        if not (super(w, h)) then return false; end;
        
        -- Update the scrollbars
        hScroll.setPosition(0, height - scrollSpacing);
        vScroll.setPosition(width - scrollSpacing, 0);
		
        recalculate();
        return true;
    end
    
    function scrollpane.setAreaSize(w, h)
        area_width, area_height = w, h;
        
        recalculate();
        return true;
    end
    
    function scrollpane.getAreaSize()
        return area_width, area_height;
    end
    
    function scrollpane.getRenderSize()
        return rend_width, rend_height;
    end
    
    function scrollpane.setViewOffset(x, y)
        local x, y = math.max(0, math.min(x, area_width - rend_width)), math.max(0, math.min(y, area_height - rend_height));
		
        hScroll.setSliderPosition(x / (area_width - rend_width));
        vScroll.setSliderPosition(y / (area_height - rend_height));
		
		if (x == viewX) and (y == viewY) then return true; end;
		
		viewX, viewY = x, y;
        
        update();
        return true;
    end
    
    function scrollpane.getViewOffset()
        return viewX, viewY;
    end
	
	function scrollpane.acceptInput()
		return true;
	end
    
    function scrollpane.keyInput(key, state)
		if not (state) then return; end;
	
        if (key == "mouse_wheel_down") or (doKeyScrolling) and (key == "arrow_d") then
            setViewOffset(viewX, viewY + scrollHeight);
        elseif (key == "mouse_wheel_up") or (doKeyScrolling) and (key == "arrow_u") then
            setViewOffset(viewX, viewY - scrollHeight);
        end
        
        return true;
    end
    
    -- Elements will be captured in the target area
    function scrollpane.getRenderTarget()
        return target;
    end
    
    function scrollpane.isHit(offX, offY)
        return (offX <= rend_width) and (offY < rend_height);
    end
    
    local function _destroyRenderTarget()
        if not (target) then return end
        
        destroyElement(target);
        
        target = false;
    end
    
    function scrollpane.preRender()
        if (updateTarget) then
            _destroyRenderTarget();
            
            target = dxCreateRenderTarget(rend_width, rend_height, isSupportingAlpha());
            
            update();
            
            updateTarget = false;
        end
        
        return super();
    end
    
    function scrollpane.renderArea()
        return true;
    end
    
    function scrollpane.render()
        dxSetRenderTarget(target);
        
        -- Let other classes render in our area
        renderArea();
        
        resetRenderTarget();
        
        dxDrawRectangle(0, 0, width, height, tocolor(0x00, 0x24, 0x80, 0xFF));
        dxDrawImage(0, 0, rend_width, rend_height, target);
        return super();
    end
    
    function scrollpane.destroy()
        _destroyRenderTarget();
        
        scrollpanes[scrollpane] = nil;
    end
    
    scrollpanes[scrollpane] = true;
    return scrollpane;
end

function isScrollPane(element)
    return not (scrollpanes[element] == nil);
end