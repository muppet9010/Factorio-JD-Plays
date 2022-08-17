--set the background image before any months data, then it can be overridden per month if desired. ONLY SEEN WHEN SIMULATIONS DISABLED.
data.raw["utility-constants"]["default"]["main_menu_background_image_location"] = "__jd_plays__/graphics/background-image.jpg"
require("utility.style-data").GeneratePrototypes()

require("modes/jd-p0ober-split-factory/data")
require("modes.jd-spider-race.data")
require("modes.battlefluffy-scenario.data")