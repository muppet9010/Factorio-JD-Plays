local mode = settings.startup["jdplays_mode"].value
if mode == "none" then
    return
else
    require("modes/" .. mode .. "/data")
end
