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
local addEventHandler = addEventHandler;
local guiReleaseFocus = guiReleaseFocus;
local getElementsByType = getElementsByType;
local getElementChildren = getElementChildren;
local guiGetPosition = guiGetPosition;
local guiGetSize = guiGetSize;
local guiBringToFront = guiBringToFront;
local guiRoot = guiRoot;

-- Only include CEGUI compatibility code if desired.
if (__DXELEMENTS_EXCLUDE_CEGUICOMPAT) then
    return false;
end

addEvent("onClientGUIPropertyChanged");
local activeGUI = false;
local removeActiveGUI = false;
local hackFocus = guiCreateStaticImage(0, 0, 1, 1, "pixel.png", false);

local editableGUI = {
    ["gui-edit"] = true,
    ["gui-memo"] = true
};

addEventHandler("onClientGUIFocus", root, function()
        activeGUI = source;
        
        removeActiveGUI = false;
    end
);

addEventHandler("onClientGUIBlur", root, function()
        removeActiveGUI = true;
    end
);

function guiReleaseFocus()
    if not (activeGUI) then return true; end;

    guiBringToFront(hackFocus);
    
    activeGUI = false;
    return true;
end

addEventHandler("onClientDXGUIClick", root,
    function()
        -- Release CEGUI focus.
        guiReleaseFocus();
    end
);

addEventHandler("onClientElementDestroy", root, function()
        if not (source == activeGUI) then return true; end;
        
        activeGUI = false;
    end
);

-- Key compatibility.
function guiGetAtPosition(x, y)
    local m,n;
    local guiroot = getElementsByType("guiroot");
    
    for m,n in ipairs(guiroot) do
        local j,k;
        local children = getElementChildren(n);
        
        for j,k in ipairs(children) do
            if (guiGetVisible(k)) then
                local posX, posY = guiGetPosition(k, false);
                local width, height = guiGetSize(k, false);
                
                if (x > posX) and (y > posY) and (x < posX + width) and (y < posY + height) then
                    return k;
                end
            end
        end
    end
    
    return false;
end

local function isEditableGUI(gui)
    return (gui) and not (editableGUI[getElementType(gui)] == nil);
end

addEventHandler("onClientGUIFocus", guiRoot, function()
        if (isEditableGUI(source)) then
            setInputMode("no_binds");
        end
    end
);

addEventHandler("onClientGUIBlur", guiRoot, function()
        if not (isEditableGUI(source)) then return true; end;
		
        setInputMode("allow_binds");
    end
);

addEventHandler("onClientPreRender", root, function()
        -- Hack for delayed GUI fade notification
        if (removeActiveGUI) then
            activeGUI = false;
            
            removeActiveGUI = false;
        end
    end
);

function setInputMode(mode)
    triggerEvent("onClientGUIPropertyChanged", guiRoot, "inputMode", mode);
    
    if (wasEventCancelled()) then return false; end;
    
    guiSetInputMode(mode);
    return true;
end

-- Create input interface
local input_interface = {};

function input_interface.isExternalInputActive()
    return not (activeGUI == false) and (isEditableGUI(activeGUI));
end

function input_interface.isExternalObjectFocused()
    return not not activeGUI;
end

-- Register the input interface at the manager.
registerInputhandlerInterface(input_interface);