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
- There is a teleport on each side to transfer and keep the player's conscience in a clone body on the other side. The control across the divide can be maintained for 15 minutes before the consience is transfered back to a body on their own side.
- Spider vehicles will be blocked from walking over (or near) the divide.

Teleporters code and graphics copied from the Teleporters mod by Klonan. https://github.com/Klonan/Teleporters

Known downsides:
- The divider tiles will remove cliffs, but they are needed to make pathfinding simple (same as water).
- Biters will run around the end of the wall by the edge of the map as it only gets generated when players go near it, not when biters run towards it.



TODO:
    - Test MP safe.
    - Add massive power drain in cycles while teleporter is in use. Have a check that the teleporter is connected to the main power network when used and while in use.