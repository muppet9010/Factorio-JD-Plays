if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end

---@class Class-halloween_2023-Maze
local Maze = {}

Maze.OnStartup = function()
    Maze.ResetLandfillRecipeAvailability()
end

Maze.ResetLandfillRecipeAvailability = function()
    -- Reset landfill to be researched if it was hidden for the force from making the map on an older mod version.
    for _, force in pairs(game.forces) do
        force.technologies["landfill"].enabled = true
    end
end

return Maze
