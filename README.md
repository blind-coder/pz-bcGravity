# Obey gravity. It's the law.

For now, Project Zomboid ignores gravity, allowing flying fortresses in the
sky. This mod fixes this.

# Limitations

Currently, this only supports fortresses crashing when items are destroyed via
the sledgehammer. I'll need a proper event to hook into.

# What'll happen exactly?

When something gets destroyed, a 7x7 area around and above the destroyed object
will be checked. Every square in that area that does not have a wall
(IsoGridSquare:getWall() function) will have all object above it in a 3x3
radius checked. Every square in THAT area that does not have a wall in a 3x3
radius BELOW it will be destroyed. Items will be dropped to the floor below, as
will corpses. Everything else (including generators!) will be destroyed.  
For every square that got destroyed, the 8 surrounding tiles will also be
checked if there's still a wall below and destroyed if not. This creates a ripple
effect.  
You CAN build a skybridge, but if its only support gets destroyed,
it'll crash...
