-- Created by (c)The_GTA. All rights reserved.

--[[
    Copyright by Martin Turski.
    
    This is the dxElements drawing environment. Sharing this code with other
    people for commercial reasons is strictly forbidden. Any other forms of
    sharing have to be approved by Martin Turski.
    
    Do not modify this library unless given permission to by Martin Turski.
    Any questionable modifications will make support hard up to a decline.
    
    This library has been coded to work with the MTA environment. It has
    dependencies on it's functionality. If you want to use dxElements in
    another environment, said environment has to emulate all functionality.
    The_GTA gives support for MTA and MTA:Lua Interpreter implementations.
    
    dxElements are sizable, positionable, orderable, blendable, inputable, clickable
    render targets.
    
    For documentation on this system, see...
    (TODO)
]]

-- Optimizations
local dxDrawImage = dxDrawImage;
local dxDrawRectangle = dxDrawRectangle;
local tocolor = tocolor;
local ipairs = ipairs;
local pairs = pairs;
local type = type;
local table = table;
local floor = math.floor;

-- Utility function for deleting a value from an indexed table.
-- Fixed the loose dependency on shared.lua
local function tdelete(t, v)
    local n = 1;
    local max = #t;
    
    while (n <= max) do
        if (t[n] == v) then
            table.remove(t, n);
            return n;
        end
        
        n = n + 1;
    end
    
    return false;
end

-- Important globals defined before loading dxElements_client.lua
local __DXDEBUG = __DXDEBUG;
local __DXDEBUG_ERROR = __DXDEBUG_ERROR;

local _G = _G;
local elements = {};

-- Let the customer decide whether dxElements should optimize the environment.
if not (__DXELEMENTS_EXCLUDE_OPTIMIZATIONS) then
    -- Temporarily force-disable instruction count hook
    debug.sethook(nil);
end

-- Plugin Interface System.
local function createPluginInterface(list)
    local constructors = {};
    local interface = {};
    local elemPairs = list;
    
    function interface.initObject(elem)
        for m,n in ipairs(constructors) do
            n(elem);
        end
        
        return true;
    end
    
    function interface.registerExtension(constructor)
        table.insert(constructors, constructor);
        
        -- If elements were already created (most likely dxRoot)
        -- run the constructors on them
        for m,n in pairs(elemPairs) do
            constructor(m);
        end
        
        return true;
    end
    
    function interface.setPairs(list)
        elemPairs = list;
        return true;
    end
    
    return interface;
end

-- Create main plugin
local dxElementPlugin = createPluginInterface(elements);

-- Drawing utilities
local function dxBlendTargetWrap(mode, routine)
    local prevMode = dxGetBlendMode();
    dxSetBlendMode(mode);
    
    -- Execute the routine
    routine();
    
    dxSetBlendMode(prevMode);
end

function isDXElement(element)
    return not (elements[element] == nil);
end

-- List of all hierarchies
local hierarchies = {};

