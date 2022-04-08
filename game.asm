##################################################################### 
# 
# CSCB58 Winter 2022 Assembly Final Project 
# University of Toronto, Scarborough 
# 
# Student: Kate Nickoriuk	k.nickoriuk@mail.utoronto.ca 
# Student #: 1003893691		Student ID: nickoriu
# 
# Bitmap Display Configuration: 
# - Unit width in pixels: 4
# - Unit height in pixels: 4
# - Display width in pixels: 256
# - Display height in pixels: 512
# - Base Address for Display: 0x10008000 ($gp)
# 
# Which approved features have been implemented?
# 1. Moving Objects (Piranhas, Pufferfish, Seahorse) 
# 2. Disappearing Platforms (Bubbles)
# 3. Different Levels
# 4. Fail Condition
# 5. Win Condition
# 6. Score
# 7. Animated Sprites (Crab, Clam, Bubble)
# 8. (Bonus) Varying light levels, sprites get brighter as you progress upwards
# 
# Additional information: 
# - The file "game_display.asm" needs to be imported by this file for the game to run.
# - On Windows, "game_display.asm" has to be in the same directory as "MARS.jar"
# - On Linux it needs to be in the same location as "game.asm"
# 
#####################################################################

.eqv	WIDTH		256		# Width of display
.eqv	SLEEP_DUR	45		# Sleep duration between loops
.eqv	DEATH_PAUSE	1024		# Sleep duration after death
.eqv	INIT_POS	31640		# Initial position of the crab (offset from $gp)
.eqv	KEYSTROKE	0xffff0000	# Address storing keystrokes & values
.eqv	SEA_COL_7	0x00004390	# Sea colour, darkest
.eqv	SEA_COL_6	0x00004d96	#	:
.eqv	SEA_COL_5	0x0000579c	#	:
.eqv	SEA_COL_4	0x000061a2	#	:
.eqv	SEA_COL_3	0x00006ba9	#	:
.eqv	SEA_COL_2	0x000075af	#	:
.eqv	SEA_COL_1	0x00007fb5	# 	:
.eqv	SEA_COL_0	0x000089bb	# Sea colour, lightest
.eqv	DARKNESS	0x000b0602	# amount to darken colours by, per level
.eqv	GLOW_AMT	0x002c1b00	# amount to brighten bg color by, around seahorse and sea stars
.eqv	NUM_STARS	8		# Maximum number of sea stars		
.eqv	NUM_PLATFORMS	7		# Maximum number of platforms
.eqv	TERMINAL_VEL	-6		# Maximum downward speed of crab
.eqv	CRAB_UP_DIST	7		# Duration of crab jump ascension
.eqv	BUBBLE_UP_DIST	6		# Duration of crab jump ascension after bouncing on a bubble
.eqv	HORIZ_DIST	8		# Distance moved left/right per screen refresh
.eqv	UPPER_LIMIT	0x10009000	# Height that, if surpassed, moves to next level 
.eqv	POP_TIME	8		# Number of screen refreshes before a popped bubble dissipates
.eqv	BUBBLE_REGEN	100		# Number of screen refreshes before bubble regenerates. BUBBLE_REGEN > POP_TIME
.eqv	MAX_TIME	512		# Max time to complete level and still get time bonus
.eqv	STAR_PTS	10		# Number of points earned per sea star collected
.eqv	CLAM_PTS	200		# Number of points earned per clam collected
.eqv	SEAHORSE_PTS	100		# Number of points earned per seahorse collected	

.include	"game_display.asm"

.data
frame_buffer: 	.space		4096
crab:		.space		12
# struct crab {
#	int position; 	# holds address of pixel it is at
#	int state; 	# 0-walk_0, 1-walk_1, 2-jump/fall, 3-dead
#	int jump_timer; # counts down frames of rising, before falling down
# } crab;
clam:		.space		8
# struct clam {
#	int state;	# 0 if invisible, 1 if open, 2 if closed
#	int position;	# Pixel address of position of clam
# }
piranha1:	.space		8
piranha2:	.space		8
# struct piranhaX {
#	int state;	# 0 if invisible, 1 if left-facing, 2 if right-facing
#	int position;	# Pixel address of position of piranha
#	int platform;	# Memory offset from `platforms` that has the platform the piranha is on
# }
pufferfish:	.space		8
# struct pufferfish {
#	int state;	# 0 if invisible, 1 if ascending, 2 if descending
#	int position;	# Pixel address of position of pufferfish
# }
seahorse:	.space		8
# struct seahorse {
#	int state;	# 0 if invisible, 1 if visible
#	int position;	# Pixel address of position of seahorse
# }
bubble1:	.space		8
bubble2:	.space		8
# struct bubbleX {
#	int state;	# 0 if invisible/disabled, 1 if visible, X if popped (set X to time of pop)
#	int position;	# Pixel address of position of bubble
# }
stars:		.space		64	# Stores pairs of (state, position) for sea stars
					# States: 0 if invisible, 1 if visible
					# Set = to NUM_STARS * 8
platforms:	.space		56	# Stores pairs of (position, length) for platforms
					# length==0 implies the platform does not exist
					# Set = to NUM_PLATFORMS * 8

.text
.globl main

########## Register Assignment for main() ##########
# $s0 - Current level (starting at 7, working towards 0)
# $s1 - `crab` data pointer
# $s2 - Last crab location
# $s3 - Score
# $s5 - background colour
# $s6 - timer: number of screen refreshes since level start
# $s7 - dead/alive flag: 0=alive, 1=dead
# $t0 - temporary values

########## Initialize Game Values ##########
main:	li   $s0, 7	# $s0 = Level
	la   $s1, crab	# $s1 = *crab
	li   $s3, 0	# $s3 = Score
	li   $s6, 0	# $s6 = Timer
	li   $s7, 0	# $s7 = Dead/alive
	
	# Setup data for Level 0
	jal  gen_level_0
	
	# Display inital level
	jal  generate_background
	jal  stamp_platforms
	jal  stamp_crab
	
########## Get Keyboard Input ##########

main_loop:
	lw   $s2, 0($s1)		# Store old crab location in $s2
	
	# If top of level was reached, build next level
	lw   $t0, 0($s1)			# $t0 = new crab.position
	bgt  $t0, UPPER_LIMIT, get_keystroke	# If height not yet reached
	lw   $t0, 4($s1)			# $t0 = crab.state
	bge  $t0, 2, get_keystroke		# If crab is not yet on land
	j    next_level

get_keystroke:		
	li   $t0, KEYSTROKE
	lw   $t0, 0($t0) 		# $t0 = 1 if key hit, 0 otherwise
	bne  $t0, 1, update_display	# if no key was hit, branch to `update_display` 
	jal  key_pressed		# Update position in `crab` struct
	j    update_display
	
########## Construct Next Level ##########

next_level: # Modify level in $s0
	addi $s0, $s0, -1	# level = level - 1
	
	# Setup data for next level
	jal  gen_next_level
	li   $s6, 0		# Reset timer to 0
	
	# Display new level
	jal  generate_background
	jal  stamp_platforms
	
########## Update Display ##########

update_display:
	jal  do_jumps		# Move crab up or down

	# Entities, if they move, are removed from display in update_positions() or detect_collisions()
	jal  detect_collisions
	jal  update_positions
	
	jal  stamp_seahorse
	jal  stamp_stars
	jal  stamp_bubble
	jal  stamp_pufferfish
	jal  stamp_piranha
	jal  stamp_clam

	# Flicker prevention: only unstamp crab if it moved
	lw   $t0, 0($s1)		# $t0 = crab.position
	beq  $s2, $t0, update_display2	# if new pos == old pos, skip next line
	jal  unstamp_crab		# remove old crab from display
update_display2:

	jal  stamp_platforms
	jal  stamp_crab
	
	addi $a0, $gp, 940	# $a0 = *position for scoreboard
	jal  display_score
	
	beq  $s7, 1, game_over	# If dead, skip to game over section

########## Sleep and Repeat ##########

sleep:	addi $s6, $s6, 1	# add 1 to timer
	# Sleep for `SLEEP_DUR` milliseconds
	li   $a0, SLEEP_DUR
	li   $v0, 32
	syscall
	
	j    main_loop	# Jump back to main loop, checking for next key press
	
########## Game Over? ##########

game_over:
	li   $a0, DEATH_PAUSE	# Sleep a while
	li   $v0, 32
	syscall

	li   $s5, 0		# set bg color to black
	jal  generate_background
	jal  display_gameover
	
game_over_loop:	
	li   $a0, SLEEP_DUR	# Sleep a bit
	li   $v0, 32
	syscall
	
	li   $t0, KEYSTROKE
	lw   $t0, 0($t0) 	 # $t0 = 1 if key hit, 0 otherwise
	
	beqz $t0, game_over_loop # loop until a key is pressed
	li   $t0, KEYSTROKE
	lw   $t0, 4($t0)  	 # $t0 = last key hit 
	beq  $t0, 0x71, exit	 # exit program if `q` pressed
	bne  $t0, 0x70, game_over_loop # if `p` was not pressed, loop again
	j    main

########## You Won! ##########

