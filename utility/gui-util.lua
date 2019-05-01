local GUI = {}
local Constants = require("constants")

local function GenerateName(arguments)
    return Constants.ModName .. "-" .. arguments.name .. "-" .. arguments.type
end

GUI.AddElement = function(arguments, store)
    arguments.name = GenerateName(arguments)
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
    return global.GUIUtilPlayerElementReferenceStorage[playernIndex][GenerateName({name = name, type = type})]
end

GUI.DestroyElementInPlayersReferenceStorage = function(playerIndex, name, type)
    if global.GUIUtilPlayerElementReferenceStorage[playerIndex] ~= nil and global.GUIUtilPlayerElementReferenceStorage[playerIndex][GenerateName({name = name, type = type})] ~= nil then
        if global.GUIUtilPlayerElementReferenceStorage[playerIndex][GenerateName({name = name, type = type})].valid then
            global.GUIUtilPlayerElementReferenceStorage[playerIndex][GenerateName({name = name, type = type})].destroy()
        end
        global.GUIUtilPlayerElementReferenceStorage[playerIndex][GenerateName({name = name, type = type})] = nil
    end
end

return GUI
