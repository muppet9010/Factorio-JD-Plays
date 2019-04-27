local GUI = {}
local Constants = require("constants")

local function GenerateName(arguments)
    return Constants.ModName .. "-" .. arguments.name .. "-" .. arguments.type
end

GUI.AddElement = function(arguments, store)
    arguments.name = GenerateName(arguments)
    local element = arguments.parent.add(arguments)
    if store ~= nil and store then
        GUI.AddElementToPlayersReferenceStorage(element.player_index, arguments.name, element)
    end
    return element
end

GUI.CreatePlayerElementReferenceStorage = function()
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
    return global.GUIUtilPlayerElementReferenceStorage[playernIndex][GenerateName({name = name, type = type})]
end

return GUI