win:	li   $s5, 0		# set bg color to black
	jal generate_background	# For a short black screen
	
	li   $a0, 256		# Sleep for ~256 ms
	li   $v0, 32
	syscall	

	jal  display_win_screen
	jal  display_you_win
	li   $s0, 3		# to darken crab stamp
	li   $s5, 0x00090921	# set bg color to dark blue
	li   $s6, 0		# set timer to 0
	addi $s3, $s3, 10000	# Add win bonus to score

	li   $t0, 0
	sw   $t0, 4($s1)	# crab.state = 0 (walk_0)
	addi $t0, $gp, 22376
	sw   $t0, 0($s1)	# set crab positon for display
	jal  stamp_crab

	addi $a0, $gp, 904	# $a0 = position for score
	jal  display_score

win_loop:
	jal  stamp_fireworks

	addi $s6, $s6, 1	# add 1 to timer
	li   $a0, 75	
	li   $v0, 32
	syscall			# Sleep ~75 ms

	# Only exit if 'p' was pressed, otherwise loop
	li   $t0, KEYSTROKE
	lw   $t0, 0($t0) 	# $t0 = 1 if key hit, 0 otherwise
	
	beqz $t0, win_loop # loop until a key is pressed
	li   $t0, KEYSTROKE
	lw   $t0, 4($t0)  	 # $t0 = last key hit 
	beq  $t0, 0x71, exit	 # exit program if `q` pressed
	bne  $t0, 0x70, win_loop # if `p` was not pressed, loop again
	j    main
	
########## Exit Program ##########
	
exit:	li   $v0, 10
	syscall
	
#########################################################################
#	KEYBOARD INPUT and MOVEMENT FUNCTIONS				#
#########################################################################

# key_pressed():
#	Determines and updates new states and positions for the crab,
#	given the current key that is pressed.
#	$t2: crab_pos, $t3: crab_state, $t6: distance, $t7: modulo comparison, $t9: key_input
key_pressed:
	li   $t9, KEYSTROKE  	# $t9 
	lw   $t9, 4($t9) 	# $t9 = last key hit 
	
	# Get crab data
	lw   $t2, 0($s1)	# $t2 = crab.position
	lw   $t3, 4($s1)	# $t3 = crab.state
	
	# If dead (state 3), don't change anything.
	beq  $t3, 3, key_input_done
	
	# Check which key pressed
	beq  $t9, 0x61, key_a  	# If $t9 == 'a', branch to `key_a`
	beq  $t9, 0x64, key_d  	# If $t9 == 'd', branch to `key_d`
	beq  $t9, 0x77, key_w  	# If $t9 == 'w', branch to `key_w`
	beq  $t9, 0x70, key_p  	# If $t9 == 'p', branch to `key_p`
	j    key_input_done	# Otherwise, treat like no key pressed

key_a:	##### MOVE LEFT #####
	li   $t6, HORIZ_DIST	# $t6 = HORIZ_DIST
	
	bne  $t3, 2, key_a_walk
key_a_jump: 	# If crab is jumping, move left twice as far
	sll  $t6, $t6, 1	# $t6 = HORIZ_DIST * 2
	addi $t7, $t6, -4	# $t7 = HORIZ_DIST*2 - 4
	j    key_a_checkwall
	
key_a_walk:	# Otherwise, crab is walking
	addi $t7, $t6, -4	# $t7 = HORIZ_DIST - 4
	
key_a_checkwall: # Check if it is at the left wall
	addi $t4, $t2, -32	# $t4 = position of left-most edge of crab
	sub  $t4, $t4, $gp	# $t4 = left-most pixel - $gp
	li   $t5, WIDTH		# $t5 = WIDTH (probably 256)
	div  $t4, $t5		# hi = $t4 % $t5
	mfhi $t5
	ble  $t5, $t7, key_a_noroom	# if remainder is <= $t7, it cannot move that far
	
	# Update position stored in `crab`
	sub $t2, $t2, $t6		# $t2 = crab.position - distance travelled
	sw   $t2, 0($s1)		# crab.position = crab.position - distance travelled

	bne  $t3, 2, key_toggle_check	# If not currently jumping (state 2), toggle walk state
	j    key_input_done
	
key_a_noroom: # If there's not room to move that much space, reduce distance by 4 and retry
	beq  $t6, 0, key_input_done	# Break if distance == 0
	addi $t6, $t6, -4	# decrease distance moved by 4
	addi $t7, $t7, -4	# decrease modulo comparison by 4
	j    key_a_checkwall

key_d:	##### MOVE RIGHT #####
	li   $t6, HORIZ_DIST	# $t6 = HORIZ_DIST
	li   $t7, WIDTH		# $t7 = WIDTH
	
	bne  $t3, 2, key_d_walk
key_d_jump: 	# If crab is jumping, move right twice as far
	sll  $t6, $t6, 1	# $t6 = HORIZ_DIST * 2
	sub  $t7, $t7, $t6	# $t7 = WIDTH - HORIZ_DIST*2
	j    key_d_checkwall
	
key_d_walk:	# Otherwise, crab is walking
	sub  $t7, $t7, $t6	# $t7 = WIDTH - HORIZ_DIST
	
key_d_checkwall: # Check if it is at the right wall
	addi $t4, $t2, 28	# $t4 = position of right-most edge of crab
	sub  $t4, $t4, $gp	# $t4 = right-most pixel - $gp
	li   $t5, WIDTH		# $t5 = WIDTH (probably 256)
	div  $t4, $t5		# hi = $t4 % $t5
	addi $t4, $t5, -8	# $t4 = WIDTH - 8
	mfhi $t5		# $t5 = modulo(position, WIDTH)
	bge  $t5, $t7, key_d_noroom	# if remainder is >= $t7, it cannot move that far
	
	# Update position stored in `crab`
	add  $t2, $t2, $t6		# $t2 = crab.position + distance travelled
	sw   $t2, 0($s1)		# crab.position = crab.position + distance travelled

	bne  $t3, 2, key_toggle_check	# If not currently jumping (state 2), toggle walk state
	j    key_input_done
	
key_d_noroom: # If there's not room to move that much space, reduce distance by 4 and retry
	beq  $t6, 0, key_input_done	# Break if distance == 0
	addi $t6, $t6, -4	# decrease distance moved by 4
	addi $t7, $t7, -4	# decrease modulo comparison by 4
	j    key_d_checkwall


key_w:	##### JUMP #####

	# Check if crab is already jumping
	beq  $t3, 2, key_input_done
	
	# Set state to `jumping` (2)
	li   $t3, 2		# $t3 = 2
	sw   $t3, 4($s1)	# crab.state = 2
	li   $t3, CRAB_UP_DIST	# $t3 = CRAB_UP_DIST
	sw   $t3, 8($s1)	# crab.jump_timer = CRAB_UP_DIST
	j    key_input_done
	
key_p:	##### RESET #####
	j    main
	
key_toggle_check: # If walking, toggle walk states from 0 <-> 1
	beq  $t2, $s2, key_input_done # If position hasn't changed, don't toggle.
	beq  $t3, 0, key_toggle_1	
	
	# Toggle crab.state from 1 to 0
	li   $t3, 0
	sw   $t3, 4($s1)	# crab.state = 0
	j    key_input_done
	
key_toggle_1: # Toggle crab.state from 0 to 1
	li   $t3, 1
	sw   $t3, 4($s1)	# crab.state = 1

key_input_done:
	jr   $ra
# ---------------------------------------------------------------------------------------


# do_jumps():
#	moves the crab's stored position up or down, depending on its state
#	$t0: outer index, $t1: inner index, $t2: crab.position, $t3 = crab.jump_timer, 
#	$t4: temp, $t5: platform pos, $t6: platform length, $t7: *platforms
do_jumps:	
	# Get crab data
	lw   $t2, 0($s1)	# $t2 = crab.position
	lw   $t3, 8($s1)	# $t3 = crab.jump_timer
	
	# if crab.jump_timer < TERMINAL_VEL, replace it with TERMINAL_VEL
	bgt  $t3, TERMINAL_VEL, dj_direction_check
	li   $t3, TERMINAL_VEL

dj_direction_check:	
	# Check jump timer	
	bgtz $t3, dj_up		# if jump_timer > 0, move up that amount and decrease jump_timer
	blez $t3, dj_down	# if jump_timer <= 0, move down that amount and decrease jump_timer
	
dj_up:	# Move crab up
	li   $t4, -WIDTH	
	mul  $t4, $t4, $t3	# $t4 = -WIDTH * crab.jump_timer
	add  $t2, $t2, $t4	# $t2 = new crab.position
	sw   $t2, 0($s1)	# crab.position = new crab.position
	
	# Decrease timer on crab.jump_timer
	addi $t3, $t3, -1	# $t3 = crab.jump_timer - 1
	sw   $t3, 8($s1)	# crab.jump_timer = crab.jump_timer - 1
	j dj_exit
	
dj_down: # Move crab down
	# if crab.pos > bottom row of display, trigger game over
	addi $t4, $gp, 32512
	blt  $t2, $t4, dj_down_check 
	li   $s7, 1		# Set dead/alive flag to 1, for dead
	li   $t4, 3
	sw   $t4, 4($s1)	# crab.state = 3 (dead)
	lw   $a0, 0($s1) 	# $a0 = crab.pos
	addi $sp, $sp, -4
	sw   $ra, 0($sp)	# Push $ra on stack
	jal  unstamp_crab
	lw   $ra, 0($sp)	# Restore $ra from stack
	addi $sp, $sp, 4
	j    dj_exit

