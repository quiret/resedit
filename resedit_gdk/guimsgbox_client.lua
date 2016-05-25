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

local messageBoxes = {};
local function addEvents(elem)
	elem.addEvent("onMsgBoxInput");
	elem.addEvent("onMsgBoxConfirm");
end
addEvents(dxRoot);

function createMsgBox(msg, setting, parent)
    local msgBox = createWindow(parent);
	local root = msgBox.getRoot();
    local screenWidth, screenHeight = msgBox.getParent().getSize();
    local fontHeight = dxGetFontHeight(1, "sans");
    local guiW, guiH;
    local lineData = structureString(msg, 350, screenWidth - 100, 1, "sans");
    
    if not (msgBox) then return false; end;
	
	-- Add events locally
	addEvents(msgBox);
	
	--msgBox.setBackgroundColor(0x08, 0x10, 0x20);
    
    function msgBox.getType()
        return "messageBox";
    end
    
    function msgBox.render()
        super();
        
        -- After call to render the target may change
        resetRenderTarget();
        
        local y = 0;
        local n;
        
        -- Render the content
        for n=1,#lineData.lines do
            local line = lineData.lines[n];
            
            if not (strlen(line) == 0) then
                dxDrawText(line, 25, 25 + y, 0, 0, tocolor(0xFF, 0xFF, 0xFF, 0xFF), 1, "sans");
            end
            
            y = y + fontHeight;
        end
        
        return true;
    end
    
    -- Adjust the window setting
    guiW = math.max(350, lineData.width) + 50;
    guiH = 65 + lineData.height;
    
    msgBox.setRootSize(guiW, guiH);
    msgBox.setPosition((screenWidth - guiW) / 2, (screenHeight - guiH) / 2);
    
    if not (setting) or (setting == "info") then
        local close = createButton(root);
        close.setPosition((guiW - 100) / 2, guiH - 30);
        close.setSize(100, 20);
        close.setText("OK");
        
        function close.events.onPress()
            msgBox.destroy();
            return true;
        end
        
        close.moveToFront();
    elseif (setting == "confirm") then
        local yes = createButton(root);
        yes.setPosition(guiW / 2 - 80, guiH - 30);
        yes.setSize(75, 20);
        yes.setText("Yes");
        local no = createButton(root);
        no.setPosition(guiW / 2 + 5, guiH - 30);
        no.setSize(75, 20);
        no.setText("No");
        
        function yes.events.onPress()
            msgBox.triggerEvent("onMsgBoxConfirm", true);
            msgBox.destroy();
            return true;
        end
        
        function no.events.onPress()
            msgBox.triggerEvent("onMsgBoxConfirm", false);
            msgBox.destroy();
            return true;
        end
        
        yes.moveToFront();
    elseif (setting == "input") then
        guiH = guiH + 25;
        msgBox.setRootSize(guiW, guiH);
        msgBox.setPosition((screenWidth - guiW) / 2, (screenHeight - guiH) / 2);
        
        local input = createEditBox(root);
        input.setPosition(25, guiH - 55);
        input.setSize(guiW - 50, 20);
        input.setText("");
        input.moveToFront();
        
        local ok = createButton(root);
        ok.setPosition(guiW / 2 - 80, guiH - 30);
        ok.setSize(75, 20);
        ok.setText("OK");
        local cancel = createButton(root);
        cancel.setPosition(guiW / 2 + 5, guiH - 30);
        cancel.setSize(75, 20);
        cancel.setText("Cancel");
        
        function input.events.onAccept()
            msgBox.triggerEvent("onMsgBoxInput", input.getText());
            msgBox.destroy();
            return true;
        end
        
        function ok.events.onPress()
            msgBox.triggerEvent("onMsgBoxInput", input.getText());
            msgBox.destroy();
            return true;
        end
        
        function cancel.events.onPress()
            msgBox.destroy();
            return true;
        end
    end
    
    function msgBox.destroy()
        messageBoxes[msgBox] = nil;
    end
    
    messageBoxes[msgBox] = true;
    return msgBox;
end

function isMsgBox(element)
    return not (messageBoxes[element] == nil);
end