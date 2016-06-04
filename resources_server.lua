if not (hasObjectPermissionTo(resource, "general.ModifyOtherObjects")) then
	return false;
end

local resourceData={};
local fsys;
local table = table;
local outputDebugString = outputDebugString;
local strsub = string.sub;

debug.sethook(nil);

-- Specialize for mods
if (createFilesystemInterface) then
	fsys = createFilesystemInterface();
	
	if (fsys) then
		outputDebugString("GREEN Filesystem found! EXmode active.");
	end
end

-- Internal API
local createFile;
local openFile;
local fexists;

if (fsys) then
	local resRoot = fsys.createTranslator("mods/deathmatch/resources/");
	local resource = resource;
	
	local function ioResPath(path)
		if (string.byte(path) == 58) then
			return strsub(path, 2, #path);
		end
		
		return getResourceName( resource ) .. "/" .. path;
	end
	
	local function ioclass(ioptr)
		local file = createClass();
		
		function file.read(len)
			return ioptr.read(len);
		end
		
		function file.readShort()
			return ioptr.readShort();
		end
		
		function file.readInt()
			return ioptr.readInt();
		end
		
		function file.readFloat()
			return ioptr.readFloat();
		end
		
		function file.eof()
			return ioptr.eof();
		end
		
		function file.size()
			return ioptr.size();
		end
		
		function file.tell()
			return ioptr.tell()
		end
		
		function file.seek(pos)
			return ioptr.seek(pos, "set");
		end
		
		function file.write(buf)
			return ioptr.write(buf);
		end
		
		function file.writeShort(num)
			return ioptr.writeShort(num);
		end
		
		function file.writeInt(num)
			return ioptr.writeInt(num);
		end
		
		function file.writeFloat(num)
			return ioptr.writeFloat(num);
		end
		
		function file.destroy()
			ioptr.destroy();
		end
		
		return file;
	end
	
	function openFile(path)
		path = ioResPath(path);
		
		if not (path) then return false; end;
		
		local ioptr = resRoot.open(path, "rb+");
		
		if not (ioptr) then return false; end;
	
		return ioclass(ioptr);
	end
	
	function createFile(path)
		path = ioResPath(path);
		
		if not (path) then return false; end;
		
		local ioptr = resRoot.open(path, "wb+");
		
		if not (ioptr) then return false; end;
		
		return ioclass(ioptr);
	end
	
	function fexists(path)
		path = ioResPath(path);
		
		if not (path) then return false; end;
		
		return resRoot.exists(path);
	end
else
	local fileOpen = fileOpen;
	local fileCreate = fileCreate;

	local function ioclass(ioptr)
		local file = createClass();
		
		function file.read(len)
			return fileRead(ioptr, len);
		end
		
		function file.readShort()
			return littleendian.fileReadShort(ioptr);
		end
		
		function file.readInt()
			return littleendian.fileReadInt(ioptr);
		end
		
		function file.readFloat()
			return 0;
		end
		
		function file.eof()
			return fileIsEOF(ioptr);
		end
		
		function file.size()
			return fileGetSize(ioptr);
		end
		
		function file.tell()
			return fileGetPos(ioptr);
		end
		
		function file.seek(pos)
			return fileSetPos(ioptr, pos);
		end
		
		function file.write(buf)
			return fileWrite(ioptr, buf);
		end
		
		function file.writeShort(num)
			return littleendian.fileWriteShort(ioptr, num);
		end
		
		function file.writeInt(num)
			return littleendian.fileWriteInt(ioptr, num);
		end
		
		function file.writeFloat(num)
			return writeInt(0);
		end
		
		function file.destroy()
			fileClose(ioptr);
		end
		
		return file;
	end

	function openFile(path)
		local ioptr = fileOpen(path);
		
		if not (ioptr) then return false; end;
		
		return ioclass(ioptr);
	end
	
	function createFile(path)
		local ioptr = fileCreate(path);
		
		if not (ioptr) then return false; end;
		
		return ioclass(ioptr);
	end
	
	fexists = fileExists;
end

function loadResource(pResource)
    local resource = createClass({
		resource = pResource,
		name = getResourceName(pResource),
		type = "",
		author = "",
		authorserial = "",
		description = "",
		realname = "",
		
		files = {},
		scripts = {},
		maps = {}
	});
	
	function resource.getName()
		return name;
	end
	
	function resource.addFile(src, type)
		local pFile = getFileFromSource(src);
		local path, isFile;
		
		if not (type) then
			type = "client";
		end
	
		if (pFile) then
			return false;
		end
		
		path, isFile = fileParsePath(src);
		
		if not (path) or not (isFile) then return false; end;
		
		if not (fileExists(":" .. name .. "/" .. path)) then return false; end;
		
		pFile = {
			src = path,
			type = type
		};
		
		table.insert(files, pFile);
		
		return pFile, false;
	end
	
	function resource.addScript(src, type)
		local script = getScriptFromSource(src);
		local path, isFile;
		
		if not (type) then return false; end;
		
		if (script) then
            return false;
		end
		
		path, isFile = fileParsePath(src);
		
		if not (path) or not (isFile) then return false; end;
		
		if not (fexists(":" .. name .. "/" .. path)) then return false; end;
		
		script = {
			src = path,
			type = type,
			
			lockClient = false,
			session = false
		};
		
		function script.link(client, session)
            if (script.lockClient) then return false; end;
        
			script.lockClient = client;
			script.session = session;
            return true;
		end
		
		function script.unlink()
            if (script.lockClient) then
                script.lockClient = false;
                script.session.destroy();
            end
		end
		
		table.insert(scripts, script);
		
		return script, false;
	end
	
	function resource.addMap(src)
		local map, existed = addFile(src, "server");
		
		if not (map) then return false; end;
		
		if (existed) then
			map = getMapFromSource(src);
			
			if (map) then return map; end;
		
			emoveFileFromSource(src);
			
			map = addFile(src, "server");
		end
	
		table.insert(maps, map);
		return map;
	end
	
	function resource.removeFileFromSource(src)
		local m,n;
		local path, isFile = fileParsePath(src);
		
		if not (path) or not (isFile) then return false; end;
		
		for m,n in ipairs(files) do
			if (n.src == path) then
				table.remove(files, m);
				return true;
			end
		end
		
		return false;
	end
	
	function resource.removeScriptFromSource(src)
		local m,n;
		local path, isFile = fileParsePath(src);
		
		if not (path) or not (isFile) then return false; end;
		
		for m,n in ipairs(scripts) do
			if (n.src == path) then
				table.remove(scripts, m);
				return true;
			end
		end
		
		return false;
	end
	
	function resource.getScriptFromSource(src)
		local m,n;
		local path, isFile = fileParsePath(src);
		
		if not (path) or not (isFile) then return false; end;
		
		for m,n in ipairs(scripts) do
			if (n.src == path) then
				return n;
			end
		end
		
		return false;
	end
	
	function resource.getFileFromSource(src)
		local m,n;
		local path, isFile = fileParsePath(src);
		
		if not (path) or not (isFile) then return false; end;
		
		for m,n in ipairs(files) do
			if (n.src == path) then
				return n;
			end
		end
		
		return false;
	end
	
	function resource.getMapFromSource(src)
		local m,n;
		local path, isFile = fileParsePath(src);
		
		if not (path) or not (isFile) then return false; end;
		
		for m,n in ipairs(maps) do
			if (n.src == path) then
				return n;
			end
		end
		
		return false;
	end
	
	function resource.openFile(path)
		return openFile(":" .. name .. "/" .. path);
	end
	
	function resource.createFile(path)
		return createFile(":" .. name .. "/" .. path);
	end
	
	function resource.existsFile(path)
		return fexists(":" .. name .. "/" .. path);
	end
    
	function resource.loadMeta()
		-- Retrive files
		local pMeta = xmlLoadFile(":" .. name .. "/meta.xml");
		
		if not (pMeta) then return false; end;
		
		active = true;
		
		local pNodes = xmlNodeGetChildren(pMeta);
		local m, n;
		
		for m,n in ipairs(pNodes) do
			local pName = xmlNodeGetName(n);
			
			if (pName == "file") then
				local src = xmlNodeGetAttribute(n, "src");
				local path, isFile = fileParsePath(src);
				
				if not (path) or not (isFile) then
					outputDebugString("Illegal file source '" .. src .. " at '" .. name .. "'!", 1);
				else
					local type = xmlNodeGetAttribute(n, "type") or "client";
					local file = getFileFromSource(path);
					
					if (file) and (file.type == type) then
						outputDebugString("Double file entry '" .. path .. "' found in '" .. name .. "'!", 1);
					else
						addFile(path, type);
					end
				end
			elseif (pName == "config") then   -- List them as files
				local src = xmlNodeGetAttribute(n, "src");
				local path, isFile = fileParsePath(src);
				
				if not (path) or not (isFile) then
					outputDebugString("Illegal file source '" .. src .. " at '" .. name .. "'!", 1);
				else
					local type = xmlNodeGetAttribute(n, "type") or "server";
					local file = getFileFromSource(path);
					
					if (file) and (file.type == type) then
						outputDebugString("Double config entry '" .. path .. "' found in '" .. name .. "'!", 1);
					else
						addFile(path, type);
					end
				end
			elseif (pName == "map") then
				local src = xmlNodeGetAttribute(n, "src");
				local path, isFile = fileParsePath(src);
				
				if not (path) or not (isFile) then
					outputDebugString("Illegal file source '" .. src .. " at '" .. name .. "'!", 1);
				else
					local file = getFileFromSource(path);
					
					if (file) then
						outputDebugString("Double map entry '" .. path .. "' found in '" .. name .. "'!", 1);
					else
						-- Maps are also files!
						addMap(path);
					end
				end
			elseif (pName == "script") then
				local src = xmlNodeGetAttribute(n, "src");
				local path, isFile = fileParsePath(src);
				
				if not (path) or not (isFile) then
					outputDebugString("Illegal file source '" .. src .. " at '" .. name .. "'!", 1);
				else
					local type = xmlNodeGetAttribute(n, "type") or "server";
					local file = getScriptFromSource(path);
					
					if (file) and ((file.type == type) or (file.type == "shared")) then
						outputDebugString("Double script entry '" .. path .. "' found in '" .. name .. "'!", 1);
					else
						addScript(path, type);
					end
				end
			elseif (pName == "info") then
				-- Update general info
				local _author = xmlNodeGetAttribute(n, "author");
				
				if (_author) then
					author = _author;
				end
				
				local _realname = xmlNodeGetAttribute(n, "name");
				
				if (_realname) then
					realname = _realname;
				end
				
				local desc = xmlNodeGetAttribute(n, "description");
				
				if (desc) then
					description = desc;
				end
				
				local ttype = xmlNodeGetAttribute(n, "type");
				
				if (ttype) then
					type = ttype;
				end
				
				local serial = xmlNodeGetAttribute(n, "authorserial");
				
				if (serial) then
					authorserial = serial;
				end
			end
		end
		
		xmlUnloadFile(pMeta);
		return true;
	end
	
	if not (resource.loadMeta()) then
		resource.active = false;
		
		table.insert(resourceData, resource);
		
		outputDebugString("Failed to load '" .. resource.getName() .. "'");
		return false;
	end
	
	function resource.update()
		local m,n;
		
		-- We write it into the file
		local xml = xmlLoadFile(":" .. name .. "/meta.xml");
		
		if not (xml) then
			-- Dont bother with bugged resources
			active = false;
			return false;
		end
		
		local children = xmlNodeGetChildren(xml);
		
		for m,n in ipairs(children) do
			local name = xmlNodeGetName(n);
			
			if (name == "info") then
				xmlNodeSetAttribute(n, "author", author);
				xmlNodeSetAttribute(n, "description", description);
				xmlNodeSetAttribute(n, "type", type);
				xmlNodeSetAttribute(n, "name", realname);
			end
		end
		
		xmlSaveFile(xml);
		xmlUnloadFile(xml);
		
		triggerClientEvent("onResourceDataUpdate", root, resource, false);
		return true;
	end
	
    table.insert(resourceData, resource);
    return resource;
end

-- Load up all resources
local m,n;
local bFailed=false;

for m,n in ipairs(getResources()) do
	if not (loadResource(n)) then
		bFailed=true;
	end
end

outputDebugString("Loaded " .. #resourceData .. " resources!");

if (bFailed) then
	outputDebugString("Some resources failed to load.", 2);
end

-- Specialize for mods
if (fsys) then
	--local resRoot = fsys.createTranslator("mods/deathmatch/resources/");
	
	--[[createThread(function()
			local strsub = string.sub;
	
			local function explodeDir()
				local m,n;
				
				for m,n in ipairs(resRoot.getDirs("")) do
					local dir = resRoot.relPath(n);
				
					if (string.byte(dir, 1) == 91) then
						resRoot.chdir(dir);
						explodeDir();
						resRoot.chdir("../");
					else
						name = strsub(dir, 1, #dir - 1);
					end
					
					yield();
				end
			end
	
			while (true) do
				explodeDir();
			
				coroutine.yield();
			end
		end
	).sustime(16);]]
end

function searchResources(wildcard, callback)
	local m,n;
	
	for m,n in ipairs(resourceData) do
		if (globmatch(n.getName(), wildcard)) then
			callback(n);
		end
	end
end

function unlinkResourceFromRegistry(resource)
	local m,n;
	
	for m,n in ipairs(resourceData) do
		if (n == resource) then
			table.remove(resourceData, m);
			return true;
		end
	end
	
	return false;
end

function getResourceFromNameEx(name)
    local m,n;
    
    for m,n in ipairs(resourceData) do
        if (n.name == name) then
            return n;
        end
    end
    
    return false;
end

function getElementResource(element)
	while (true) do
		element = getElementParent(element);
		
		if (element == getRootElement()) then
			return false;
		elseif (getElementType(element) == "resource") then
			local m,n;
			local resources = getResources();
			
			for m,n in ipairs(resources) do
				if (getResourceRootElement(n) == element) then
					return n;
				end
			end
			
			return false;
		end
	end
end

function getElementResourceEx(element)
	local resource = getElementResource(element);
	local m,n;
	
	for m,n in ipairs(resourceData) do
		if (n.name == getResourceName(resource)) then
			return n;
		end
	end
	
	return false;
end

function isElementChildOf(element, parent)
	while (element) do
		element = getElementParent(element);
		
		if (element == parent) then
			return true;
		elseif (element == root) then
			return false;
		end
	end
end

function isClientAdmin(client)
    return hasObjectPermissionTo(client, "general.ModifyOtherObjects");
end

function checkResourceAccess(client, resource)
    -- We could be root admin.
    if (isClientAdmin(client)) then
        return true;
    end

    local pAccount = getPlayerAccount(client);
	
    if not (pAccount) then return false; end;
    
    local groups = aclGroupList();
    local clientGroups = {};
    local resourceGroups = {};
    local m,n;
	
    for m,n in ipairs(groups) do
        local k,j;
        local objects = aclGroupListObjects(n);
        
        for k,j in ipairs(objects) do
            if ("user." .. getAccountName(pAccount) == j) then
                local a,b;
                local acl=aclGroupListACL(n);
                
                for a,b in ipairs(acl) do
                    table.insert(clientGroups, b);
                end
            elseif ("resource." .. getResourceName(resource) == j) then
                local a,b;
                local acl=aclGroupListACL(n);
                
                for a,b in ipairs(acl) do
                    table.insert(resourceGroups, b);
                end
            end
        end
    end
    
    -- Compare groups
    for m,n in ipairs(resourceGroups) do
        local k,j;
        local bFound=false;
        
        for k,j in ipairs(clientGroups) do
            if (j==n) then
                bFound=true;
                break;
            end
        end
        if not (bFound) then
            return false;
        end
    end
    return true;
end

function checkSpecialResourceAccess(client, resource)
    return hasObjectPermissionTo(client, "general.ModifyOtherObjects");
end

function updateClientResourceData(client)
    -- Send them our resourceData
    local m,n;
    
    -- Send silent updates
    for m,n in ipairs(resourceData) do
        triggerClientEvent(client, "onResourceDataUpdate", root, n, true);
    end
	
    return true;
end

addEvent("onClientResourceSystemReady", true);

addEventHandler("onClientResourceSystemReady", root, function()
        updateClientResourceData(client);
    end
);