dj_down_check: # Must determine if we are on/would fall through a platform
	li   $t0, 0		# $t0 = i; outer loop index
	la   $t7, platforms	# $t7 = *platforms
	
	addi $t4, $t2, WIDTH	# $t4 = pixel 1 row below crab pos
	
	dj_outer_loop: # Iterate over all platforms
		beq  $t0, NUM_PLATFORMS, dj_no_platform
	
		# Get platform start point and length
		lw  $t5, 0($t7)		# $t5 = platform[i] position
		lw  $t6, 4($t7)		# $t6 = platform[i] length
	
		# Convert length to number of pixels
		sll  $t6, $t6, 2	# $t6 = length*4
		addi $t6, $t6, 1	# $t6 = length*4 + 1
	
		# Calculate end point of platform
		sll  $t6, $t6, 2	# $t6 = (# pixels)*(sizeof int)
		add  $t6, $t5, $t6	# $t6 = start_point + (# pixels)*(sizeof int)
		
		# Inner loop: check once for each row upwards
		li   $t1, 0	# j = 0; inner loop index, counts down
		dj_inner_loop: # Iterate over the next n=`crab.jump_timer` rows
			blt  $t1, $t3, dj_outer_update	# if j < crab.jump_timer, break loop
			
			# Check if pixel address $t4 is between the start/end points of the platform
			blt  $t4, $t5, dj_inner_update	# if $t4 < start point, branch to `dp_update`
			bgt  $t4, $t6, dj_inner_update	# if $t4 > end point, branch to `dp_update`
			j    dj_on_plat
			
		dj_inner_update: # Update indices and row we are looking at
			addi $t1, $t1, -1	# j = j - 1
			addi $t5, $t5, -WIDTH	# $t4 = one row higher
			addi $t6, $t6, -WIDTH	# $t5 = one row higher
			j    dj_inner_loop
		
	dj_outer_update: # Update index and pointer
		addi $t0, $t0, 1	# i = i + 1
		addi $t7, $t7, 8	# $t7 = *platforms[i+1]
		j    dj_outer_loop
	
dj_no_platform:
	beq  $t4, 1, dj_on_plat	# branch to `dj_on_plat` if crab is on a platform
	
	# Move crab down
	li   $t4, -WIDTH	
	mul  $t4, $t4, $t3	# $t4 = -WIDTH * crab.jump_timer
	add  $t2, $t2, $t4	# $t2 = new crab.position
	sw   $t2, 0($s1)	# crab.position = new crab.position

	# Subtract from crab.jump_timer
	addi $t3, $t3, -1	# $t3 = crab.jump_timer - 1
	sw   $t3, 8($s1)	# crab.jump_timer = crab.jump_timer - 1
	
	# Set crab.state to `jumping` (2)
	li   $t4, 2		# $t4 = 2
	sw   $t4, 4($s1)	# crab.state = 2
	j dj_exit
	
dj_on_plat: # if crab is above a platform, move it down just to the platform:
	# Move crab down j pixels
	li   $t4, -WIDTH	
	mul  $t4, $t4, $t1	# $t4 = -WIDTH * j
	add  $t2, $t2, $t4	# $t2 = new crab.position
	sw   $t2, 0($s1)	# crab.position = new crab.position
	
	# Set jump_timer to 0
	li   $t3, 0		# $t3 = 0
	sw   $t3, 8($s1)	# crab.jump_timer = 0 
	
	# Set crab.state to 0 IFF it was already set to 2 (jumping)
	lw   $t4, 4($s1)	# $t4 = crab.state
	bne  $t4, 2, dj_exit
	sw   $t3, 4($s1)	# crab.state = 0
		
dj_exit:	
	jr   $ra	
# ---------------------------------------------------------------------------------------


# update_positions():
#	Updates the stored position value in all entity structs
#	Will also unstamp any entities that have moved
#	$t0: entity pointer, $t1: entity state, $t2: entity position, $t7: temp, $t8: temp2
update_positions:
	# Store $ra
	addi $sp, $sp, -4
	sw   $ra, 0($sp)

	# Update puffer
	la   $t0, pufferfish	# $t0 = *puffer
	lw   $t1, 0($t0)	# $t1 = puffer.state
	lw   $t2, 4($t0)	# $t2 = puffer.pos
	
	beq  $t1, 0 update_piranha1	# if puffer.state == 0, is invisible; skip it
	beq  $t1, 1, move_puff_up	# If puffer.state == 1, move it up
					# Otherwise, move it down
	# Move Puffer Down
	addi $t2, $t2, WIDTH
	sw   $t2, 4($t0)	# puffer.pos = 1 pixel below old puffer.pos
	addi $t7, $gp, 32512	# If new pos is at bottom of display, change its direction
	blt  $t2, $t7, update_piranha1
	li   $t7, 1
	sw   $t7, 0($t0) # Change state to 1 (ascending)
	j    update_piranha1
	
move_puff_up: # Move Puffer Up
	addi $t2, $t2, -WIDTH
	sw   $t2, 4($t0)	# puffer.pos = 1 pixel above old puffer.pos
	addi $t7, $gp, 256	# If new pos is at top of display, change its direction
	bgt  $t2, $t7, update_piranha1
	li   $t7, 2
	sw   $t7, 0($t0) # Change state to 2 (descending)

update_piranha1: # Update piranha1
	la   $t0, piranha1	# $t0 = *piranha1
	lw   $t1, 0($t0)	# $t1 = piranha1.state
	lw   $t2, 4($t0)	# $t2 = piranha1.pos
	move $a0, $t2		# $a0 = original piranha.pos
	
	beq  $t1, 0 update_piranha2	# if piranha.state == 0, is invisible; skip it
	beq  $t1, 1, move_piran1_left	# If piranha.state == 1, move it left
					# Otherwise, move it right
					
	# Move Piranha1 Right
	addi $t2, $t2, 4
	sw   $t2, 4($t0)	# piranha1.pos = 1 pixel right of old piranh1.pos
	
	# If new pos is at right of display, change its direction
	addi $t7, $t2, 28	# $t7 = right-most pixel of piranha
	sub  $t7, $t7, $gp	# $t7 = right-most pixel as an offset from $gp
	li   $t8, WIDTH		# $t8 = number of bytes in 1 row of pixels
	div  $t7, $t8		# hi = $t7 % $t8
	addi $t7, $t8, -4	# $t7 = WIDTH - 4
	mfhi $t8		# $t8 = modulo(position, WIDTH)
	blt  $t8, $t7, update_piranha2 # if remainder is < WIDTH-4, don't change its direction
	li   $t7, 1
	sw   $t7, 0($t0) # Change state to 1 (left-facing)
	jal  unstamp_piranha
	j    update_piranha2
	
move_piran1_left: # Move Piranha1 Left
	addi $t2, $t2, -4
	sw   $t2, 4($t0)	# piranha1.pos = 1 pixel left of old piranh1.pos
	
	# If new pos is at right of display, change its direction
	addi $t7, $t2, -28	# $t7 = left-most pixel of piranha
	sub  $t7, $t7, $gp	# $t7 = left-most pixel as an offset from $gp
	li   $t8, WIDTH		# $t8 = number of bytes in 1 row of pixels
	div  $t7, $t8		# hi = $t7 % $t8
	mfhi $t8		# $t8 = modulo(position, WIDTH)
	bgtz  $t8, update_piranha2 # if remainder is > 0, don't change its direction
	li   $t7, 2
	sw   $t7, 0($t0) # Change state to 2 (right-facing)
	jal  unstamp_piranha
	
update_piranha2: # Update piranha2
	la   $t0, piranha2	# $t0 = *piranha2
	lw   $t1, 0($t0)	# $t1 = piranha2.state
	lw   $t2, 4($t0)	# $t2 = piranha2.pos
	move $a0, $t2		# $a0 = original piranha2.pos
	
	beq  $t1, 0 update_bubble1	# if piranha.state == 0, is invisible; skip it
	beq  $t1, 1, move_piran2_left	# If piranha.state == 1, move it left
					# Otherwise, move it right
					
	# Move Piranha2 Right
	addi $t2, $t2, 4
	sw   $t2, 4($t0)	# piranha2.pos = 1 pixel right of old piranha.pos
	
	# If new pos is at right of display, change its direction
	addi $t7, $t2, 28	# $t7 = right-most pixel of piranha
	sub  $t7, $t7, $gp	# $t7 = right-most pixel as an offset from $gp
	li   $t8, WIDTH		# $t8 = number of bytes in 1 row of pixels
	div  $t7, $t8		# hi = $t7 % $t8
	addi $t7, $t8, -4	# $t7 = WIDTH - 4
	mfhi $t8		# $t8 = modulo(position, WIDTH)
	blt  $t8, $t7, update_bubble1 # if remainder is < WIDTH-4, don't change its direction
	li   $t7, 1
	sw   $t7, 0($t0) # Change state to 1 (left-facing)
	jal  unstamp_piranha
	j    update_bubble1
	
