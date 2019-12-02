local Events = require("utility/events")
local SharedPlayerDamage = {}

SharedPlayerDamage.CreateGlobals = function()
    global.SharedPlayerDamage = global.SharedPlayerDamage or {}
    global.SharedPlayerDamage.enabled = global.SharedPlayerDamage.enabled or true
    global.SharedPlayerDamage.multiplier = global.SharedPlayerDamage.multiplier or 1
end

SharedPlayerDamage.OnLoad = function()
    Events.RegisterHandler(defines.events.on_entity_damaged, "SharedPlayerDamage", SharedPlayerDamage.OnEntityDamagedFilteredCharacter, "type=character")
end

SharedPlayerDamage.OnStartup = function()
    if global.SharedPlayerDamage.scriptForce == nil then
        global.SharedPlayerDamage.scriptForce = game.create_force("sharedPlayerDamage")
    end
end

SharedPlayerDamage.OnEntityDamagedFilteredCharacter = function(event)
    if (not global.SharedPlayerDamage.enabled) or event.force == global.SharedPlayerDamage.scriptForce then
        return
    end
    if event.damage_type ~= nil and (event.damage_type == "snowball") then
        return
    end
    for i, player in pairs(game.connected_players) do
        if not (player.name == event.entity.player.name) then
            if player.character ~= nil then
                local damageToDo = math.floor(event.original_damage_amount * global.SharedPlayerDamage.multiplier)
                player.character.damage(damageToDo, global.SharedPlayerDamage.scriptForce, event.damage_type.name)
            end
        end
    end
end

return SharedPlayerDamage
