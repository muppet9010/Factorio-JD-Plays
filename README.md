# Factorio-JD-Plays



A mod for streamer JD-Play's server. Includes a number of distinct modes.


General Notes
==============

All listed modes below "should" still just work, but only the top one was tested during most recent updates.
All modes from before Factorio 1.1 have been removed from the active mod as part of the upgrade to 1.1. The code is retained in a deactivated fashion, but would require updating and testing to re-enable.



JD Spider Race
================

A race by 2 teams to hunt down a massive hostile australian spider and kill it on a parallel frontier style map.
Full details found here including RCON commands: [PDF docuemnt](https://github.com/muppet9010/Factorio-JD-Plays/tree/master/modes/jd-spider-race/JD-Plays & Mukkie Spider Hunt.pdf)
Significant code contributions by AndrewReds.
Expects the mod: JD Goes Boom.

NOTE: this specific mod version (20.2.5) is for play testing and has a reduced Spider. It differs from the PDF document in JD's exact requested manner; starting only 1.5k tiles from spawn, having only 10% health, being 10% the size of normal boss spider (small biter sized). Indirect chanegs to accomidate the above are: retreating at each 50% of new health (2nd retreat would be its death), retreating only 500 tiles, only roaming 250 +/- on the X axis, spider will only chase 1k tiles to avoid running in to spawn. The spider has the same movement speed and AI, so should be ok, but this is a known risk as not extensively tested liek this.

Information that players should know at a minimum to avoid surprises (or they can read the many page document in full).

- Big scary spider far to the west. Aim is to kill the spider and take the reward coin back to your market to nuke the other tea and win.
- The spider is a mega spidertron. It has lots of weapons including atomic bombs and artillery shells. The atomic-bombs are only used on high value targets. The spider never runs out of standard bullets, rockets and cannon shells, with the better ammo being given by chat (RCON).
- The spider is naturally immune to artillery and tank shells, but is also immune to atomic bombs. Attack with lasers, rockets and bullets.
- The spider roams a large area and can be moved by RCON commands. It has some basic reactive behaviour for fighting and intelligently pursuing enemies, so engage with caution. Once it’s suffered considerable damage it will retreat further away from you.
- When you attack the spider all the nearby biters will attack towards you. This can be very large numbers, you have been warned.
- You can’t interact directly with the team on the other side of the divide (electric wall) or walk a spidertron near/across the divide. You can steal each other's power, so be careful how close you build power poles to the divide. It's a race against your biters to the west, not directly against the other player's team.
- Each team has a starting area of resources with continuous water to the east on a thin ribbon map.


Future compatibility note: this mod has had to include copies of some base spidertron code and so is at risk of any changes to base game spidertron code after Factorio 1.1.60.


Easter Egg Suprise (2022)
================

When Biter Egg Nests are destroyed sometimes random items will be revealed as having been collected within the nest.

- Expected Mods: Biter Eggs
- When Biter Egg Nests are destroyed and the chance of neither it containing some number of biters or worms occurs, some random items will be revealed as being within the nest. Biter Eggs mod settings control the chance of an egg containing either biters or worms. But also contains settings that can then potentially spawn 0 of them in. This would lead to 0 items as the chance of biter/worms was met.
- These random items will be 1 item per small egg nest and 1-3 items per large egg nest.
- These items will just be simple vanilla items (with equal chance weight): iron plate, copper plate, steel plate, green circuits, gears, pipes, basic ammo, walls, gun turrets.
- There won't be a repeat item within the same destroyed egg nest.



JD P0ober Split Factory
==============

There is an impassable divide splitting the map in half; east and west. P0ober has the west side as her home, while JD has the east side.

- Both sides are on the same team, sharing research progress, etc.
- When a player dies they will always respawn on their home side of the divide.
- Underground belts can go under the divide, while power pole wires and robots can go over the divide.
- There is a teleport on each side that can transfer the player's conscience into a cloned body on the other side of the divide. The cloned body can only be controlled for 15 minutes before you're returned to a new body on your own side. When a conscience leaves a body for any reason the body dies.
- Spider vehicles will be blocked from walking over (or near) the divide.

Teleporters graphics and sound copied from the Teleporters mod (with approval) by Klonan. https://mods.factorio.com/mod/Teleporters
