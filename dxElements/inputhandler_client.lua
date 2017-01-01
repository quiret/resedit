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

-- Add system events.
addEvent("onClientKeyStateChange");
addEvent("onClientInterfaceClick");
addEvent("onClientInterfaceMouseMove");
addEvent("onClientInterfaceKey");
addEvent("onClientInterfaceInput");
addEvent("onClientGUIDissolve");
addEvent("onClientDXGUIClick");
local specialKeys = {};
local active = true;
local input_interface = false;
local targetHierarchy = dxScreenContext;

-- Settings of the input handler.
local enableCursor = true;
local enableKeyInput = true;
local enableInput = true;

local keyInfo = {};
_G.keyInfo = keyInfo;

-- Mouse Globals
mouseX, mouseY = 0, 0;
mouseMoveTime = getTickCount();

addEventHandler("onClientPreRender", root, function()
        if not (enableCursor) then return true; end;
		if not (active) then return true; end;

		local relX, relY = getCursorPosition();
		
		if (relX) then
            local screenW, screenH = guiGetScreenSize();
            local x, y = relX * screenW, relY * screenH;
            
            if (mouseX == x) and (mouseY == y) then return true; end;
            
            mouseX, mouseY = x, y;
            mouseMoveTime = getTickCount();
            
            if (targetHierarchy.handleMouseMove(x, y)) then return true; end;
            
            triggerEvent("onClientInterfaceMouseMove", root, x, y);
        else
            -- We should cancel mouse activity from the hierarchy.
            local elem = targetHierarchy.getMouseElement();
            
            if (elem) then
                elem.dropMouseFocus();
            end
        end
	end
);

addEventHandler("onClientClick", root, function(button, state, x, y)
		local down = (state == "down");
        
        if (enableCursor) and (targetHierarchy.handleMouseClick(button, down, x, y)) then
            triggerEvent("onClientDXGUIClick", root, button, down, x, y);
            return true;
        end
        
        triggerEvent("onClientInterfaceClick", root, button, down, x, y);
    end
);

-- KEY TABLES START
local keyTable = { "arrow_l", "arrow_u", "arrow_r", "arrow_d", "num_0", "num_1", "num_2", "num_3", "num_4", "num_5",
 "num_6", "num_7", "num_8", "num_9", "num_mul", "num_add", "num_sep", "num_sub", "num_div", "num_dec", "F1", "F2", "F3", "F4", "F5",
 "F6", "F7", "F8", "F9", "F10", "F11", "F12", "backspace", "tab", "lalt", "ralt", "enter", "space", "pgup", "pgdn", "end", "home",
 "insert", "delete", "lshift", "rshift", "lctrl", "rctrl", "pause", "capslock", "scroll" };
 
local inputTable = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k",
 "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "[", "]", ";", ",", "-", ".", "/", "#", "\\", "=" };
 
local specialTable = { "mouse2", "mouse3", "mouse4", "mouse5", "mouse_wheel_up", "mouse_wheel_down" };
 -- KEY TABLES END
 
-- Init our keyInfo
for m,n in ipairs(keyTable) do
    local info = {};
    
    info.state = false;
    info.input = false;
    info.rep = true;
    keyInfo[n] = info;
end

for m,n in ipairs(inputTable) do
    local info = {};
    
    info.state = false;
    info.input = true;
    info.rep = true;
    keyInfo[n] = info;
end

-- Special entry for left mouse button
keyInfo.mouse1 = {
    state = false,
    input = false,
    rep = false
};

for m,n in ipairs(specialTable) do
    specialKeys[n] = true;
end

function inputPreserveStatus()
	if not (active) then return; end;

	active = false;

	-- Save settings
	return {
		lastActive = getActiveDXElement()
	};
end

function inputResurrect(status)
	if (active) then return; end;

	-- Update to last status
	if (status.lastActive) then
		status.lastActive.giveFocus();
	end
	
	active = true;
end

function inputIsValidKey(keyName)
    local info = keyInfo[keyName];
    
    return not not (info);
end

local function handleKeyInput(button, down, isInput)
    if (isMTAWindowActive()) then return false; end;
    if (active) and (enableKeyInput) and (targetHierarchy.handleKeyInput(button, down, isInput)) then return true; end;
    
    triggerEvent("onClientInterfaceKey", root, button, down, isInput);
    return true;
end
 
addEventHandler("onClientPreRender", root, function()
		if not (active) then return true; end;

        local m,n;
        local now = getTickCount();
        
        for m,n in pairs(keyInfo) do
            local state = getKeyState(m);
            
            if not (state == n.state) then
                if (state) and (not (n.input) or not ((input_interface) and (input_interface.isExternalInputActive()))) then
                    handleKeyInput(m, true, n.input);
					
                    if (n.rep) then
                        lastKeyPress = m;
                        lastKeyTime = getTickCount();
                    end
                else
                    handleKeyInput(m, false, n.input);
					
                    if (lastKeyPress == m) then
                        lastKeyPress = false;
                    end
                end
                
                n.state = state;
            end
        end
        
        if (lastKeyPress) and (now - lastKeyTime > 500) then
            handleKeyInput(lastKeyPress, true, keyInfo[lastKeyPress].input);
            
            lastKeyTime = now - 475;
        end
    end
);

addEventHandler("onClientCharacter", root, function(char)
        if (isMTAWindowActive()) then return true; end;

		-- We do not support unicode characters
		if (#char > 1) then
			char = "?";
		end

        if (active) and not ((input_interface) and (input_interface.isExternalObjectFocused()))
            and (enableInput) and (targetHierarchy.handleInput(char)) then return true; end;
        
        triggerEvent("onClientInterfaceInput", root, char);
    end
);

addEventHandler("onClientKey", root, function(button, down)
        if (isMTAWindowActive()) then return true; end;
        if not (specialKeys[button]) then return true; end;
        
        handleKeyInput(button, down, false);
    end
);

function registerInputhandlerInterface(interface)
    input_interface = interface;
    return true;
end

-- Extend the dxElements interface
local dxInterface = dxScreenContext.getInterface();

function dxInterface.getMousePosition()
    return mouseX, mouseY;
end

function dxInterface.getKeyState(key)
    local info = keyInfo[key];

    if not (info) then return false; end;
    
    return info.state;
end

-- Configuration function
function inputSetTargetHierarchy(hierarchy)
    targetHierarchy = hierarchy;
    return true;
end

function inputGetTargetHierarchy(hierarchy)
    return targetHierarchy;
end

function inputSetCursorState(enabled)
    enableCursor = enabled;
    return true;
end

function inputSetKeyInputState(enabled)
    enableKeyInput = enabled;
    return true;
end

function inputSetInputState(enabled)
    enableInput = enabled;
    return true;
end