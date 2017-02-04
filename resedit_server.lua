if not (hasObjectPermissionTo(getThisResource(), "general.ModifyOtherObjects")) then
    error("Permission Denied ('general.ModifyOtherObjects')");
	return false;
end

local playerData={};
local controlSessions={};
local string = string;
local math = math;
local table = table;
local strsub = string.sub;
local strlen = string.len;
local strbyte = string.byte;
local strfind = string.find;
local version = getVersion();

local accountData={};
local defaultAccount = {};

local transactionPacketBytes = 1200;

-- Temporily disable instruction count hook
debug.sethook(nil);

-- Init all configuration files
local pAccessConfig = xmlLoadFile("access.xml");

if not (pAccessConfig) then
	local xml = xmlLoadFile("default/access.xml");
    
    pAccessConfig = xmlCopyFile(xml, "access.xml");
    
    xmlUnloadFile(xml);
end

local pConfig = xmlLoadFile("config.xml");

if not (pConfig) then
	local xml = xmlLoadFile("default/server_config.xml");
	
	pConfig = xmlCopyFile(xml, "config.xml");
	
	xmlUnloadFile(xml);
end

function getFileExtension(src)
    local lastOffset = false;
    local begin, last = string.find(src, "[.]");

    while (begin) do
        lastOffset = begin+1;
        begin, last = string.find(src, "[.]", lastOffset);
    end
    
    if not (lastOffset) then
        return false;
    end
    
    return string.sub(src, lastOffset, string.len(src));
end

local function inheritAccountDefaults(account)
	local editor = account.editor;
	local controlPanel = account.controlPanel;
	local resources = account.resources;
	
	for m,n in pairs(defaultAccount.editor) do
		editor[m] = n;
	end
	
	for m,n in pairs(defaultAccount.controlPanel) do
		controlPanel[m] = n;
	end
	
	for m,n in pairs(defaultAccount.resources) do
		resources[m] = n;
	end
end

local function initAccountDependencies(account)
	function account.addRight(right, allow)
		local found = strfind(right, "[.]");
		local objectType;
		local objectParam;
		
		if not (found) then return false; end;
		
		objectType = strsub(right, 1, found - 1);
		objectParam = strsub(right, found + 1, strlen(right));
		
		if (strlen(objectParam) == 0) then
			outputDebugString("Invalid parameter for type '" .. objectType .. "' at '" .. account.user .. "'", 2);
			return false;
		end
		
		if (objectType == "editor") then
			account.editor[objectParam] = allow;
		elseif (objectType == "resource") then
			searchResources(objectParam, function(res)
					account.resources[res.getName()] = allow;
				end
			);
		elseif (objectType == "controlPanel") then
			account.controlPanel[objectParam] = allow;
		else
			outputDebugString("Invalid access right for '" .. account.user .. "'", 2);
			return false;
		end
		
		return true;
	end
    
    function account.clearRights()
        -- Set all rights to unknown.
        account.controlPanel = {}
        account.editor = {}
        account.resources = {}
        
        -- Inherit the defaults.
        inheritAccountDefaults(account);
        
        -- Now the access rights are at their clean state.
        return true;
    end
end

-- Set up pseudo default account
defaultAccount = {
	user = "guest"
};
initAccountDependencies(defaultAccount);

local function initDefaultAccountRights()
	defaultAccount.editor = {
		access = false,
		objectManagement = false,
		scriptLock = false,
        addScript = false,
        removeScript = false,
		createResource = false,
		removeResource = false
	};
	defaultAccount.controlPanel = {
		access = false,
		requirePassword = true
	};
	defaultAccount.resources = {
		resedit = false
	};
end
initDefaultAccountRights();

local function createAccountData(user)
	local account = {
		user = user,
		
		editor = {},
		controlPanel = {},
		
		resources = {}
	};
	
	-- Inherit defaultAccount's settings
    inheritAccountDefaults(account);
	
	initAccountDependencies(account);
	
	accountData[user] = account;
	return account;
end

local function findCreateAccountData(user)
    local alreadyExists = accountData[user];
    
    if (alreadyExists) then
        return alreadyExists;
    end
    
    return createAccountData(user);
end

local config;
local access;
local general;
local controlPanel;

local function parseAccessConfigAccountNode(account, node)
    local j,k;

    for j,k in ipairs(node.children) do
        if (k.name == "right") then
            account.addRight(k.attr.object, k.attr.allow == "true");
        end
    end
end

