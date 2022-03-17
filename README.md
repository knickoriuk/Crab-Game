## Yet-to-be-Named Crab Game in Assembly

This is a platforming game running in MIPS assembly. It operates in the MARS MIPS simulator.

## Data and Global Variables

### Constants:
 - `WIDTH`: width of display
 - `SLEEP_DUR`: duration of sleep between loops
 - `INIT_POS`: position of crab at game start, offset from $gp
 - `SEA_COL_0` through `SEA_COL_4`: background colours
 - `DARKNESS`: amount to darked sprites by, for each level in `world`

### Global Variables:
 - `frame_buffer`: additional space for display (confirm this is needed?)
 - `crab`:
   - +0: Position of crab
   - +4: Status
   - +8: ?
 - `world`:
   - +0: Level	(4,3,2,1,0)

## Functions

### Painting Functions:
 - `generate_background()`
 - `build_platform(*start, int length)`
 - `stamp_crab()`
 - `stamp_open_clam(*pixel)`
 - `stamp_closed_clam(*pixel)`
 - `stamp_piranha_L(*pixel)`
 - `stamp_piranha_R(*pixel)`
 - `stamp_pufferfish(*pixel)`
 - `stamp_seahorse(*pixel)`

### Un-Painting Functions:
 - `unstamp_crab()`

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
