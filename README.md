## Yet-to-be-Named Crab Game in Assembly

This is a platforming game running in MIPS assembly. It operates in the MARS MIPS simulator.

## Data and Global Variables

### Constants:
 - NOISE_PCT: percent background noise (probably has to be removed)
 - WIDTH: width of display

### Global Variables:
 - frame_buffer: additional space for display (confirm this is needed?)
 - crab:
 - world:

## Functions

### Painting Functions:
 - generate_background()
 - stamp_crab()
 - stamp_open_clam(*pixel)
 - stamp_closed_clam(*pixel)
 - stamp_pufferfish(*pixel)
 - stamp_seahorse(*pixel)

### Un-Painting Functions:
 - unstamp_crab()

## Ideas: 
 - Can jump up fast, but fall down slow.
 - Pufferfish transcend upwards, floating past. Have to dodge them.
 - Get points from pearls, sand dollars?
 - Seahorse -> temporary immunity? 
 - Static level screens probably easier. non-infinite game
 - Horizontally travelling eels like super mario
 - platforms that look like coral, dynamic-lengthed?
 - background gets lighter as you ascend
 - piranha enemy that paces along platforms