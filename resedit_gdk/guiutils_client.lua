-- Utilities for loading resources.

-- Define this variable so it points to the location you install this GDK.
-- It starts from the resource root folder.
-- If you place this GDK into the resource root, no change required.
local gdk_path_offset = "resedit_gdk/";

local function gdkGetPath(path)
    return gdk_path_offset .. path;
end
_G.gdkGetPath = gdkGetPath;

-- Prevent warnings of loading by handling resource requests specially.
local dxCreateTexture = dxCreateTexture;
local fileExists = fileExists;

function gdkLoadTexture(path)
    local gdk_path = gdkGetPath(path);
    
    if not (gdk_path) then return false; end;
    if not (fileExists(gdk_path)) then return false; end;
    
    -- We are allowed to cache textures here.
    return dxCreateTexture(gdk_path);
end

function gdkCreateShader(path)
    local gdk_path = gdkGetPath(path);
    
    if not (gdk_path) then return false; end;
    if not (fileExists(gdk_path)) then return false; end;
    
    -- The runtime has requested a shader it will terminate itself.
    return dxCreateShader(gdk_path);
end