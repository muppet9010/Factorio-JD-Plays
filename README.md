# Factorio-JD-Plays



A mod for streamer JD-Play's server. Includes a number of distinct modes.



General Notes
==============

All listed modes below "should" still just work, but only the top one was tested during most recent updates.
All modes from before Factorio 1.1 have been removed from the active mod as part of the upgrade to 1.1. The code is retained in a deactivated fashion, but would require updating and testing to re-enable.



Halloween 2023
==============

Small changes for a halloween play through. Other mods provide most of the gameplay changes.
- Disabled artillery in all forms via technology.
- Radar nerfed to restrict vision.
- Replacement graphics for other mods to make them more halloween themed: Biter Eggs & Zombie Engineer.



JD Split Factory
==============

There is an impassable divide splitting the map in half; east and west. JD has the east side as his home, while any other player goes on the west side.

- Both sides are on the same team, sharing research progress, etc.
- When a player dies they will always respawn on their home side of the divide.
- Underground belts can go under the divide, while power pole wires and robots can go over the divide.
- There is a teleporter on each side that can transfer the player's conscience into a cloned body on the other side of the divide. The cloned body only lives for 15 minutes before it dies and you're returned to a new body on your own side. When a conscience leaves a body for any reason the body dies. The teleporter is in a hard coded position.
- Spider vehicles will be blocked from walking over (or near) the divide.

Teleporters graphics and sound copied from the Teleporters mod (with approval) by Klonan. https://mods.factorio.com/mod/Teleporters



Battlefluffy Scenario
================

For use with BattleFluffy's scenario.

- Adds a lot of lights to effects as the map is pitch black, i.e. weapon shooting, weapon impacts, fires and building death explosions.
- Adjusts when lights and lamps turn on times to work better with the dark map.
- Removes most things from glowing in the dark. So a projectile fired across a dark screen are dark themselves now, rather than always being bright like vanilla Factorio is. Also means biter spit doesn't glow in the dark.
- Modifies the "camp-fire" entity added by the Fire Place mod to be suitable for creation by Muppet Streamer mod's Spawn Around Player. This includes making it non minable, auto fuelling it (so it is active and has fire) and removing it 30-60 seconds after created.
- Artillery wagons are not able to shoot, they are just good for artillery ammo carrying. They are thus renamed, re-imaged, and have an updated recipe accordingly. This is to work around the issue that they won't and can't be made to be naturally targetted by enemy artillery. Normal artillery turrets can be used for doing the shooting.

Expects the mod: Fire Place.



JD Spider Race
================

A race by 2 teams to hunt down a massive hostile australian spider and kill it on a parallel frontier style map.
Full details found here including RCON commands: [PDF document](https://github.com/muppet9010/Factorio-JD-Plays/tree/master/modes/jd-spider-race/JD-Plays & Mukkie Spider Hunt.pdf)
Initial code contributions by AndrewReds.
Expects the mod: JD Goes Boom.

NOTE: this specific mod version (20.2.5) is for play testing and has a reduced Spider. It differs from the PDF document in JD's exact requested manner; starting only 1.5k tiles from spawn, having only 10% health, being 10% the size of normal boss spider (small biter sized). Indirect changes to accommodate the above are: retreating at each 50% of new health (2nd retreat would be its death), retreating only 500 tiles, only roaming 250 +/- on the X axis, spider will only chase 1k tiles to avoid running in to spawn. The spider has the same movement speed and AI, so should be ok, but this is a known risk as not extensively tested like this.

Information that players should know at a minimum to avoid surprises (or they can read the many page document in full).

- Big scary spider far to the west. Aim is to kill the spider and take the reward coin back to your market to nuke the other tea and win.
- The spider is a mega spidertron. It has lots of weapons including atomic bombs and artillery shells. The atomic-bombs are only used on high value targets. The spider never runs out of standard bullets, rockets and cannon shells, with the better ammo being given by chat (RCON).
- The spider is naturally immune to artillery and tank shells, but is also immune to atomic bombs. Attack with lasers, rockets and bullets.
- The spider roams a large area and can be moved by RCON commands. It has some basic reactive behavior for fighting and intelligently pursuing enemies, so engage with caution. Once it’s suffered considerable damage it will retreat further away from you.
- When you attack the spider all the nearby biters will attack towards you. This can be very large numbers, you have been warned.
- You can’t interact directly with the team on the other side of the divide (electric wall) or walk a spidertron near/across the divide. You can steal each other's power, so be careful how close you build power poles to the divide. It's a race against your biters to the west, not directly against the other player's team.
- Each team has a starting area of resources with continuous water to the east on a thin ribbon map.

Future compatibility note: this mod has had to include copies of some base spidertron code and so is at risk of any changes to base game spidertron code after Factorio 1.1.60.



Easter Egg Surprise (2022)
================

When Biter Egg Nests are destroyed sometimes random items will be revealed as having been collected within the nest.

- Expected Mods: Biter Eggs
- When Biter Egg Nests are destroyed and the chance of neither it containing some number of biters or worms occurs, some random items will be revealed as being within the nest. Biter Eggs mod settings control the chance of an egg containing either biters or worms. But also contains settings that can then potentially spawn 0 of them in. This would lead to 0 items as the chance of biter/worms was met.
- These random items will be 1 item per small egg nest and 1-3 items per large egg nest.
- These items will just be simple vanilla items (with equal chance weight): iron plate, copper plate, steel plate, green circuits, gears, pipes, basic ammo, walls, gun turrets.
- There won't be a repeat item within the same destroyed egg nest.
