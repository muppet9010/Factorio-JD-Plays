# Factorio-JD-Plays


A mod for streamer JD-Plays's server. Includes a number of distinct modes.
Note that older months code should work, but are untested retrospectively.
All older months from 0.17 removed from mod as part of upgrade to 0.18.

JD P00ber - August 2020
================

- Tested with Factorio 0.18.35.
- Command to set spawn/respawn location per player:

    - Set via command "jd_plays_set_player_spawn".
    - Taken as 3 arguments seperated by a space in format: PlayerName XPos YPos.
    - If the player name has a space in it wrap the name in single or double quotes, i.e. 'player name'
    - Example: /jd_plays_set_player_spawn muppet9010 10 90
- Command to show all players spawn locations in chat, "jd_plays_get_players_spawns".

March 2020 - Easter Egg Suprise
================

- Tested with Factorio 0.18.17
- Expected Mods: Biter Eggs
- When Biter Egg Nests are destroyed and the chance of neither biters or worms occurs, some random items will be revealed as being witihn the nest.
- These random items will be 1 item per small egg nest and 1-3 items per large egg nest.
- These items can include nearly every item in the game (vanilla and map editor specail items) with very few exceptions.
- There won't be a repeat item within the same destroyed egg nest.