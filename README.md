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
 - `NUM_STARS`: maximum number of sea stars
 - `NUM_PLATFORMS`: maximum number of platforms
 - `CRAB_UP_DIST`: height of crab jumps
 - `HORIZ_DIST`: distance moved left/right 
 - `UPPER_LIMIT`: height to pass to get to next level
 - `POP_TIME`: number of screen refreshes before a popped bubble dissipates
 - `BUBBLE_REGEN`: number of screen refreshes before a bubble regenerates
 - `MAX_TIME`: time to complete level by to earn a time bonus
 - `STAR_PTS`: points earned per sea star
 - `CLAM_PTS`: points earned per clam
 - `SEAHORSE_PTS`: points earned per sea horse

### Data Structs:
 - `frame_buffer`: additional space for display (confirm this is needed?)
 - `crab`:
   - +0: Position - Address of pixel
   - +4: State - {0=walk_0, 1=walk_1, 2=jump, 3=dead}
   - +8: Jump timer - counts frames of rising, before falling down
 - `world`:
   - +0: Level - {0,1,2,3,4,5, ...}
   - +4: Darkness - {4,3,2,1,0}
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
 - `bubble1` and `bubble2`:
   - +0: State - {0=invisible, 1=visible, X=time it was popped}
   - +4: Position - Address of pixel
 - `stars`:
   - +0: Star1 State - {0=invisible, 1=visible}
   - +4: Star1 Position
   - +8: Star2 State - {0=invisible, 1=visible}
   - +12: Star2 Position
   - etc.
 - `platforms`:
   - +0: Platform1 Position
   - +4: Platform1 Length
   - +8: Platform2 Position
   - +12: Platform2 Length
   - +16: Platform3 Position
   - +20: Platform3 Length
   - etc.

### Global Registers:
 - `$s0`: Pointer to `world` struct
 - `$s1`: Pointer to `crab` struct
 - `$s2`: Last crab position
 - `$s3`: Score
 - `$s4`:
 - `$s5`: Background colour
 - `$s6`: Timer
 - `$s7`: Dead/alive flag, {0=alive, 1=dead}

## Functions

### Keyboard Input and Movement Functions:
 - `key_pressed()`
 - `do_jumps()`
 - `update_positions()`
 - `detect_collisions()`

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
 - `stamp_bubble()`
 - `stamp_stars()`
 - `display_score()`

### Un-Painting Functions:
 - `_get_bg_color()` [no longer used]
 - `unstamp_crab()`
 - `unstamp_clam($a0=*position)`
 - `unstamp_piranha($a0=*position)`
 - `unstamp_pufferfish($a0=*position)`
 - `unstamp_seahorse($a0=*position)`
 - `unstamp_bubble($a0=*position)`
 - `unstamp_star($a0=*position)`

## To do:
 - [x] ~~Ensure all `stamp_` functions have switched to using global struct data~~
 - [x] ~~Complete `unstamp_` functions~~
 - [x] ~~Implement a check in the main loop: check if crab has surpassed `UPPER_LIMIT` and switch to a new level~~
 - [x] ~~Make Level 1 (`gen_level_1()`)~~
 - [x] ~~Bubble sprite + popped sprite(?)~~
 - [x] ~~Implement `update_positions()` to move pufferfish and piranha positions~~
 - [x] ~~Detect if touching other entities~~
 - [x] ~~Implement temporary bubble platforms~~
 - [x] ~~Make Level 2~~
 - [ ] Falling off screen leads to game over
 - [ ] Fail condition / Game over screen
 - [ ] Add dead crab sprite
 - [ ] Win condition / Win screen
 - [ ] Make Level 3

## Ideas: 
 - May be able to optimize movement of puffer and piranha (and reduce awful flickering) by changing stamp and unstamp functions. Since we know they always move a fixed amount, we can stamp the bg color within stamp_ functions to cover where they moved from. Then don't call unstamp in main, only call when changing levels
 - Should also optimize by calling unstamp_ functions only if state changes (for star, seahorse, clam, bubble) but still stamp every time