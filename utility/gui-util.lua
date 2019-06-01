local GUI = {}
local Constants = require("constants")

GUI.GenerateName = function(name, type)
    return Constants.ModName .. "-" .. name .. "-" .. type
end

GUI.AddElement = function(arguments, store)
    arguments.name = GUI.GenerateName(arguments.name, arguments.type)
    local element = arguments.parent.add(arguments)
    if store ~= nil and store == true then
        GUI.AddElementToPlayersReferenceStorage(element.player_index, arguments.name, element)
    end
    return element
end

GUI.CreateAllPlayersElementReferenceStorage = function()
    global.GUIUtilPlayerElementReferenceStorage = global.GUIUtilPlayerElementReferenceStorage or {}
end

GUI.CreatePlayersElementReferenceStorage = function(playerIndex)
    global.GUIUtilPlayerElementReferenceStorage[playerIndex] = global.GUIUtilPlayerElementReferenceStorage[playerIndex] or {}
end

GUI.AddElementToPlayersReferenceStorage = function(playernIndex, fullName, element)
    global.GUIUtilPlayerElementReferenceStorage[playernIndex][fullName] = element
end

GUI.RemovePlayersReferenceStorage = function(playernIndex)
    global.GUIUtilPlayerElementReferenceStorage[playernIndex] = nil
end

GUI.GetElementFromPlayersReferenceStorage = function(playernIndex, name, type)
    return global.GUIUtilPlayerElementReferenceStorage[playernIndex][GUI.GenerateName(name, type)]
end

GUI.DestroyElementInPlayersReferenceStorage = function(playerIndex, name, type)
    local elementName = GUI.GenerateName(name, type)
    if global.GUIUtilPlayerElementReferenceStorage[playerIndex] ~= nil and global.GUIUtilPlayerElementReferenceStorage[playerIndex][elementName] ~= nil then
        if global.GUIUtilPlayerElementReferenceStorage[playerIndex][elementName].valid then
            global.GUIUtilPlayerElementReferenceStorage[playerIndex][elementName].destroy()
        end
        global.GUIUtilPlayerElementReferenceStorage[playerIndex][elementName] = nil
    end
end

return GUI