move_piran2_left: # Move Piranha2 Left
	addi $t2, $t2, -4
	sw   $t2, 4($t0)	# piranha2.pos = 1 pixel left of old piranha2.pos
	
	# If new pos is at right of display, change its direction
	addi $t7, $t2, -28	# $t7 = left-most pixel of piranha
	sub  $t7, $t7, $gp	# $t7 = left-most pixel as an offset from $gp
	li   $t8, WIDTH		# $t8 = number of bytes in 1 row of pixels
	div  $t7, $t8		# hi = $t7 % $t8
	mfhi $t8		# $t8 = modulo(position, WIDTH)
	bgtz $t8, update_bubble1 # if remainder is > 0, don't change its direction
	li   $t7, 2
	sw   $t7, 0($t0) # Change state to 2 (right-facing)
	jal  unstamp_piranha

update_bubble1:	# Update State of Bubble1
	la   $t0, bubble1	# $t0 = *bubble1
	lw   $t1, 0($t0)	# $t1 = bubble1.state
	
	ble  $t1, 1, update_bubble2 # If state <= 1, skip it
	
	addi $t1, $t1, POP_TIME
	blt  $s6, $t1, update_bubble2 # if current time < time of dissipation, dont do anything
				      # otherwise, unstamp bubble and check state

	lw   $a0, 4($t0)	# $a0 = bubble1.pos
	jal  unstamp_bubble
	
	la   $t0, bubble1	# $t0 = *bubble1
	lw   $t1, 0($t0)	# $t1 = bubble1.state
	addi $t1, $t1, BUBBLE_REGEN
	blt  $s6, $t1, update_bubble2   # if current time < time of regen, don't reset state
					# Otherwise, reset state to 1 (intact)
	li   $t1, 1
	sw   $t1, 0($t0)	# bubble1.state = 1

update_bubble2: # Update State of Bubble2
	la   $t0, bubble2	# $t0 = *bubble2
	lw   $t1, 0($t0)	# $t1 = bubble2.state
	
	ble  $t1, 1, update_seahorse # If state <= 1, skip it
	
	addi $t1, $t1, POP_TIME
	blt  $s6, $t1, update_seahorse # if current time < time of dissipation, dont do anything
				      # otherwise, unstamp bubble and check state

	lw   $a0, 4($t0)	# $a0 = bubble2.pos
	jal  unstamp_bubble
	
	la   $t0, bubble2	# $t0 = *bubble2
	lw   $t1, 0($t0)	# $t1 = bubble2.state
	addi $t1, $t1, BUBBLE_REGEN
	blt  $s6, $t1, update_seahorse   # if current time < time of regen, don't reset state
					# Otherwise, reset state to 1 (intact)
	li   $t1, 1
	sw   $t1, 0($t0)	# bubble2.state = 1
	
update_seahorse: # Update position of seahorse
	la   $t0, seahorse	# $t0 = *seahorse
	lw   $t1, 0($t0)	# $t1 = seahorse.state
	beq  $t1, 0, update_done # If state == 0, skip it

	# Move seahorse up 1 if (time % 8) == 0
	li   $t7, 8
	div  $s6, $t7
	mfhi $t7	# $t7 = time % 8
	beqz $t7, move_sh_up
	
	# Else, move seahorse down 1 if (time % 4) == 0
	li   $t7, 4
	div  $s6, $t7
	mfhi $t7	# $t7 = time % 4
	beqz $t7, move_sh_down
	j    update_done

move_sh_up:
	lw   $a0, 4($t0)	# $a0 = old seahorse.pos
	addi $t2, $a0, -WIDTH	# $t2 = 1 pixel above old pos
	sw   $t2, 4($t0)	# seahorse.pos = 1 pixel above old position
	jal  unstamp_seahorse
	j    update_done
	
move_sh_down:
	lw   $a0, 4($t0)	# $a0 = old seahorse.pos
	addi $t2, $a0, WIDTH	# $t2 = 1 pixel below old pos
	sw   $t2, 4($t0)	# seahorse.pos = 1 pixel below old position
	jal  unstamp_seahorse

update_done:
	# Restore $ra
	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	
	# Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


# detect_collisions():
#	Detects if the crab is touching any entities, based on positions stored in data structs
#	$t0: crab.pos, $t1: temp, $t2: index i, $t3: index j, 
#	$t6-$t7: temp hitboxes, $t8-$t9: crab hitbox
detect_collisions:
	lw   $t0, 0($s1)	# $t0 = crab.pos
	# Checking 6 hot spots around the crab so we don't have to check everything every time
	lw   $t1, 0($t0)		# $t1 = color under crab belly
	bne  $t1, $s5, dc_check		# if color is not bg_color, check for collisions
	lw   $t1, -276($t0)		# $t1 = color under left claw
	bne  $t1, $s5, dc_check		# :
	lw   $t1, -236($t0)		# $t1 = color under right claw
	bne  $t1, $s5, dc_check		# :
	lw   $t1, -1280($t0)		# $t1 = color above crab head
	bne  $t1, $s5, dc_check		# :
	lw   $t1, -1296($t0)		# $t1 = color above left claw
	bne  $t1, $s5, dc_check		# :
	lw   $t1, -1264($t0)		# $t1 = color above right claw
	bne  $t1, $s5, dc_check		# :
	jr   $ra			# Otherwise, (probably) no collisions
	
dc_check: # Check collisions with all entities
	# Store $ra
	addi $sp, $sp, -4
	sw   $ra, 0($sp)
	# Set up crab hitbox registers
	addi $t8, $t0, -28	# $t8 = bottom left
	addi $t9, $t0, 28	# $t9 = bottom right

dc_check_puff: # Check collisions with pufferfish
	la   $t0, pufferfish	# $t0 = *pufferfish

	lw   $t1, 0($t0)	# $t1 = puffer.state
	beqz $t1, dc_check_piranhas # if state==0, invisible; skip it
	lw   $t1, 4($t0)	# $t1 = puffer.pos
		
	addi $t6, $t8, 988	# $t6 = lower left hitbox
	addi $t7, $t9, 1060	# $t7 = lower right hitbox
	li   $t3, 0		# $t3 = j =0
	dccpu_hitbox_check:
		beq  $t3, 16, dc_check_piranhas	# Exit loop after 16 rows checked
		# if clam.pos not within $t6 - $t7, check next row up
		bgt  $t1, $t7, dccpu_hitbox_update
		blt  $t1, $t6, dccpu_hitbox_update
		
		# Otherwise, crab has collided with puffer.
		li   $s7, 1	# set alive/dead flag to dead
		li   $t1, 3
		sw   $t1, 4($s1) # crab.state = 3 (dead)
		lw   $a0, 0($s1) # $a0 = crab.pos
		jal  unstamp_crab
		
		# Don't check anything else, you're dead
		j    dc_done
		
	dccpu_hitbox_update:
		addi $t3, $t3, 1	# $t3 = j + 1
		addi $t6, $t6, -WIDTH	# iterate over next row up
		addi $t7, $t7, -WIDTH
		j    dccpu_hitbox_check
		
dc_check_piranhas: # Check collisions with piranhas
	la   $t0, piranha1	# $t0 = *piranha1
	li   $t2, 0		# $t2 = i = 0
	dccpi_loop:
		beq  $t2, 2, dc_check_star
		lw   $t1, 0($t0)	# $t1 = piranha.state
		beqz $t1, dccpi_update	# if state==0, invisible; skip this piranha
		lw   $t1, 4($t0)	# $t1 = piranha.pos
		
		addi $t6, $t8, 2540	# $t6 = lower left hitbox
		addi $t7, $t9, 2580	# $t7 = lower right hitbox
		li   $t3, 0		# $t3 = j =0
		dccpi_hitbox_check:
			beq  $t3, 16, dccpi_update	# Exit loop after 16 rows checked
			# if piranha.pos not within $t6 - $t7, check next row up
			bgt  $t1, $t7, dccpi_hitbox_update
			blt  $t1, $t6, dccpi_hitbox_update
			
			# Otherwise, crab has collided with piranha.
			li   $s7, 1	# set alive/dead flag to dead
			li   $t1, 3
			sw   $t1, 4($s1) # crab.state = 3 (dead)
			lw   $a0, 0($s1) # $a0 = crab.pos
			jal  unstamp_crab
			
			# Don't check anything else, you are dead
			j    dc_done
			
		dccpi_hitbox_update:
			addi $t3, $t3, 1	# $t3 = j + 1
			addi $t6, $t6, -WIDTH	# iterate over next row up
			addi $t7, $t7, -WIDTH
			j    dccpi_hitbox_check

	dccpi_update:
		addi $t2, $t2, 1	# $t2 = i + 1
		addi $t0, $t0, 8	# $t0 = *piranha2
		j    dccpi_loop
	
dc_check_star: # Check collisions with sea stars
	la   $t0, stars		# $t0 = *stars
	li   $t2, 0		# $t2 = i = 0
	dccss_loop:
		beq  $t2, NUM_STARS, dc_check_clam
		lw   $t1, 0($t0)	# $t1 = star.state
		beqz $t1, dccss_update	# if state==0, invisible; skip this star
		lw   $t1, 4($t0)	# $t1 = star.pos
		
		move $t6, $t8		# $t6 = lower left hitbox
		move $t7, $t9		# $t7 = lower right hitbox
		li   $t3, 0		# $t3 = j =0
		dccss_hitbox_check:
			beq  $t3, 7, dccss_update	# Exit loop after 7 rows checked
			# if star.pos not within $t6 - $t7, check next row up
			bgt  $t1, $t7, dccss_hitbox_update
			blt  $t1, $t6, dccss_hitbox_update
			
			# Otherwise, crab has collided with star.
			addi $s3, $s3, STAR_PTS	# add STAR_PTS to score
			li   $t1, 0
			sw   $t1, 0($t0)	# Set star.state to 0 (invisible)
			lw   $a0, 4($t0)
			jal  unstamp_star	# Remove star from display
			
			# Don't check other stars
			j    dc_check_clam
			
		dccss_hitbox_update:
			addi $t3, $t3, 1	# $t3 = j + 1
			addi $t6, $t6, -WIDTH	# iterate over next row up
			addi $t7, $t7, -WIDTH
			j    dccss_hitbox_check

	dccss_update:
		addi $t2, $t2, 1	# $t2 = i + 1
		addi $t0, $t0, 8	# $t0 = *stars[i+1]
		j    dccss_loop
		
