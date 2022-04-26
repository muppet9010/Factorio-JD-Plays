-- Makes Spidertron Boss immune to all nukes.

-- Add a new target type that will be used to to distinguish everything from spidertron bosses.
data:extend(
    {
        {
            type = "trigger-target-type",
            name = "jd_plays-jd_spider_race-non_boss_spider"
        }
    }
)

-- For every real prototype other than spidertron boss add the new target mask.
for _, prototypeTypeEntries in pairs(data.raw) do
    for _, entityPrototype in pairs(prototypeTypeEntries) do
        -- There's no mandatory attribute we can check, but any entity type we care about will have a non default max_health set.
        if entityPrototype.max_health ~= nil then
            if entityPrototype.name ~= "jd_plays-jd_spider_race-spidertron_boss" then
                entityPrototype.trigger_target_mask = entityPrototype.trigger_target_mask or {}
                table.insert(entityPrototype.trigger_target_mask, "jd_plays-jd_spider_race-non_boss_spider")
            end
        end
    end
end

-- Change the nuke weapon's damage trigger to only affect entities with the non_boss_spider target mask.
data.raw["projectile"]["atomic-bomb-wave"].action[1].trigger_target_mask = {"jd_plays-jd_spider_race-non_boss_spider"}
data.raw["projectile"]["atomic-bomb-ground-zero-projectile"].action[1].trigger_target_mask = {"jd_plays-jd_spider_race-non_boss_spider"}
