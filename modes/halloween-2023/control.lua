local CombatLighting = require("modes.halloween-2023.scripts.combat-lighting")

if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end





local function OnLoad()
    CombatLighting.OnLoad()
end

local function OnStartup()
    OnLoad()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
