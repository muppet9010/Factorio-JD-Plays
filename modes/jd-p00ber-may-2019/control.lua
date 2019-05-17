local Utils = require("utility/utils")

if settings.startup["jdplays_mode"].value ~= "jd-p00ber-may-2019" then
    return
end

local function OnEntityDamaged(event)
    if event.entity.type == "rocket-silo" and event.force.name == "player" then
        event.entity.health = event.entity.health + event.final_damage_amount
    end
end

local function OnRocketLaunched(event)
    local rocket = event.rocket
    if rocket == nil or not rocket.valid then
        return
    end
    for name, count in pairs(rocket.get_inventory(defines.inventory.rocket).get_contents()) do
        if name == "jd-p00ber-may-2019-escape-pod" and count > 0 then
            game.set_game_state {game_finished = true, player_won = true, can_continue = true, victorious_force = rocket.force}
        end
    end
end

local function OnLoad()
    Utils.DisableSiloScript()
end

local function OnStartup()
    OnLoad()
end

script.on_init(OnStartup)
script.on_load(OnLoad)
script.on_configuration_changed(OnStartup)
script.on_event(defines.events.on_rocket_launched, OnRocketLaunched)
script.on_event(defines.events.on_entity_damaged, OnEntityDamaged)
