# Factorio-JD-Plays


A mod for streamer JD-Plays's server. Includes a number of distinct modes.

May 2019
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
- Players in orbit, on a spaceship or without a character are not deemed valid. Provides compatibility with Space Exploration mod.

April 2019
-----------

- Tested with Factorio 0.17.33
- Players start with: 5 centrifuges, 10 medium power poles, 3 burner mining drills, 3 stone furnaces, 20 iron plate, Sub-machine gun, 10 AP ammo.
- Players re-spawn with: Sub-machine gun, 10 AP ammo.
- At game start unlock the "stone-enrichment-process" recipe from the "Stone Enrichment" mod.
- The entire map is covered in the 2 vanilla entity rock types after chunk generation

JD P00ber May 2019
------------------

- Tested with Factorio 0.17.41
- Rocket Silo is immune from player damage.
- Add an escape pod recipe and item that is unlocked with the rocket silo. Cost is the same as 1 satalite, plus a fish. Uses alien in yellow tank graphic.
- Game is only won when a player rides a rocket in an escape pod.