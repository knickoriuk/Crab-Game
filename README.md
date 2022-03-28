# Yet-to-be-Named Crab Game in Assembly

This is a platforming game running in MIPS assembly. It operates in the MARS MIPS simulator.

## Data and Global Variables

### Constants:
 - `WIDTH`: width of display
 - `SLEEP_DUR`: duration of sleep between loops
 - `INIT_POS`: position of crab at game start, offset from $gp
 - `KEYSTROKE`: address where key inputs is stored
 - `SEA_COL_0` through `SEA_COL_4`: background colours
 - `DARKNESS`: amount to darken sprites by, multiplied by world.darkness
 - `NUM_PLATFORMS`: maximum number of platforms
 - `CRAB_UP_DIST`: height of crab jumps
 - `HORIZ_DIST`: distance moved left/right 
 - `UPPER_LIMIT`: height to pass to get to next level

### Global Variables:
 - `frame_buffer`: additional space for display (confirm this is needed?)
 - `crab`:
   - +0: Position - Address of pixel
   - +4: State - {0=walk_0, 1=walk_1, 2=jump, 3=dead}
   - +8: Jump timer - counts frames of rising, before falling down
 - `world`:
   - +0: Level - {0,1,2,3,4,5, ...}
   - +4: Darkness - {4,3,2,1,0}
   - +8: Score
 - `clam`:
   - +0: State - {0=invisible, 1=open, 2=closed}
   - +4: Position - Address of pixel
 - `piranha1` and `piranha2`:
   - +0: State - {0=invisible, 1=left-facing, 2=right-facing}
   - +4: Position - Address of pixel
 - `pufferfish`:
   - +0: State - {0=invisible, 1=ascending, 2=descending}
   - +4: Position - Address of pixel
 - `seahorse`:
   - +0: State - {0=invisible, 1=visible}
   - +4: Position - Address of pixel
 - `platforms`:
   - +0: Platform1 Position
   - +4: Platform1 Length
   - +8: Platform2 Position
   - +12: Platform2 Length
   - +16: Platform3 Position
   - +20: Platform3 Length
   - etc.

## Functions

### Keyboard Input and Movement Functions:
 - `key_pressed()`
 - `do_jumps()`
 - `update_positions()`

### Initialize Level Functions:
 - `gen_level_0()`
 - `gen_next_level()`

### Painting Functions:
 - `generate_background()`
 - `_build_platform(*start, int length)`
 - `stamp_platforms()`
 - `stamp_crab()`
 - `stamp_clam()`
 - `stamp_piranha()`
 - `stamp_pufferfish()`
 - `stamp_seahorse()`

### Un-Painting Functions:
 - `_get_bg_color()`
 - `unstamp_platforms()`
 - `unstamp_crab()`
 - `unstamp_clam()`
 - `unstamp_piranha()`
 - `unstamp_pufferfish($a0=*position)`
 - `unstamp_seahorse()`

## To do:
 - [x] ~~Ensure all `stamp_` functions have switched to using global struct data~~
 - [ ] Complete `unstamp_` functions
 - [x] ~~Implement a check in the main loop: check if crab has surpassed `UPPER_LIMIT` and switch to a new level~~
 - [ ] Implement `update_positions()` to move pufferfish and piranha positions
 - [x] ~~Make Level 1 (`gen_level_1()`)~~
 - [ ] Falling off screen leads to game over
 - [ ] Detect if touching other entities

## Ideas: 
 - Pufferfish float up and down, through platforms
 - Piranha paces left and right along platforms
 - Get points from pearls, maybe sand dollars?
 - Seahorse grants temporary immunity
 - Collision detection: can make square hitboxes, iterate over the pixels in the hitbox range to see if one of four points of the crab passed through it (upper left, upper right, lower left, lower right)
 - Bubbles that you can double bounce on, but pop and come back after X display refreshes