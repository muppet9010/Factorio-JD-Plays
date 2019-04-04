local Commands = {}

function Commands.Register(name, helpText, commandFunction, adminOnly)
    commands.remove_command(name)
    local handlerFunction
    if not adminOnly then
        handlerFunction = commandFunction
    elseif adminOnly then
        handlerFunction = function(data)
            local player = game.get_player(data.player_index)
            if player.admin then
                commandFunction(data)
            else
                player.print {"api-error.must-be-admin", data.name}
            end
        end
    end
    commands.add_command(name, helpText, handlerFunction)
end

return Commands