local function createDXHierarchy()
    local hierarchy = createClass();
    
    local dx_root; -- the hierarchy root element.
    local rootCapture = false;
    local activeElement = false;
    local mouseElement = false;
    local lastMouseButton = false;
    local mouseClickTime = 0;
    
    local outbreakElements = {};

    local function createDXElement(elementType, parent)
        local element, methodenv = createClass({
            x = 0,
            y = 0,
            width = 0,
            height = 0,
            visible = true
        },
        {
            mouseenter = true,
            mousemove = true,
            mouseclick = true,
            mousedoubleclick = true,
            mouseleave = true,
            focus = true,
            blur = true,
            enable = true,
            disable = true,
            keyInput = true,
            input = true,
            invalidate = true
        });
        
        local events = {};
        local target = false;
        local updateTarget = false;
        local alwaysOnTop = false;
        local changed = false;
        local captiveMode = true;
        local outbreakMode = false;
        local supportAlpha = false;
        local disabled = false;
        local extra_top = 0;
        local extra_left = 0;
        local extra_right = 0;
        local extra_bottom = 0;
        local minWidth = 0;
        local minHeight = 0;
        local blend_r, blend_g, blend_b, blend_a;
        local blendColor;
        local cursorRenderFunctor = false;
        local cursorRenderWidth = 0;
        local cursorRenderHeight = 0;
        local drawingOrder = {};
        local captAlwaysOnTop = {};
        local noncaptive = {};
        local alwaysOnTopElements = {};
        local childAPI;
        local rootContext;
        
        if (parent) then 
            if not (isDXElement(parent)) or not (parent.getHierarchy() == hierarchy) then return false; end;
        else
            parent = dx_root;
        end
        
        function element.getHierarchy()
            return hierarchy;
        end
        
        function element.getType()
            return elementType;
        end
        
        function element.getParent()
            return parent;
        end
        
        function element.isDragging()
            return false;
        end
        
        function element.supportAlpha(enabled)
            if (enabled == supportAlpha) then return true; end;
            
            supportAlpha = enabled;
            
            update();
            return true;
        end
        
        function element.isSupportingAlpha()
            return supportAlpha;
        end
        
        function element.setCaptiveMode(enabled)
            if (captiveMode == enabled) then return true; end;
            
            captiveMode = enabled;
            
            childAPI.setCaptiveMode(enabled);
            return true;
        end
        
        function element.isCaptiveMode()
            return captiveMode;
        end
        
        function element.setOutbreakMode(enabled)
            if (outbreakMode == enabled) then return true; end;
            
            outbreakMode = enabled;
            
            childAPI.setOutbreakMode(enabled);
            return true;
        end
        
        function element.isOutbreakMode()
            return outbreakMode;
        end
        
        function element.getRenderCapture()
            if (outbreakMode) then
                return rootCapture;
            end
        
            if not (captiveMode) then
                return parent.getRenderCapture();
            end
            
            return parent.getRenderTarget();
        end
        
        function element.getScreenSize()
            if (outbreakMode) then
                return dx_root.getScreenSize();
            end
        
            if not (captiveMode) then
                return parent.getScreenSize();
            end
            
            return parent.getSize();
        end
        
        function element.setPosition(posX, posY)
            posX, posY = floor(posX), floor(posY);
        
            if not (triggerEvent("onPosition", posX, posY)) then return false; end;
            
            parent.update();
            
            x, y = posX, posY;
            return true;
        end
        
        function element.getScreenPosition()
            local _x, _y = parent.getScreenPosition();
            return x + _x, y + _y;
        end
        
        function element.getAbsolutePosition()
            if (outbreakMode) then
                return getScreenPosition();
            end
        
            if not (captiveMode) then
                local offX, offY = parent.getAbsolutePosition();
                
                return x + offX, y + offY;
            end
            
            return x, y;
        end
        
        function element.getAbsoluteMousePosition()
            if not (captiveMode) then
                return parent.getAbsoluteMousePosition();
            end
            
            local mouseX, mouseY = dx_root.getAbsoluteMousePosition();
            
            if not (mouseX) then return false; end;
            
            local x, y = parent.getAbsolutePosition();
            
            return mouseX - x, mouseY - y;
        end
        
        function element.getMousePosition()
            local mouseX, mouseY = dx_root.getMousePosition();
            
            if not (mouseX) then return false; end;
        
            local x, y = getScreenPosition();
            
            return mouseX - x, mouseY - y;
        end
        
        function element.getPosition()
            return x, y;
        end
        
        function element.setSize(w, h)
            w = floor(w);
            h = floor(h);
        
            w = math.max(w, minWidth);
            h = math.max(h, minHeight);
        
            if (width == w) and (height == h) then return false; end;
        
            if not (triggerEvent("onSize", w, h)) then return false; end;
            
            width, height = w, h;
            
            -- Make sure we update the target later, since caching slows down alot
            updateTarget = true;
            return true;
        end
        
        function element.getSize()
            return width, height;
        end
        
        function element.setMinimumSize(w, h)
            minWidth = w;
            minHeight = h;
            
            -- Make sure we meet this criteria.
            if (width < minWidth) then
                setWidth(minWidth);
            end
            
            if (height < minHeight) then
                setHeight(minHeight);
            end
            
            return true;
        end
        
        function element.getMinimumSize()
            return minWidth, minHeight;
        end
        
        function element.setWidth(w)
            setSize(w, height);
            return true;
        end
        
        function element.setHeight(h)
            setSize(width, h);
            return true;
        end
        
        function element.setExtraMargin(top, left, bottom, right)
            extra_top = top;
            extra_left = left;
            extra_bottom = bottom;
            extra_right = right;
            
            updateMouse();
            return true;
        end
        
        function element.getExtraMargin()
            return extra_left, extra_top, extra_right, extra_bottom;
        end
        
        function element.setMouseRenderFunctor(functor, functorWidth, functorHeight)
            cursorRenderFunctor = functor;
            cursorRenderWidth = functorWidth;
            cursorRenderHeight = functorHeight;
            return true;
        end
        
        function element.getMouseRenderFunctor()
            if (cursorRenderFunctor) then
                return cursorRenderFunctor, cursorRenderWidth, cursorRenderHeight;
            end
            
            return false;
        end
        
        function element.setBlendColor(r, g, b, a)
            if not (a) then
                a = 0xFF;
            end
            
            if (r == blend_r) and (g == blend_g) and (b == blend_b) and (a == blend_a) then return true; end;
        
            blend_r, blend_g, blend_b, blend_a = r, g, b, a;
            
            blendColor = tocolor(r, g, b, a);
            
            parent.update();
            return true;
        end
        
        function element.getBlendColor()
            return blend_r, blend_g, blend_b, blend_a;
        end
        
        function element.isInLocalArea(posX, posY)
            return (-extra_left <= posX) and (-extra_top <= posY) and (posX <= width + extra_right) and (posY <= height + extra_bottom);
        end
        
        function element.isHit(offX, offY)
            return true;
        end
        
        function element.test(offX, offY)
            local m,n;
            local inLocalArea = isInLocalArea(offX, offY);
            
            for m,n in ipairs(getChildren()) do
                if (n.visible) then
                    if (not (n.isCaptiveMode()) or (inLocalArea)) then
                        local dx, dy = n.getPosition();
                    
                        if (n.test(offX - dx, offY - dy)) then
                            return true;
                        end
                    end
                end
            end
            
            return inLocalArea and isHit(offX, offY);
        end
        
        function element.setVisible(show)
            if (visible == show) then return false; end;
            
            if not (show) then
                if not (triggerEvent("onHide")) then return false; end;
                
                visible = false;
                
                parent.update();
                
                element.hide();
                return true;
            elseif not (triggerEvent("onShow")) then return false; end;
            
            visible = true;
            
            parent.update();
            
            element.show();
            return true;
        end

        function element.dropMouseFocus()
            if (element == mouseElement) then
                mouseElement = false;
            
                triggerEvent("onMouseLeave");
                
                mouseleave();

                -- We do not update mousefocus here.
                -- This function requests to simply drop it.
            end
        end

        function element.dropFocus()
            if (element == activeElement) then
                activeElement = false;
            
                triggerEvent("onBlur");
                
                blur();
            end
        end
        
        function element.defereControls()
            -- Make sure we dont conflict with active states
            if (element == mouseElement) then
                mouseElement = false;
            
                triggerEvent("onMouseLeave");
                
                mouseleave();
                
                -- Update the mouse for fluent controls
                hierarchy.updateMouse();
            end

            dropFocus();
        end
        
        function element.show()
            local m,n;
            
            for m,n in ipairs(getChildren()) do
                if not (n.visible) then
                    n.show();
                end
            end
            
            return true;
        end
        
        function element.hide()
            local m,n;
        
            for m,n in ipairs(getChildren()) do
                if (n.visible) then
                    n.hide();
                end
            end
            
            -- Terminate sessions, i.e. mouse focus
            defereControls();
            return true;
        end
        
        function element.isVisible()
            if not (parent.isVisible()) then return false; end;
            
            return visible;
        end
        
        function element.getVisible()
            return visible;
        end
        
        function element.setDisabled(mode)
            if (mode == disabled) then return true; end;
        
            if (mode) then
                disabled = true;
                
                disable();
                return true;
            end
            
            disabled = false;
            
            enable();
            return true;
        end
        
        function element.enable()
            local m,n;
        
            for m,n in ipairs(getChildren()) do
                if not (n.getDisabled()) then
                    n.enable();
                end
            end
        
            return true;
        end
        
        function element.disable()
            local m,n;
        
            for m,n in ipairs(getChildren()) do
                if not (n.getDisabled()) then
                    n.disable();
                end
            end
        
            return true;
        end
        
        function element.isDisabled()
            if (parent.isDisabled()) then return true; end;
            
            return disabled;
        end
        
        function element.getDisabled()
            return disabled;
        end
        
        function element.addEvent(name)
            local m,n;
        
            if (events[name]) then return true; end;
        
            local event = {
                handlers = {}
            };
            
            events[name] = event;
            
            for m,n in ipairs(getChildren()) do
                n.addEvent(name);
            end
            
            return true;
        end
        
        function element.addEventHandler(name, handler, propagate)
            local event = events[name];
            
            if not (event) or not (handler) then return false; end;
            
            if (propagate == nil) then
                propagate = true;
            end
            
            table.insert(event.handlers, {
                handler = handler,
                propagate = propagate
            });
            return true;
        end
        
        function element.removeEventHandler(name, handler)
            local event = events[name];
            
            if not (event) then return false; end;
            
            if not (handler) then
                event.handlers = {};
                return true;
            end
            
            local m,n;
            
            for m,n in ipairs(event.handlers) do
                if (n.handler == handler) then
                    table.remove(event.handlers, m);
                    return true;
                end
            end
            
            return false;
        end
        
        function element.createContext()
            local context = {};
            local eventTable = {};
            local eventMeta = {};
            local events = {};
            
            function context.addEventHandler(name, handler, propagate)
                if (addEventHandler(name, handler, propagate)) then
                    table.insert(events, {
                            name = name,
                            handler = handler
                    });
                    return true;
                end
                
                return false;
            end
            
            function context.destroy()
                local m,n;
                
                for m,n in ipairs(events) do
                    removeEventHandler(n.name, n.handler);
                end
            end
            
            -- Set up a private event namespace 
            function eventMeta.__index()
                return false;
            end
            
            function eventMeta.__newindex(t, key, value)
                if not (type(key) == "string") then
                    error("event namespace requires string type keys", 2);
                end
                
                if not (type(value) == "function") then
                    error("event namespace requires function handlers", 2);
                end
                
                setfenv(value, envAcquireDispatcher(debug.getfenv(value)));
                
                context.addEventHandler(key, value, false);
                return true;
            end
            
            eventMeta.__metatable = false;
            
            setmetatable(eventTable, eventMeta);
            
            context.events = eventTable;
            return context;
        end
        
        -- rootContext is an inline event access interface
        rootContext = element.createContext();
        element.events = rootContext.events;
        
        function element.executeEventHandlers(name, ...)
            local event = events[name];
            
            local m,n;
            
            if not (event) then return false; end;
            
            for m,n in ipairs(event.handlers) do
                if (n.propagate) or (source == element) then
                    if (n.handler(...) == false) then
                        return false;
                    end
                end
            end
            
            if (parent) then
                parent.executeEventHandlers(name, ...);
            end
            
            return true;
        end
        
        function element.triggerEvent(name, ...)
            local previous = source;
            
            -- Preserve the previous source, while setting it to the current element
            _G.source = element;
            
            if not (element.executeEventHandlers(name, ...)) then
                _G.source = previous;
                return false;
            end
            
            _G.source = previous;
            return true;
        end
        
        function element.setChild(child)
            local m,n;
            local childAPI = super(child);
            local alwaysOnTop = child.isAlwaysOnTop();
            local captive = child.isCaptiveMode();
            local outbreak = child.isOutbreakMode();
            local context = child.createContext();
        
            -- Add events to it
            for m,n in pairs(events) do
                child.addEvent(m);
            end
            
            function childAPI.getTopTable()
                return captive and captAlwaysOnTop or alwaysOnTop;
            end
            
            local function getDrawingOrder()
                return outbreak and outbreakElements or (captive and (alwaysOnTop and captAlwaysOnTop or drawingOrder) or (alwaysOnTop and alwaysOnTopElements or noncaptive));
            end
            
            function childAPI.setOutbreakMode(enabled)
                if (outbreak == enabled) then return false; end;
                
                tdelete(getDrawingOrder(), child);
                
                outbreak = enabled;
                
                table.insert(getDrawingOrder(), child);
                
                update();
                return true;
            end
            
            function childAPI.setCaptiveMode(enabled)
                if (enabled == captive) then return false; end;
                
                tdelete(getDrawingOrder(), child);
                
                captive = enabled;
                
                table.insert(getDrawingOrder(), child);
                
                update();
                return true;
            end
            
            function childAPI.setAlwaysOnTop(enabled)
                if (alwaysOnTop == enabled) then return false; end;
                
                tdelete(getDrawingOrder(), child);
                
                alwaysOnTop = enabled;
                
                table.insert(getDrawingOrder(), child);
                
                update();
                return true;
            end
            
            function childAPI.putToFront()
                update();
                
                local order = getDrawingOrder();
                
                tdelete(order, child);
                table.insert(order, child);
                return true;
            end
            
            function childAPI.putToBack()
                update();
                
                local order = getDrawingOrder();
            
                tdelete(order, child);
                table.insert(order, 1, child);
                return true;
            end
            
            function childAPI.destroy()
                update();
            
                context.destroy();
                context = nil;
                
                tdelete(getDrawingOrder(), child);
                
                childAPI = nil;
                child = nil;
                return true;
            end
            
            -- Force rerender
            update();
            
            table.insert(getDrawingOrder(), child);
            return childAPI;
        end
        
        function element.getTopTable()
            return childAPI.getTopTable();
        end
        
        function element.moveToBack()
            if (activeElement == element) then
                activeElement = false;
            
                triggerEvent("onBlur");
                
                blur();
            end
            
            childAPI.putToBack();
            return true;
        end
        
        function element.giveFocus()
            if (activeElement == element) then return true; end;
        
            if not (triggerEvent("onFocus")) then return false; end;
            
            if (activeElement) then
                local active = activeElement;
                
                activeElement = false;
            
                active.triggerEvent("onBlur");
                
                active.blur();
            end
        
            activeElement = element;
            
            focus();
            return true;
        end
        
        function element.moveToFront()
            parent.moveToFront();
            
            giveFocus();
            
            childAPI.putToFront();
            return true;
        end
        
        function element.setAlwaysOnTop(enabled)
            if (alwaysOnTop == enabled) then return false; end;
            
            childAPI.setAlwaysOnTop(enabled);
        
            alwaysOnTop = enabled;
            return true;
        end
        
        function element.isAlwaysOnTop()
            return alwaysOnTop;
        end
        
        function element.focus()
        end
        
        function element.blur()
        end
        
        function element.isActive()
            return activeElement == element;
        end
        
        function element.isMouseActive()
            return mouseElement == element;
        end
        
        function element.getTopElementAtOffset(offX, offY)
            local n = #alwaysOnTopElements;
            
            while not (n == 0) do
                local element = alwaysOnTopElements[n];
            
                if (element.isVisible()) then
                    local dx, dy = element.getPosition();
                    
                    if (element.test(offX - dx, offY - dy)) then return element; end;
                end
                
                n = n - 1;
            end
            
            n = #noncaptive;
            
            while not (n == 0) do
                local element = noncaptive[n];
            
                if (element.isVisible()) then
                    local dx, dy = element.getPosition();
                    
                    if (element.test(offX - dx, offY - dy)) then return element; end;
                end
                
                n = n - 1;
            end
            
            return false;
        end
        
        function element.getElementAtOffset(offX, offY)
            local e = getTopElementAtOffset(offX, offY);
            
            if (e) then return e; end;
            
            local n = #captAlwaysOnTop;
            
            while not (n == 0) do
                local element = captAlwaysOnTop[n];
            
                if (element.isVisible()) then
                    local dx, dy = element.getPosition();
                    
                    if (element.test(offX - dx, offY - dy)) then return element; end;
                end
                
                n = n - 1;
            end
            
            local n = #drawingOrder;
            
            while not (n == 0) do
                local element = drawingOrder[n];
            
                if (element.isVisible()) then
                    local dx, dy = element.getPosition();
                    
                    if (element.test(offX - dx, offY - dy)) then return element; end;
                end
                
                n = n - 1;
            end
            
            return false;
        end
        
        function element.handleMouseClick(button, x, y)
            local mouse = getElementAtOffset(x, y);
            
            if (mouse) then
                local posX, posY = mouse.getPosition();
                
                if (mouse.handleMouseClick(button, x - posX, y - posY)) then
                    return true;
                end
            end
            
            local triggerEvent = triggerEvent;
            local now = getTickCount();
            
            if not (element == activeElement) then
                moveToFront();
            elseif (lastMouseButton == button) and (now - mouseClickTime < 200) then
                if (triggerEvent("onDoubleClick", button, x, y)) then
                    mousedoubleclick(button, x, y);
                end
            end
            
            lastMouseButton = button;
            mouseClickTime = now;
            
            if not (triggerEvent("onClick", button, true, x, y)) then return true; end;
            
            mouseclick(button, true, x, y);
            return true;
        end
        
        function element.handleMouseMove(offX, offY)
            local mouse = getElementAtOffset(offX, offY);
            
            if not (mouse) then
                local triggerEvent = triggerEvent;
            
                if not (mouseElement == element) then
                    if (mouseElement) then
                        mouseElement.triggerEvent("onMouseLeave");
                        
                        mouseElement.mouseleave();
                    end
                    
                    mouseElement = element;
                    
                    triggerEvent("onMouseEnter");
                    mouseenter();
                end
                
                triggerEvent("onMouseMove", offX, offY);
                
                mousemove(offX, offY);
                return true;
            end
            
            local posX, posY = mouse.getPosition();
            
            return mouse.handleMouseMove(offX - posX, offY - posY);
        end
        
        function element.scanForElement(offX, offY)
            local subElem = getElementAtOffset(offX, offY);
            
            if not (subElem) then return element; end;
            
            local posX, posY = subElem.getPosition();
            
            return subElem.scanForElement(offX - posX, offY - posY);
        end
        
        function element.mouseclick(button, state, offX, offY)
            return true;
        end
        
        function element.mousedoubleclick(button, offX, offY)
            return true;
        end
        
        function element.mouseenter()
            return true;
        end
        
        function element.mousemove(offX, offY)
            return true;
        end
        
        function element.mouseleave()
            lastMouseButton = false;
        end
        
        function element.acceptInput()
            return false;
        end
        
        function element.keyInput(button, state)
            return true;
        end
        
        function element.input(char)
            return true;
        end
        
        function element.update()
            if (parent) then
                parent.update();
            end
        
            changed = true;
            return true;
        end
        
        function element.getRenderTarget()
            return target;
        end
        
        function element.destroyRenderTarget()
            if not (target) then return false; end;
            
            destroyElement(target);
            
            target = false;
            return true;
        end
        
        function element.ready()
            if not (isVisible()) then return false; end;
        
            return not (target == false);
        end
        
        function element.preRender()
            if (updateTarget) then
                destroyRenderTarget();
                
                target = dxCreateRenderTarget(width, height, supportAlpha);
                
                assert(target, "render target creation failed (" .. getType() .. ")");
                
                update();
                
                updateTarget = false;
            end
            
            if not (changed) then return false; end;
            
            dxSetRenderTarget(target, supportAlpha);
            return true;
        end
        
        function element.render()
            local m,n;
            
            -- Make sure we do it here, since children might flag during render!
            changed = false;
            
            local myTarget = getRenderTarget();
            
            for m,n in ipairs(drawingOrder) do
                if (n.visible) then
                    if (n.preRender()) then
                        dxBlendTargetWrap("modulate_add", n.render);
                    end
                    
                    dxSetRenderTarget(myTarget);
                    
                    n.present();
                end
            end
            
            for m,n in ipairs(captAlwaysOnTop) do
                if (n.visible) then
                    if (n.preRender()) then
                        dxBlendTargetWrap("modulate_add", n.render);
                    end
                    
                    dxSetRenderTarget(myTarget);
                    
                    n.present();
                end
            end
            
            triggerEvent("onRender");
            return true;
        end
        
        function element.renderTop()
            local screen = getRenderCapture();
            
            for m,n in ipairs(noncaptive) do
                if (n.visible) then
                    if (n.preRender()) then
                        dxBlendTargetWrap("modulate_add", n.render);
                    end
                    
                    dxSetRenderTarget(screen);
                    
                    n.present();
                end
            end
            
            for m,n in ipairs(alwaysOnTopElements) do
                if (n.visible) then
                    if (n.preRender()) then
                        dxBlendTargetWrap("modulate_add", n.render);
                    end
                    
                    dxSetRenderTarget(screen);
                    
                    n.present();
                end
            end
            
            return true;
        end
        
        function element.present()
            local x, y = getAbsolutePosition();

            local mode = dxGetBlendMode();
            dxSetBlendMode("modulate_add");
            
            dxDrawImage(x, y, width, height, target, 0, 0, 0, blendColor);
            
            dxSetBlendMode(mode);
            
            renderTop();
            
            triggerEvent("onPresent", false, x, y);
            return true;
        end
        
        function element.resetRenderTarget()
            dxSetRenderTarget(target);
            return true;
        end
        
        function element.invalidate()
            return true;
        end
        
        local function restore()
            element.invalidate();
            
            element.update();
            return true;
        end
        
        function element.destroy()
            _G.removeEventHandler("onClientRestore", root, restore);
            
            triggerEvent("onDestruction");
            
            -- Clear graphics
            destroyRenderTarget();
            
            defereControls();
        
            elements[element] = nil;
        end
        
        addEventHandler("onClientRestore", root, restore);
        
        if (parent) then	--dxRoot will skip this
            -- We have to succeed being assigned a parent.
            -- Otherwise the element is invalid, has to be destroyed.
            if not (element.setParent(parent)) then
                element.destroy();
                return false;
            end
            childAPI = element.getChildAPI();
            
            -- Set things up
            element.setBlendColor(0xFF, 0xFF, 0xFF, 0xFF);
        
            -- Trigger creation event
            element.triggerEvent("onCreation");
        end
        
        -- Run all extension constructors on them
        dxElementPlugin.initObject(element);
        
        elements[element] = true;
        return element;
    end

    if (__DXDEBUG) then
        local _createDXElement = createDXElement;
        local error_callback = __DXDEBUG_ERROR;
        local type = type;
        local error = error;
        local min = math.min;
        local tremove = table.remove;
        
        function createDXElement(...)
            local elem = _createDXElement(...);
            
            if not (elem) then return false; end;
            
            local function outError(name, msg)
                if (error_callback) then
                    error_callback(elem, name, msg);
                end
                
                error(msg .. " [in " .. name .. "]", 4);
            end
            
            function elem.wrapDebug(name, ...)
                local argInfo = { ... };
                local infoCount = #argInfo;
                
                elem[name] = function(...)
                    local args = { ... };
                    local n = 1;
                    local count = min(#args, infoCount);
                    
                    while (n <= count) do
                        local this_type = type(args[n]);
                        local exp_type = argInfo[n];
                        local d_type = type(exp_type);
                        
                        if (d_type == "string") then
                            if not (exp_type == "any") and not (this_type == exp_type) then
                                outError(name, "invalid argument #" .. n .. " type  '" .. this_type .. "' (expected '" .. exp_type .."')");
                                return false;
                            end
                        elseif (d_type == "table") then
                            local i = 1;
                            local d_count = #exp_type;
                            local kind = exp_type[1];
                            
                            if (kind == "opt") then
                                i = i + 1;
                            end
                            
                            if (i <= d_count) then
                                local found = false;
                                
                                while (i <= d_count) do
                                    if (this_type == exp_type[i]) then
                                        found = true;
                                        break;
                                    end
                                
                                    i = i + 1;
                                end
                                
                                if (found == false) then
                                    outError(name, "invalid argument #" .. n .. " type " .. this_type);
                                    return false;
                                end
                            end
                        end
                    
                        n = n + 1;
                    end
                    
                    while (n <= infoCount) do
                        local info = argInfo[n];
                        local d_type = type(info);
                        
                        if (d_type == "table") then
                            if not (info[1] == "opt") then
                                outError(name, "invalid argument count (got " .. count ..", expected " .. infoCount ..")");
                                return false;
                            end
                        else
                            outError(name, "invalid argument count (got " .. count ..", expected " .. infoCount ..")");
                            return false;
                        end
                        
                        n = n + 1;
                    end
                    
                    return super(...);
                end
            end
            
            for m,n in ipairs({
                { "supportAlpha", "boolean" },
                { "setCaptiveMode", "boolean" },
                { "setOutbreakMode", "boolean" },
                { "setPosition", "number", "number" },
                { "setSize", "number", "number" },
                { "setWidth", "number" },
                { "setHeight", "number" },
                { "setExtraMargin", "number", "number", "number", "number" },
                { "setBlendColor", "number", "number", "number", { "opt", "number" } },
                { "isInLocalArea", "number", "number" },
                { "isHit", "number", "number" },
                { "test", "number", "number" },
                { "setVisible", "boolean" },
                { "setDisabled", "boolean" },
                { "addEvent", "string" },
                { "addEventHandler", "string", "function", { "opt", "boolean" } },
                { "removeEventHandler", "string", { "opt", "function" } },
                { "setAlwaysOnTop", "boolean" },
                { "getTopElementAtOffset", "number", "number" },
                { "getElementAtOffset", "number", "number" },
                { "handleMouseClick", "string", "number", "number" },
                { "handleMouseMove", "number", "number" }
            }) do
                local name = n[1];
                tremove(n, 1);
                
                elem.wrapDebug(name, unpack(n));
            end
            
            -- Debug that it has a valid size at render-target creation
            function elem.preRender()
                if (width < 1) or (height < 1) then
                    outError("preRender", "invalid render size");
                    return false;
                end
            
                return super();
            end
            
            return elem;
        end
    end
    
    --[[ Set up the context interface ]]--
    hierarchy.createElement = createDXElement;
    
    -- dxElements application interface given by the environment it is running in.
    -- Should contain compatibility callbacks. (optional)
    -- Can be any indexable type.
    local dxInterface = createClass();  -- a class for easy extendability.
    
    -- An obstructed mouse cannot interact with captive elements.
    -- Top layer elements (i.e. outbreak layer) can still interact.
    -- Return a boolean whether the mouse is obstructed.
    function dxInterface.isMouseObstructed()
        return false;
    end
    
    -- By default, a mouse is not defined in a dxHierarchy.
    -- Return the x and y coordinates in this function, false if the mouse is
    -- outside the screen.
    function dxInterface.getMousePosition()
        return false;
    end
    
    -- The dxHierarchy needs to be aware of key states, so the dxElements can
    -- be independent from the inputhandler. The system does not define a
    -- strict definition of key names (beyond mouse keys, which are "left", "right", etc).
    -- Returns a boolean. True indicated pressed down, false released.
    function dxInterface.getKeyState(key)
        return false;
    end
    
    function hierarchy.handleMouseClick(button, state, x, y)
        if not (state) then
            if not (activeElement) then return false; end;
            
            local posX, posY = activeElement.getScreenPosition();
            local offX, offY = x - posX, y - posY;
            
            dx_root.reference();
            
            if not (activeElement.triggerEvent("onClick", button, false, offX, offY)) then
                dx_root.dereference();
                return true;
            end
            
            activeElement.mouseclick(button, false, offX, offY);
            dx_root.dereference();
            return true;
        end
        
        local mouse = dx_root.getTopElementAtOffset(x, y);
        
        if (mouse) then
            local posX, posY = mouse.getScreenPosition();
            
            dx_root.reference();
        
            mouse.handleMouseClick(button, x - posX, y - posY);
            
            dx_root.dereference();
            return true;
        end
        
        if (dxInterface.isMouseObstructed(x, y)) then
            if (activeElement) then
                local element = activeElement;
                
                dx_root.reference();
                
                activeElement = false;
                
                element.triggerEvent("onBlur");
                
                element.blur();
                
                dx_root.dereference();
            end
            
            return false;
        end

        return dx_root.handleMouseClick(button, x, y);
    end
    
    function hierarchy.handleMouseMove(x, y)
        if (mouseElement) and (mouseElement.isDragging()) then
            local _x, _y = mouseElement.getScreenPosition();
            
            _x, _y = x - _x, y  - _y;
            
            dx_root.reference();
            
            mouseElement.triggerEvent("onMouseMove", _x, _y);
            mouseElement.mousemove(_x, _y);
            
            dx_root.dereference();
            return true;
        end
        
        local mouse = dx_root.getTopElementAtOffset(x, y);
        
        if (mouse) then
            local posX, posY = mouse.getScreenPosition();
            
            dx_root.reference();
        
            local ret = mouse.handleMouseMove(x - posX, y - posY);
            
            dx_root.dereference();
            return ret;
        end
        
        if (dxInterface.isMouseObstructed(x, y)) then
            if (mouseElement) then
                dx_root.reference();
                
                mouseElement.triggerEvent("onMouseLeave");
                
                mouseElement.mouseleave();
                
                dx_root.dereference();
                
                mouseElement = false;
            end
            
            return false;
        end
        
        return dx_root.handleMouseMove(x, y);
    end
    
    function hierarchy.updateMouse()
        if (mouseElement) and (mouseElement.isDragging()) then
            return;
        end
        
        local mouseX, mouseY = dx_root.getAbsoluteMousePosition();
        
        local curRootMouseElement = false;
        
        do
            local curTopMouseElement = dx_root.getTopElementAtOffset(mouseX, mouseY);
        
            if (curTopMouseElement) then
                curRootMouseElement = curTopMouseElement;
            end
            
            if not (dxInterface.isMouseObstructed(mouseX, mouseY)) then
                if not (curMouseElement) then
                    local regMouseElement = dx_root.getElementAtOffset(mouseX, mouseY);
                    
                    if (regMouseElement) then
                        curRootMouseElement = regMouseElement;
                    end
                end
            end
        end
        
        --.If we have found a element on the dx_root layer, we must scan inside of it aswell.
        local curMouseElement = false;
        
        if (curRootMouseElement) then
            local posX, posY = curRootMouseElement.getPosition();
        
            curMouseElement = curRootMouseElement.scanForElement(mouseX - posX, mouseY - posY);
        end
        
        if not (curMouseElement == mouseElement) then
            if (mouseElement) then
                mouseElement.triggerEvent("onMouseLeave");
                
                mouseElement.mouseleave();
                
                mouseElement = false;
            end
            
            if (curMouseElement) then
                mouseElement = curMouseElement;
            
                curMouseElement.triggerEvent("onMouseEnter");
                
                curMouseElement.mouseenter();
                
                -- Signal activity with a mouse move.
                local screenX, screenY = curMouseElement.getScreenPosition();
                
                local localMouseX = mouseX - screenX;
                local localMouseY = mouseY - screenY;
                
                curMouseElement.triggerEvent("onMouseMove", localMouseX, localMouseY);
                curMouseElement.mousemove(localMouseX, localMouseY);
            end
        end
    end
    
    function hierarchy.handleKeyInput(button, down, isInput)
        if not (activeElement) then return false; end;
        
        dx_root.reference();
        
        if not (activeElement.triggerEvent("onKeyInput", button, down, isInput)) then
            dx_root.dereference();
            return false;
        end
        
        activeElement.keyInput(button, down, isInput);
        
        dx_root.dereference();
        return true;
    end
    
    function hierarchy.handleInput(char)
        if not (activeElement) then return false; end;
        
        dx_root.reference();
        
        if not (activeElement.triggerEvent("onInput", char)) then
            dx_root.dereference();
            return false;
        end
        
        activeElement.input(char);
        
        dx_root.dereference();
        return true;
    end
    
    function hierarchy.getMouseRenderFunctor()
        if (mouseElement) then
            return mouseElement.getMouseRenderFunctor();
        end
        
        return false;
    end
    
    -- Create the hierarchy root element.
    dx_root = createDXElement("root");
    
    local rootWidth, rootHeight = 0, 0;  -- render-size of the hierarchy.
    local updateTarget = false;
    
    -- Specialize the root instance
    function dx_root.setSize(w, h)
        if not (super(w, h)) then return false; end;
        
        rootWidth, rootHeight = w, h;
        
        updateTarget = true;
        return true;
    end
    
    function dx_root.isVisible()
        return visible;
    end

    function dx_root.setVisible(vis)
        if (visible == vis) then return false; end;
        
        if not (vis) then
            if not (triggerEvent("onHide")) then return false; end;
            
            visible = false;
            
            hide();
            return true;
        elseif not (triggerEvent("onShow")) then return false; end;
        
        visible = true;
        
        show();
        
        update();
        return true;
    end

    function dx_root.isDisabled()
        return false;
    end

    function dx_root.getRenderCapture()
        return rootCapture;
    end

    -- By default, every position is valid inside of a dxHierarchy.
    function dx_root.isInScreen(x, y)
        return true;
    end

    function dx_root.moveToFront()
        return giveFocus();
    end

    function dx_root.getTopElementAtOffset(offX, offY)
        local n = #outbreakElements;
        
        while not (n == 0) do
            local element = outbreakElements[n];
        
            if (element.isVisible()) then
                local dx, dy = element.getScreenPosition();
                
                if (element.test(offX - dx, offY - dy)) then return element; end;
            end
            
            n = n - 1;
        end
        
        return super(offX, offY);
    end

    function dx_root.ready()
        return false;
    end

    function dx_root.isHit()
        return true;
    end
    
    function dx_root.updateRT()
        if (updateTarget) then
            rootCapture = dxCreateRenderTarget(rootWidth, rootHeight, true);
            
            assert(rootCapture, "could not create root capture for render hierarchy");
            
            updateTarget = false;
        end
    end

    function dx_root.preRender()
        updateRT();
        return super();
    end
    
    function dx_root.drawOutbreakLayer(capture)
        dxSetRenderTarget(getRenderTarget());
        
        -- Draw the elements which were rendered alwaysOnTop!
        dxDrawImage(0, 0, width, height, capture, 0, 0, 0, tocolor(0xFF, 0xFF, 0xFF, 0xFF));
        return true;
    end
    
    function dx_root.present()
        dxSetRenderTarget(rootCapture, true);
        
        renderTop();
        
        -- Render the outbreak elements
        local m,n;
        
        for m,n in ipairs(outbreakElements) do
            if (n.isVisible()) then
                if (n.preRender()) then
                    dxBlendTargetWrap("modulate_add", n.render);
                end
                
                dxSetRenderTarget(rootCapture);
                
                n.present();
            end
        end
        
        drawOutbreakLayer(rootCapture);
        
        triggerEvent("onPresent");
        return true;
    end

    function dx_root.getScreenSize()
        return width, height;
    end

    function dx_root.isInLocalArea()
        return true;
    end

    function dx_root.isInArea()
        return true;
    end

    function dx_root.moveToFront()
        if (activeElement) then
            local active = activeElement;
            
            activeElement = false;
        
            active.triggerEvent("onBlur");
            
            active.blur();
        end

        activeElement = dx_root;
        
        triggerEvent("onFocus");
        
        focus();
        return true;
    end

    function dx_root.moveToBack()
        return false;
    end

    function dx_root.getScreenPosition()
        return 0, 0;
    end

    function dx_root.getAbsolutePosition()
        return 0, 0;
    end
    
    local function mousepos()
        local interface = dxInterface;
        
        if (interface) then
            return interface.getMousePosition();
        end
        
        return false;
    end

    function dx_root.getMousePosition()
        return mousepos();
    end

    function dx_root.getAbsoluteMousePosition()
        return mousepos();
    end

    function dx_root.defereControls()
        return true;
    end

    function dx_root.setParent()
        return false;
    end
    
    -- Add the main events.
    dx_root.addEvent("onCreation");
    dx_root.addEvent("onSize");
    dx_root.addEvent("onPosition");
    dx_root.addEvent("onShow");
    dx_root.addEvent("onHide");
    dx_root.addEvent("onFocus");
    dx_root.addEvent("onBlur");
    dx_root.addEvent("onClick");
    dx_root.addEvent("onDoubleClick");
    dx_root.addEvent("onMouseEnter");
    dx_root.addEvent("onMouseLeave");
    dx_root.addEvent("onMouseMove");
    dx_root.addEvent("onKeyInput");
    dx_root.addEvent("onInput");
    dx_root.addEvent("onFrame");
    dx_root.addEvent("onRender");
    dx_root.addEvent("onPresent");
    dx_root.addEvent("onDestruction");
    
    -- Function to render the given hierarchy.
    -- The target surface should be got through getRenderTarget.
    function hierarchy.render()
        if (dx_root.isVisible()) then
            if (dx_root.preRender()) then
                dx_root.render();
            end
            
            -- Other stuff
            dx_root.present();
            
            -- Restore render target to default
            dxSetRenderTarget();
        end
        
        return true;
    end
    
    function hierarchy.getRoot()
        return dx_root;
    end
    
    function hierarchy.getKeyState(key)
        return dxInterface.getKeyState(key);
    end
    
    function hierarchy.getActiveElement()
        return activeElement;
    end
    
    function hierarchy.getMouseElement()
        return mouseElement;
    end
    
    function hierarchy.getInterface()
        return dxInterface;
    end
    
    function hierarchy.destroy()
        dx_root.destroy();
    
        hierarchies[hierarchy] = nil;
    end
    
    hierarchies[hierarchy] = true;
    return hierarchy;
end
_G.createDXHierarchy = createDXHierarchy;

local screenWidth, screenHeight = guiGetScreenSize();

local screenContext = createDXHierarchy();
local dxRoot = screenContext.getRoot();

-- We have to specialize the screenbuffer.
function dxRoot.getScreenSize()
    return screenWidth, screenHeight;
end

function dxRoot.getRenderTarget()
    return nil;
end

function dxRoot.preRender()
    updateRT();
    return true;
end

function dxRoot.drawOutbreakLayer(capture)
    dxSetRenderTarget();
    
    -- Draw the elements which were rendered alwaysOnTop!
    dxDrawImage(0, 0, width, height, capture, 0, 0, 0, tocolor(0xFF, 0xFF, 0xFF, 0xFF), true);
    return true;
end

function dxRoot.invalidate()
    local sw, sh = guiGetScreenSize();
    
    if not (sw == screenWidth) or not (sh == screenHeight) then
        setSize(sw, sh);
        
        screenWidth, screenHeight = sw, sh;
    end
end
dxRoot.setSize(screenWidth, screenHeight);

-- Define the standard globals.
_G.dxRoot = dxRoot;
_G.dxScreenContext = screenContext;

-- Standard old-style dxElement creation callback.
-- Now it creates elements at the appropriate hierarchy.
function _G.createDXElement(elementType, parent)
    if not (parent) then
        parent = dxRoot;
    end
    
    return parent.getHierarchy().createElement(elementType, parent);
end

-- Callback to render the dx elements, for better control
-- There for backwards compatibility! Or for simple applications.
function renderDXElements()
    return screenContext.render();
end

-- Function for backwards compatibilty, as there is no globally active
-- dxElement anymore. Activity is defined in hierarchies now.
function getActiveDXElement()
    return screenContext.getActiveElement();
end

function getActiveMouseDXElement()
    return screenContext.getMouseElement();
end

-- Input functions set for the default screenbuffer.
-- Available for backwards compatibility.
-- The screen context should be accessed directly from now on.
function handleDXMouseClick(button, state, x, y)
    return screenContext.handleMouseClick(button, state, x, y);
end

function handleDXMouseMove(x, y)
    return screenContext.handleMouseMove(x, y);
end

function handleDXKeyInput(button, down, isInput)
    return screenContext.handleKeyInput(button, down, isInput);
end

function handleDXInput(char)
    return screenContext.handleInput(char);
end

function registerDXExtension(constructor)
    return dxElementPlugin.registerExtension(constructor);
end

-- Function to destroy the dxElements environment.
-- After calling this function, dxElements should not be used anymore.
function shutdownDXElements()
    for m,n in pairs(hierarchies) do
        m.destroy();
    end

    return true;
end