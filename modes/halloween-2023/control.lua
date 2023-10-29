local CombatLighting = require("modes.halloween-2023.scripts.combat-lighting")
local Maze = require("modes.halloween-2023.scripts.maze")

if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end





local function OnLoad()
    CombatLighting.OnLoad()
end

local function OnStartup()
    OnLoad()

    Maze.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
