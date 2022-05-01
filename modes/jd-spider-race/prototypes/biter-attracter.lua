volume = 1 -- Step up from behemoth worm.
data:extend(
    {
        {
            -- Dud turret, just used to attract biters when its damaged via script.
            type = "turret",
            name = "jd_plays-jd_spider_race-biter_attracter_turret",
            icon = "__base__/graphics/icons/behemoth-worm.png",
            icon_size = 64,
            icon_mipmaps = 4,
            call_for_help_radius = 200, -- How far away biters from the spiders X pos will be called in to attack the player from. Theres a limit (?) or distance (300~) of how many biters will commit to make the journey, so no point triggering biters momentarily beyond this limit.
            attack_parameters = {type = "beam", range = 0, cooldown = 9999, ammo_type = {category = "artillery-shell"}},
            folded_animation = {direction_count = 1, filename = "__core__/graphics/empty.png", size = 1},
            flags = {"not-in-kill-statistics"}
        },
        {
            type = "sound",
            name = "jd_plays-jd_spider_race-spidertron_boss_attacked",
            variations = {
                {
                    filename = "__base__/sound/creatures/worm-roar-big-1.ogg",
                    volume = volume
                },
                {
                    filename = "__base__/sound/creatures/worm-roar-big-2.ogg",
                    volume = volume
                },
                {
                    filename = "__base__/sound/creatures/worm-roar-big-3.ogg",
                    volume = volume
                },
                {
                    filename = "__base__/sound/creatures/worm-roar-big-4.ogg",
                    volume = volume
                },
                {
                    filename = "__base__/sound/creatures/worm-roar-big-5.ogg",
                    volume = volume
                },
                {
                    filename = "__base__/sound/creatures/worm-roar-alt-big-1.ogg",
                    volume = volume
                },
                {
                    filename = "__base__/sound/creatures/worm-roar-alt-big-2.ogg",
                    volume = volume
                },
                {
                    filename = "__base__/sound/creatures/worm-roar-alt-big-3.ogg",
                    volume = volume
                },
                {
                    filename = "__base__/sound/creatures/worm-roar-alt-big-4.ogg",
                    volume = volume
                },
                {
                    filename = "__base__/sound/creatures/worm-roar-alt-big-5.ogg",
                    volume = volume
                }
            },
            audible_distance_modifier = 3 -- Very high so it travels well, same as atomic bomb.
        }
    }
)
