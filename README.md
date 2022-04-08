# Crab Ascent

This is a platforming game made entirely from scratch using MIPS assembly, a final project for the course CSCB58 at UofT. It operates in the MARS simulator. Partake in the crab's journey as it makes its way up from the depths of the ocean, featuring hand-drawn graphics by none other than me.

## Data and Global Variables

### Constants:
 - `WIDTH`: width of display
 - `SLEEP_DUR`: duration of sleep between loops
 - `DEATH_PAUSE`: duration of sleep after dying
 - `INIT_POS`: position of crab at game start, offset from $gp
 - `KEYSTROKE`: address where key inputs is stored
 - `SEA_COL_0` through `SEA_COL_7`: background colours
 - `DARKNESS`: amount to darken sprites by, multiplied by level in $s0
 - `GLOW_AMT`: amount to brighten bg color by, around seahorse and stars
 - `NUM_STARS`: maximum number of sea stars
 - `NUM_PLATFORMS`: maximum number of platforms
 - `TERMINAL_VEL`: maximum downward speed of crab
 - `CRAB_UP_DIST`: height of crab jumps
 - `BUBBLE_UP_DIST`: height of crab jumps after bouncing off a bubble
 - `HORIZ_DIST`: distance moved left/right 
 - `UPPER_LIMIT`: height to pass to get to next level
 - `POP_TIME`: number of screen refreshes before a popped bubble dissipates
 - `BUBBLE_REGEN`: number of screen refreshes before a bubble regenerates
 - `MAX_TIME`: time to complete level by to earn a time bonus
 - `STAR_PTS`: points earned per sea star
 - `CLAM_PTS`: points earned per clam
 - `SEAHORSE_PTS`: points earned per sea horse

### Data Structs:
 - `frame_buffer`: additional space for display
 - `crab`:
   - +0: Position - Address of pixel
   - +4: State - {0=walk_0, 1=walk_1, 2=jump, 3=dead}
   - +8: Jump timer - counts frames of rising, before falling down
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
 - `$s0`: Level - {9,8,7,6,5,4,3,2,1,0}
 - `$s1`: Pointer to `crab` struct
 - `$s2`: Last crab position
 - `$s3`: Score
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

### Un-Painting Functions:
 - `unstamp_crab()`
 - `unstamp_clam($a0=*position)`
 - `unstamp_piranha($a0=*position)`
 - `unstamp_seahorse($a0=*position)`
 - `unstamp_bubble($a0=*position)`
 - `unstamp_star($a0=*position)`

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
 - `display_score($a0=*position)`
 - `_display_number($a0=*position, $a1=number)`
 - `display_gameover()`
 - `stamp_fireworks()`
 - `display_you_win()`
 - `display_win_screen()`