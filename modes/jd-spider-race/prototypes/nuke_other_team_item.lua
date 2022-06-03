if settings.startup["jdplays_mode"].value ~= "jd_spider_race" then
    return
end

data:extend(
    {
        {
            type = "item-with-label",
            name = "jd_plays-jd_spider_race-nuke_other_team",
            flags = {"hidden"},
            icon = "__base__/graphics/icons/atomic-bomb.png",
            icon_size = 64,
            icon_mipmaps = 4,
            stack_size = 1
        }
    }
)