dc_check_clam: # Check collisions with clam
	la   $t0, clam		# $t0 = *clam

	lw   $t1, 0($t0)	# $t1 = clam.state
	bne  $t1, 1, dc_check_seahorse # if state!=1, invisible or closed; skip it
	lw   $t1, 4($t0)	# $t1 = clam.pos
		
	addi $t6, $t8, -24	# $t6 = lower left hitbox
	addi $t7, $t9, 24	# $t7 = lower right hitbox
	li   $t3, 0		# $t3 = j =0
	dccc_hitbox_check:
		beq  $t3, 3, dc_check_seahorse	# Exit loop after 3 rows checked
		# if clam.pos not within $t6 - $t7, check next row up
		bgt  $t1, $t7, dccc_hitbox_update
		blt  $t1, $t6, dccc_hitbox_update
		
		# Otherwise, crab has collided with clam.
		addi $s3, $s3, CLAM_PTS	# add CLAM_PTS to score
		li   $t1, 2
		sw   $t1, 0($t0)	# Set clam.state to 2 (closed)
		lw   $a0, 4($t0)
		jal  unstamp_clam	# Remove clam from display
		
		# Don't check other rows
		j    dc_check_seahorse
		
	dccc_hitbox_update:
		addi $t3, $t3, 1	# $t3 = j + 1
		addi $t6, $t6, -WIDTH	# iterate over next row up
		addi $t7, $t7, -WIDTH
		j    dccc_hitbox_check
	
dc_check_seahorse: # Check collisions with seahorse
	la   $t0, seahorse	# $t0 = *seahorse

	lw   $t1, 0($t0)	# $t1 = seahorse.state
	beq  $t1, 0, dc_check_bubbles # if state==0, invisible; skip it
	lw   $t1, 4($t0)	# $t1 = seahorse.pos
		
	addi $t6, $t8, 1024	# $t6 = lower left hitbox
	addi $t7, $t9, 1024	# $t7 = lower right hitbox
	li   $t3, 0		# $t3 = j =0
	dccsh_hitbox_check:
		beq  $t3, 6, dc_check_bubbles	# Exit loop after 6 rows checked
		# if seahorse.pos not within $t6 - $t7, check next row up
		bgt  $t1, $t7, dccsh_hitbox_update
		blt  $t1, $t6, dccsh_hitbox_update
		
		# Otherwise, crab has collided with seahorse.
		addi $s3, $s3, SEAHORSE_PTS	# add SEAHORSE_PTS to score
		li   $t1, 0
		sw   $t1, 0($t0)	# Set seahorse.state to 0 (invisible)
		lw   $a0, 4($t0)
		jal  unstamp_seahorse	# Remove seahorse from display
		
		# Don't check other rows
		j    dc_check_bubbles
		
	dccsh_hitbox_update:
		addi $t3, $t3, 1	# $t3 = j + 1
		addi $t6, $t6, -WIDTH	# iterate over next row up
		addi $t7, $t7, -WIDTH
		j    dccsh_hitbox_check
		
dc_check_bubbles:
	la   $t0, bubble1	# $t0 = *bubble1
	li   $t2, 0		# $t2 = i = 0
	dccb_loop:
		beq  $t2, 2, dc_done
		lw   $t1, 0($t0)	# $t1 = bubble.state
		bne  $t1, 1, dccb_update # if state!=1, invisible/popped; skip it
		
		# Only pop bubble and bounce crab if crab was falling
		lw   $t1, 8($s1)	# $t1 = crab.jump_timer
		bgtz $t1, dc_done	# if jump_timer > 0, dont do bubble collisions
					# Otherwise, crab is falling down
						
		lw   $t1, 4($t0)	# $t1 = bubble.pos
		
		addi $t6, $t8, 2288	# $t6 = lower left hitbox
		addi $t7, $t9, 2320	# $t7 = lower right hitbox
		li   $t3, 0		# $t3 = j =0
		dccb_hitbox_check:
			beq  $t3, 10, dccb_update	# Exit loop after 10 rows checked
			# if bubble.pos not within $t6 - $t7, check next row up
			bgt  $t1, $t7, dccb_hitbox_update
			blt  $t1, $t6, dccb_hitbox_update
			
			# Otherwise, crab has collided with a bubble.
			sw   $s6, 0($t0)	# set bubble.state to level timer
			lw   $a0, 4($t0)	# $a0 = bubble.pos
			jal  unstamp_bubble
			li   $t1, BUBBLE_UP_DIST
			sw   $t1, 8($s1)	# set crab.jump_timer to BUBBLE_UP_DIST
			li   $t1, 2
			sw   $t1, 4($s1)	# set crab.state to 2 (jumping)
			
			# Don't check other bubble
			j    dc_done
			
		dccb_hitbox_update:
			addi $t3, $t3, 1	# $t3 = j + 1
			addi $t6, $t6, -WIDTH	# iterate over next row up
			addi $t7, $t7, -WIDTH
			j    dccb_hitbox_check

	dccb_update:
		addi $t2, $t2, 1	# $t2 = i + 1
		addi $t0, $t0, 8	# $t0 = *bubble2
		j    dccb_loop

dc_done:
	# Restore $ra
	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	
	# Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


#########################################################################
#	INITIALIZE LEVEL FUNCTIONS					#
#########################################################################


# gen_level_0():
# 	Sets up level 0 details in global structs
gen_level_0:
	li   $s5, SEA_COL_7	# Store current BG color
	
	# crab data
	addi $t0, $gp, INIT_POS
	sw   $t0, 0($s1)	# crab.pos = addr($gp) + INIT_POS
	li   $t0, 0
	sw   $t0, 4($s1)	# crab.state = walk_0
	sw   $t0, 8($s1)	# crab.jump_timer = 0
	
	# piranha data
	la   $t1, piranha1	# $t1 = piranha1
	li   $t0, 0
	sw   $t0, 0($t1)	# piranha1.state = invisible
	la   $t1, piranha2	# $t1 = piranha2
	li   $t0, 0
	sw   $t0, 0($t1)	# piranha2.state = invisible
	
	# pufferfish data
	la   $t1, pufferfish
	li   $t0, 0
	sw   $t0, 0($t1)	# pufferfish.state = invisible
	
	# clam data
	la   $t1, clam
	li   $t0, 0
	sw   $t0, 0($t1)	# clam.state = invisible
	
	# seahorse data
	la   $t1, seahorse
	li   $t0, 0
	sw   $t0, 0($t1)	# seahorse.state = invisible
	
	# bubble data
	la   $t1, bubble1
	li   $t0, 0
	sw   $t0, 0($t1)	# bubble1.state = invisible
	la   $t1, bubble2
	li   $t0, 0
	sw   $t0, 0($t1)	# bubble2.state = invisible
	
	# Platforms
	la   $t1, platforms
	addi $t0, $gp, 25600 # = platform_1.pos
	sw   $t0, 0($t1)
	li   $t0, 7 # = platform_1.len
	sw   $t0, 4($t1)
	addi $t0, $gp, 21660 # = platform_2.pos
	sw   $t0, 8($t1)
	li   $t0, 6 # = platform_2.len
	sw   $t0, 12($t1)
	addi $t0, $gp, 15104 # = platform_3.pos
	sw   $t0, 16($t1)
	li   $t0, 10 # = platform_3.len
	sw   $t0, 20($t1)	
	addi $t0, $gp, 7976 # = platform_4.pos
	sw   $t0, 24($t1)	
	li   $t0, 4 # = platform_4.len
	sw   $t0, 28($t1)	
	addi $t0, $gp, 2908 # = platform_5.pos
	sw   $t0, 32($t1)	
	li   $t0, 5 # = platform_5.len
	sw   $t0, 36($t1)	
	addi $t0, $gp, 31744 # = platform_6.pos
	sw   $t0, 40($t1)
	li   $t0, 16 # = platform_6.len
	sw   $t0, 44($t1)
	li   $t0, 0 # = platform_7.len
	sw   $t0, 52($t1)
	
	# Sea Stars
	la   $t1, stars
	li   $t0, 1 # = star_1.state = visible
	sw   $t0, 0($t1)
	add  $t0, $gp, 24408 # = star_1.pos
	sw   $t0, 4($t1)
	li   $t0, 1 # = star_2.state = visible
	sw   $t0, 8($t1)
	add  $t0, $gp, 21108 # = star_2.pos
	sw   $t0, 12($t1)
	li   $t0, 1 # = star_3.state = visible
	sw   $t0, 16($t1)
	add  $t0, $gp, 19872 # = star_3.pos
	sw   $t0, 20($t1)
	li   $t0, 1 # = star_4.state = visible
	sw   $t0, 24($t1)
	add  $t0, $gp, 7240 # = star_4.pos
	sw   $t0, 28($t1)
	li   $t0, 0 # = star_5.state = invisible
	sw   $t0, 32($t1)
	li   $t0, 0 # = star_6.state = invisible
	sw   $t0, 40($t1)
	li   $t0, 0 # = star_7.state = invisible
	sw   $t0, 48($t1)
	li   $t0, 0 # = star_8.state = invisible
	sw   $t0, 56($t1)
	
	# Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


