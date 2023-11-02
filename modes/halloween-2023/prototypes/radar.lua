if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end

local radarEntityPrototype = data.raw["radar"]["radar"]
radarEntityPrototype.max_distance_of_sector_revealed = 0
radarEntityPrototype.max_distance_of_nearby_sector_revealed = 2 -- This gives a vision area of 2 chunks beyond the chunk the radar is in. This matches a players map chart/reveal range.
radarEntityPrototype.rotation_speed = radarEntityPrototype.rotation_speed / 6
radarEntityPrototype.localised_name = { "entity-name.jd_plays-halloween_2023-radar" }
radarEntityPrototype.localised_description = { "entity-description.jd_plays-halloween_2023-radar" }
radarEntityPrototype.energy_per_sector = "999YJ" -- Make the scan bar basically never move as it won't ever scan any area.
