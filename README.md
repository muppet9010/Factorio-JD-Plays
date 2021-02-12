# Factorio-JD-Plays


A mod for streamer JD-Play's server. Includes a number of distinct modes.
Note that older months code should work, but are untested retrospectively.
All older months from 1.0 and earlier removed from mod as part of upgrade to 1.1

JD P0ober Split Factory
==============

There is an unpassable divide splitting the map in half; east and west. P0ober has the west side as her home, while JD has the east side.
- Both sides are on the same team, sharing research progress, etc.
- When a player dies they will respawn on their home side of the divide.
- Underground belts can go under the divide, while power pole wires and robots can go over the divide.
- There is a teleport on each side to transfer the player's conscience to a clone body on the other side. After 15 minutes the clone body will deteriate, transfering the consience back to the players real body.
- Spider vehicles will be returned if they cross the divide, although they can walk over it techncially.
- Command to set other named player on either JD or P00ber's team.

Teleporters code and graphics copied from the Teleporters mod by Klonan. https://github.com/Klonan/Teleporters

Known downsides:
- The divider tiles will remove cliffs, but they are needed to make pathfinding simple (same as water).
- Biters will run around the end of the wall as it only gets generated when players go near it, not whne biters run a long way.



TODO:
    - Add the 15 minute tracker post teleport.
    - Handle Spiders, either:
        - Add a large entity on the divider that blocks spider legs collision so they can't step over the divider.
        - Track a player when in a spider vehicle and if they go over the line teleport the player out of it.
    - change the divider entity graphics for a laser beam type thing...
    - add the command to assign a player name to a team incase anyone wants to play along.
    - Add massive power drain in cycles while teleporter is in use. Have a check that the teleporter is connected to the main power network when used and while in use.