#  gen_next_level():
#	Sets up the structs according to the level specified in $s0
#	Assumes $s0 is positive (eg. we have branched out of main loop if reached end level)
gen_next_level:	
	# Calculate time bonus for level
	li   $t1, MAX_TIME
	sub  $t1, $t1, $s6	# $t1 = MAX_TIME - (time to complete level)
	blez $t1, gen_level_select # Skip if negative
	sra  $t1, $t1, 2	# $t1 = $t1/4
	add  $s3, $s3, $t1	# Add time bonus to score

gen_level_select:
	# if $s0 has reached -1, trigger Win screen
	bltz $s0, win

	# Branch to correct level setup:
	beq  $s0, 6, gen_level_1
	beq  $s0, 5, gen_level_2
	beq  $s0, 4, gen_level_3
	beq  $s0, 3, gen_level_4
	beq  $s0, 2, gen_level_5
	beq  $s0, 1, gen_level_6
	beq  $s0, 0, gen_level_7

gen_level_1: ##### LEVEL ONE #####
	li   $s5, SEA_COL_6	# Store current BG color
	
	# crab data
	lw   $t0, 0($s1)
	add  $t0, $t0, 28928	# Move crab down to bottom of display
	sw   $t0, 0($s1)
	
	# seahorse data
	la   $t1, seahorse
	li   $t0, 1 # = seahorse.state = visible
	sw   $t0, 0($t1) 
	addi $t0, $gp, 13360 # = seahorse.position
	sw   $t0, 4($t1)
	
	# Bubbles
	la   $t1, bubble1
	li   $t0, 1 # = bubble1.state
	sw   $t0, 0($t1)
	addi $t0, $gp, 27604 # = bubble1.pos
	sw   $t0, 4($t1)
	la   $t1, bubble2
	li   $t0, 1 # = bubble2.state
	sw   $t0, 0($t1)
	addi $t0, $gp, 27436 # = bubble2.pos
	sw   $t0, 4($t1)

	# Platforms
	la   $t1, platforms
	addi $t0, $gp, 31836 # = platform_1.pos <-- Bottom Platform
	sw   $t0, 0($t1)
	li   $t0, 5 # = platform_1.len
	sw   $t0, 4($t1)
	addi $t0, $gp, 20572 # = platform_2.pos
	sw   $t0, 8($t1)
	li   $t0, 5 # = platform_2.len
	sw   $t0, 12($t1)
	addi $t0, $gp, 13692 # = platform_3.pos
	sw   $t0, 16($t1)
	li   $t0, 8 # = platform_3.len
	sw   $t0, 20($t1)	
	addi $t0, $gp, 6912 # = platform_4.pos
	sw   $t0, 24($t1)	
	li   $t0, 7 # = platform_4.len
	sw   $t0, 28($t1)	
	addi $t0, $gp, 3740 # = platform_5.pos <-- Top Platform
	sw   $t0, 32($t1)	
	li   $t0, 4 # = platform_5.len
	sw   $t0, 36($t1)	
	li   $t0, 0 # = platform_6.len
	sw   $t0, 44($t1)	
	
	# Sea Stars
	la   $t1, stars
	li   $t0, 1 # = star_1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 19756 # = star_1.pos
	sw   $t0, 4($t1)
	li   $t0, 1 # = star_2.state = visible
	sw   $t0, 8($t1)
	addi $t0, $gp, 19924 # = star_2.pos
	sw   $t0, 12($t1)
	li   $t0, 1 # = star_3.state = visible
	sw   $t0, 16($t1)
	addi $t0, $gp, 27776 # = star_3.pos
	sw   $t0, 20($t1)
	li   $t0, 1 # = star_4.state = visible
	sw   $t0, 24($t1)
	addi $t0, $gp, 11176 # = star_4.pos
	sw   $t0, 28($t1)
	li   $t0, 1 # = star_5.state = visible
	sw   $t0, 32($t1)
	addi $t0, $gp, 8344 # = star_5.pos
	sw   $t0, 36($t1)
	li   $t0, 1 # = star_6.state = visible
	sw   $t0, 40($t1)
	addi $t0, $gp, 6008 # = star_6.pos
	sw   $t0, 44($t1)

	jr   $ra
	
gen_level_2: ##### LEVEL TWO #####
	li   $s5, SEA_COL_5	# Store current BG color

	# crab data
	lw   $t0, 0($s1)
	add  $t0, $t0, 28160	# Move crab down to bottom of display
	sw   $t0, 0($s1)
	
	# seahorse data
	la   $t1, seahorse
	li   $t0, 0 # = seahorse.state = invisible
	sw   $t0, 0($t1) 
		
	# clam data
	la   $t1, clam
	li   $t0, 1 # = clam.state = open
	sw   $t0, 0($t1)
	addi $t0, $gp, 15152 # = clam.pos
	sw   $t0, 4($t1)
	
	# Bubbles
	la   $t1, bubble1
	li   $t0, 0 # = bubble1.state = invisible
	sw   $t0, 0($t1)
	la   $t1, bubble2
	li   $t0, 0 # = bubble2.state = invisible
	sw   $t0, 0($t1)
	
	# pufferfish data
	la   $t1, pufferfish
	li   $t0, 1 # = pufferfish.state = ascending
	sw   $t0, 0($t1)	
	addi $t0, $gp, 13448
	sw   $t0, 4($t1)

	# Platforms
	la   $t1, platforms
	addi $t0, $gp, 3676 # = platform_1.pos <- Top Platform
	sw   $t0, 0($t1)
	li   $t0, 10 # = platform_1.len
	sw   $t0, 4($t1)
	addi $t0, $gp, 10956 # = platform_2.pos
	sw   $t0, 8($t1)
	li   $t0, 3 # = platform_2.len
	sw   $t0, 12($t1)
	addi $t0, $gp, 15360 # = platform_3.pos
	sw   $t0, 16($t1)
	li   $t0, 7 # = platform_3.len
	sw   $t0, 20($t1)	
	addi $t0, $gp, 18108 # = platform_4.pos
	sw   $t0, 24($t1)	
	li   $t0, 4 # = platform_4.len
	sw   $t0, 28($t1)	
	addi $t0, $gp, 25020 # = platform_5.pos
	sw   $t0, 32($t1)	
	li   $t0, 3 # = platform_5.len
	sw   $t0, 36($t1)
	addi $t0, $gp, 31900 # = platform_6.pos <-- Bottom Platform
	sw   $t0, 40($t1)	
	li   $t0, 4 # = platform_6.len
	sw   $t0, 44($t1)
	

	# Sea Stars
	la   $t1, stars
	li   $t0, 1 # = star_1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 24276 # = star_1.pos
	sw   $t0, 4($t1)
	li   $t0, 1 # = star_2.state = visible
	sw   $t0, 8($t1)
	addi $t0, $gp, 17380 # = star_2.pos
	sw   $t0, 12($t1)
	li   $t0, 1 # = star_3.state = visible
	sw   $t0, 16($t1)
	addi $t0, $gp, 10212 # = star_3.pos
	sw   $t0, 20($t1)
	li   $t0, 1 # = star_4.state = visible
	sw   $t0, 24($t1)
	addi $t0, $gp, 14348 # = star_4.pos
	sw   $t0, 28($t1)
	li   $t0, 1 # = star_5.state = visible
	sw   $t0, 32($t1)
	addi $t0, $gp, 14420 # = star_5.pos
	sw   $t0, 36($t1)
	li   $t0, 0 # = star_6.state = invisible
	sw   $t0, 40($t1)

	jr   $ra
	
