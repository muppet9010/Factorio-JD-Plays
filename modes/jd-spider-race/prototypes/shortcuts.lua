local Constants = require("constants")

if settings.startup["jdplays_mode"].value ~= "jd_spider_race" then
    return
end

data:extend(
    {
        {
            type = "shortcut",
            name = "jd_plays-jd_spider_race-player_manager-gui_button",
            action = "lua",
            toggleable = true,
            icon = {
                filename = Constants.AssetModName .. "/graphics/jd-spider-race/player_manager-shortcuts/team_member32.png",
                width = 32,
                height = 32
            },
            small_icon = {
                filename = Constants.AssetModName .. "/graphics/jd-spider-race/player_manager-shortcuts/team_member24.png",
                width = 24,
                height = 24
            },
            disabled_small_icon = {
                filename = Constants.AssetModName .. "/graphics/jd-spider-race/player_manager-shortcuts/team_member24-disabled.png",
                width = 24,
                height = 24
            }
        }
    }
)
