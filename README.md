# Yet-to-be-Named Crab Game in Assembly

This is a platforming game running in MIPS assembly. It operates in the MARS MIPS simulator.

## Data and Global Variables

### Constants:
 - `WIDTH`: width of display
 - `SLEEP_DUR`: duration of sleep between loops
 - `INIT_POS`: position of crab at game start, offset from $gp
 - `KEYSTROKE`: address where key inputs is stored
 - `SEA_COL_0` through `SEA_COL_4`: background colours
 - `DARKNESS`: amount to darken sprites by, for each level in `world`

### Global Variables:
 - `frame_buffer`: additional space for display (confirm this is needed?)
 - `crab`:
   - +0: Position - Address of pixel
   - +4: State - {0=walk_0, 1=walk_1, 2=jump, 3=dead}
   - +8: Jump timer - counts frames of rising, before falling down
 - `world`:
   - +0: Level - {4,3,2,1,0}
   - +4: Score
 - `clam`:
   - +0: Visible - {0=invisible, 1=visible}
   - +4: Position - Address of pixel
   - +8: State - {0=closed, 1=open}

## Functions

### Keyboard Input Functions:
 - `key_pressed()`

### Painting Functions:
 - `generate_background()`
 - `build_platform(*start, int length)`
 - `stamp_crab()`
 - `stamp_clam(*pixel)`
 - `stamp_piranha(*pixel)`
 - `stamp_pufferfish(*pixel)`
 - `stamp_seahorse(*pixel)`

### Un-Painting Functions:
 - `get_bg_color()`
 - `unstamp_crab()`

## Ideas: 
 - Can jump up fast, but fall down slow.
 - Pufferfish float up and down, through platforms
 - Piranha paces left and right along platforms
 - Get points from pearls, maybe sand dollars?
 - Seahorse grants temporary immunity