local function loadAccessConfig()
    local m,n;

	access = xmlGetNode(pAccessConfig);
    
	-- Load up all access configurations
	accessData = {};
	
	for m,n in ipairs(access.children) do
		if (n.name == "account") then
			local account = findCreateAccountData(n.attr.user);
            
            parseAccessConfigAccountNode(account, n);
		elseif (n.name == "default") then
			parseAccessConfigAccountNode(defaultAccount, n);
		end
	end
    
    -- If you are reloading account rights, you should update the clients and their local copies aswell.
end
loadAccessConfig();

local function loadConfig()
	config = xmlGetNode(pConfig);
	controlPanel = findCreateNode(config, "controlPanel");
    general = findCreateNode(config, "general");
end
loadConfig();

local function initPlayer(client)
	local sessions = {};
    local pData = {
        isReady = false,
		isEditing = false,
		editElement = false,
		controlSession = false,
		access = {},
		account = defaultAccount,
		uploads = {},
		downloads = {}
	};
	
	function pData.linkScript(res, script)
		-- Script lock check
		if (script.lockClient == client) then
			return true;    -- You have the lock already
		elseif (script.lockClient) then
			return false;
		end
	
		local session = {
			resource = res,
			script = script,
		};
		
		function session.destroy()
			triggerClientEvent("onClientScriptLockFree", client, res.name, script.src);
		
			local m,n;
			
			for m,n in ipairs(sessions) do
				if (n == session) then
					table.remove(sessions, m);
					break;
				end
			end
		end
		
		table.insert(sessions, session);
		script.link(client, session);
		
		-- Update global data
		triggerClientEvent("onClientScriptLockAcquire", client, res.name, script.src);
		return true;
	end
	
	function pData.clearLinks()
		while not (#sessions == 0) do
			sessions[1].script.unlink();
		end
		
		sessions = {};
		return true;
	end
	
	function pData.updateAccess()
		local n = 1;
	
		while (n <= #sessions) do
			local session = sessions[n];
		
			if not (pData.hasAccessTo("resources", session.resource.getName()) or not (pData.hasAccessTo("editor", "scriptLock"))) then
				session.script.unlink();
			else
				n = n + 1;
			end
		end
		
		return true;
	end
    
    function pData.hasAccessTo(accGroup, itemId)
        -- If we have the right to modify other objects, we are basically root admin.
        -- Do not give this priviledge out to anyone uncarefully.
        if (hasObjectPermissionTo(client, "general.ModifyOtherObjects")) then return true; end;
    
        if (accGroup == "editor") then
            return pData.account.editor[ itemId ];
        elseif (accGroup == "controlPanel") then
            return pData.account.controlPanel[itemId];
        elseif (accGroup == "resources") then
            return pData.access.resources[itemId];
        end
        
        return false;
    end
	
	-- Usually, a joined player is logged out, but whatever
	local account = getPlayerAccount(client);
	
	if not (isGuestAccount(account)) then
		pData.account = accountData[getAccountName(account)];
		
		if not (pData.account) then
			pData.account = defaultAccount;
		end
	end
	
	playerData[client] = pData;
    return true;
end

local m,n;
for m,n in ipairs(getElementsByType("player")) do
    initPlayer(n);
end

addEventHandler("onPlayerJoin", root, function()
        initPlayer(source);
    end
);

local function updateClientAccess(client)
    local m,n;
    local resources = getResources();
    local pData = playerData[client];
    local playerAccess = pData.access;
    
    pData.isReady = true;
    
	-- We simply send the account
    playerAccess.account = pData.account;
    playerAccess.isAdmin = isClientAdmin(client);
	
    playerAccess.resources = {};
    
    for m,n in ipairs(resources) do
        playerAccess.resources[getResourceName(n)] = checkResourceAccess(client, n);
    end
	
	-- Overwrite this with the account settings
	for m,n in pairs(pData.account.resources) do
		playerAccess.resources[m] = n;
	end
    
    -- Send this table to the client
    triggerClientEvent(client, "onClientAccessRightsUpdate", root, playerAccess);
    return true;
end

local function reloadAccessConfig()
    -- The server requested to reload our access configuration.
    -- So let's do that.
    
    -- Initialize all globals to defaults that are populated by access.xml.
    initDefaultAccountRights();
    
    -- Reset all other registered accounts.
    for m,n in pairs(accountData) do
        n.clearRights();
    end
    
    -- Load new configuration from disk.
    xmlUnloadFile(pAccessConfig);
    
    pAccessConfig = xmlLoadFile("access.xml");
    
    loadAccessConfig();
    
    -- Now update the network players.
    local connectedPlayers = getElementsByType("player");
    
    for m,n in ipairs(connectedPlayers) do
        -- Player has to be initialized first of course.
        local pData = playerData[n];
        
        if (pData.isReady) then
            updateClientAccess(n);
        end
    end
end

addEventHandler("onPlayerLogin", root, function(previous, account, auto)
        local pData = playerData[source];
		
		-- Give client the account it logged into
		pData.account = accountData[getAccountName(account)];
		
		if not (pData.account) then
			pData.account = defaultAccount;
		end
		
		updateClientAccess(source);
    end
);

addEventHandler("onPlayerLogout", root, function(previous, account)
        local pData = playerData[source];
		
		-- Give client the guest account data
		pData.account = defaultAccount;

        updateClientAccess(source);
        
        -- Kill illegal transactions
        local m,n;
        
        for m,n in pairs(pData.downloads) do
            if not (pData.hasAccessTo("resources", n.resource.name)) then
                triggerClientEvent(source, "onClientDownloadAbort", root, n.id);
                
                pData.downloads[m] = nil;
            end
        end
		
		-- Abort uploads
		for m,n in pairs(pData.uploads) do
			if not (pData.hasAccessTo("resources", n.resource.name)) then
				n.abort();
			end
		end
		
		-- Illegal scriptlock?
		pData.updateAccess();
    end
);

local function fileSwitchHack(file)
	local stub = file.read(3);
	
	if not (string.byte(stub, 1) == 239) or not (string.byte(stub, 2) == 187) or not (string.byte(stub, 3) == 191) then
		file.seek(0);
		return false;
	end
	
	return true;
end

addEvent("onFileHashRequest", true);
addEventHandler("onFileHashRequest", root, function(id, resource, filename)
		local pData = playerData[client];
		local res = getResourceFromNameEx(resource);
		
		if not (res) then return false; end;
		
		if not (pData.hasAccessTo("resources", resource)) then
			triggerClientEvent(client, "onClientFileHashAbort", root, id);
			return false;
		end
		
		filename = fileParsePath(filename);
		
		-- We just send the hash
		local file = res.openFile(filename);
		
		if not (file) then
			triggerClientEvent(client, "onClientFileHash", root, id, false);
			return true;
		end
		
		local size = file.size();
		
		if (res.getScriptFromSource(filename)) and (size > 2) then
			if (fileSwitchHack(file)) then
				size = size - 3;
			end
		end
		
		if (size == 0) then
			file.destroy();
		
			triggerClientEvent(client, "onClientFileHash", root, id, "");
			return true;
		end
		
		triggerClientEvent(client, "onClientFileHash", root, id, md5(file.read(size)));
		
		file.destroy();
	end	
);

addEvent("onDownloadRequest", true);
addEventHandler("onDownloadRequest", root, function(id, resource, filename)
        local pData = playerData[client];
        local res = getResourceFromNameEx(resource);
        local found = false;
		local isScript = false;
        local m,n;
        
        if not (res) then return false; end;
        
        if not (pData.hasAccessTo("resources", resource)) then
            outputChatBox("Access denied to resource '" .. resource .. "'", client);
            return false;
        end
        
        -- Transaction is already running under this id
        if (pData.downloads[tostring(id)]) then
            triggerClientEvent(client, "onClientDownloadAbort", root, id);
            return false;
        end
		
		-- Parse it
		filename = fileParsePath(filename);
        
        -- It must be listed as file, else it is a safe hack
        for m,n in ipairs(res.files) do
            if (n.src == filename) then
                found = true;
            end
        end
        
        for m,n in ipairs(res.scripts) do
            if (n.src == filename) then
                found = true;
				isScript = true;
            end
        end
        
        if not (found) then
            kickPlayer(client, "Tried to request a non marked file. Please contact the server administrator.");
            return false;
        end
        
        -- Send data to client
        file = res.openFile(filename);
        
        if not (file) then
            triggerClientEvent(client, "onClientDownloadAbort", root, id);
            return false;
        end
		
		local size = file.size();
		
		if (isScript) and (size > 2) then
			if (fileSwitchHack(file)) then
				size = size - 3;
			end
		end
        
        local trans = {};
        pData.downloads[tostring(id)] = trans;
        trans.resource = res;
        trans.file = file;
        
        triggerClientEvent(client, "onClientDownloadAccept", root, id, size);
    end
);

addEvent("onDownloadReady", true);
addEventHandler("onDownloadReady", root, function(id)
        local pData = playerData[client];
        local trans = pData.downloads[tostring(id)];
        
        if not (trans) then
            outputDebugString("Internal Error: Unknown transaction", client);   -- Short for HAAAAAXXXXXXX
            return false;
        end
        
        -- Much safer if we wait for another ready to tell client he is finished
        if (trans.file.eof()) then
            triggerClientEvent(client, "onClientDownloadComplete", root, id);
            
            pData.downloads[tostring(id)] = nil;
            trans.file.destroy();
            return true;
        end
    
        -- Send the client more data
        triggerClientEvent(client, "onClientDownloadData", root, id, trans.file.read(transactionPacketBytes));
    end
);

addEvent("onDownloadAbort", true);
addEventHandler("onDownloadAbort", root, function(id)
        local pData = playerData[client];
		local trans = pData.downloads[tostring(id)];
        
        if not (trans) then
            outputDebugString("Internal error: Unknown transaction", client);   -- :( somebody screws around with us
            return false;
        end
		
		-- Close the file
		trans.file.destroy();
        
        -- We disable the transaction simply
        pData.downloads[tostring(id)] = nil;
    end
);

addEvent("onClientRequestScriptLock", true);
addEventHandler("onClientRequestScriptLock", root, function(resource, filename)
        local pData = playerData[client];
        local res = getResourceFromNameEx(resource);
        
        if not (res) then return false; end;
		
		if not (pData.hasAccessTo("editor", "scriptLock")) then return false; end;
        
        -- Access check
        if not (pData.hasAccessTo("resources", resource)) then
            return false;
        end
		
		local script = res.getScriptFromSource(filename);
		
		if not (script) then
			kickPlayer(client, "Failed to find scriptData. Please contact the server administrator.");
			return false;
		end
		
		return pData.linkScript(res, script);
    end
);

addEvent("onClientFreeScriptLock", true);
addEventHandler("onClientFreeScriptLock", root, function(resource, src)
        local pData = playerData[client];
        
		if not (resource) then
			pData.clearLinks();
			return true;
		end
		
		local res = getResourceFromNameEx(resource);
		
		if not (res) then return false; end;
		
		local script = res.getScriptFromSource(src);
		
		if not (script) then
			kickPlayer(client, "Failed to find scriptData. Please contact the server administrator.");
			return false;
		end
		
		if not (script.lockClient == client) then
			kickPlayer(client, "Failed to unlink script");
			return false;
		end
		
		return script.unlink();
    end
);

local function createUpload(client, id, res, filename)
	local pData = playerData[client];
	local trans = createClass({
		resource = res,
		filename = filename,
		data = ""
	});
	
	function trans.cbAbort()
		return true;
	end
	
	function trans.cbComplete()
		return true;
	end
	
	function trans.cbData(data)
		return true;
	end
	
	function trans.abort()
		triggerClientEvent(client, "onClientUploadAbort", root, id);
		
		destroy();
		return true;
	end
	
	function trans.destroy()
		data = nil;
	
		pData.uploads[tostring(id)] = nil;
	end
	
	triggerClientEvent(client, "onClientUploadReady", root, id);
	
	pData.uploads[tostring(id)] = trans;
	return trans;
end

addEvent("onUploadRequest", true);
addEventHandler("onUploadRequest", root, function(id, resource, filename)
        local pData = playerData[client];
        local res = getResourceFromNameEx(resource);
        
        if not (res) then return false; end;
        
        -- Transaction overlap?
        if (pData.uploads[tostring(id)]) then
            triggerClientEvent(client, "onClientUploadAbort", root, id);
            return false;
        end
        
        -- Access check
        if not (pData.hasAccessTo("resources", resource)) then
            outputChatBox("Access denied to resource '" .. res.name .. "'", client);
            return false;
        end
        
        -- Check what type this request is
        local script = res.getScriptFromSource(filename);
		
		if (script) then
			local client = client;
		
			if not (script.lockClient == client) then
				kickPlayer(client, "Tried to update a locked script.");
				return false;
			end
		
			local trans = createUpload(client, id, res, filename);
			
			function trans.cbAbort()
				outputDebugString("Client '" .. getPlayerName(client) .. "' aborted a transaction", 2);
				return true;
			end
			
			function trans.cbComplete()
				triggerClientEvent("onScriptUpdate", client, resource, filename);
				return true;
			end
			
			return true;
        end
        
        local file = res.getFileFromSource(filename);
		
		if not (file) then
			-- Kicking is too harsh, let us abort the upload request
			triggerClientEvent(client, "onClientUploadAbort", root, id);
			return false;
		end
		
		-- We have to lock files too for safety
		if (file.lockClient) and not (file.lockClient == client) then
			triggerClientEvent(client, "onClientUploadAbort", root, id);
			return true;
		end
		
		file.lockClient = client;
		
		local trans = createUpload(client, id, res, filename);
		
		function trans.cbAbort()
			outputDebugString("Client aborted a transaction");
			return true;
		end
		
		function trans.destroy()
			file.lockClient = false;
			return true;
		end
    end
);

addEvent("onUploadData", true);
addEventHandler("onUploadData", root, function(id, data)
        local trans = playerData[client].uploads[tostring(id)];
        
        if not (trans) then return false; end;
        
		trans.cbData(data);
        
        trans.data = trans.data .. data;
        triggerClientEvent(client, "onClientUploadReady", root, id);
    end
);

addEvent("onUploadAbort", true);
addEventHandler("onUploadAbort", root, function(id)
		local trans = playerData[client].uploads[tostring(id)];
		
		if not (trans) then return false; end;
		
		trans.cbAbort();
		
		trans.destroy();
	end
);

addEvent("onUploadComplete", true);
addEventHandler("onUploadComplete", root, function(id)
        local trans = playerData[client].uploads[tostring(id)];
		
		if not (trans) then return false; end;
		
		trans.cbComplete();
		
		local file = trans.resource.createFile(trans.filename);
		file.write(trans.data);
		file.destroy();
		
		trans.destroy();
    end
);

addEvent("onClientRequestControlPanelSession", true);
addEventHandler("onClientRequestControlPanelSession", root, function(password)
		local pData = playerData[client];
		local session;
		local m,n;
        
        if not (password) then
            kickPlayer(client, "smart asses not welcome here.");
            return false;
        end
        
        if not (pData.hasAccessTo("controlPanel", "access")) then
            outputChatBox("Access denied to control panel.", client);
            return false;
        end
		
        -- Access check.
		if (pData.account.controlPanel.requirePassword) then
            local reqPassword = controlPanel.attr.password;
            
            if not (reqPassword) or not (password == reqPassword) then
                triggerClientEvent(client, "onControlPanelWrongPassword", client);
                return false;
            end
		end
		
		session = {
			start = getTickCount()
		};
		
		controlSessions[client] = session;
		
		-- Send the notification
		triggerClientEvent("onControlPanelAccess", client);
		
		-- Now update him on the server data
		local serverData = {
			defaultAccount = false,
			accounts = {}
		};
		
		for m,n in pairs(access.children) do
			if (n.name == "account") then
				local account = {
					rights = {}
				};
				
				local j,k;
				
				for j,k in ipairs(n.children) do
					if (k.name == "right") then
						table.insert(account.rights, {
							object = k.attr.object,
							allow = k.attr.allow == "true"
						});
					end
				end
				
				table.insert(serverData.accounts, account);
			elseif (n.name == "default") then
				local account = {
					rights = {}
				};
				
				local j,k;
				
				for j,k in ipairs(n.children) do
					if (k.name == "right") then
						table.insert(account.rights, {
							object = k.attr.object,
							allow = k.attr.allow == "true"
						});
					end
				end
				
				serverData.defaultAccount = account;
			end
		end
		
		triggerClientEvent(client, "onControlPanelUpdate", root, serverData);
	end
);

addEvent("onClientControlPanelTerminate", true);
addEventHandler("onClientControlPanelTerminate", root, function()
		local session = controlSessions[client];
		
		if not (session) then return true; end;
		
		controlSessions[client] = nil;
		
		triggerClientEvent("onControlPanelTerminate", client);
	end
);

local function allowAuthorResourceAccess(client, resource)
    if not (general.attr.allowAuthorResourceAccess == "true") then return false; end;
    
    local playerSerial = getPlayerSerial(client);
    
    if (playerSerial) then
        if (playerSerial == resource.authorserial) then
            return true;
        end
    end
    
    return false;
end

addEvent("onClientAddScript", true);
addEventHandler("onClientAddScript", root, function(resource, filename, scripttype)
		local pData = playerData[client];
        local res = getResourceFromNameEx(resource);
        
        if not (scripttype == "client") and not (scripttype == "server") and not (scripttype == "shared") then
            return false;
        end
		
		if not (res) then return false; end;
            
		if not (allowAuthorResourceAccess(client, res)) then
            if not (pData.hasAccessTo("editor", "addScript")) then
                outputChatBox("No permission to add scripts.", client);
                return false;
            end
        
            if not (pData.hasAccessTo("resources", resource)) then
                outputChatBox("Access denied to resource '" .. n.name .. "'", client);
                return false;
            end
		end
		
		-- no hax plz
		if (filename == "meta.xml") then
			return false;
		end
		
		if not (res.existsFile(filename)) then
			local pScript = res.createFile(filename);
			
			if not (pScript) then
				outputChatBox("Failed to create script", client);
				return false;
			end
			
			pScript.destroy();
		end
		
		if not (res.addScript(filename, scripttype)) then
			outputChatBox("Failed to add script", client);
			return false;
		end
		
		local content;
		local metaPath = ":" .. resource .. "/meta.xml";
		
		pMeta = xmlLoadFile(metaPath);
		
		if (pMeta) then
			content = xmlGetNode(pMeta);
		
			xmlUnloadFile(pMeta);
		else
			content = xmlCreateNodeEx("meta");
		end
		
		-- Hack to force creation of meta.xml
		fileClose(fileCreate(metaPath));
		
		-- Make sure we have a copy on local filesystem
		pMeta = xmlCreateFile(metaPath, "meta");
		
		-- We emulate the shared script association
        local pScript = xmlCreateChildEx(content, "script");
        pScript.attr.src = filename;
        pScript.attr.type = scripttype;
		
		xmlSetNode(pMeta, content);
		
		xmlSaveFile(pMeta);
		xmlUnloadFile(pMeta);
		
		triggerClientEvent("onResourceAddScript", root, resource, filename, scripttype, "");
    end
);

addEvent("onClientRemoveScript", true);
addEventHandler("onClientRemoveScript", root, function(resource, filename)
		local pData = playerData[client];
        local m,n;
        local res = getResourceFromNameEx(resource);
		
		if not (res) then return false; end
            
		if not (allowAuthorResourceAccess(client, res)) then
            if not (pData.hasAccessTo("editor", "removeScript")) then
                outputChatBox("No permission to remove scripts", client);
                return false;
            end
        
            if not (pData.hasAccessTo("resources", resource)) then
                outputChatBox("Access denied to resource '" .. resource .. "'", client);
                return false;
            end
		end
		
		-- File exists already?
		local script = res.getScriptFromSource(filename);
		
		if not (script) then
			outputChatBox("Script '" .. filename .. "' does not exist in resource '" .. resource .. "'", client);
			return false;
		end
		
		if (script.lockClient) then
			if not (script.lockClient == client) then
				outputChatBox("You have to own the lock to '" .. filename .. "'!", client);
				return false;
			end
			
			-- Free scriptLock,
			script.unlink();
		end
		
		local path = ":" .. resource .. "/" .. filename;
		
		if not (fileExists(path)) then
			outputChatBox("Internal Error: Couldn't find matching file ('" .. filename .. "')", client);
			return false;
		end
		
		fileDelete(path);
		
		-- Remove it
		res.removeScriptFromSource(filename);
		
		local metaPath = ":" .. resource .. "/meta.xml";
		
		-- Remove it from XML
		local pMeta = xmlLoadFile(metaPath);
		
		if not (pMeta) then
			return false;
		end 
		
		local content = xmlGetNode(pMeta);
		xmlUnloadFile(pMeta);
		
		-- Hack to force creation of meta.xml
		fileClose(fileCreate(metaPath));
		
		-- Make sure we have a copy on local filesystem
		pMeta = xmlCreateFile(metaPath, "meta");
		
		-- Fish out the node and kill it
		for m,n in ipairs(content.children) do
			if (n.name == "script") and (n.attr.src == filename) then
				table.remove(content.children, m);
				break;
			end
		end
		
		xmlSetNode(pMeta, content);
		
		xmlSaveFile(pMeta);
		xmlUnloadFile(pMeta);
		
		triggerClientEvent("onResourceRemoveScript", root, resource, filename);
    end
);

addEvent("onClientRequestResourceCreation", true);
addEventHandler("onClientRequestResourceCreation", root, function(name, restype, description)
		local pData = playerData[client];

        if not (pData.hasAccessTo("editor", "createResource")) then
            outputChatBox("You do not have the permission to create resources", client);
            return false;
        end
        
        if (#name == 0) or (#restype == 0) then
            return false;
        end
		
        -- Check if resource already exists
        local pResource = getResourceFromName(name);
		
        if (pResource) then
            local pMeta = xmlLoadFile(":"..getResourceName(pResource).."/meta.xml");
			
            if not (pMeta) then
                -- Resource bugged
                return false;
            end
        else
            pResource = createResource(name);
			
            if not (pResource) then
                outputChatBox("Failed to create resource '"..name.."'", client);
                return false;
            end
        end
		
        local pMeta = xmlCreateFile(":" .. name .. "/meta.xml", "meta");
        local pInfo = xmlCreateChild(pMeta, "info");
		
        xmlNodeSetAttribute(pInfo, "author", getPlayerName(client));
        xmlNodeSetAttribute(pInfo, "authorserial", getPlayerSerial(client));
        xmlNodeSetAttribute(pInfo, "description", description);
        xmlNodeSetAttribute(pInfo, "type", restype);
        xmlNodeSetAttribute(pInfo, "version", "1.0");
		
        xmlSaveFile(pMeta);
        xmlUnloadFile(pMeta);
        
        -- Load it
        local data = loadResource(pResource);
        data.update();
		
		-- Update access rights
		local m,n;
		
		for m,n in pairs(playerData) do
			updateClientAccess(m);
		end
    end
);

addEvent("onClientRequestResourceRemoval", true);
addEventHandler("onClientRequestResourceRemoval", root, function(resname)
		local pData = playerData[client];
		local res = getResourceFromNameEx(resname);
		
		if not (res) then
			return false;
		end
		
		-- You can only remove your resources, or if you have admin
		if not (allowAuthorResourceAccess(client, res)) and not (pData.hasAccessTo("editor", "removeResource")) then
			outputChatBox("You do not have the permission to remove resource '"..resname.."'", client);
			return false;
		end
        
        outputDebugString( "user " .. getPlayerName(client) .. " deleted resource " .. res.name );
		
        -- Kill the resource from server presence.
        deleteResource(res.name);
        
        -- Remove the resource from clientside presence.
        triggerClientEvent("onResourceRemove", root, resname);
        
        -- Remove all traces from the registration from our server.
		unlinkResourceFromRegistry(res);
    end
);

addEvent("onClientRequestStartResource", true);
addEventHandler("onClientRequestStartResource", root, function(resource)
        local pData = playerData[client];
		local res = getResourceFromNameEx(resource);
        
        if not (res) then
			return false;
		end

        if not (allowAuthorResourceAccess(client, res)) then
            if not (hasObjectPermissionTo(client, "command.start")) then
                outputChatBox("Invalid access (/start)", client);
                return false;
            end

            if not (pData.hasAccessTo("resources", resource)) then
                outputChatBox("Access denied to resource '" .. resource .. "'", client);
                return false;
            end
        end
		
		if (getResourceState(res.resource) == "running") then
			restartResource(res.resource);
		else
			startResource(res.resource);
		end
    end
);

addEvent("onClientRequestStopResource", true);
addEventHandler("onClientRequestStopResource", root, function(resource)
        local pData = playerData[client];
		local res = getResourceFromNameEx(resource);
		
        if not (res) then
			return false;
		end
        
        if not (allowAuthorResourceAccess(client, res)) then
            if not (hasObjectPermissionTo(client, "command.stop")) then
                outputChatBox("Invalid access (/stop)", client);
                return false;
            end

            if not (pData.hasAccessTo("resources", resource)) then
                outputChatBox("Access denied to resource '" .. resource .. "'", client);
                return false;
            end
        end
		
        stopResource(res.resource);
    end
);

addEvent("onClientRequestElementEdit", true);
addEventHandler("onClientRequestElementEdit", root, function()
        -- Check whether the element is being edited already
		local pData = playerData[client];
        local bMap = false;
        local resource;
        
        for m,n in pairs(playerData) do
            if (n.isEditing) and (n.editElement==source) then
                outputChatBox("Element is being edited already!", client);
                return false;
            end
        end
        
        if (getElementType(source) == "player") then
            if not (hasObjectPermissionTo(client, "general.ModifyOtherObjects")) then
                outputChatBox("You do not have the permission to edit players", client);
                return false;
            end
			
            resource = getResourceFromNameEx("resedit");
        else
			local children;
			local m,n;
		
			resource = getElementResourceEx(source);
			
			if not (resource) then
				outputDebugString("Failed to find element resource. Please restart resedit!", 2);
				return false;
			end
		
			-- Check all map roots
			for m,n in ipairs(resource.maps) do
				local map = getResourceMapRootElement(resource.resource, n.src);
				
				if (map) and (isElementChildOf(source, map)) then
					bMap = true;
					break;
				end
            end
			
            if not (resource) then
                outputChatBox("Invalid element selected", client);
                return false;
            end
			
            if not (checkResourceAccess(client, resource.resource)) then
                outputChatBox("Access denied to resource '" .. resource.name .. "'", client);
                return false;
            end
        end
        
        if (pData.isEditing) then
            outputChatBox("Editing already!", client);
            return false;
        end
		
        -- Set him as editor
        pData.isEditing = true;
        pData.editElement = source;
        triggerClientEvent("onElementEditStart", source, client, resource.name, bMap);
    end
);

addEvent("onClientRequestEditElementPosition", true);
addEventHandler("onClientRequestEditElementPosition", root, function(posX, posY, posZ)
        local pData = playerData[client];
        
        if not (pData.isEditing) or not (pData.editElement == source) then
            kickPlayer(client, "Invalid Element");
            return false;
        end
        
        if not (type(posX) == "number") or not (type(posY) == "number") or not (type(posZ) == "number") then
            return false;
        end
		
        setElementPosition(source, posX, posY, posZ);
        triggerClientEvent("onElementPositionUpdate", source, posX, posY, posZ);
    end
);

addEvent("onClientRequestEditElementRotation", true);
addEventHandler("onClientRequestEditElementRotation", root, function(rotX, rotY, rotZ)
        local pData = playerData[client];
        
        if not (pData.isEditing) or not (pData.editElement==source) then
            outputChatBox("Wrong element", client);
            return false;
        end
        
        if not (type(rotX) == "number") or not (type(rotY) == "number") or not (type(rotZ) == "number") then
            return false;
        end
		
        setElementRotation(source, rotX, rotY, rotZ);
        triggerClientEvent("onElementRotationUpdate", source, rotX, rotY, rotZ);
    end
);

addEvent("onElementRepair", true);
addEventHandler("onElementRepair", root, function()
        local pData = playerData[client];
        
        if not (pData.isEditing) or not (pData.editElement==source) then
            kickPlayer(client, "Hacking attempt");
            return false;
        end
        
        if (getElementType(source) == "vehicle") then
            fixVehicle(source);
        end
    end
);

addEvent("onClientRequestElementDestroy", true);
addEventHandler("onClientRequestElementDestroy", root, function()
        local pData = playerData[client];
        
        if not (pData.isEditing) or not (pData.editElement == source) then
            kickPlayer(client, "Hacking attempt");
            return false;
        end
        
        -- Detaching from the player interface is handled through destroy event
        if (getElementType(source)=="player") then
            killPed(source);
        else
            destroyElement(source);
        end
    end
);

addEvent("onClientRequestEditEnd", true);
addEventHandler("onClientRequestEditEnd", root, function()
        local pData = playerData[client];
        
        if not (pData.isEditing) then return false; end;
		
        if not (pData.editElement == source) then
            kickPlayer(client, "Hacking attempt");
            return false;
        end
        
        -- End the session
        pData.isEditing = false;
        triggerClientEvent("onElementEditEnd", pData.editElement, client);
    end
);

addEventHandler("onElementDestroy", root, function()
        local m,n;
        
        for m,n in pairs(playerData) do
            if (n.isEditing) and (n.editElement == source) then
                outputDebugString("Quit edit session onDestroy("..getPlayerName(m)..");");
				
                n.isEditing = false;
				
                triggerClientEvent("onElementEditEnd", source, m);
                break;
            end
        end
    end
);

addEventHandler("onPlayerQuit", root, function()
        local pData = playerData[source];
        local m,n;
        
        if (pData.isEditing) then
            triggerClientEvent("onElementEditEnd", pData.editElement, source);
        end
		
        playerData[source] = nil;
        
        -- Make sure all locks are removed
        for m,n in pairs(pData.uploads) do
			n.destroy();
        end
        
        pData.clearLinks();
    end
);

addEvent("onResourceSet", true);
addEventHandler("onResourceSet", root, function(resource, cmd, ...)
        local args = {...};
		local res = getResourceFromNameEx(resource);
		
        if not (allowAuthorResourceAccess(client, res)) then
            if not (checkSpecialResourceAccess(client, res.resource)) then
                outputChatBox("Invalid access (" .. cmd .. ")", client);
                return false;
            end
        end
		
		if (cmd == "type") then
			res.type = args[1];
            
            setResourceInfo(res.resource, "type", res.type);
		elseif (cmd == "description") then
			res.description = args[1];
            
            setResourceInfo(res.resource, "description", res.description);
		end
		
		res.update();
    end
);

addCommandHandler("resedit_accupd", function(sender)
        if not (isClientAdmin(sender)) then
            return false;
        end

        outputDebugString("reloading resedit access config...");

        reloadAccessConfig();
    end
);

addCommandHandler("resedit_cfgupd", function(sender)
        if not (isClientAdmin(sender)) then
            return false;
        end
        
        outputDebugString("reloading resedit main config...");
        
        xmlUnloadFile(pConfig);
        
        pConfig = xmlLoadFile("config.xml");
        
        loadConfig();
    end
);

addEventHandler("onResourceStop", resourceRoot, function()
		-- Save the configurations
		xmlSetNode(pConfig, config);
		xmlSetNode(pAccessConfig, access);
		
		xmlSaveFile(pConfig);
		xmlSaveFile(pAccessConfig);
		
		xmlUnloadFile(pConfig);
		xmlUnloadFile(pAccessConfig);
	end
);
    
addEventHandler("onClientResourceSystemReady", root, function()
        updateClientAccess(client);
    end
);