gen_level_3: ##### LEVEL THREE #####
	li   $s5, SEA_COL_4	# Store current BG color

	# crab data
	lw   $t0, 0($s1)
	add  $t0, $t0, 28160	# Move crab down to bottom of display
	sw   $t0, 0($s1)
	
	# pufferfish data
	la   $t1, pufferfish
	li   $t0, 0 # = pufferfish.state = invisible
	sw   $t0, 0($t1)
	
	# clam data
	la   $t1, clam
	li   $t0, 0 # = clam.state = invisible
	sw   $t0, 0($t1)
	
	# Bubbles
	la   $t1, bubble1
	li   $t0, 1 # = bubble1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 8756 # = bubble1.position
	sw   $t0, 4($t1)
	
	# piranha data
	la   $t1, piranha1
	li   $t0, 1 # = piranha1.state = left-facing
	sw   $t0, 0($t1)
	addi $t0, $gp, 18224 # = piranha1.position
	sw   $t0, 4($t1)
	la   $t1, piranha2
	li   $t0, 2 # = piranha2.state = right-facing
	sw   $t0, 0($t1)
	addi $t0, $gp, 24904 # = piranha2.position
	sw   $t0, 4($t1)
	
	# seahorse data
	la   $t1, seahorse
	li   $t0, 1 # = seahorse.state = visible
	sw   $t0, 0($t1) 
	addi $t0, $gp, 9416 # = seahorse.position
	sw   $t0, 4($t1)
	
	# Platforms
	la   $t1, platforms
	addi $t0, $gp, 31836 # = platform_1.pos <- Bottom Platform
	sw   $t0, 0($t1)
	li   $t0, 10 # = platform_1.len
	sw   $t0, 4($t1)
	addi $t0, $gp, 25600 # = platform_2.pos
	sw   $t0, 8($t1)
	li   $t0, 7 # = platform_2.len
	sw   $t0, 12($t1)
	addi $t0, $gp, 18944 # = platform_3.pos
	sw   $t0, 16($t1)
	li   $t0, 8 # = platform_3.len
	sw   $t0, 20($t1)	
	addi $t0, $gp, 12328 # = platform_4.pos
	sw   $t0, 24($t1)	
	li   $t0, 6 # = platform_4.len
	sw   $t0, 28($t1)	
	addi $t0, $gp, 3180 # = platform_5.pos <-- Top Platform
	sw   $t0, 32($t1)	
	li   $t0, 9 # = platform_5.len
	sw   $t0, 36($t1)	
	li   $t0, 0 # = platform_6.len
	sw   $t0, 44($t1)
	
	# Sea Stars
	la   $t1, stars
	li   $t0, 1 # = star_1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 12232 # = star_1.position
	sw   $t0, 4($t1)
	li   $t0, 1 # = star_2.state = visible
	sw   $t0, 8($t1)
	addi $t0, $gp, 14792 # = star_2.position
	sw   $t0, 12($t1)
	li   $t0, 1 # = star_3.state = visible
	sw   $t0, 16($t1)
	addi $t0, $gp, 17352 # = star_3.position
	sw   $t0, 20($t1)
	li   $t0, 1 # = star_4.state = visible
	sw   $t0, 24($t1)
	addi $t0, $gp, 19912 # = star_4.position
	sw   $t0, 28($t1)
	li   $t0, 1 # = star_5.state = visible
	sw   $t0, 32($t1)
	addi $t0, $gp, 22472 # = star_5.position
	sw   $t0, 36($t1)
	li   $t0, 0 # = star_6.state = invisible
	sw   $t0, 40($t1)
	li   $t0, 0 # = star_7.state = invisible
	sw   $t0, 48($t1)
	li   $t0, 0 # = star_8.state = invisible
	sw   $t0, 56($t1)
	
	jr   $ra
	
gen_level_4: ##### LEVEL FOUR #####
	li   $s5, SEA_COL_3	# Store current BG color

	# crab data
	lw   $t0, 0($s1)
	add  $t0, $t0, 28672	# Move crab down to bottom of display
	sw   $t0, 0($s1)
	
	# Bubbles
	la   $t1, bubble1
	li   $t0, 1 # = bubble1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 20028 # = bubble1.position
	sw   $t0, 4($t1)
	la   $t1, bubble2
	li   $t0, 1 # = bubble2.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 14292 # = bubble2.position
	sw   $t0, 4($t1)
	
	# piranha data
	la   $t1, piranha1
	li   $t0, 1 # = piranha1.state = left-facing
	sw   $t0, 0($t1)
	addi $t0, $gp, 17780 # = piranha1.position
	sw   $t0, 4($t1)
	la   $t1, piranha2
	li   $t0, 0 # = piranha2.state = invisible
	sw   $t0, 0($t1)
	
	# pufferfish data
	la   $t1, pufferfish
	li   $t0, 2 # = pufferfish.state = descending
	sw   $t0, 0($t1)
	addi $t0, $gp, 8084 # = pufferfish.position
	sw   $t0, 4($t1)
	
	# seahorse data
	la   $t1, seahorse
	li   $t0, 0 # = seahorse.state = invisible
	sw   $t0, 0($t1) 
	
	# clam data
	la   $t1, clam
	li   $t0, 1 # = clam.state = open
	sw   $t0, 0($t1)
	addi $t0, $gp, 6860 # = clam.pos
	sw   $t0, 4($t1)

	# Platforms
	la   $t1, platforms
	addi $t0, $gp, 31852 # = platform_1.pos <-- Bottom Platform
	sw   $t0, 0($t1)
	li   $t0, 9 # = platform_1.len
	sw   $t0, 4($t1)
	addi $t0, $gp, 24576 # = platform_2.pos
	sw   $t0, 8($t1)
	li   $t0, 10 # = platform_2.len
	sw   $t0, 12($t1)
	addi $t0, $gp, 18588 # = platform_3.pos
	sw   $t0, 16($t1)
	li   $t0, 4 # = platform_3.len
	sw   $t0, 20($t1)	
	addi $t0, $gp, 12800 # = platform_4.pos
	sw   $t0, 24($t1)	
	li   $t0, 6 # = platform_4.len
	sw   $t0, 28($t1)	
	addi $t0, $gp, 7084 # = platform_5.pos
	sw   $t0, 32($t1)	
	li   $t0, 5 # = platform_5.len
	sw   $t0, 36($t1)
	addi $t0, $gp, 7696 # = platform_6.pos
	sw   $t0, 40($t1)
	li   $t0, 2 # = platform_6.len
	sw   $t0, 44($t1)
	addi $t0, $gp, 2048 # = platform_7.pos <-- Top Platform
	sw   $t0, 48($t1)
	li   $t0, 4 # = platform_7.len
	sw   $t0, 52($t1)		

	# Sea Stars
	la   $t1, stars
	li   $t0, 1 # = star_1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 6944 # = star_1.position
	sw   $t0, 4($t1)
	li   $t0, 1 # = star_2.state = visible
	sw   $t0, 8($t1)
	addi $t0, $gp, 17852 # = star_2.position
	sw   $t0, 12($t1)
	li   $t0, 1 # = star_3.state = visible
	sw   $t0, 16($t1)
	addi $t0, $gp, 30620 # = star_3.position
	sw   $t0, 20($t1)
	li   $t0, 1 # = star_4.state = visible
	sw   $t0, 24($t1)
	addi $t0, $gp, 30660 # = star_4.position
	sw   $t0, 28($t1)
	li   $t0, 1 # = star_5.state = visible
	sw   $t0, 32($t1)
	addi $t0, $gp, 30700 # = star_5.position
	sw   $t0, 36($t1)
	li   $t0, 0 # = star_6.state = invisible
	sw   $t0, 40($t1)
	li   $t0, 0 # = star_7.state = invisible
	sw   $t0, 48($t1)
	li   $t0, 0 # = star_8.state = invisible
	sw   $t0, 56($t1)
	
	jr   $ra
	
gen_level_5: ##### LEVEL FIVE #####
	li   $s5, SEA_COL_2	# Store current BG color

	# crab data
	lw   $t0, 0($s1)
	add  $t0, $t0, 29696	# Move crab down to bottom of display
	sw   $t0, 0($s1)
	
	# Bubbles
	la   $t1, bubble1
	li   $t0, 1 # = bubble1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 27208 # = bubble1.position
	sw   $t0, 4($t1)
	la   $t1, bubble2
	li   $t0, 1 # = bubble2.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 22944 # = bubble2.position
	sw   $t0, 4($t1)
	
	# clam data
	la   $t1, clam
	li   $t0, 0 # = clam.state = invisible
	sw   $t0, 0($t1)
	
	# piranha data
	la   $t1, piranha1
	li   $t0, 2 # = piranha1.state = right-facing
	sw   $t0, 0($t1)
	addi $t0, $gp, 15148 # = piranha1.position
	sw   $t0, 4($t1)
	
	# pufferfish data
	la   $t1, pufferfish
	li   $t0, 0 # = pufferfish.state = invisible
	sw   $t0, 0($t1)
	
	# seahorse data
	la   $t1, seahorse
	li   $t0, 1 # = seahorse.state = visible
	sw   $t0, 0($t1) 
	addi $t0, $gp, 17956 # = seahorse.position
	sw   $t0, 4($t1)

	# Sea Stars
	la   $t1, stars
	li   $t0, 1 # = star_1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 6080 # = star_1.pos
	sw   $t0, 4($t1)
	li   $t0, 1 # = star_2.state = visible
	sw   $t0, 8($t1)
	addi $t0, $gp, 9768 # = star_2.pos
	sw   $t0, 12($t1)
	li   $t0, 1 # = star_3.state = visible
	sw   $t0, 16($t1)
	addi $t0, $gp, 9808 # = star_3.pos
	sw   $t0, 20($t1)
	li   $t0, 1 # = star_4.state = visible
	sw   $t0, 24($t1)
	addi $t0, $gp, 9848 # = star_4.pos
	sw   $t0, 28($t1)
	li   $t0, 1 # = star_5.state = visible
	sw   $t0, 32($t1)
	addi $t0, $gp, 20516 # = star_5.pos
	sw   $t0, 36($t1)
	li   $t0, 0 # = star_6.state = invisible
	sw   $t0, 40($t1)
	li   $t0, 0 # = star_7.state = invisible
	sw   $t0, 48($t1)
	li   $t0, 0 # = star_8.state = invisible
	sw   $t0, 56($t1)
	
	# Platforms
	la   $t1, platforms
	addi $t0, $gp, 31744 # = platform_1.pos <-- Bottom Platform 
	sw   $t0, 0($t1)
	li   $t0, 4 # = platform_1.len
	sw   $t0, 4($t1)
	addi $t0, $gp, 16332 # = platform_2.pos
	sw   $t0, 8($t1)
	li   $t0, 3 # = platform_2.len
	sw   $t0, 12($t1)
	addi $t0, $gp, 10496 # = platform_3.pos
	sw   $t0, 16($t1)
	li   $t0, 9 # = platform_3.len
	sw   $t0, 20($t1)	
	addi $t0, $gp, 7096 # = platform_4.pos
	sw   $t0, 24($t1)	
	li   $t0, 1 # = platform_4.len
	sw   $t0, 28($t1)	
	addi $t0, $gp, 2144 # = platform_5.pos <-- Top Platform
	sw   $t0, 32($t1)	
	li   $t0, 3 # = platform_5.len
	sw   $t0, 36($t1)
	li   $t0, 0 # = platform_6.len
	sw   $t0, 44($t1)
	li   $t0, 0 # = platform_7.len
	sw   $t0, 52($t1)
	
	jr   $ra
	
