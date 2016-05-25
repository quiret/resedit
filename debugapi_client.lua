-- Debug API exports for resedit.
-- Use those if you want a quick interface for error detection and server maintenance.

function openScript(resource, scriptPath, lineNumberOpt)
    -- Before attempting anything volatile, see if a resource with that script even exists.
    if not (doesResourceHaveScript(resource, scriptPath)) then
        return false, "resource or script unavailable";
    end

    -- First try to actually show the editor GUI.
    local couldDisplayEditor, errMsg = showResourceGUI(true);
    
    if not (couldDisplayEditor) then
        local debugMsg = "failed to display editor";
        
        if (errMsg) then
            debugMsg = debugMsg .. ": " .. errMsg;
        end
    
        return false, debugMsg;
    end

    -- Now just open the script.
    local mainGUI = mainGUI;
    
    local openSuccess, errMsg = mainGUI.openScriptByPath(resource, scriptPath, lineNumberOpt);
    
    if not (openSuccess) then
        local debugMsg = "failed to open script";
        
        if (errMsg) then
            debugMsg = debugMsg .. ": " .. errMsg;
        end
        
        return false, debugMsg;
    end
    
    return true;
end