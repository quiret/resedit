-- Created by (c)The_GTA. All rights reserved.

-- Optimizations
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
local guiSetVisible = guiSetVisible;
local guiSetSize = guiSetSize;

-- Only include CEGUI compatibility code if desired.
if (__DXELEMENTS_EXCLUDE_CEGUICOMPAT) then
    return false;
end

-- Create a screen-sized CEGUI buffer which prevents clicks on unrelated CEGUI.
local screenWidth, screenHeight = guiGetScreenSize();
local hackStatic = guiCreateStaticImage(0, 0, screenWidth, screenHeight, "pixel.png", false);
guiSetVisible(hackStatic, false);
guiSetProperty(hackStatic, "AlwaysOnTop", "True");

-- TODO: implement standard element extensions.
local registerDXExtension = registerDXExtension;

-- CEGUI extension.
registerDXExtension(
    function(element)
        local previousGUIState = false;
        local guiRoot = guiRoot;
    
        function element.focus()
            previousGUIState = guiGetInputMode();
            
            guiSetInputEnabled(acceptInput());
        end
        
        function element.blur()
            guiSetInputMode(previousGUIState);
        end
        
        local function propertyHandler(name, value)
            if not (name == "inputMode") then return true; end;
            if not (element == activeElement) then return true; end;
            
            previousGUIState = value;
            
            cancelEvent();
            return false;
        end
        
        addEventHandler("onClientGUIPropertyChanged", guiRoot, propertyHandler);
        
        function element.destroy()
            _G.removeEventHandler("onClientGUIPropertyChanged", guiRoot, propertyHandler);
        end
    end
);

-- Since this file is included after dxElements_client.lua, dxRoot is set.
local dxRoot = dxRoot;

local function isTopElement(element)
    local parent = element.getParent();
    
    if not (parent == dxRoot) then
        return isTopElement(parent);
    end
    
    return not element.isCaptiveMode();
end

-- If the mouse leaves dxElements render screen (obstructed by CEGUI),
-- we remove the hackStatic.
-- Otherwise, if mouse is on an dxElement, CEGUI underneath should not be
-- trigerred.
dxRoot.addEventHandler("onMouseEnter", function()
        if (source == dxRoot) then return true; end;
        
        if not (isTopElement(source)) then return true; end;
        
        return guiSetVisible(hackStatic, true);
    end
);

dxRoot.addEventHandler("onMouseLeave", function()
        if (source == dxRoot) then return true; end;
        
        if not (isTopElement(source)) then return true; end;
        
        return guiSetVisible(hackStatic, false);
    end
);

-- Handle the CEGUI backbuffer.
function dxRoot.invalidate()
    screenWidth, screenHeight = guiGetScreenSize();
    
    guiSetSize(hackStatic, screenWidth, screenHeight, false);
end

-- Setup default dxElements interface
local dxInterface = dxScreenContext.getInterface();

function dxInterface.isMouseObstructed(x, y)
    return not not (guiGetAtPosition(x, y));
end