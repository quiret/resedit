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
local tostring = tostring;

addEvent("onClientScriptLockAcquire", true);
addEvent("onClientScriptLockFree", true);
addEvent("onResourceDataUpdate", true);
local resourceData={};
local resourceList={};

-- Globals
access = false;
transactionPacketBytes=0;
deleteOnQuit=false;
createClientRepository=false;

-- Resource GUI
mainGUI=false;
local pNoteEditor=false;
local pResourceInfo=false;
local pFileList=false;
local pTextbox=false;
local pSaveButton=false;
local pCloseButton=false;
local pTabHolder=false;
local pResourceName=false;
local pResourceType=false;
local pResourceDescription=false;
local pResourceAuthor=false;
local pFilename=false;
local pScriptType=false;
local pFunctionSearch=false;
local pFunctionList=false;
local pMenu=false;
local pRightClickMenu=false;
local pFunctionTabPanel=false;
local preservedStatus=false;

-- General
local charScale, charFont;
local lastKeyPress=false;
local lastKeyTime=0;
local editorMode=0;
local enableHighlighting;
local showLineNumbers;
local notifyOnChange;
local useFileManager;
local useResourceSelect;
local showFunctionsFullscreen;
local enableHints;
local colorFunctions;
local showHintDescription;
local functionlistArguments;
local automaticIndentation;
local soundPreview=false;
local library={};
local functionlist={};
local sortedFunctionlist={};
local internalDefinitions;
local importedDictionary;
local currentResource = false;
local sessions = {};
local currentSession = false;
local requestControlPanel=false;
local serverData;
local version=getVersion();

-- Sub GUI
local pDenyEditorAccessMsg=false;
local pClientConfigGUI=false;
local pServerConfigGUI=false;
local pFileManager=false;
local pSelectGUI=false;
local pScriptDebug=false;
local pUpdateGUI=false;
local pConfigEditor=false;
local pResourceCreation=false;
local pControlPanel=false;
local pPasteGUI=false;

local fileColors = {
	png = { 110, 160, 255 },
	dff = { 220, 220, 75 },
	txd = { 75, 220, 200 },
	mp3 = { 75, 220, 140 },
	wav = { 75, 220, 140 },
	ogg = { 75, 220, 140 },
	riff = { 75, 220, 140 },
	mod = { 75, 220, 140 },
	xm = { 75, 220, 140 },
	it = { 75, 220, 140 },
	s3m = { 75, 220, 140 }
};

local scriptColors = {
	server = { 75, 255, 75 },
	client = { 255, 100, 75 },
	shared = { 200, 75, 220 }
};

local rowSelect=false;
local curSelectRadius=200;

if not (getClipboard) then
	local _setClipboard = setClipboard;
	local buffer = "";

	function setClipboard(text)
		buffer = text;
		
		_setClipboard(text);
		return true;
	end
	
	function getClipboard()
		return buffer;
	end
end

function showMessageBox(msg, title, setting)
    local msgBox = themeCreateMsgBox(msg, setting);
	
	if (title) then
		msgBox.setText(title);
	end
    
    return msgBox;
end

local function isEditorClientReady()
    if (access) then
        return true;
    end
    
    return false;
end
_G.isEditorClientReady = isEditorClientReady;

function doWeHaveAccessTo(group, itemId)
    if (access.isAdmin) then
        return true;
    end
    
    if (group == "editor") then
        return access.account.editor[itemId];
    elseif (group == "controlPanel") then
        return access.account.controlPanel[itemId];
    elseif (group == "resources") then
        return access.resources[itemId];
    end
    
    return false;
end

function initLibrary()
	library = {};
end

function loadDictionary(node)
	local j,k;
	local dictionary = {};
	
	for j,k in ipairs(node.children) do
		local class = {
			functions = {},
			vars = {}
		};
		
		local functions = xmlFindSubNodeEx(k, "functions");
		
		if (functions) then
			local m,n;
		
			for m,n in ipairs(functions.children) do
				local details = {
					name = n.name,
				
					returnType = n.attr.returnType or "void",
					arguments = n.attr.arguments or "",
					textColor = n.attr.textColor,
					backColor = n.attr.backColor,
					
					type = k.name
				};
				
				if (n.attr.description) then
					details.description = parseStringInternal(n.attr.description)
				end
				
				table.insert(class.functions, details);
			end
		end
		
		dictionary[k.name] = class;
	end
	
	table.insert(library, dictionary);
	return dictionary;
end

function importDefinitions(type)
	local m,n;
	
	for m,n in ipairs(library) do
		local class = n[type];
		
		if (class) then
			local x,y;
			
			for x,y in ipairs(class.functions) do
				local functions = functionlist[y.name];
				
				if not (functions) then
					functions = {};
					
					functionlist[y.name] = functions;
				end
				
				table.insert(functions, y);
				table.insert(sortedFunctionlist, y);
			end
		end
	end
end