gen_level_6: ##### LEVEL SIX #####
	li   $s5, SEA_COL_1	# Store current BG color

	# crab data
	lw   $t0, 0($s1)
	add  $t0, $t0, 29696	# Move crab down to bottom of display
	sw   $t0, 0($s1)
	
	# seahorse data
	la   $t1, seahorse
	li   $t0, 0 # = seahorse.state = invisible
	sw   $t0, 0($t1)
	
	# piranha data
	la   $t1, piranha1
	li   $t0, 2 # = piranha1.state = right-facing
	sw   $t0, 0($t1)
	addi $t0, $gp, 24016 # = piranha1.position
	sw   $t0, 4($t1)
	la   $t1, piranha2
	li   $t0, 1 # = piranha2.state = left-facing
	sw   $t0, 0($t1)
	addi $t0, $gp, 10620 # = piranha2.position
	sw   $t0, 4($t1)
	
	# pufferfish data
	la   $t1, pufferfish
	li   $t0, 2 # = pufferfish.state = descending
	sw   $t0, 0($t1)
	addi $t0, $gp, 13700 # = pufferfish.position
	sw   $t0, 4($t1)
	
	# Bubbles
	la   $t1, bubble1
	li   $t0, 1 # = bubble1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 9860 # = bubble1.position
	sw   $t0, 4($t1)
	la   $t1, bubble2
	li   $t0, 0 # = bubble2.state = invisible
	sw   $t0, 0($t1)
	
	# Platforms
	la   $t1, platforms
	addi $t0, $gp, 31840 # = platform_1.pos <-- Bottom Platform 
	sw   $t0, 0($t1)
	li   $t0, 3 # = platform_1.len
	sw   $t0, 4($t1)
	addi $t0, $gp, 24576 # = platform_2.pos
	sw   $t0, 8($t1)
	li   $t0, 4 # = platform_2.len
	sw   $t0, 12($t1)
	addi $t0, $gp, 18532 # = platform_3.pos
	sw   $t0, 16($t1)
	li   $t0, 4 # = platform_3.len
	sw   $t0, 20($t1)	
	addi $t0, $gp, 11452 # = platform_4.pos
	sw   $t0, 24($t1)	
	li   $t0, 4 # = platform_4.len
	sw   $t0, 28($t1)	
	addi $t0, $gp, 3172 # = platform_5.pos <-- Top Platform
	sw   $t0, 32($t1)	
	li   $t0, 4 # = platform_5.len
	sw   $t0, 36($t1)
	li   $t0, 0 # = platform_6.len
	sw   $t0, 44($t1)
	li   $t0, 0 # = platform_7.len
	sw   $t0, 52($t1)

	# Sea Stars
	la   $t1, stars
	li   $t0, 1 # = star_1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 17796 # = star_1.pos
	sw   $t0, 4($t1)
	li   $t0, 1 # = star_2.state = visible
	sw   $t0, 8($t1)
	addi $t0, $gp, 15236 # = star_2.pos
	sw   $t0, 12($t1)
	li   $t0, 1 # = star_3.state = visible
	sw   $t0, 16($t1)
	addi $t0, $gp, 12676 # = star_3.pos
	sw   $t0, 20($t1)
	li   $t0, 1 # = star_4.state = visible
	sw   $t0, 24($t1)
	addi $t0, $gp, 23584 # = star_4.pos
	sw   $t0, 28($t1)
	li   $t0, 1 # = star_5.state = visible
	sw   $t0, 32($t1)
	addi $t0, $gp, 10716 # = star_5.pos
	sw   $t0, 36($t1)
	li   $t0, 0 # = star_6.state = invisible
	sw   $t0, 40($t1)
	li   $t0, 0 # = star_7.state = invisible
	sw   $t0, 48($t1)
	li   $t0, 0 # = star_8.state = invisible
	sw   $t0, 56($t1)
	
	jr   $ra
	
gen_level_7: ##### LEVEL SEVEN #####
	li   $s5, SEA_COL_0	# Store current BG color

	# crab data
	lw   $t0, 0($s1)
	add  $t0, $t0, 28672	# Move crab down to bottom of display
	sw   $t0, 0($s1)
	
	# seahorse data
	la   $t1, seahorse
	li   $t0, 1 # = seahorse.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 11732 # = seahorse.position
	sw   $t0, 4($t1)
	
	# piranha data
	la   $t1, piranha1
	li   $t0, 1 # = piranha1.state = left-facing
	sw   $t0, 0($t1)
	addi $t0, $gp, 17860 # = piranha1.position
	sw   $t0, 4($t1)
	la   $t1, piranha2
	li   $t0, 0 # = piranha2.state = invisible
	sw   $t0, 0($t1)
	
	# pufferfish data
	la   $t1, pufferfish
	li   $t0, 1 # = pufferfish.state = ascending
	sw   $t0, 0($t1)
	addi $t0, $gp, 25288 # = pufferfish.position
	sw   $t0, 4($t1)
	
	# Bubbles
	la   $t1, bubble1
	li   $t0, 1 # = bubble1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 9320 # = bubble1.position
	sw   $t0, 4($t1)
	
	# clam data
	la   $t1, clam
	li   $t0, 1 # = clam.state = open
	sw   $t0, 0($t1)
	addi $t0, $gp, 5084 # = clam.position
	sw   $t0, 4($t1)
	
	# Platforms
	la   $t1, platforms
	addi $t0, $gp, 31844 # = platform_1.pos <-- Bottom Platform 
	sw   $t0, 0($t1)
	li   $t0, 4 # = platform_1.len
	sw   $t0, 4($t1)
	addi $t0, $gp, 25120 # = platform_2.pos
	sw   $t0, 8($t1)
	li   $t0, 8 # = platform_2.len
	sw   $t0, 12($t1)
	addi $t0, $gp, 18540 # = platform_3.pos
	sw   $t0, 16($t1)
	li   $t0, 8 # = platform_3.len
	sw   $t0, 20($t1)	
	addi $t0, $gp, 12288 # = platform_4.pos
	sw   $t0, 24($t1)	
	li   $t0, 6 # = platform_4.len
	sw   $t0, 28($t1)	
	addi $t0, $gp, 5292 # = platform_5.pos
	sw   $t0, 32($t1)	
	li   $t0, 5 # = platform_5.len
	sw   $t0, 36($t1)
	addi $t0, $gp, 2560 # = platform_6.pos
	sw   $t0, 40($t1)
	li   $t0, 4 # = platform_6.len
	sw   $t0, 44($t1)
	li   $t0, 0 # = platform_7.len
	sw   $t0, 52($t1)

	# Sea Stars
	la   $t1, stars
	li   $t0, 1 # = star_1.state = visible
	sw   $t0, 0($t1)
	addi $t0, $gp, 24376 # = star_1.pos
	sw   $t0, 4($t1)
	li   $t0, 1 # = star_2.state = visible
	sw   $t0, 8($t1)
	addi $t0, $gp, 24416 # = star_2.pos
	sw   $t0, 12($t1)
	li   $t0, 1 # = star_3.state = visible
	sw   $t0, 16($t1)
	addi $t0, $gp, 24456 # = star_3.pos
	sw   $t0, 20($t1)
	li   $t0, 1 # = star_4.state = visible
	sw   $t0, 24($t1)
	addi $t0, $gp, 17796 # = star_4.pos
	sw   $t0, 28($t1)
	li   $t0, 1 # = star_5.state = visible
	sw   $t0, 32($t1)
	addi $t0, $gp, 17836 # = star_5.pos
	sw   $t0, 36($t1)
	li   $t0, 1 # = star_6.state = visible
	sw   $t0, 40($t1)
	addi $t0, $gp, 17876 # = star_6.pos
	sw   $t0, 44($t1)
	li   $t0, 1 # = star_7.state = visible
	sw   $t0, 48($t1)
	addi $t0, $gp, 11552 # = star_7.pos
	sw   $t0, 52($t1)
	li   $t0, 1 # = star_8.state = visible
	sw   $t0, 56($t1)
	addi $t0, $gp, 11592 # = star_8.pos
	sw   $t0, 60($t1)

	jr   $ra
# ---------------------------------------------------------------------------------------
