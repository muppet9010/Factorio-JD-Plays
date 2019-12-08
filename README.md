# Factorio-JD-Plays


A mod for streamer JD-Plays's server. Includes a number of distinct modes.
Note that older months code should work, but are untested retrospectively.

December 2019 - Race To The North Pole
----------

- Tested with Factorio 0.17.75
- Players start with: 8 iron plate, 1 wood, 1 burner mining drill, 1 stone furnace, 10 research appropriate ammo, 1 research appropriate bullet gun
- Players re-spawn with: 10 research appropriate ammo, 1 research appropriate bullet gun
- Utilises Biter Hunting Packs as per May 2019 mode settings. With the addition that a hunted player disconnecting counts as a loss and the biters target spawn instead. Adds command to write out biter hunt group results as JSON: biters_write_out_hunt_group_results
- Shared damage between all players is the proportion of 75% inbound damage (not damage after armor/shields) that you are from the injured player vs the max generated map distance from spawn. Further away from the player in proportion to whole map the less damage. There is a 60 second safe period after respawning. Players killing others via shared damage are named the total deaths killers/victims have caused/suffered is included. Shared damage deaths suffered and caused are logged for a future use. Command to write out others killed and your deaths from shared damage as JSON: shared_damage_write_out_kills_deaths
- Rocket silo crafting is disabled. There is a silo around 5k tiles north somewhere. This rocket silo is invincible and can not be mined.
- There is just ocean south of the starting area. It has a nice pretty random coastline with all the fish and freezing fog! Any player, building or vehicle out in the freezing fog will take damage.
- There is a thick forest at the starting area which fades out to no trees from 100k to 150k north.
- All minable rocks on the map are replaced with biter eggs. Huge rocks = large egg nests, big rocks = small egg nests.
- When chunks past 150,000 tiles are generated the corrisponding chunk row from 100,000 tiles are cleansed of all rocks, trees, ores, dropped items, fish, decoratives, corpses to keep the map & save file down.
- Other mods expected (but can't be forced): xmas-feels, BigWinter, biter_santa, biter_eggs, biter_reincarnation
- Map Generation Settings:
    - disable trees on their tick box
    - map size width = 1000, height unlimited (0)
- Mod Settings:
    - Biter Eggs mod Startup setting - Egg nest quantity = 0
    - Biter Santa mod settings:
        - Set the desired position up north and call santa in once the map has loaded.
        - Set the Santa's Inventory Contents setting to: [ {"name":"coal", "quantity":5000} ]

June 2019 - Tree World
---------

- Tested with Factorio 0.17.44
- Players start with: 8 iron plate, 1 wood, 1 burner mining drill, 1 stone furnace, 10 research appropriate ammo, 1 research appropriate bullet gun
- Players re-spawn with: 10 research appropriate ammo, 1 research appropriate bullet gun
- The entire world is covered in trees. If Biter Reincarnation mod is present they will be biome appropriate trees, otherwise each tree will be a random tree type.

May 2019 - Biter Hunting Packs
---------

- Tested with Factorio 0.17.36
- Players start with: 8 iron plate, 1 wood, 1 burner mining drill, 1 stone furnace, 10 research appropriate ammo, 1 research appropriate bullet gun
- Players re-spawn with: 10 research appropriate ammo, 1 research appropriate bullet gun
- Every 20-45 minutes 80 enemies will spawn in a 100 tile radius around a randomly targeted valid player. They will be evolution appropriate +10% and will individually target that player. There will be 3 seconds of dirt borrowing effect before each biter will come up. Should the targeted player die during this time the biters will continue to come up and target the spawn area on that surface. If no players are alive anywhere the biters will target spawn on the nauvis surface.
- A small GUI will give a 10 second warning for the next biter hunter group and when there is a current group show who is being targeted.
- The success of a biter hunt group vs the targeted player is broadcast in game chat using icons and stored for future modding use in an in-game persistent table. The winner is whoever lasts the longest out of the special biters and the targeted player after the biter hunt group targets the player, regardless of cause of death. Should neither have won by the next biter hunt group it is declared a draw.
- Command to trigger a biter hunting pack now: biters_attack_now
- Added a character-corpse image as the default game one is of an alive player.
- Use "Extra Biter Control" mod and increase the pathfinder limits by at least a multiple of 5 to ensure all biters path to target quickly.
- Players in orbit, on a spaceship or without a character are not deemed valid. Provides compatibility with Space Exploration mod. Space Exploration mod does break the detection of winner between biter pack and targeted player.

April 2019 - Rocky World
-----------

- Tested with Factorio 0.17.33
- Players start with: 5 centrifuges, 10 medium power poles, 3 burner mining drills, 3 stone furnaces, 20 iron plate, Sub-machine gun, 10 AP ammo.
- Players re-spawn with: Sub-machine gun, 10 AP ammo.
- At game start unlock the "stone-enrichment-process" recipe from the "Stone Enrichment" mod.
- The entire map is covered in the 2 vanilla entity rock types after chunk generation

JD P00ber May 2019 - Banished Engineers
------------------

- Tested with Factorio 0.17.41
- Rocket Silo is immune from player damage.
- Add an escape pod recipe and item that is unlocked with the rocket silo. Cost is the same as 1 satalite, plus a fish. Uses vanilla game's alien in yellow tank graphic.
- Game is only won when a rocket is launched with an escape pod in it.