local function getLexicalDefinition(token)
	if (token == "client") then
		return "Player who sent last event";
	elseif (token == "source") then
		return "Triggered event's source element";
	end
	
	local entry = functionlist[token];
	local text = "";
	local m,n;
	
	if not (entry) then return false; end;
	
	local m,n;
	
	for m,n in ipairs(entry) do
		text = text .. n.returnType .. " " .. token .. " (" .. n.arguments .. ")";
		
		if (showHintDescription) and (n.description) then
			text = text .. "\n\n" .. n.description;
		end
		
		if not (m == #entry) then
			text = text .. "\n\n";
		end
	end
	
	return text;
end

function updateFunctionList()
	if not (mainGUI) then return false; end;
	
	pFunctionList.clearRows();
	
	local find = pFunctionSearch.getText();
	local w = 1;
	
	for m,n in ipairs(sortedFunctionlist) do
		if (string.find(n.name, find, 1, true)) then
			local row = pFunctionList.addRow();
			local display = n.name;
			
			if (functionlistArguments) then
				display = display .. " (" .. n.arguments ..  ")";
			end
			
			pFunctionList.setItemText(1, row, display);
            
            pFunctionList.getItemData(1, row).funcName = n.name;
			
			local color = scriptColors[n.type];
			
			if (color) then
				local r, g, b = unpack(color);
				
				if ((w % 2) == 0) then
					pFunctionList.setRowBackgroundColor(row, r / 2, g / 2, b / 2);
				else
					pFunctionList.setRowBackgroundColor(row, r / 3, g / 3, b / 3);
				end
			end
			
			w = w + 1;
		end
	end
	
	pFunctionList.setColumnWidth(1, math.max(150, pFunctionList.getMinimumColumnWidth(1)));
	return true;
end

function clearDefinitions()
	functionlist = {};
	sortedFunctionlist = {};
	
	pFunctionList.clearRows();
	return true;
end

function unloadDictionary(dict)
	local m,n;
	
	for m,n in ipairs(library) do
		if (n == dict) then
			table.remove(library, m);
			return true;
		end
	end
	
	return false;
end

-- Load the configuration files
local pConfigFile = xmlLoadFile("config.xml");

if not (pConfigFile) then
    local xml = xmlLoadFile("default/config.xml");
	
    pConfigFile = xmlCopyFile(xml, "config.xml");
	
    xmlUnloadFile(xml);
end
local config;
local editor;
local themes;
local syntax;
local specialsyntax;
local string1;
local string2;
local string3;
local comment1;
local comment2;
local dict;
local clientDict;
local serverDict;
local sharedDict;

local function loadConfig()
    config = xmlGetNode(pConfigFile);
    editor = findCreateNode(config, "editor");
	themes = findCreateNode(config, "themes");
    transfer = findCreateNode(config, "transfer");	-- global node
    objmgmt = findCreateNode(config, "objmgmt"); -- global node
    syntax = findCreateNode(config, "syntax");
    specialsyntax = findCreateNode(config, "specialsyntax");
    keybinds = findCreateNode(config, "keybinds"); -- global node
    string1 = findCreateNode(specialsyntax, "string1");
    string2 = findCreateNode(specialsyntax, "string2");
    string3 = findCreateNode(specialsyntax, "string3");
    comment1 = findCreateNode(specialsyntax, "comment1");
    comment2 = findCreateNode(specialsyntax, "comment2");
    dict = findCreateNode(config, "dict");
	clientDict = findCreateNode(dict, "client");
	serverDict = findCreateNode(dict, "server");
	sharedDict = findCreateNode(dict, "shared");
	
	-- Share editor node globally
	_G.editorNode = editor;

    local function isHexDigit(char)
        if (char > 96) and (char < 103) or
            (char > 47) and (char < 58) or
            (char > 64) and (char < 91) then
            
            return true;
        end
        
        return false;
    end

    -- Set up the nodes
    local m,n;
    
    function objmgmt.cbAddChild(child)
        showMessageBox("Cannot add children to objmgmt node", "Child Creation Failure");
        return false;
    end
    
    function objmgmt.cbSetAttribute(key, value)
        if (key == "enable") then
            if (value == "true") or (value == "false") then
                objmgmt.attr[key] = value;
                return true;
            end
        
            showMessageBox("Can be either 'true' or 'false'", "Value Error");
            return false;
        end
        
        return true;
    end
    
    function initSyntaxEntry(node)
        function node.cbAddChild(child)
            return false;
        end
        
        function node.cbSetAttribute(key, value)
            if (key == "textColor") or
                (key == "backColor") then
                
                local m;
                local len = strlen(value);
                
                if not (len == 6) then
                    showMessageBox("Color has to be 6 hex digits long.", "Color Error");
                    return false;
                end
                
                for m=1,6 do
                    if not (isHexDigit(strbyte(value, m))) then
                        showMessageBox("Invalid '" .. key .. "'", "Color Error");
                        return false;
                    end
                end
                
                -- We set it here to immediatly have effect
                node.attr[key] = value;
                
				local n;
				
				for m,n in ipairs(sessions) do
					n.getEditor().parseColor();
				end
				
                return true;
            end
            
            return true;
        end
        
        function node.cbUnsetAttribute(key)
            if (key == "textColor") or
                (key == "backColor") then
               
                node.attr[key] = nil;
				
				local m,n;

				for m,n in ipairs(sessions) do
					n.getEditor().parseColor();
				end           
            end
            
            return true;
        end
        
        return true;
    end

    function initSpecialSyntaxEntry(node)
        function node.cbAddChild(child)
            return false;
        end
        
        function node.cbSetAttribute(key, value)
            if (key == "textColor") or
                (key == "backColor") then
                
                local m,n;
                local len = strlen(value);
                
                if not (len == 6) then
                    showMessageBox("Color has to be 6 hex digits long.", "Color Error");
                    return false;
                end
                
                for m=1,6 do
                    if not (isHexDigit(strbyte(value, m))) then
                        showMessageBox("Invalid '" .. key .. "'", "Color Error");
                        return false;
                    end
                end
                
                -- We set it here to immediatly have effect
                node.attr[key] = value;
                
                -- Update the GUI
                if (pClientConfigGUI) then
                    pClientConfigGUI.updateSyntax(node);
                end
                
				for m,n in ipairs(sessions) do
					n.getEditor().parseColor();
				end
				
                return true;
            end
            
            return true;
        end
        
        function node.cbUnsetAttribute(key)
            if (key == "textColor") or (key == "backColor") then
                node.attr[key] = nil;
                
                -- Update the GUI
                if (pClientConfigGUI) then
                    pClientConfigGUI.updateSyntax(node);
                end

                local m,n;
				
				for m,n in ipairs(sessions) do
					n.getEditor().parseColor();
				end
            end
            
            return true;
        end
        
        return true;
    end

    for m,n in ipairs(syntax.children) do
        initSyntaxEntry(n);
    end

    for m,n in ipairs(specialsyntax.children) do
        initSpecialSyntaxEntry(n);
    end

    function config.cbRemoveChild(id)
        local node = config.children[id];

        if (node.name == "editor")
			or (node.name == "transfer")
            or (node.name == "syntax")
			or (node.name == "specialsyntax")
            or (node.name == "dict") then
            
            showMessageBox("You cannot remove '" .. node.name .. "'");
            return false;
        end
        
        return true;
    end

    function syntax.cbAddChild(node)
        local n;
        local len = strlen(node.name);

        -- Check if it is a correct name
        for n=1,len do
            if not (isName(strbyte(node.name, n))) then
                showMessageBox("Invalid name given to syntax highlight.", "Invalid Name");
                return false;
            end
        end
        
        initSyntaxEntry(node);
        return true;
    end

    function syntax.cbRemoveChild(id)
        local m,n;

        -- Remove for immediate effect
        syntax.children[id] = nil;
        
        -- Now color parse
		local m,n;
		
		for m,n in ipairs(sessions) do
			n.getEditor().parseColor();
		end
		
        return true;
    end

    function syntax.cbSetAttribute(key, value)
        if (key == "enable") then
            if (value == "true") then
                if (pClientConfigGUI) then
                    pClientConfigGUI.enableSyntax.setSelected(true);
                end
            
                enableHighlighting = true;
				
				local m,n;
				
				for m,n in ipairs(sessions) do
					n.getEditor().setColorEnabled(true);
				end
				
				return true;
            elseif (value == "false") then
                if (pClientConfigGUI) then
                    pClientConfigGUI.enableSyntax.setSelected(false);
                end
				
				enableHighlighting = false;
            
				local m,n;
				
				for m,n in ipairs(sessions) do
					n.getEditor().setColorEnabled(false);
				end
				
				return true;
            else
                showMessageBox("Either 'true' or 'false'.", "Syntax Error");
                return false;
            end
        end
        
        return true;
    end
	
	function syntax.cbUnsetAttribute(key)
		if (key == "enable") then
			showMessageBox("You cannot remove '" .. key .. "'.", "Attribute Error");
			return false;
		end
		
		return true;
	end

    function specialsyntax.cbAddChild(node)
        showMessageBox("You cannot add children to 'specialsyntax'", "Child Creation Failed");
        return false;
    end

    function specialsyntax.cbRemoveChild(id)
        showMessageBox("You cannot remove children from 'specialsyntax'", "Child Removal Failed");
        return false;
    end

    function editor.cbAddChild(node)
        showMessageBox("You cannot add children to the editor.", "Child Creation Failed");
        return false;
    end

    function editor.cbSetAttribute(key, value)
        if (key == "font") then
            if not (value == "default") and
                not (value == "default-bold") and
                not (value == "clear") and
                not (value == "arial") and
                not (value == "sans") and
                not (value == "pricedown") and
                not (value == "bankgothic") and
                not (value == "diploma") and
                not (value == "beckett") then
                
                showMessageBox("Unknown font");
                return false;
            end
            
            charFont = value;
            
            if (pClientConfigGUI) then
				pClientConfigGUI.font.selectItem(charFont);
            end
            
			local m,n;
			
			for m,n in ipairs(sessions) do
				n.getEditor().setFont(charScale, charFont);
			end
        elseif (key == "fontSize") then
            local size = tonumber(value);
        
            if not (size) then
                showMessageBox("Invalid fontSize");
                return false;
            end
            
            charScale = size;
            
            if (pClientConfigGUI) then
                pClientConfigGUI.fontSize.setText(value);
            end
            
			local m,n;
			
			for m,n in ipairs(sessions) do
				n.getEditor().setFont(charScale, charFont);
			end
        elseif (key == "notifyOnChange") then
            if (value == "true") then
                notifyOnChange = true;
            elseif (value == "false") then
                notifyOnChange = false;
            else
                showMessageBox("Either 'true' or 'false'", "Boolean Required");
                return false;
            end
            
            if (pClientConfigGUI) then
                pClientConfigGUI.notifyOnChange.setChecked(notifyOnChange);
            end
        elseif (key == "showLineNumbers") then
            if (value == "true") then
                showLineNumbers = true;
            elseif (value == "false") then
                showLineNumbers = false;
            else
                showMessageBox("Either 'true' or 'false'", "Boolean Required");
                return false;
            end
            
            if (pClientConfigGUI) then
                pClientConfigGUI.showLineBar.setChecked(showLineNumbers);
            end
            
			local m,n;
			
			for m,n in ipairs(sessions) do
				n.getEditor().showLineNumbers(showLineNumbers);
			end
        elseif (key == "useFileManager") then
            if (value == "true") then
                useFileManager = true;
                
                if (mainGUI.mode == "file") then
                    mainGUI.nextFileMode();
					
                    showFileManager(true);
                end
            elseif (value == "false") then
                useFileManager = false;
                
                if (pFileManager) and (guiGetVisible(pFileManager.window)) then
                    showFileManager(false);
					
                    mainGUI.nextFileMode();
                end
            else
                showMessageBox("Either 'true' or 'false'", "Boolean Required");
                return false;
            end
            
            if (pClientConfigGUI) then
                pClientConfigGUI.useFileManager.setChecked(useFileManager);
            end
        elseif (key == "useResourceSelect") then
            if (value == "true") then
                useResourceSelect = true;
            elseif (value == "false") then
                useResourceSelect = false;
            else
                showMessageBox("Either 'true' or 'false'", "Boolean Required");
                return false;
            end
		elseif (key == "automaticIndentation") then
            if (value == "true") then
				automaticIndentation = true;
            elseif (value == "false") then
                automaticIndentation = false;
            else
                showMessageBox("Either 'true' or 'false'", "Boolean Required");
                return false;
            end
			
			if (pClientConfigGUI) then
				pClientConfigGUI.automaticIndentation.setChecked(automaticIndentation);
			end
			
			local m,n;
			
			for m,n in ipairs(sessions) do
				n.getEditor().setAutoIndentEnabled(automaticIndentation);
			end
		elseif (key == "showFunctionsFullscreen") then
			if (value == "true") then
				showFunctionsFullscreen = true;
			elseif (value == "false") then
				showFunctionsFullscreen = false;
			else
                showMessageBox("Either 'true' or 'false'", "Boolean Required");
                return false;
			end
			
			setEditorMode(editorMode);
			
			if (pClientConfigGUI) then
				pClientConfigGUI.showFunctionsFullscreen.setChecked(showFunctionsFullscreen);
			end
		end
        
        return true;
    end

    function editor.cbUnsetAttribute(key)
        if (key == "fontSize") or
            (key == "font") or
            (key == "notifyOnChange") or
            (key == "showLineNumbers") or
            (key == "useFileManager") or
			(key == "showFunctionsFullscreen") or
			(key == "automaticIndentation") then
        
            showMessageBox("You cannot remove '" .. key .. "'", "Attribute Error");
            return false;        
        end
        
        return true;
    end
    
    local function initKeyBindNode(node)
        function node.cbAddChild(child)
            return false;
        end
        
        function node.cbSetAttribute(key, value)
            if (key == "key") then
                -- Check if the value is a valid key name.
                if not (inputIsValidKey(value)) then
                    showMessageBox(value .. " is not a valid key name.", "Value Error");
                    return false;
                end
                
                -- OK.
                node.attr[key] = value;
                return true;
            end
            
            return true;
        end
        
        return true;
    end
    
    function keybinds.cbAddChild(node)
        initKeyBindNode(node);
        return true;
    end
    
    for m,n in ipairs(keybinds.children) do
        initKeyBindNode(n);
    end
	
	-- Load the internal definitions
	internalDefinitions = loadDictionary(dict);
	
	local function initDictionaryNode(node)
		function node.cbAddChild()
			return false;
		end
		
		function node.cbSetAttribute(key, value)
			if (key == "description") then
				return true;
			elseif (key == "returnType") then
				return true;
			elseif (key == "arguments") then
				return true;
			elseif (key == "textColor")
				or (key == "backColor") then
				
				local m,n;
				local len = strlen(value);
				
				if not (len == 6) then
					showMessageBox("Color has to be 6 hex digits long.", "Color Error");
					return false;
				end
				
				for m=1,6 do
					if not (isHexDigit(strbyte(value, m))) then
						showMessageBox("Invalid '" .. key .. "'", "Color Error");
						return false;
					end
				end
				
				-- We set it here to immediatly have effect
				node.attr[key] = value;
				
				-- Update the GUI
				if (pClientConfigGUI) then
					pClientConfigGUI.updateSyntax(k);
				end
				
				parseColor();
				return true;
			else
				showMessageBox("Invalid dictionary attribute '" .. key .. "'", "Invalid Attribute");
				return false;
			end
		end
		
		function node.cbUnsetAttribute(key)
			if (key == "textColor") or
				(key == "backColor") then
				
				node.attr[key] = nil;
				parseColor();     
			elseif (key == "returnType") or
				(key == "arguments") then
				
				showMessageBox("Cannot remove attribute '" .. key .. "'");
				return false;
			end
			
			return true;
		end
	end
	
	function initDictionary(node)
		local j,k;
		local functions = xmlFindSubNodeEx(node, "functions");
		
		if not (functions) then return false; end;
		
		function functions.cbAddChild(node)
			if (string.find(node.name, "[^%a%d_.:]")) then
				showMessageBox("Invalid dictionary entry name", "Child Creation Failed");
				return false
			end
			
			node.attr.returnType = "void";
			node.attr.arguments = "";
			
			local msgBox = showMessageBox("Give in the description.", "Set description", "input");
			
			addEventHandler("onClientMessageBoxClose", msgBox, function(input)
					if not (input) then return false; end;
					
					xmlNotify(node, "set_attribute", "description", input);
					node.attr.description = input;
				end
			);
			
			initDictionaryNode(node);
			return true;
		end
		
		for j,k in ipairs(functions.children) do
			initDictionaryNode(k);
		end
	end
	
	initDictionary(clientDict);
	initDictionary(serverDict);
	initDictionary(sharedDict);
	
	function dict.cbAddChild(node)
		if not (node.name == "client") and not (node.name == "server") and not (node.name == "shared") then
			showMessageBox("Invalid dictionary node '" .. node.name .. "'", "Child Creation Failed");
			return false;
		end
		
		return true;
	end
	
	function dict.cbSetAttribute(key, value)
		if (key == "enableHints") then
			if (value == "true") then
				enableHints = true;
			elseif (value == "false") then
				enableHints = false;
			else
                showMessageBox("Either 'true' or 'false'", "Boolean Required");
                return false;
			end
			
			if (pClientConfigGUI) then
				pClientConfigGUI.enableHints.setChecked(enableHints);
			end
		elseif (key == "colorFunctions") then
			if (value == "true") then
				colorFunctions = true;
			elseif (value == "false") then
				colorFunctions = false;
			else
                showMessageBox("Either 'true' or 'false'", "Boolean Required");
                return false;
			end
			
			if (pClientConfigGUI) then
				pClientConfigGUI.colorFunctions.setChecked(colorFunctions);
			end
			
			local m,n;
			
			for m,n in ipairs(sessions) do
				n.getEditor().parseColor();
			end
		elseif (key == "showHintDescription") then
			if (value == "true") then
				showHintDescription = true;
			elseif (value == "false") then
				showHintDescription = false;
			else
                showMessageBox("Either 'true' or 'false'", "Boolean Required");
                return false;
			end
			
			if (pClientConfigGUI) then
				pClientConfigGUI.showHintDescription.setChecked(showHintDescription);
			end
		elseif (key == "functionlistArguments") then
			if (value == "true") then
				functionlistArguments = true;
			elseif (value == "false") then
				functionlistArguments = false;
			else
                showMessageBox("Either 'true' or 'false'", "Boolean Required");
                return false;
			end
			
			updateFunctionList();
		else
			showMessageBox("Invalid dictionary attribute '" .. key .. "'", "Invalid Attribute");
			return false;
		end
		
		return true;
	end
	
	function dict.cbUnsetAttribute(key)
		if (key == "enableHints") or
			(key == "colorFunctions") or
			(key == "showHintDescription") then
			
            showMessageBox("You cannot remove '" .. key .. "'", "Attribute Error");
            return false;        
		end
		
		return true;
	end
	
	function transfer.cbAddChild(name)
		showMessageBox("You cannot add children to transfer.", "Child Creation Failed");
		return false;
	end
	
	function transfer.cbSetAttribute(key, value)
		if (key == "mtu") then
			local mtu = tonumber(value);
			
			if not (mtu) then
				showMessageBox("You did not specify a valid Maximum Transfer Unit.");
				return false;
			end
			
			if (mtu < 256) or (mtu > 65535) then
				showMessageBox("Invalid MTU (256 - 65535).", "Invalid Value");
				return false;
			end
			
			transactionPacketBytes = mtu;
			
			if (pClientConfigGUI) then
				pClientConfigGUI.mtu.setText(value);
			end
		elseif (key == "deleteOnQuit") then
			
		elseif (key == "createRepository") then
			if (value == "true") then
				createClientRepository = true;
			elseif (value == "false") then
				createClientRepository = false;
			else
				showMessageBox("Either 'true' or 'false'.", "Boolean Required");
				return false;
			end
			
			if (pClientConfigGUI) then
				pClientConfigGUI.createRepository.setChecked(createClientRepository);
			end
		end
		
		return true;
	end
	
	function transfer.cbUnsetAttribute(key)
		if (key == "mtu") or
			(key == "deleteOnQuit") or
			(key == "createRepository") then
			
			showMessageBox("You cannot remove '" .. key .. "'", "Attribute Error");
			return false;
		end
		
		return true;
	end
	
    -- Set some configurations
    charScale = tonumber(editor.attr.fontSize);
    charFont = editor.attr.font;
    enableHighlighting = (syntax.attr.enable == "true");
    showLineNumbers = (editor.attr.showLineNumbers == "true");
    notifyOnChange = (editor.attr.notifyOnChange == "true");
    useFileManager = (editor.attr.useFileManager == "true");
    useResourceSelect = (editor.attr.useResourceSelect == "true");
	showFunctionsFullscreen = (editor.attr.showFunctionsFullscreen == "true");
	automaticIndentation = (editor.attr.automaticIndentation == "true");
    transactionPacketBytes = tonumber(transfer.attr.mtu);
    deleteOnQuit = (transfer.attr.deleteOnQuit == "true");
	createClientRepository = (transfer.attr.createRepository == "true");
	enableHints = (dict.attr.enableHints == "true");
	colorFunctions = (dict.attr.colorFunctions == "true");
	showHintDescription = (dict.attr.showHintDescription == "true");
	functionlistArguments = (dict.attr.functionlistArguments == "true");
	
	-- Load the current theme
	local theme = editor.attr.theme;
	
	if (theme) then
		if not (themeLoad(theme)) then
			showMessageBox("Failed to load current theme! Cleared theme option.", "Theme Load Error");
			
			editor.attr.theme = nil;
		end
	end
end
loadConfig();

function reseditGetKeyBind(keyName, defaultKey)
    local keybinds = keybinds;
    
    local keyNode = xmlFindSubNodeEx(keybinds, keyName);
    
    if (keyNode) then
        local valueName = keyNode.attr.key;
        
        if (valueName) then
            return valueName;
        end
    end
    
    return defaultKey;
end

function showResourceSelect(bShow)
    if (bShow == true) then
        if not (pSelectGUI) then
            local screenWidth, screenHeight = guiGetScreenSize();
            local guiW, guiH=300,450;
            
            pSelectGUI = {};
            
            local window = themeCreateWindow();
            window.setAllowCursorResize(true);
            window.setPosition((screenWidth - guiW) / 2, (screenHeight - guiH) / 2);
            window.setText("Select Resource");
            local winRoot = window.getRoot();
            
            pSelectGUI.window = window;
            
            local searchEditBox = themeCreateEditBox(winRoot);
            searchEditBox.setPosition(5, 5);
            
            local pList = themeCreateListBox(winRoot);
            pList.setPosition(5, 25);
            
            pSelectGUI.resList = pList;
            
            local resColIndex = pList.addColumn();
            pList.setColumnWidth(resColIndex, 150);
            pList.setColumnName(resColIndex, "Resource");
            
            local realNameColIndex = pList.addColumn();
            pList.setColumnWidth(400);
            pList.setColumnName(realNameColIndex, "Real Name");

            local function resizeColumn(column, width)
                local minWidth = pList.getMinimumColumnWidth(column);
                
                pList.setColumnWidth(column, math.max(minWidth + 20, width));
            end
            
            function pSelectGUI.update()
                pList.clearRows();
				
                local filterText = searchEditBox.getText();
                
                local m,n;

                for m,n in ipairs(resourceList) do
                    if (string.find(n, filterText, 1, true)) then
                        if (doWeHaveAccessTo("resources", n)) then
                            local resource = resourceData[n];
                            local row = pList.addRow();
                            
                            pList.setItemText(resColIndex, row, n);
                            pList.setItemText(realNameColIndex, row, resource.realname);
                        end
                    end
                end
				
                resizeColumn(resColIndex, 100);
                resizeColumn(realNameColIndex, 50);
                return true;
            end
            
            function searchEditBox.events.onEditBoxChanged()
                pSelectGUI.update();
            end
            
            function pList.events.onListBoxSelect(row)
                local res = pList.getItemText(resColIndex, row);
                
                currentResource = resourceData[res];

                outputDebugString("Selected resource '" .. res .. "'");
                
                mainGUI.updateResource();
                
                showResourceSelect(false);
            end
            
            -- The fabled close button.
            local closeButton = themeCreateButton(winRoot);
            closeButton.setText("Close");
            
            function closeButton.events.onPress()
                showResourceSelect(false);
            end
            
            function window.setSize(w, h)
                if not (super(w, h)) then return false; end;
                
                -- Update ourselves.
                searchEditBox.setSize(winRoot.width - 10, 20);
                pList.setSize(winRoot.width - 10, winRoot.height - 50);
                closeButton.setPosition((winRoot.width - winRoot.width / 2) / 2, winRoot.height - 23);
                closeButton.setSize(winRoot.width / 2, 20);
                return true;
            end
            
            window.setSize(guiW, guiH);
            window.setMinimumSize(guiW / 2, guiH / 2);
        else
            pSelectGUI.window.setVisible(true);
            pSelectGUI.window.moveToFront();
        end
        
        pSelectGUI.resList.giveScrollFocus();
        
        -- Update it
        pSelectGUI.update();
    else
        if (pSelectGUI) then
            pSelectGUI.window.setVisible(false);
        end
    end
    return true;
end

function showScriptDebug(bShow)
    if (bShow == true) then
        local screenW, screenH = guiGetScreenSize();
        local guiW = screenW-600;
        local guiH = 225;
        local posX = 250;
        local posY = screenH - guiH - 40;

        if not (pScriptDebug) then
			local buffer = "";
		
			pScriptDebug = {};
		
			local window = guiCreateWindow(posX, posY, guiW, guiH, "Script Debug", false);
            guiWindowSetSizable(window, false);
			pScriptDebug.window = window;
			
            local pOutput = guiCreateMemo(10, 25, guiW-20, guiH-50, "", false, window);
            guiMemoSetReadOnly(pOutput, true);
			
			local pClear = guiCreateButton(guiW - 215, 200, 100, 20, "Clear", false, window);
			
			addEventHandler("onClientGUIClick", pClear, function()
					buffer = "";
					
					guiSetText(pOutput, "");
				end, false
			);
			
            local pClose = guiCreateButton(guiW-110, 200, 100, 20, "Close", false, window);
            
            addEventHandler("onClientGUIClick", pClose, function(button, state, x, y)
                    showScriptDebug(false);
                end, false
            );
			
			function pScriptDebug.output(text)
				if not (strbyte(text, strlen(text)) == 10) then
					text = text .. "\n";
				end
				
				buffer = buffer .. text;
				
				guiSetText(pOutput, buffer);
				guiSetProperty(pOutput, "CaratIndex", tostring(strlen(buffer) - 1));
				
				guiBringToFront(window);
				return true;
			end
        else
            guiSetVisible(pScriptDebug.window, true);
            guiBringToFront(pScriptDebug.window);
        end
		
        guiSetPosition(pScriptDebug.window, posX, posY, false);
    else
        if (pScriptDebug) then
            guiSetVisible(pScriptDebug.window, false);
        end
    end
	
    return true;
end

function showUpdateGUI(bShow, text, time, fade)
    if (bShow == true) then
        if not (pUpdateGUI) then
            local screenWidth, screenHeight = guiGetScreenSize();
            local guiW, guiH = 325, 125;
			
			pUpdateGUI = {};
            
			local window = guiCreateWindow(screenWidth-guiW, screenHeight-guiH, guiW, guiH, "Update!", false);
            guiWindowSetMovable(window, false);
            guiWindowSetSizable(window, false);
			pUpdateGUI.window = window;
			
            local pUpdate = guiCreateMemo(5, 15, guiW - 10, guiH - 15, "", false, window);
            guiMemoSetReadOnly(pUpdate, true);
            pUpdateGUI.update = pUpdate;
			
			-- Event optimization, all child events get destroyed, yo
			addEventHandler("onClientRender", root, function()
					if not (guiGetVisible(window) == true) then return false; end;
					
					local now = getTickCount();
					
					if (pUpdateGUI.showstart + pUpdateGUI.showtime < now) then
						showUpdateGUI(false);
						return true;
					end
					
					if (getTickCount() - pUpdateGUI.showstart <= pUpdateGUI.fadetime) then
						local fadeTime = now - pUpdateGUI.showstart;
						guiSetProperty(window, "Alpha", tostring(fadeTime / pUpdateGUI.fadetime));
					elseif (now - pUpdateGUI.showstart > pUpdateGUI.showtime - pUpdateGUI.fadetime) then
						local fadeTime = pUpdateGUI.showtime - (now - pUpdateGUI.showstart);
						guiSetProperty(window, "Alpha", tostring(fadeTime / pUpdateGUI.fadetime));
					else
						guiSetProperty(window, "Alpha", "1");
					end
				end
			);
        else
            guiSetVisible(pUpdateGUI.window, true);
            guiBringToFront(pUpdateGUI.window);
        end
        
        -- Make it fade in
        pUpdateGUI.showstart = getTickCount();
		
        if not (time) then
            pUpdateGUI.showtime = 5000;
        else
            pUpdateGUI.showtime = time;
        end
		
        if not (fade) then
            pUpdateGUI.fadetime = 1000;
        else
            pUpdateGUI.fadetime = fade;
        end
		
        guiSetText(pUpdateGUI.update, text);
    else
        if (pUpdateGUI) then
            guiSetVisible(pUpdateGUI.window, false);
        end
    end
	
    return true;
end

function showConfigEditor(bShow)
    if (bShow == true) then
        if not (pConfigEditor) then
            local guiW, guiH = 0, 0;
			
			--pConfigEditor = {};
        else
            guiSetVisible(pConfigEditor.window, true);
            guiBringToFront(pConfigEditor.window);
        end
    else
        if (pConfigEditor) then
            guiSetVisible(pConfigEditor.window, false);
        end
    end
	
    return true;
end

function showResourceCreation(bShow)
    if (bShow == true) then
        if not (pResourceCreation) then
            local screenWidth, screenHeight = guiGetScreenSize();
            local guiW, guiH = 450, 160;
			
			pResourceCreation = themeCreateWindow();
			local winRoot = pResourceCreation.getRoot();
			pResourceCreation.setText("Resource Creation");
			pResourceCreation.setPosition((screenWidth - guiW)/2, (screenHeight - guiH)/2);
			pResourceCreation.setRootSize(guiW, guiH);
			
			local rootW, rootH = winRoot.getSize();
			
			local pName = themeCreateEditBox(winRoot);
			pResourceCreation.name = pName;
			pName.setPosition(60, 10);
			pName.setSize(rootW - 70, 18);
			
			local pType = themeCreateEditBox(winRoot);
			pResourceCreation.type = pType;
			pType.setPosition(60, 30);
			pType.setSize(rootW - 70, 18);
			
			local pDesc = themeCreateEditor(winRoot);
			pResourceCreation.description = pDesc;
			pDesc.setPosition(95, 51);
			pDesc.setSize(rootW - 105, 54);
			
			function winRoot.render()
				dxDrawText("Name:", 10, 10);
				dxDrawText("Type:", 10, 30);
				dxDrawText("Description:", 10, 51);
				return super();
			end
			
            -- Buttons
            local buttonOffset = 113;
			local pCreate = themeCreateButton(winRoot);
			pCreate.setPosition(10, buttonOffset);
			pCreate.setSize(rootW - 20, 20);
			pCreate.setText("Create");
			
            function pCreate.events.onPress()
				-- Check if everything is filled out correctly
				local name = string.gsub(pName.getText(), "[^a-z,A-Z,0-9,_,-]", "");
				local ttype = string.gsub(pType.getText(), "[^a-z,_,-]", "");
				local description = pDesc.getText();
				
				if (string.len(name) < 4) then
					showMessageBox("Invalid resource name", "Creation Failed");
					return false;
				end
				
				if (string.len(ttype) == 0) then
					showMessageBox("Invalid resource type", "Creation Failed");
					return false;
				end
				
				triggerServerEvent("onClientRequestResourceCreation", root, name, ttype, description);
				showResourceCreation(false);
			end
			
			local pCancel = themeCreateButton(winRoot);
			pCancel.setPosition(10, buttonOffset+20);
			pCancel.setSize(rootW - 20, 20);
			pCancel.setText("Cancel");
            
            function pCancel.events.onPress()
				showResourceCreation(false);
			end
        elseif not (pResourceCreation.getVisible()) then
            pResourceCreation.setVisible(true);
			pResourceCreation.moveToFront();

            -- Clean up GUI
            pResourceCreation.name.setText("");
            pResourceCreation.type.setText("");
            pResourceCreation.description.setText("");
        end
    else
        if (pResourceCreation) then
            pResourceCreation.setVisible(false);
        end
    end
end

function enterEditorMode()
	local screenW, screenH = guiGetScreenSize();

    if (editorMode == 0) then
        pFileList.setVisible(true);
        pSaveButton.setVisible(true);
        pCloseButton.setVisible(true);
        pTabHolder.setVisible(true);
		pFunctionSearch.setVisible(true);
		pFunctionList.setVisible(true);
		
		pFunctionSearch.setPosition(screenW - 348, 315);
		pFunctionList.setPosition(screenW - 350, 335);
		
		pFunctionList.setSize(350, screenH - 335);
		
		-- Update the tabpanel
		pFunctionTabPanel.setPosition(250, 20);
		pFunctionTabPanel.setSize(screenW - 600, screenH - 60);
    elseif (editorMode == 1) then
		-- Update the tabpanel
		pFunctionTabPanel.setPosition(0, 20);
	
		if (showFunctionsFullscreen) then
			pFunctionSearch.setVisible(true);
			pFunctionList.setVisible(true);
			
			pFunctionSearch.setPosition(screenW - 348, 20);
			pFunctionList.setPosition(screenW - 350, 40);
			pFunctionList.setSize(350, screenH - 40);
			
			-- Set the tabpanel width smaller
			pFunctionTabPanel.setSize(screenW - 350, screenH - 20);
		else
			-- Fullscreen mode
			pFunctionTabPanel.setSize(screenW, screenH - 20);
		end
	end
end

function leaveEditorMode()
    if (editorMode == 0) then
        pFileList.setVisible(false);
        pSaveButton.setVisible(false);
        pCloseButton.setVisible(false);
        pTabHolder.setVisible(false);
		pFunctionSearch.setVisible(false);
		pFunctionList.setVisible(false);
    elseif (editorMode == 1) then
		pFunctionSearch.setVisible(false);
		pFunctionList.setVisible(false);
	end
end

function setEditorMode(mode)
    if not (mainGUI) then return false; end;
	
    -- Exit out mode
    leaveEditorMode();
    
    editorMode = math.mod(math.floor(mode), 2);
	
	-- Init new mode
	enterEditorMode();
    return true;
end

-- Internal routine for color recalculation, is used by editor to generate colors
local function getColorFromToken(token)
	local char = strbyte(token);

	if (char == 34) then    -- '"'
		if not (string1.attr.backColor) then
			return tonumbersign("0x" .. (string1.attr.textColor or "000000") .. "FF");
		end
		
		return tonumbersign("0x" .. (string1.attr.textColor or "000000") .. "FF"), tonumbersign("0x" .. string1.attr.backColor .. "FF");
	elseif (char == 39) then     -- "'"
		if not (string2.attr.backColor) then
			return tonumbersign("0x" .. (string2.attr.textColor or "000000") .. "FF");
		end
		
		return tonumbersign("0x" .. (string2.attr.textColor or "000000") .. "FF"), tonumbersign("0x" .. string2.attr.backColor .. "FF");
	elseif (strsub(token, 1, 4) == "--[[") then
		if not (comment2.attr.backColor) then
			return tonumbersign("0x" .. (comment2.attr.textColor or "000000") .. "FF");
		end
		
		return tonumbersign("0x" .. (comment2.attr.textColor or "000000") .. "FF"), tonumbersign("0x" .. comment2.attr.backColor .. "FF");
	elseif (strsub(token, 1, 2) == "--") then
		if not (comment1.attr.backColor) then
			return tonumbersign("0x" .. (comment1.attr.textColor or "000000") .. "FF");
		end
		
		return tonumbersign("0x" .. (comment1.attr.textColor or "000000") .. "FF"), tonumbersign("0x" .. comment1.attr.backColor .. "FF");
	else
		local colorNode = xmlFindSubNodeEx(syntax, token);
		
		if (colorNode) then
			if not (colorNode.attr.backColor) then
				return tonumbersign("0x" .. (colorNode.attr.textColor or "000000") .. "FF");
			end
			
			return tonumbersign("0x" .. (colorNode.attr.textColor or "000000") .. "FF"), tonumbersign("0x" .. colorNode.attr.backColor .. "FF");
		elseif (colorFunctions) then
			local entry = functionlist[token];
			
			if (entry) and (entry.textColor) then
				if not (entry.backColor) then
					return tonumbersign("0x" .. entry.textColor .. "FF");
				end
				
				return tonumbersign("0x" .. entry.textColor .. "FF"), tonumbersign("0x" .. entry.backColor .. "FF");
			end
		end
	end
	
	return false;
end

local function getLineNumberFromError(data)
    local m;
    local len = strlen(data);
    local args = 0;
    local didpass = false;
    local instring = false;
    local didfind = false;
    local findstart = 0;
    
    for m=1,len do
        local char = strbyte(data, m);
        
        if (char == 91) then    -- [
            if not (instring) then
                args = args + 1;
            end
        elseif (char == 93) then    -- ]
            if not (instring) then
                args = args - 1;
                if (args==0) then
                    didpass = true;
                end
            end
        elseif (char == 34) then    -- "
            if (instring) then
                instring = false;
            else
                instring = true;
            end
        elseif (char == 58) then    -- :
            if not (instring) then
                if (didfind) then
					return tonumber(strsub(data, findstart, m - 1));
                end
				
				didfind = true;
				findstart = m + 1;
            end
        end
    end
	
    return 1;
end

addEventHandler("onClientKey", root, function(button, state)
		if not (state) then return false; end;
        if not (isEditorClientReady()) then return false; end;
		
		if not (mainGUI) or not (mainGUI.visible) then
			if (button == reseditGetKeyBind("editoropen", "F6")) then
				showResourceGUI(true);
			end
		else		
			if (button == reseditGetKeyBind("fullscreeneditor", "F7")) then
				if (guiGetScreenSize() < 1024) then return; end;
			
				setEditorMode(editorMode + 1);
			elseif (button == reseditGetKeyBind("editoropen", "F6")) then
				showResourceGUI(false);
			elseif (button == reseditGetKeyBind("xmleditoropen", "F5")) then
                if not (xmlDoesEditorExistForNode(config)) then
                    xmlCreateEditor(config);
                end
			elseif (button == reseditGetKeyBind("fileeditoropen", "F4")) then
				if (useFileManager) then
					showFileManager(true);
				else
					mainGUI.nextFileMode();
				end
			elseif (button == reseditGetKeyBind("controlpanelopen", "F2")) then
				showControlPanel(true);
			end
		end
	end
);

function executeFile(file)
    local ext = getFileExtension(file.src);

    if (ext == "png") then
        if not (file.type == "client") then return false; end;

		local trans = getFile(currentResource, file.src);
		
		function trans.cbComplete()
			if not (file.width) then
				local png = fileOpen("@" .. trans.target);
				
				if not (png) then traceback(); end;
				
				fileSetPos(png, 16);
				
				file.width = bigendian.fileReadInt(png);
				file.height = bigendian.fileReadInt(png);
				
				fileClose(png);
				
				outputDebugString("Cached .png info ('" .. trans.target .. "')");
			end
			
			mainGUI.createImagePreview("@" .. trans.target, file.width, file.height);
			return true;
		end
    elseif (ext == "mp3") or
        (ext == "wav") or
        (ext == "ogg") or
        (ext == "riff") or
        (ext == "mod") or
        (ext == "xm") or
        (ext == "it") or
        (ext == "s3m") then
        
        if not (file.type == "client") then return false; end
        
		local trans = getFile(currentResource, file.src);
		
		function trans.cbComplete()
			if (soundPreview) then
				destroyElement(soundPreview);
			end
			
			soundPreview = playSound("@" .. trans.target);
			
			if not (soundPreview) then return false; end;
			
			addEventHandler("onClientElementDestroy", soundPreview, function()
					soundPreview = false;
				end, false
			);
			return true;
		end
    elseif (ext == "xml") or
        (ext == "map") then
        
        local trans = getFile(currentResource, file.src);
        
        function trans.cbAbort()
            showMessageBox("Failed to request '" .. file.src .. "'", "Request Aborted");
            return true;
        end
        
        function trans.cbComplete()
			local node;
			local xml = xmlLoadFile("@" .. trans.target);
				
			node = xmlGetNode(xml);
            
            if not (node) then
				pNoteEditor.setText(trans.data);
				
				clearDefinitions();
            
                showMessageBox("Corrupted .xml file", "XML Error");
                return true;
            end
            
            local editor = xmlCreateEditor(node);
            
            local function onXMLDestroy()
				local m,n;
		
				-- Kill children
				for m,n in ipairs(editor.node.children) do
					xmlNotify(n, "destroy");
				end
				
				-- Send the node as plaintext
				xmlSetNode(xml, node);
				xmlSaveFile(xml);
				xmlUnloadFile(xml);
				
				xml = fileOpen("@" .. trans.target);
				
				local xmltrans = sendFile(trans.resource, file.src, fileRead(xml, fileGetSize(xml)));
				
				fileClose(xml);
				
				function xmltrans.cbAbort()
					showMessageBox("Failed to update XML file", "Transaction Error");
					return true;
				end
				
				function xmltrans.cbComplete()
					showUpdateGUI(true, "Saved successfully");
					return true;
				end
			end
			
			setfenv(onXMLDestroy, _G);
			
			addEventHandler("onClientElementDestroy", editor.window, onXMLDestroy, false);
            return true;
        end
    elseif (ext == "txt") then
        local trans = getFile(currentResource, file.src);
        
        function trans.cbComplete()
			pNoteEditor.setText(trans.data);
			
			clearDefinitions();
            return true;
        end
    end
end

function showFileManager(bShow)
    if (bShow == true) then
        if not (pFileManager) then
            local screenW, screenH = guiGetScreenSize();
            local guiW, guiH = 450, 400;
            
            pFileManager = {};
            pFileManager.window = guiCreateWindow((screenW - guiW) / 2, (screenH - guiH) / 2, guiW, guiH, "File Manager", false);
            
            local pList = guiCreateGridList(guiW - 210, 25, 200, guiH - 30, false, pFileManager.window);
            guiGridListAddColumn(pList, "Resource File", 0.5);
            guiGridListAddColumn(pList, "Type", 0.25);
            
            addEventHandler("onClientGUIDoubleClick", pList, function(button, state, x, y)
                    local row = guiGridListGetSelectedItem(pList);
                    
                    if (row == -1) then return false; end;
                    
                    executeFile(currentResource.files[tonumber(guiGridListGetItemData(pList, row, 1))]);
                end, false
            );
            
            local pClose = guiCreateButton(10, guiH - 30, guiW - 225, 20, "Close", false, pFileManager.window);
            
            addEventHandler("onClientGUIClick", pClose, function(button, state, x, y)
                    showFileManager(false);
                end, false
            );
            
            function pFileManager.update()
                guiGridListClear(pList);
                local sort = guiGetProperty(pList, "SortDirection");
                
                guiSetProperty(pList, "SortDirection", "");
            
                for m,n in ipairs(currentResource.files) do
                    local row = guiGridListAddRow(pList);
                    guiGridListSetItemText(pList, row, 1, n.src, false, false);
                    guiGridListSetItemText(pList, row, 2, n.type, false, false);
                    guiGridListSetItemData(pList, row, 1, tostring(m));
                    
                    local colorType = fileColors[getFileExtension(n.src)];
					
					if not (colorType) then
						colorType = { 255, 255, 255 };
					end
					
					colorType[4] = 255;
                    
					guiGridListSetItemColor(pList, row, 1, unpack(colorType));
                end
                
                guiSetProperty(pList, "SortDirection", sort);
                
                resizeColumn(pList, 1, 100);
                return true;
            end
            
            addEventHandler("onClientGUISize", pFileManager.window, function()
                    local width, height = guiGetSize(pFileManager.window, false);
                    
                    width = math.max(guiW, width);
                    height = math.max(guiH, height);
                    
                    guiSetSize(pFileManager.window, width, height, false);
                    guiSetSize(pList, width - 250, height - 30, false);
                    
                    guiSetPosition(pClose, 10, height - 30, false);
                end, false
            );
            
            -- Update it
            pFileManager.update();
        else
            guiSetVisible(pFileManager.window, true);
            guiBringToFront(pFileManager.window);
        end
    else
        if (pFileManager) then
            guiSetVisible(pFileManager.window, false);
        end
    end
end

addEventHandler("onClientScriptLockAcquire", root, function(resource, filename)
        local res = resourceData[resource];
        local m,n;
        
        for m,n in ipairs(res.scripts) do
            if (n.src == filename) then
                if (source == localPlayer) then
					local session = getSession(resource, filename);
					
					if (session) then
						session.acquire();
					end
                end
                
                n.lockClient = source;
                
                outputDebugString(getPlayerName(source) .. " acquired script lock: :"..resource.."/"..filename);
                return true;
            end
        end
    end
);

addEventHandler("onClientScriptLockFree", root, function(resource, filename)
        local res = resourceData[resource];
        local m,n;
        
        for m,n in ipairs(res.scripts) do
            if (n.src == filename) then
				local session = getSession(resource, filename);
			
				if (session) then
					if (source == getLocalPlayer()) then
						session.free();
					else
						session.request();
					end
				end
                
                n.lockClient = false;
                
                outputDebugString(getPlayerName(source) .. " released script lock");
                return true;
            end
        end
    end
);

-- todo
function showDictionary(show)
	if (show == true) then

	else
	
	end
end

function showControlPanel(show)
	if (show == true) then
		if not (pControlPanel) then
			local guiW, guiH = 725, 520;
			local screenW, screenH = guiGetScreenSize();
			
			pControlPanel = {};
			
			local window = guiCreateWindow((screenW - guiW) / 2, (screenH - guiH) / 2, guiW, guiH, "Server Control Panel", false);
			guiWindowSetSizable(window, false);
			pControlPanel.window = window;
			
			local pTabHolder = guiCreateTabPanel(0, 20, guiW, guiH - 55, false, window);
			
			-- General tab
			local pGeneral = guiCreateTab("General", pTabHolder);
			
			guiCreateLabel(20, 20, 150, 15, "Maximum Transfer Unit:", false, pGeneral);
			local pMTU = guiCreateEdit(170, 18, 75, 20, "", false, pGeneral);
			
			-- Access tab
			local pAccess = guiCreateTab("Access", pTabHolder);
			
			local pAccounts = guiCreateGridList(20, 20, 180, guiH - 155, false, pAccess);
			guiGridListAddColumn(pAccounts, "Account", 0.87);
			
			local pAddAccount = guiCreateButton(20, guiH - 135, 180, 20, "Add Access", false, pAccess);
			
			local pRemoveAccount = guiCreateButton(20, guiH - 115, 180, 20, "Remove Access", false, pAccess);
			
			local pRights = guiCreateGridList(215, 20, guiW - 250, guiH - 160, false, pAccess);
			guiGridListAddColumn(pRights, "Object", 0.6);
			guiGridListAddColumn(pRights, "Allow", 0.25);
			
			local pNewObject = guiCreateButton(215, guiH - 140, 140, 20, "New Object", false, pAccess);
			
			local pDeleteObject = guiCreateButton(355, guiH - 140, 140, 20, "Delete Object", false, pAccess);
			
			local pDefaultAccess = guiCreateButton(550, guiH - 140, 140, 20, "See Default", false, pAccess);
			
			guiCreateLabel(220, guiH - 115, 125, 15, "Amount of objects:", false, pAccess);
			local pAmountOfObjects = guiCreateLabel(345, guiH - 115, 40, 15, "0", false, pAccess);
			
			-- Buttons
			local pSetPassword = guiCreateButton(15, guiH - 30, 150, 20, "Set Password", false, window);
			
			local pClose = guiCreateButton(guiW - 150, guiH - 30, 120, 20, "Close", false, window);
			
			addEventHandler("onClientGUIClick", pClose, function()
					showControlPanel(false);
				end, false
			);
		else
			guiSetVisible(pControlPanel.window, true);
		end
	else
		if (pControlPanel) then
			guiSetVisible(pControlPanel.window, false);
		end
	end
end

function showClientConfig(bShow)
    if (bShow == true) then
        if not (pClientConfigGUI) then
            local m,n;
            
            local window = themeCreateWindow();
			pClientConfigGUI = window;
			local screenW, screenH = window.getScreenSize();
			window.setRootSize(450, 275);
			window.setPosition((screenW - window.width) / 2, (screenH - window.height) / 2);
            window.setText("Client Preferences");
			
            local function showConfigMessageBox(msg, title, usage)
                local msgBox = themeCreateMsgBox(msg, usage, window);
				msgBox.setText(title);
                
                return msgBox;
            end
			
			local root = window.getRoot();
            
			local tabPanel = themeCreateTabPanel(root);
			tabPanel.setSize(root.width, root.height - 30);
            
            -- Editor
			local editorTab = tabPanel.addTab();
			editorTab.setText("Editor");
			
			function editorTab.render()
				dxDrawText("Font Size:", 20, 20);
				dxDrawText("Font:", 20, 45);
				return super();
			end
			
			local pFontSize = themeCreateEditBox(editorTab);
			pFontSize.setPosition(90, 18);
			pFontSize.setSize(40, 20);
			pFontSize.setText(tostring(charScale));
			window.fontSize = pFontSize;
            
			local pFontCombo = themeCreateComboBox(editorTab);
			pFontCombo.setPosition(90, 43);
			pFontCombo.setSize(100, 20);
                
			-- List all fonts
			pFontCombo.addItem("default");
			pFontCombo.addItem("default-bold");
			pFontCombo.addItem("clear");
			pFontCombo.addItem("arial");
			pFontCombo.addItem("sans");
			pFontCombo.addItem("pricedown");
			pFontCombo.addItem("bankgothic");
			pFontCombo.addItem("diploma");
			pFontCombo.addItem("beckett");

            pClientConfigGUI.font = pFontCombo;
            
			local pNotifyOnChange = themeCreateCheckBox(editorTab);
			pNotifyOnChange.setPosition(20, 85);
			pNotifyOnChange.setSize(editorTab.width - 40, 16);
			pNotifyOnChange.setText("Warn me if script progress might be lost");
			window.notifyOnChange = pNotifyOnChange;
            
			local showLineBar = themeCreateCheckBox(editorTab);
			showLineBar.setPosition(20, 105);
			showLineBar.setSize(editorTab.width - 40, 16);
			showLineBar.setText("Show line numbers");
			window.showLineBar = showLineBar;
			
			local pUseFileManager = themeCreateCheckBox(editorTab);
			pUseFileManager.setPosition(20, 125);
			pUseFileManager.setSize(editorTab.width - 40, 16);
			pUseFileManager.setText("Use File Manager for file viewing");
            window.useFileManager = pUseFileManager;
			
			local pShowFunctionsFullscreen = themeCreateCheckBox(editorTab);
			pShowFunctionsFullscreen.setPosition(20, 145);
			pShowFunctionsFullscreen.setSize(editorTab.width - 40, 16);
			pShowFunctionsFullscreen.setText("Show functionlist in fullscreen");
			window.showFunctionsFullscreen = pShowFunctionsFullscreen;
			
			local pAutomaticIndentation = themeCreateCheckBox(editorTab);
			pAutomaticIndentation.setPosition(20, 165);
			pAutomaticIndentation.setSize(editorTab.width - 40, 16);
			pAutomaticIndentation.setText("Enable automatic indentation");
			window.automaticIndentation = pAutomaticIndentation;
			
            -- Syntax coloring
			local syntaxTab = tabPanel.addTab();
			syntaxTab.setText("Syntax");
			
			local enableSyntax = themeCreateCheckBox(syntaxTab);
			enableSyntax.setPosition(20, 20);
			enableSyntax.setSize(syntaxTab.width - 40, 16);
			enableSyntax.setText("Enable Syntax Highlighting");
			window.enableSyntax = enableSyntax;
			
			local syntaxList = themeCreateListBox(syntaxTab);
			syntaxList.setPosition(20, 45);
			syntaxList.setSize(syntaxTab.width - 60, syntaxTab.height - 85);
			syntaxList.addColumn();
			syntaxList.setColumnName(1, "Syntax");
			syntaxList.setColumnWidth(1, 80);
			syntaxList.addColumn();
			syntaxList.setColumnName(2, "Color");
			syntaxList.setColumnWidth(2, 140);
			window.syntaxList = syntaxList;
			
            function syntaxList.events.onListBoxConfirm()
				local selection = getSelection();
				
				if (#selection == 0) then return; end;
				
				xmlCreateEditor(specialsyntax.children[selection[1]]);
			end
			
			function syntaxList.updateEntry(row, child)
				if (child.attr.textColor) and (child.attr.backColor) then
					setItemText(2, row, child.attr.textColor .. ", " .. child.attr.backColor);
				elseif (child.attr.textColor) then
					setItemText(2, row, child.attr.textColor.. ", ");
				elseif (child.attr.backColor) then
					setItemText(2, row, ", " .. child.attr.backColor);
				end
			end
            
            function window.updateSyntax(child)
                local rowcount = syntaxList.getNumRows();
                local j,k;
				
                -- Find out id of child
                for j,k in ipairs(specialsyntax.children) do
                    if (k == child) then
						syntaxList.updateEntry(k, child);
                        break;
                    end
                end
            end
            
            -- Fill it with specialsyntax
            for m,n in ipairs(specialsyntax.children) do
                local row = syntaxList.addRow();
                syntaxList.setItemText(1, row, n.name);
				syntaxList.updateEntry(row, n);
            end
			
			local openAdvSyntax = themeCreateButton(syntaxTab);
			openAdvSyntax.setPosition(20, 45 + syntaxList.height);
			openAdvSyntax.setSize(syntaxList.width, 20);
			openAdvSyntax.setText("Advanced Syntax Settings");
            
            function openAdvSyntax.events.onPress()
				xmlCreateEditor(syntax);
			end
            
            -- Dictionary
            local dictTab = tabPanel.addTab();
			dictTab.setText("Dict");
			
			local pEnableHints = themeCreateCheckBox(dictTab);
			pEnableHints.setPosition(20, 20);
			pEnableHints.setSize(175, 16);
			pEnableHints.setText("Enable Lexical Popups");
			window.enableHints = pEnableHints;
			
			local pColorFunctions = themeCreateCheckBox(dictTab);
			pColorFunctions.setPosition(205, 20);
			pColorFunctions.setSize(215, 16);
			pColorFunctions.setText("Color functionnames in editor");
			window.colorFunctions = pColorFunctions;
			
			local pShowHintDescription = themeCreateCheckBox(dictTab);
			pShowHintDescription.setPosition(20, 40);
			pShowHintDescription.setSize(dictTab.width - 40, 16);
			pShowHintDescription.setText("Show description in editor hints");
			window.showHintDescription = pShowHintDescription;
			
			local pFunctionlistArguments = themeCreateCheckBox(dictTab);
			pFunctionlistArguments.setPosition(20, 60);
			pFunctionlistArguments.setSize(dictTab.width - 40, 16);
			pFunctionlistArguments.setText("Show arguments in functionlist");
			window.functionlistArguments = pFunctionlistArguments;
            
            -- File Transfer
			local transferTab = tabPanel.addTab();
			transferTab.setText("Transfer");
			
			function transferTab.render()
				dxDrawText("Maximum Transfer Unit:", 20, 20);
				return super();
			end
			
			local pMTU = themeCreateEditBox(transferTab);
			pMTU.setPosition(160, 18);
			pMTU.setSize(60, 20);
			window.mtu = pMTU;
			
			local pCreateRepository = themeCreateCheckBox(transferTab);
			pCreateRepository.setPosition(20, 50);
			pCreateRepository.setSize(transferTab.width - 40, 16);
			pCreateRepository.setText("Create clientside resource repository");
			window.createRepository = pCreateRepository;
            
            -- Bottom
            local function saveGUI()
                if (enableSyntax.isChecked()) then
                    enableHighlighting = true;
                    
                    if not (syntax.attr.enable == "true") then
                        xmlNotify(syntax, "set_attribute", "enable", "true");
                        syntax.attr.enable = "true";
                    end
                else
                    enableHighlighting = false;
                    
                    xmlNotify(syntax, "set_attribute", "enable", "false");
                    syntax.attr.enable = "false";
                end
                
                if (showLineBar.isChecked()) then
                    showLineNumbers = true;
                    
                    if not (editor.attr.showLineNumbers == "true") then
                        xmlNotify(editor, "set_attribute", "showLineNumbers", "true");
                        editor.attr.showLineNumbers = "true";
                    end
                else
                    showLineNumbers = false;
                    
                    if not (editor.attr.showLineNumbers == "false") then
                        xmlNotify(editor, "set_attribute", "showLineNumbers", "false");
                        editor.attr.showLineNumbers = "false";
                    end
                end
                
                if (pNotifyOnChange.isChecked()) then
                    notifyOnChange = true;
                    
                    if not (editor.attr.notifyOnChange == "true") then
                        xmlNotify(editor, "set_attribute", "notifyOnChange", "true");
                        editor.attr.notifyOnChange = "true";
                    end
                else
                    notifyOnChange = false;
                    
                    if not (editor.attr.notifyOnChange == "false") then
                        xmlNotify(editor, "set_attribute", "notifyOnChange", "false");
                        editor.attr.notifyOnChange = "false";
                    end
                end
                
                if (pUseFileManager.isChecked()) then
                    useFileManager = true;
                    
                    if (mainGUI.mode == "file") then
                        mainGUI.nextFileMode();
                        showFileManager(true);
                    end
                    
                    if not (editor.attr.useFileManager == "true") then
                        xmlNotify(editor, "set_attribute", "useFileManager", "true");
                        editor.attr.useFileManager = "true";
                    end
                else
                    useFileManager = false;
                    
                    if (pFileManager) and (guiGetVisible(pFileManager.window)) then
                        showFileManager(false);
                        mainGUI.nextFileMode();
                    end
                    
                    if not (editor.attr.useFileManager == "false") then
                        xmlNotify(editor, "set_attribute", "useFileManager", "false");
                        editor.attr.useFileManager = "false";
                    end
                end
				
				if (pAutomaticIndentation.isChecked()) then
					automaticIndentation = true;
					
					if not (editor.attr.automaticIndentation == "true") then
						xmlNotify(editor, "set_attribute", "automaticIndentation", "true");
						editor.attr.automaticIndentation = "true";
					end
				else
					automaticIndentation = false;
					
					if not (editor.attr.automaticIndentation == "false") then
						xmlNotify(editor, "set_attribute", "automaticIndentation", "false");
						editor.attr.automaticIndentation = "false";
					end
				end
				
				if (pShowFunctionsFullscreen.isChecked()) then
					showFunctionsFullscreen = true;
					
					if not (editor.attr.showFunctionsFullscreen == "true") then
						xmlNotify(editor, "set_attribute", "showFunctionsFullscreen", "true");
						editor.attr.showFunctionsFullscreen = "true";
					end
				else
					showFunctionsFullscreen = false;
					
					if not (editor.attr.showFunctionsFullscreen == "false") then
						xmlNotify(editor, "set_attribute", "showFunctionsFullscreen", "false");
						editor.attr.showFunctionsFullscreen = "false";
					end
				end
				
				if (pEnableHints.isChecked()) then
					enableHints = true;
					
					if not (dict.attr.enableHints == "true") then
						xmlNotify(dict, "set_attribute", "enableHints", "true");
						dict.attr.enableHints = "true";
					end
				else
					enableHints = false;
					
					if not (dict.attr.enableHints == "false") then
						xmlNotify(dict, "set_attribute", "enableHints", "false");
						dict.attr.enableHints = "false";
					end
				end
				
				if (pColorFunctions.isChecked()) then
					colorFunctions = true;
					
					if not (dict.attr.colorFunctions == "true") then
						xmlNotify(dict, "set_attribute", "colorFunctions", "true");
						dict.attr.colorFunctions = "true";
					end
				else
					colorFunctions = false;
					
					if not (dict.attr.colorFunctions == "false") then
						xmlNotify(dict, "set_attribute", "colorFunction", "false");
						dict.attr.colorFunctions = "false";
					end
				end
				
				if (pShowHintDescription.isChecked()) then
					showHintDescription = true;
					
					if not (dict.attr.showHintDescription == "true") then
						xmlNotify(dict, "set_attribute", "showHintDescription", "true");
						dict.attr.showHintDescription = "true";
					end
				else
					showHintDescription = false;
					
					if not (dict.attr.showHintDescription == "false") then
						xmlNotify(dict, "set_attribute", "showHintDescription", "false");
						dict.attr.showHintDescription = "false";
					end
				end
				
				if (pFunctionlistArguments.isChecked()) then
					functionlistArguments = true;
					
					if not (dict.attr.functionlistArguments == "true") then
						xmlNotify(dict, "set_attribute", "functionlistArguments", "true");
						dict.attr.functionlistArguments = "true";
						
						updateFunctionList();
					end
				else
					functionlistArguments = false;
					
					if not (dict.attr.functionlistArguments == "false") then
						xmlNotify(dict, "set_attribute", "functionlistArguments", "false");
						dict.attr.functionlistArguments = "false";
						
						updateFunctionList();
					end
				end
                
                local fontSize = pFontSize.getText();
                
                if (tonumber(fontSize)) then
                    charScale = tonumber(fontSize);
                    xmlNotify(editor, "set_attribute", "fontSize", fontSize);
                    editor.attr.fontSize = fontSize;
                end
                
                local font = pFontCombo.getItem(pFontCombo.getSelected());
				
                xmlNotify(editor, "set_attribute", "font", font);
                editor.attr.font = font;
                charFont = font;
				
				if (pCreateRepository.isChecked()) then
					createClientRepository = true;
					
					if (transfer.attr.createRepository == "false") then
						xmlNotify(transfer, "set_attribute", "createRepository", "true");
						transfer.attr.createRepository = "true";
					end
				else
					createClientRepository = false;
					
					if (transfer.attr.createRepository == "true") then
						xmlNotify(transfer, "set_attribute", "createRepository", "false");
						transfer.attr.createRepository = "false";
					end
				end
				
				local mtu = pMTU.getText();
				
				if not (mtu == transfer.attr.mtu) then
					xmlNotify(transfer, "set_attribute", "mtu", mtu);
					transfer.attr.mtu = mtu;
					
					transactionPacketBytes = tonumber(mtu);
				end
                
                -- Update the editors
				for m,n in ipairs(sessions) do
					n.getEditor().showLineNumbers(showLineNumbers);
					n.getEditor().setColorEnabled(enableHighlighting);
					n.getEditor().setLexicalHintingEnabled(enableHints);
					n.getEditor().setFont(charScale, charFont);
					n.getEditor().setAutoIndentEnabled(automaticIndentation);
				end
                
                -- Also update the manager
                setEditorMode(editorMode);
            end
			
			local restoreDefaults = themeCreateButton(root);
			restoreDefaults.setPosition(10, root.height - 25);
			restoreDefaults.setSize(120, 20);
			restoreDefaults.setText("Restore Defaults");

            function restoreDefaults.events.onPress()
				local ask = showConfigMessageBox("Are you sure you want to restore your settings to default?", "Factory Reset", "confirm");
				
				function ask.events.onMsgBoxConfirm(switch)
					if not (switch) then return false; end;
					
					-- Kill editors
					xmlNotify(config, "destroy");
					
					local xml = xmlLoadFile("default/config.xml");
					pConfigFile = xmlCopyFile(xml, "config.xml");
					xmlUnloadFile(xml);
					
					-- We have to unload configured data
					unloadDictionary(internalDefinitions);
					
					-- Unload the current theme
					themeUnload();
					
					-- Reload xml data
					loadConfig();
					
					showClientConfig(false);
					
					-- Update editor configuration
					local m,n;
					
					for m,n in ipairs(sessions) do
						n.getEditor().showLineNumbers(showLineNumbers);
						n.getEditor().setColorEnabled(enableHighlighting);
						n.getEditor().setLexicalHintingEnabled(enableHints);
						n.getEditor().setAutoIndentEnabled(automaticIndentation);
						n.getEditor().setFont(charScale, charFont);
						
						-- Make sure we update the color
						n.getEditor().parseCode();
					end
				end
			end
			
			local cancel = themeCreateButton(root);
			cancel.setPosition(root.width - 100, root.height - 25);
			cancel.setSize(75, 20);
			cancel.setText("Cancel");
            
            function cancel.events.onPress()
				showClientConfig(false);
			end
			
			local ok = themeCreateButton(root);
			ok.setPosition(root.width - 180, root.height - 25);
			ok.setSize(75, 20);
			ok.setText("OK");
            
            function ok.events.onPress()
				saveGUI();
				
				showClientConfig(false);
			end
        else
            pClientConfigGUI.setVisible(true);
            pClientConfigGUI.moveToFront();
            
            -- Update easy stuff
            pClientConfigGUI.fontSize.setText(tostring(charScale));
        end
		
		pClientConfigGUI.font.selectItem(charFont);
		
		pClientConfigGUI.mtu.setText(tostring(transactionPacketBytes));
        
        pClientConfigGUI.enableSyntax.setChecked(enableHighlighting);
        pClientConfigGUI.notifyOnChange.setChecked(notifyOnChange);
        pClientConfigGUI.showLineBar.setChecked(showLineNumbers);
        pClientConfigGUI.useFileManager.setChecked(useFileManager);
		pClientConfigGUI.showFunctionsFullscreen.setChecked(showFunctionsFullscreen);
		pClientConfigGUI.automaticIndentation.setChecked(automaticIndentation);
		pClientConfigGUI.enableHints.setChecked(enableHints);
		pClientConfigGUI.colorFunctions.setChecked(colorFunctions);
		pClientConfigGUI.showHintDescription.setChecked(showHintDescription);
		pClientConfigGUI.functionlistArguments.setChecked(functionlistArguments);
		pClientConfigGUI.createRepository.setChecked(createClientRepository);
    elseif (pClientConfigGUI) then
        pClientConfigGUI.setVisible(false);
    end
end

function resizeColumn(gridlist, column, width)
    local n = 0;
    local rowcount = guiGridListGetRowCount(gridlist);
    
    while (n < rowcount) do
        local curWidth = dxGetTextWidth(guiGridListGetItemText(gridlist, n, column)) + 20;
        
        if (width < curWidth) then
            width = curWidth;
        end
    
        n = n + 1;
    end
    
    return guiGridListSetColumnWidth(gridlist, column, width, false);
end

function dxRoot.mouseclick(button, state, x, y)
	if not (button == "right") or not (state) then return true; end;
	
	if (pRightClickMenu) then
		if (pRightClickMenu.isInArea(mouseX, mouseY)) then return true; end;
		
		pRightClickMenu.destroy();
	end

	pRightClickMenu = themeCreateDropDown();
	pRightClickMenu.setPosition(mouseX, mouseY);
	pRightClickMenu.moveToFront();
	
	pRightClickMenu.addItem("lol", function()
			showMessageBox("It works!");
		end
	);
	
	function pRightClickMenu.focus()
		outputDebugString("focus");
	end
	
	function pRightClickMenu.blur()
		outputDebugString("ok");
		
		destroy();
		
		pRightClickMenu = false;
	end
end

local pasteEditor;

function showPasteGUI(show, editor)
	if (show) then
		pasteEditor = editor;
	
		if not (pPasteGUI) then
			local screenW, screenH = guiGetScreenSize();
			local guiW, guiH = 150, 80;
		
			pPasteGUI = {};
			
			local window = guiCreateWindow((screenW - guiW) / 2, (screenH - guiH) / 2, guiW, guiH, "Paste GUI", false);
			pPasteGUI.window = window;
			
			local edit = guiCreateMemo(5, 5, guiW - 10, guiH - 10, "", false, window);
			pPasteGUI.edit = edit;
			
			addEventHandler("onClientGUIChanged", edit, function()
					local text = parseScript(guiGetText(edit));
			
					if (strlen(text) == 1) then return true; end;
					
					local len = strlen(text) - 1;
					local text = strsub(text, 1, len);
					local cursor = pasteEditor.getCursor();
					
					pasteEditor.insertText(text, cursor);
					
					-- Show some highlight
					pasteEditor.setHighlight(cursor, cursor + len);
					pasteEditor.setCursor(cursor + strlen(text));
					
					pasteEditor.moveToFront();
					
					showPasteGUI(false);
				end
			);
		else
			guiSetVisible(pPasteGUI.window, true);
			
			guiSetText(pPasteGUI.edit, "");
		end
		
		guiBringToFront(pPasteGUI.edit);
	else
		if (pPasteGUI) then
			guiSetVisible(pPasteGUI.window, false);
			guiMoveToBack(pPasteGUI.window);
		end
	end
end

local function createAdvancedEditor(parent)
	local editor = themeCreateEditor(parent);
	local searchWnd = false;
	
	searchWnd = themeCreateWindow(editor);
	searchWnd.setSize(300, 175);
	searchWnd.setOutbreakMode(true);
	searchWnd.setVisible(false);
	searchWnd.setText("Search & Replace");
	
	local root = searchWnd.getRoot();
	local rw, rh = root.getSize();
	
	local tabPanel = themeCreateTabPanel(root);
	tabPanel.setPosition(5, 5);
	tabPanel.setSize(rw - 10, 120);
	
	local findTab = tabPanel.addTab();
	findTab.setText("Find");
	
	local tw, th = findTab.getSize();
	
	local findEdit = themeCreateEditBox(findTab);
	findEdit.setPosition(10, 10);
	findEdit.setSize(tw - 70, 20);
	
	local function detectMatch(match)
		local buffer = editor.getText();
		local m = strfind(buffer, match, editor.getCursor(), true);
		
		if not (m) then
			m = strfind(buffer, match, 1, true);
			
			if not (m) then
				return false;
			end
		end
		
		return m;
	end
	
	local function findOne(text)
		local m = detectMatch(text);
		
		if not (m) then return false; end;
		
		local e = m + #text;
		editor.setHighlight(m, e);
		editor.setCursor(e);
		return true;
	end
	
	local function findAction()
		local text = findEdit.getText();
		
		if (#text == 0) then return true; end;
		
		if not (findOne(text)) then
			showMessageBox("Nothing found.");
			return true;
		end

		return true;
	end
	
	function findEdit.events.onAccept()
		findAction();
	end
	
	function findTab.events.onShow()
		findEdit.moveToFront();
	end
	
	local findNow = themeCreateButton(findTab);
	findNow.setPosition(tw - 60, 10 );
	findNow.setSize(50, 20);
	findNow.setText("Find");
	
	function findNow.events.onPress()
		findAction();
		
		findEdit.moveToFront();
	end
	
	local replaceTab = tabPanel.addTab();
	replaceTab.setText("Replace");
	
	function replaceTab.render()
		dxDrawText("Text:", 10, 12);
		dxDrawText("Replace With:", 10, 35);
		return super();
	end
	
	local replaceText = themeCreateEditBox(replaceTab);
	replaceText.setPosition(48, 10);
	replaceText.setSize(tw - 58, 20);
	
	local replaceWith = themeCreateEditBox(replaceTab);
	replaceWith.setPosition(93, 32);
	replaceWith.setSize(tw - 103, 20);
	
	local function replaceOne(text, with)
		local m = detectMatch(text);
		
		if not (m) then return false; end;
		
		editor.removeText(m, #text);
		editor.insertText(with, m);
		local e = m + #with;
		editor.setHighlight(m, e);
		editor.setCursor(e);
		return true;
	end
	
	local function singleReplaceAction()
		local text = replaceText.getText();
		local with = replaceWith.getText();
		
		if (#text == 0) or (#with == 0) then
			replaceText.moveToFront();
			return true;
		end
		
		if not (replaceOne(text, with)) then
			showMessageBox("Nothing to replace.", "Info");
		end

		return true;
	end
	
	function replaceText.events.onAccept()
		if (#replaceWith.getText() == 0) then
			replaceWith.moveToFront();
			return true;
		end
		
		singleReplaceAction();
	end
	
	function replaceWith.events.onAccept()
		singleReplaceAction();
	end
	
	local singleReplace = themeCreateButton(replaceTab);
	singleReplace.setPosition((tw - 210) / 2, 60);
	singleReplace.setSize(100, 20);
	singleReplace.setText("Replace");
	
	function singleReplace.events.onPress()
		singleReplaceAction();
	end
	
	local allReplace = themeCreateButton(replaceTab);
	allReplace.setPosition((tw + 5) / 2, 60);
	allReplace.setSize(100, 20);
	allReplace.setText("Replace All");
	
	function allReplace.events.onPress()
		local text = replaceText.getText();
		local with = replaceWith.getText();
		
		if (#text == 0) or (#with == 0) then
			replaceText.moveToFront();
			return true;
		end
		
		local n = 0;
		
		while (replaceOne(text, with)) do
			n = n + 1;
		end
		
		showMessageBox("Replaced " .. n .. " instances.", "Replace Finished");
		return true;
	end
	
	local closeButton = themeCreateButton(root);
	closeButton.setPosition(rw - 110, 130);
	closeButton.setSize(100, 20);
	closeButton.setText("Close");
	
	function closeButton.events.onPress()
		searchWnd.setVisible(false);
		
		editor.moveToFront();
	end
	
	editor.addEventHandler("onKeyInput", function(button, state)
			if not (state) then return true; end;
			
			if (keyInfo.lctrl.state) then
				if (button == "f") then
					local w, h = editor.getSize();
					searchWnd.setVisible(true);
					searchWnd.setPosition((w - searchWnd.width) / 2, (h - searchWnd.height) / 2);
				end
			elseif (keyInfo.lalt.state) then
				if (button == "f") then
					local text = findEdit.getText();
					
					if (#text == 0) then return true; end;
					
					findOne(text);
				end
			end
		end
	);
	
	return editor;
end

local function createScriptEditor(parent)
	local editor = createAdvancedEditor(parent);
	editor.showLineNumbers(showLineNumbers);
	editor.setColorEnabled(enableHighlighting);
	editor.setColorTokenHandler(getColorFromToken);
	editor.setLexicalHintingEnabled(enableHints);
	editor.setLexicalTokenHandler(getLexicalDefinition);
	editor.setAutoIndentEnabled(automaticIndentation);
	editor.setFont(charScale, charFont);
	return editor;
end

-- Session management
local function linkScriptSession(res, script)
	local session = createClass({
		res = res,
		script = script
	});
	table.insert(sessions, session);
	
	local lock = (script.lockClient == localClient);
	local tab = pFunctionTabPanel.addTab();
	tab.setText(":" .. res.name .. "/" .. script.src);
	local editor = createScriptEditor(tab);
	editor.setSize(tab.getSize());
	
	function session.update()
		pFilename.setText(script.src);
		--pScriptSize.setText(tostring(strlen(pEditor.getText())));
		pScriptType.setText(script.type);
		return true;
	end
	session.update();

	function tab.events.onSize(w, h)
		editor.setSize(w, h);
		return true;
	end
	
	function tab.events.onShow()
		currentSession = session;
	
		pCloseButton.setDisabled(false);
		pSaveButton.setDisabled(not lock);
		
		-- Import definition data
		if (script.type == "shared") then
			importDefinitions("server");
			importDefinitions("client");
		else
			importDefinitions(script.type);
		end
		
		importDefinitions("shared");
		
		-- Now fill our list
		updateFunctionList();
		
		editor.moveToFront();
		
		session.update();
	end
	
	function tab.events.onHide()
		clearDefinitions();
	
		currentSession = false;
		
		pFilename.setText("");
		pScriptType.setText("");
		
		pSaveButton.setDisabled(true);
		pCloseButton.setDisabled(true);
	end
	
	editor.addEventHandler("onKeyInput", function(button, state)
			if not (state) then return true; end;
		
			if (button == "F3") then
				local routine, error = loadstring(editor.getText());
				local line;
				
				if (routine) then
					showCursorHint("Parsed successfully!");
					return true;
				end
				
				showScriptDebug(true);
				pScriptDebug.output(error);
				
				line = getLineNumberFromError(error);
				
				-- Set the cursor to the line
				editor.setCursor(editor.getLine(line));
			elseif (keyInfo.lctrl.state) then
				if (button == "s") then
					local text = editor.getText();
			
					if not (lock) then
						showCursorHint("You need the scriptLock!");
						return true;
					end
				
					if not (loadstring(text)) then
						showCursorHint("Parse Failed");
						return true;
					end
				
					local trans = sendFile(res, script.src, text);
					
					function trans.cbAbort()
						showCursorHint("Failed to transfer script");
						return true;
					end
					
					function trans.cbComplete()
						showCursorHint("Successfully updated!");
						return true;
					end
				end
			elseif (keyInfo.lalt.state) then
				if (button == "x") then
					session.destroy();
				end
			end
		end
	);
	
	function session.getEditor()
		return editor;
	end
	
	function session.pulse()
		tab.select();
		return true;
	end
	
	function session.request()
		triggerServerEvent("onClientRequestScriptLock", root, res.name, script.src);
		return true;
	end
	
	function session.acquire()
		if (tab.visible) then
			pSaveButton.setDisabled(false);
		end
		
		lock = true;
	end
	
	function session.isLock()
		return lock;
	end
	
	function session.free()
		if (tab.visible) then
			pSaveButton.setDisabled(true);
		end
		
		lock = false;
	end
	
	function session.save()
		local text = editor.getText();
		
		if not (loadstring(text)) then
			showMessageBox("Parse failed, please debug the script.", "Parse Error");
		else
			local trans = sendFile(res, script.src, text);
		
			function trans.cbAbort()
				showMessageBox("Failed to save script.", "Script Error");
				return true;
			end
		
			function trans.cbComplete()
				outputDebugString("Saved '" .. script.src .. "'!");
				return true;
			end
		end
		
		return true;
	end
	
	function session.destroy()
		if (lock) then
			triggerServerEvent("onClientFreeScriptLock", root, res.name, script.src);
		end
		
		free();
	
		tab.destroy();
		table.delete(sessions, session);
	end
	
	if not (script.lockClient) then
		session.request();
	end
	
	tab.select();
	return session;
end

function getSession(resource, src)
	local m,n;
	
	for m,n in ipairs(sessions) do
		if (n.res.name == resource) and (n.script.src == src) then
			return n;
		end
	end
	
	return false;
end

local function clearSessions()
	while not (#sessions == 0) do
		sessions[1].destroy();
	end
	
	return true;
end

local function findResourceScriptByPath(res, path)
    for m,n in pairs(res.scripts) do
        if (n.src == path) then
            return m;
        end
    end
    
    return false;
end

function doesResourceHaveScript(resname, scriptPath)
    local res = resourceData[resname];
    
    if not (res) then return false; end;
    
    local parsed_path = fileParsePath(scriptPath);
    
    if not (parsed_path) then return false; end;
    
    local script_id = findResourceScriptByPath(res, parsed_path);
    
    return not not (script_id);
end

function showResourceGUI(bShow)
    if (bShow == true) then
        if not (isEditorClientReady()) then return false, "not initialized"; end;
        
        -- Priviledge to open it
        if (doWeHaveAccessTo("editor", "access") == false) then
            return false, "no permission";
        end
    
        showCursor(true);
        showChat(false);
        
        if not (mainGUI) then
            local m,n;
            local screenW, screenH = guiGetScreenSize();
            
            mainGUI = {
				mode = "script",
				
				imagePreviews = {},
				visible = true
			};
            
			if (screenW < 1024) then
				editorMode = 1;
			else
				editorMode = 0;
			end
			
			-- Create the functional tab panel
			pFunctionTabPanel = themeCreateTabPanel();
			
			-- Create the editor
			local noteTab = pFunctionTabPanel.addTab();
			noteTab.setText("Notes");
			pNoteEditor = createAdvancedEditor(noteTab);
			pNoteEditor.showLineNumbers(true);
			
			function noteTab.events.onSize(w, h)
				pNoteEditor.setSize(w, h);
			end
			
			-- Create the top menu
			pMenu = themeCreateMenu();
			
			local fileMenu = pMenu.addItem("File");

			fileMenu.addItem("Open Resource", function()
					showResourceSelect(true);
					return true;
				end
			);
			
			fileMenu.addItem("Create Resource", function()
					showResourceCreation(true);
					return true;
				end
			);
			
			fileMenu.addItem("Delete Resource", function()
					if not (currentResource) then return false; end;
					
					local resource = currentResource;
					local msg = showMessageBox("Are you sure you want to delete '" .. resource.name .. "'?", "Resource Deletion", "confirm");
					
					function msg.events.onMsgBoxConfirm(accepted)
						if not (accepted) then return false; end;
                        
						triggerServerEvent("onClientRequestResourceRemoval", root, resource.name);
					end
					
					return true;
				end
			);
			
			fileMenu.addBreak();
			
			local scriptMenu = fileMenu.addSubList("Open Script");
			
			local filesMenu = fileMenu.addSubList("Open File");
			
			fileMenu.addBreak();
			
			fileMenu.addItem("Exit", function()
					showResourceGUI(false);
				end
			);
			
			local optionsMenu = pMenu.addItem("Options");
			
			optionsMenu.addItem("Preferences", function()
					showClientConfig(true);
				end
			);
			
			optionsMenu.addItem("Themes", function()
					showThemeManager(true);
				end
			);
			
			local toolsMenu = pMenu.addItem("Tools");
			
			local advConf = toolsMenu.addItem("Advanced Configuration", function()
					xmlCreateEditor(config);
				end
			);
			
			toolsMenu.setItemDescription(advConf, "F5");
			
			toolsMenu.addBreak();
			
			local runOpt = toolsMenu.addItem("Run...", function()
					local sw, sh = dxRoot.getScreenSize();
			
					local window = themeCreateWindow();
					window.setSize(400, 350);
					window.setPosition((sw - window.width) / 2, (sh - window.height) / 2);
					window.setText("Command Window");
					
					local menu = window.doMenu();
					local fileItem = menu.addItem("File");
					
					local closeWindow = fileItem.addItem("Close", function()
							window.destroy();
						end
					);
					
					local root = window.getRoot();
					
					local editor = themeCreateEditor(root);
					local w, h = root.getSize();
					editor.setSize(w, 180);
					editor.moveToFront();
					
					local logEditor = themeCreateEditor(root);
					logEditor.setSize(w, 100);
					logEditor.setPosition(0, 182);
					logEditor.setDisabled(true);
					
					function logEditor.print(text)
						logEditor.setText(logEditor.getText() .. text .. "\n");
						logEditor.setCursor(#logEditor.getText() + 1);
						return true;
					end
					
					function root.events.onSize(w, h)
						editor.setSize(w, 180);
						logEditor.setSize(w, 100);
					end
					
					local exec = themeCreateButton(root);
					exec.setSize(100, 20);
					exec.setPosition((w - 100) / 2, 287);
					exec.setText("Execute");
					
					-- Create local environment
					local env, methenv = createClass();
					local global = {
						colorSelect = function()
							local cselect = themeCreateColorSelect(window);
							
							cselect.setSelectedColor(window.getBackgroundColor());
							
							function cselect.events.onColorSelect(r, g, b)
								cselect.setBackgroundColor(r, g, b);
							end
							
							return cselect;
						end
					};
					env.setGlobal(global);
					
					local createClass = createClass;
					
					function global.createClass(...)
						return createClass(...);
					end
					
					local showThemeManager = showThemeManager;
					
					function global.themeManage()
						showThemeManager(true);
					end
					
					function global.print(text)
						logEditor.print(tostring(text));
					end
					
					function window.destroy()
						env.destroy();
					end
					
					local function execRun()
						local script = editor.getText();
						local prot, err = loadstring("return " .. script);
						
						if not (prot) then
							prot, err = loadstring(script);
							
							if not (prot) then
								logEditor.print("[Syntax Error]: " .. err);
								return;
							end
						end
						
						editor.removeText(1, #script);
						
						setfenv(prot, methenv);
						
						local res = { pcall(prot) };
						
						if not (res[1]) then
							logEditor.print("[Runtime Error]: " .. res[2]);
							return;
						end
						
						if (#res == 1) then
							logEditor.print("Command Successful!");
							return;
						end
						
						table.remove(res, 1);
						
						local m,n;
						local outs = "Result: ";
						
						for m,n in ipairs(res) do
							outs = outs .. tostring(n) .. " [" .. type(n) .. "], ";
						end
						
						logEditor.print(outs);
					end
					
					function exec.events.onPress()
						execRun();
						
						editor.moveToFront();
					end
					
					editor.addEventHandler("onKeyInput", function(button, state)
							if not (state) then return; end;
							
							if (button == "lalt") then
								execRun();
								return;
							end
						end
					);
					
					editor.showLineNumbers(true);
					editor.setColorEnabled(true);
					editor.setColorTokenHandler(getColorFromToken);
					editor.setAutoIndentEnabled(true);
				end
			);
			
			local viewMenu = pMenu.addItem("View");
			
			viewMenu.addItem("Switch Mode", function()
					mainGUI.nextFileMode();
				end
			);
			
			local helpMenu = pMenu.addItem("?");
			
			helpMenu.addItem("About", function()
					showMessageBox(
                        "Resource Manager created by (c)The_GTA.\nVisit http://community.mtasa.com/index.php?p=resources&s=details&id=1821\n\nDo you like my tools? Check out Magic.TXD, RenderWare TXD editor!",
                        "About"
                    );
				end
			);
	
			local fileListTheme = themeRegisterTemplate("fileList");
			fileListTheme.link(themeFindTemplate("listBox"));
			pFileList = themeCreateListBox();
			pFileList.setPosition(0, 20);
			pFileList.setSize(250, screenH-20);
			pFileList.setVisible(false);
			pFileList.setHeaderColor(15, 60, 10);
			pFileList.setActiveHeaderColor(20, 120, 30);
			pFileList.setSelectionColor(20, 180, 50);
			fileListTheme.register(pFileList);
			pFileList.addColumn();
			pFileList.setColumnName(1, "Resource File");
			pFileList.addColumn();
			pFileList.setColumnName(2, "Type");
			pFileList.setColumnWidth(2, 70);
            
			function pFileList.events.onListBoxSelect(row)
				if (mainGUI.mode == "script") then
					mainGUI.openScript(row);
				else
					local file = currentResource.files[row];
					
					outputDebugString("Selected '" .. file.src .. "' (" .. row .. ", " .. file.type .. ")");
					
					executeFile(file);
				end
			end
			
			pSaveButton = themeCreateButton();
			pSaveButton.setPosition(screenW - 440, screenH - 30);
			pSaveButton.setSize(75, 20);
			pSaveButton.setVisible(false);
			pSaveButton.setText("Save");
            
            function pSaveButton.events.onPress()
				currentSession.save();
				return true;
			end
			
			pCloseButton = themeCreateButton();
			pCloseButton.setPosition(screenW - 530, screenH - 30);
			pCloseButton.setSize(75, 20);
			pCloseButton.setVisible(false);
			pCloseButton.setText("Close");
            
            function pCloseButton.events.onPress()
				currentSession.destroy();
                
                currentSession = false;
				return true;
			end
        
            local currentName="";
            local currentType="";
            local currentRealname="";
            local currentDescription="none";
            local currentAuthor="community";
            
            -- Create advanced settings tabpanel (with special theme)
			local spcTabPanelTheme = themeRegisterTemplate("spcTabPanel");
			spcTabPanelTheme.link(themeFindTemplate("tabPanel"));
			pTabHolder = createTabPanel();
			pTabHolder.setBackgroundColor(0x00, 0x18, 0x60);
			spcTabPanelTheme.register(pTabHolder);
			pTabHolder.setPosition(screenW-350, 20);
			pTabHolder.setSize(350, 290);
			pTabHolder.setVisible(false);
            
            local pGeneralTab = pTabHolder.addTab();
			pGeneralTab.setText("General");
			
			function pGeneralTab.render()
				dxDrawText("Resource Name:", 15, 20);
				dxDrawText("Resource Type:", 15, 40);
				dxDrawText("Description:", 15, 60);
				dxDrawText("Author:", 15, 120);
				return super();
			end
			
			pResourceName = themeCreateEditBox(pGeneralTab);
			pResourceName.setPosition(115, 20);
			pResourceName.setSize(225, 18);
			pResourceName.setText(currentName);
			pResourceName.setDisabled(true);
			
			pResourceType = themeCreateEditBox(pGeneralTab);
			pResourceType.setPosition(115, 40);
			pResourceType.setSize(150, 18);
			pResourceType.setText(currentType);
			
			local pTypeSet = themeCreateButton(pGeneralTab);
			pTypeSet.setPosition(265, 40);
			pTypeSet.setSize(75, 18);
			pTypeSet.setText("Set");
			
			local function typeAccept()
				if not (currentResource) then return false; end;
				
				triggerServerEvent("onResourceSet", root, currentResource.name, "type", pResourceType.getText());
			end
			
			pTypeSet.addEventHandler("onPress", typeAccept, false);
			pResourceType.addEventHandler("onAccept", typeAccept, false);
			
			pResourceDescription = themeCreateEditor(pGeneralTab);
			pResourceDescription.setPosition(95, 60);
			pResourceDescription.setSize(245, 54);
			pResourceDescription.setText(currentDescription);
			pResourceDescription.setCursor(#currentDescription + 1);
			
			local pSetDescription = themeCreateButton(pGeneralTab);
			pSetDescription.setPosition(15, 76);
			pSetDescription.setSize(80, 20);
			pSetDescription.setText("Set");
            
            function pSetDescription.events.onPress()
				if not (currentResource) then return false; end;
				
				triggerServerEvent("onResourceSet", root, currentResource.name, "description", pResourceDescription.getText());
			end
			
			pResourceAuthor = themeCreateEditBox(pGeneralTab);
			pResourceAuthor.setPosition(115, 120);
			pResourceAuthor.setSize(225, 18);
			pResourceAuthor.setText(currentAuthor);
			pResourceAuthor.setDisabled(true);
            
            -- Resource buttons
            local buttonOffset=155;
			local pStartResource = themeCreateButton(pGeneralTab);
			pStartResource.setPosition(10, buttonOffset+20);
			pStartResource.setSize(165, 20);
			pStartResource.setText("Start Resource");
			
            function pStartResource.events.onPress()
				if not (currentResource) then return false; end;
				
				triggerServerEvent("onClientRequestStartResource", root, currentResource.name);
			end
			
			local pStopResource = themeCreateButton(pGeneralTab);
			pStopResource.setPosition(175, buttonOffset+20);
			pStopResource.setSize(165, 20);
			pStopResource.setText("Stop Resource");
            
            function pStopResource.events.onPress()
				if not (currentResource) then return false; end;
				
				triggerServerEvent("onClientRequestStopResource", root, currentResource.name);
			end
            
            -- Script
			local pScriptTab = pTabHolder.addTab();
			pScriptTab.setText("Script");
			
			function pScriptTab.render()
				dxDrawText("Filename:", 15, 20);
				dxDrawText("Type:", 15, 40);
				return super();
			end
			
			pFilename = themeCreateEditBox(pScriptTab);
			pFilename.setPosition(75, 20);
			pFilename.setSize(265, 18);

			pScriptType = themeCreateEditBox(pScriptTab);
			pScriptType.setPosition(55, 40);
			pScriptType.setSize(285, 18);
            
            -- Buttons
            local buttonOffset=85;
			local pAddScript = themeCreateButton(pScriptTab);
			pAddScript.setPosition(10, buttonOffset);
			pAddScript.setSize(165, 20);
			pAddScript.setText("Add Script");
			
            function pAddScript.events.onPress()
				if not (currentResource) then return false; end;
				
				local src = pFilename.getText();
				local path, isFile = fileParsePath(src);
				
				if not (path) then
					showMessageBox("Target '" .. src .. "' is an invalid path");
					return false;
				end
				
				if not (isFile) then
					showMessageBox("Target '" .. src .. "' does not point to a file location!");
					return false;
				end
				
				triggerServerEvent("onClientAddScript", root, currentResource.name, path, pScriptType.getText());
			end
            
			local pRemoveScript = themeCreateButton(pScriptTab);
			pRemoveScript.setPosition(175, buttonOffset);
			pRemoveScript.setSize(165, 20);
			pRemoveScript.setText("Remove Script");

            function pRemoveScript.events.onPress()
				if not (currentResource) then return false; end;
				
				triggerServerEvent("onClientRemoveScript", root, currentResource.name, pFilename.getText());
			end
			
			-- Functions list
			pFunctionSearch = themeCreateEditBox();
			pFunctionSearch.setPosition(screenW - 348, 315);
			pFunctionSearch.setSize(346, 20);
			
			function pFunctionSearch.events.onEditBoxChanged()
				updateFunctionList();
			end
			
			pFunctionList = themeCreateListBox();
			pFunctionList.setPosition(screenW - 350, 335);
			pFunctionList.setSize(335, 350);
			pFunctionList.addColumn();
			pFunctionList.setColumnName(1, "Function");
			pFunctionList.setColumnWidth(1, 335);
            
            function pFunctionList.events.onListBoxConfirm()
                local selectedItems = pFunctionList.getSelection();

                if not (selectedItems) then return; end;

                local firstSelect = selectedItems[1];
                
                if not (firstSelect) then return; end;
                
                local itemData = getItemData(1, firstSelect);
                
                -- Add stuff to our magic.
                if (currentSession) then
                    local editor = currentSession.getEditor();
                    
                    local cursor = editor.getCursor();
                    
                    editor.insertText(itemData.funcName, cursor);
                    editor.setCursor(cursor + #itemData.funcName);
                    
                    editor.giveFocus();
                end
            end
			
            function mainGUI.update()
                pFileList.clearRows();
                
                if (currentResource) then
                    local m,n;
                    
                    if (mainGUI.mode == "script") then
                        for m,n in ipairs(currentResource.scripts) do
                            local row = pFileList.addRow();
                            pFileList.setItemText(1, row, n.src);
                            pFileList.setItemText(2, row, n.type);
                            
                            local colorType = scriptColors[n.type];
							
							if not (colorType) then
								colorType = { 255, 255, 255 };
							end
							
							pFileList.setItemColor(1, row, unpack(colorType));
                        end
                        
                        pFileList.setColumnWidth(1, math.max(100, pFileList.getMinimumColumnWidth(1) + 5));
                    elseif (mainGUI.mode == "file") then
                        for m,n in ipairs(currentResource.files) do
                            local row = pFileList.addRow();
                            pFileList.setItemText(1, row, n.src);
                            pFileList.setItemText(2, row, n.type);
							
                            local colorType = fileColors[getFileExtension(n.src)];
							
							if not (colorType) then
								colorType = { 255, 255, 255 };
							end
							
							colorType[4] = 255;
							
							pFileList.setItemColor(1, row, unpack(colorType));
                        end
                        
                        pFileList.setColumnWidth(1, math.max(100, pFileList.getMinimumColumnWidth(1) + 5));
                    end
                    
                    -- Update info
                    pResourceName.setText(currentResource.name);
                    pResourceType.setText(currentResource.type);
                    pResourceDescription.setText(currentResource.description);
					pResourceDescription.setCursor(#currentResource.description + 1);
                    pResourceAuthor.setText(currentResource.author);
                else
                    pResourceName.setText("");
                    pResourceType.setText("");
                    pResourceDescription.setText("");
                    pResourceAuthor.setText("");
                end

                -- Update sub GUI
                if (pSelectGUI) then
                    pSelectGUI.update();
                end
                
                if (pFileManager) then
                    pFileManager.update();
                end

                outputDebugString("Updated mainGUI");
                return true;
            end
			
			function mainGUI.updateResource()
				-- Update the usual thing
				mainGUI.update();
			
				scriptMenu.clear();
				filesMenu.clear();
				
                if (currentResource) then
                    for m,n in ipairs(currentResource.scripts) do
                        local menu, id = scriptMenu.addSubList(n.src);
                        
                        local function openHandler()
                            mainGUI.openScript(m);
                        end
                        
                        scriptMenu.setItemHandler(id, openHandler);
                        
                        menu.addItem("Open", openHandler);
                        menu.addItem("Delete", function()
                                if (n.lockClient) and not (n.lockClient == localPlayer) then
                                    showMessageBox("'" .. n.src .. "' is locked!");
                                    return true;
                                end
                        
                                local msgBox = themeCreateMsgBox("Are you sure you want to remove '" .. n.src .. "'?", "confirm");
                                msgBox.setText("File Deletion");
                                
                                function msgBox.events.onMsgBoxConfirm(c)
                                    if not (c) then return true; end;
                                    
                                    triggerServerEvent("onClientRemoveScript", root, currentResource.name, n.src);
                                end
                            end
                        );
                        
                        scriptMenu.setItemDescription(id, n.type);
                        
                        local colorType = scriptColors[n.type];
                        
                        if not (colorType) then
                            colorType = { 255, 255, 255 };
                        end
                        
                        colorType[4] = 255;
                        
                        scriptMenu.setItemColor(id, unpack(colorType));
                    end
                    
                    for m,n in ipairs(currentResource.files) do
                        local id = filesMenu.addItem(n.src, function()
                                executeFile(n);
                            end
                        );
                        
                        filesMenu.setItemDescription(id, n.type);
                        
                        local colorType = fileColors[getFileExtension(n.src)];
                        
                        if not (colorType) then
                            colorType = { 255, 255, 255 };
                        end
                        
                        filesMenu.setItemColor(id, unpack(colorType));
                    end
                end
				
				return true;
			end
			
			function mainGUI.updateAccess()
				-- Update access oriented elements
                pAddScript.setDisabled(doWeHaveAccessTo("editor", "addScript") == false);
                pRemoveScript.setDisabled(doWeHaveAccessTo("editor", "removeScript") == false);
                
				return true;
			end
            
            function mainGUI.setFileMode(mode)
                if not (mainGUI.mode == mode) then
                    mainGUI.mode = mode;
					
                    mainGUI.update();
                end
                
                return true;
            end
            
            function mainGUI.nextFileMode()
                if not (mainGUI.mode == "file") then
                    mainGUI.setFileMode("file");
                else
                    mainGUI.setFileMode("script");
                end
            end
            
            function mainGUI.openScriptByPath(resname, filename, lineNumOpt)
                local res = resourceData[resname];
                
                if not (res) then return false, "resource not found"; end;
                
                local parsed_path = fileParsePath(filename);
                
                if not (parsed_path) then return false, "invalid script path"; end;
                
                -- Check if we even have such a script.
                local script_id = findResourceScriptByPath(res, parsed_path);
                
                if not (script_id) then return false, "script not found"; end;
                
                -- Change focus to the requested resource.
                currentResource = res;
                
                mainGUI.updateResource();
                
                -- Open up that script!
                return mainGUI.openScript(script_id, lineNumOpt);
            end
			
			function mainGUI.openScript(id, lineNumOpt)
				local script = currentResource.scripts[id];
				local session = getSession(currentResource.name, script.src);
				
				if (session) then
					session.pulse();
                    
                    if (lineNumOpt) then
                        -- Select the line anyway.
                        local editor = session.getEditor();
                        
                        if (editor) then
                            local beg, term = editor.getLine(lineNumOpt);
                            
                            if (beg) then
                                editor.setCursor(term + 1);
                            end
                        end
                    end
                    
					return true;
				end
				
				-- We need to get the lock beforehand
				session = linkScriptSession(currentResource, script);
			
				-- Request it
				local trans = getFile(currentResource, script.src);
				trans.setParent(session);
				
				function session.destroy()
					session = nil;
				end
				
				function trans.cbAbort()
					if not (session) then return true; end;
				
					showMessageBox("Unable to request script '" .. script.src .. "'", "Request Error");
					
					session.destroy();
					return true;
				end
				
				function trans.cbComplete()
					session.getEditor().setText(trans.data);
                    
                    if (lineNumOpt) then
                        local beg, term = session.getEditor().getLine(lineNumOpt);
                        
                        if (beg) then
                            session.getEditor().setCursor(term + 1);
                        end
                    end
                    
					return true;
				end
                
                return true;
			end
            
            function mainGUI.createImagePreview(src, width, height)
                local screenWidth, screenHeight = guiGetScreenSize();
                local guiW,guiH = math.max(200, width), math.max(200, height + 50);
                local titleWidth = dxGetTextWidth(src) + 30;
                
                if (guiW < titleWidth) then
                    guiW = titleWidth;
                end
                
                local window = guiCreateWindow((screenWidth - guiW) / 2, (screenH - guiH) / 2, guiW, guiH, src, false);
                local image = guiCreateStaticImage((guiW - width) / 2, 20 + ((guiH-50) - height) / 2, width, height, src, false, window);
                guiWindowSetSizable(window, false);
                
                local button = guiCreateButton((guiW - 100) / 2, guiH - 30, 100, 20, "Close", false, window);
                
                addEventHandler("onClientGUIClick", button, function(button, state, x, y)
                        mainGUI.imagePreviews[window] = nil;
                    
                        destroyElement(window);
                    end, false
                );
				
				guiSetVisible(window, mainGUI.visible);
                
                mainGUI.imagePreviews[window] = true;
                return window;
            end
            
			pCloseButton.setDisabled(true);
            pSaveButton.setDisabled(true);
			
			-- Make the noteEditor active
			pNoteEditor.moveToFront();
			
			-- Render our special background correctly in MTA:Eir
			function dxRoot.render()
				dxDrawRectangle(0, 20, width, height - 20, tocolor(20, 20, 20, 255));
			
				super();
				
				-- Add a cute notification <3
				if (editorMode == 0) then
					dxDrawText("Resource Manager by (c)The_GTA", 265, height-27);
				end
				
				return true;
			end
            
            function dxRoot.present()
                super();
                
                -- We want to draw our mouse cursor, if there is a special one.
                local hierarchy = dxRoot.getHierarchy();
                
                local mouseFunctor, functorWidth, functorHeight = hierarchy.getMouseRenderFunctor();
                
                if (mouseFunctor) then
                    setCursorAlpha(0);
                    
                    -- Render a special mouse cursor.
                    local mouseX = mouseX;
                    local mouseY = mouseY;
                    
                    local mouseStartX = ( mouseX - functorWidth / 2 );
                    local mouseStartY = ( mouseY - functorHeight / 2 );
                    
                    mouseFunctor(mouseStartX, mouseStartY, functorWidth, functorHeight);
                else
                    setCursorAlpha(255);
                end
                
                return true;
            end
			
			if not (greenBuild) then
				-- We compiled dxElements within resedit; handle it
				addEventHandler("onClientRender", root, function()
						-- Render the dx elements
						renderDXElements();
					end
				);
			else
				function dxRoot.isHit()
					return true;
				end
			end
			
			-- Reset definitions
			clearDefinitions();
			
			-- Update
			mainGUI.updateResource();
            mainGUI.updateAccess();
		elseif (mainGUI.visible) then
			return true;
        else
            local m,n;
            local j,k;
			
			dxRoot.setVisible(true);
			
			if not (greenBuild) then
				-- Restart updating the input status
				inputResurrect(preservedInputStatus);
			end
            
            -- Show xmleditors
            xmlShowEditors(true);
            
            -- Show image previews
            for m,n in pairs(mainGUI.imagePreviews) do
                guiSetVisible(m, true);
            end
			
			mainGUI.visible = true;
        end
		
		enterEditorMode();
    else
        if (mainGUI) and (mainGUI.visible) then
            local m,n;
            local j,k;
        
			-- Switch modes
            showCursor(false);
            showChat(true);
            showFileManager(false);
            showScriptDebug(false);
			showControlPanel(false);
			showPasteGUI(false);

			leaveEditorMode();
			
			if not (greenBuild) then
				-- Disable the GUI input provider
				preservedInputStatus = inputPreserveStatus();
			end
			
			dxRoot.setVisible(false);
			
			destroyHint();
            
            -- Hide xmleditors
            xmlShowEditors(false);
            
            -- Hide image previews
            for m,n in pairs(mainGUI.imagePreviews) do
                guiSetVisible(m, false);
            end
			
			if not (greenBuild) then
				--guiReleaseFocus();
				guiSetInputEnabled(false);
			end
	
			mainGUI.visible = false;
        end
    end
	
    return true;
end

if not (greenBuild) then
	addEventHandler("onClientResourceStop", resourceRoot, function()
			dxRoot.destroy();
		end
	);
end

function dxRoot.destroy()
	local m,n;
    
    --Make sure we are 'terminated' editor mode.
    -- This prevents us from trying to access any dxElements components,
    -- since they are destroyed already.
    editorMode = -1;

	showResourceGUI(false);
	
	-- Kill xmleditors
	xmlDestroyEditors();
	
	-- Notify modules
	saveThemes();
	
	-- Save config changes
	xmlSetNode(pConfigFile, config);
	xmlSaveFile(pConfigFile);
	xmlUnloadFile(pConfigFile);
end

addEvent("onClientAccessRightsUpdate", true);
addEventHandler("onClientAccessRightsUpdate", root, function(accessTable)
        -- When the client received their first access rights, it is ready.
        _G.access = accessTable;
        outputDebugString("Received access rights");
        
        if (doWeHaveAccessTo("editor", "access")) then
            -- Close that window to avoid bugs ;)
            if (pDenyEditorAccessMsg) then
                closeMessageBox(pDenyEditorAccessMsg);
				
				-- Let us show the editor here
				showResourceGUI(true);
            end
		
			-- Check whether we lost access or just do not have a valid resource selected
			if not (currentResource) or not (doWeHaveAccessTo("resources", currentResource.name)) then
				currentResource = false;
			
				-- Select the first resource we have access to
				for m,n in ipairs(resourceList) do
					if (doWeHaveAccessTo("resources", n)) then
						currentName = n;
						currentResource = resourceData[n];
						currentType = currentResource.type;
						currentAuthor = currentResource.author;
						currentRealname = currentResource.realname;
						currentDescription = currentResource.description;
						break;
					end
				end
				
				if (mainGUI) then
					mainGUI.updateResource();
				end
			elseif (pSelectGUI) then
				pSelectGUI.update();
			end
			
			if (mainGUI) then
				mainGUI.updateAccess();
			end
        else
            -- Woops, we probably lost access to the editor
            showResourceGUI(false);
        end
    end
);

addEvent("onScriptUpdate", true);
addEventHandler("onScriptUpdate", root, function(resource, filename)
        outputDebugString("File '" .. filename .. "' updated!");
        showUpdateGUI(true, "["..resource.."]: "..filename.." ("..getPlayerName(source)..")", 3500);
		
		local session = getSession(resource, filename);
		
		if not (session) then return true; end;
		if (session.isLock()) then return true; end;	-- We got the same stuff
		
		local trans = getFile(session.res, filename);
		trans.setParent(session);
		
		function trans.cbComplete()
			session.getEditor().setText(trans.data);
			return true;
		end
    end
);

addEvent("onResourceDataUpdate",true);
addEventHandler("onResourceDataUpdate", root, function(data, silent)
        if not (resourceData[data.name]) then
            table.insert(resourceList, data.name);
			
			resourceData[data.name] = data;
			
			if not (silent) then
				showUpdateGUI(true, "Added resource '" .. data.name .. "'", 5000);
			end
			
			if (pSelectGUI) then
				pSelectGUI.update();
			end
			
			return;
		end
		
		-- Resource already exists
		resourceData[data.name] = data;

		if not (silent) then
			showUpdateGUI(true, "Resource '" .. data.name .. "' update", 5000);
		end
		
		if (mainGUI) and (currentResource.name == data.name) then
			currentResource = data;
		
			mainGUI.updateResource();
		end
    end
);

addEvent("onResourceRemove", true);
addEventHandler("onResourceRemove", root, function(resname)
        local m,n;

        if (currentResource) then
            if (resname == currentResource.name) then
                currentResource = false;
            
                if (mainGUI) then
                    mainGUI.updateResource();
                end
            end
        end
        
        local resEntry = resourceData[resname];
        
        if (resEntry) then
            -- Kill all resource script locks.
            for m,n in ipairs(resEntry.scripts) do
                if (n.lockClient) then
                    triggerEvent("onClientScriptLockFree", n.lockClient, resname, n.src);
                end
            end
        
            -- Drop the resource from the sorted resource list.
            for m,n in ipairs(resourceList) do
                if (n == resname) then
                    table.remove(resourceList, m);
                    break;
                end
            end
        
            -- Drop the resource registration.
            resourceData[resname] = nil;
        end
        
        showUpdateGUI(true, "Resource Deletion: "..resname);
    end
);

addEvent("onResourceAddScript", true);
addEventHandler("onResourceAddScript", root, function(resource, filename, scripttype, data)
        local pRes = resourceData[resource];
        local pEntry={};
        pEntry.src=filename;
        pEntry.type=scripttype;
        table.insert(pRes.scripts, pEntry);
        
        if (mainGUI) and (pRes == currentResource) then
            mainGUI.updateResource();
        end
		
        showUpdateGUI(true, "[" .. resource .. "]: Added script '" .. filename .. "'");
    end
);

addEvent("onResourceRemoveScript", true);
addEventHandler("onResourceRemoveScript", root, function(resource, filename)
        local pRes = resourceData[resource];
        local m,n;
        
        for m,n in ipairs(pRes.scripts) do
            if (n.src == filename) then
				if (n.lockClient) then
					triggerEvent("onClientScriptLockFree", n.lockClient, resource, filename);
				end
			
                table.remove(pRes.scripts, m);
            end
        end
		
		-- Notify the user
		showUpdateGUI(true, "[" .. resource.."]: Removed script '" .. filename .. "'");
		
        if (mainGUI) and (pRes == currentResource) then
            mainGUI.updateResource();
        end
    end
);

triggerServerEvent("onClientResourceSystemReady", localPlayer);