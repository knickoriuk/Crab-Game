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
# Which milestones have been reached in this submission? 
# (See the assignment handout for descriptions of the milestones) 
# - Milestone 1/2/3 (choose the one the applies) 
# 
# Which approved features have been implemented for milestone 3? 
# (See the assignment handout for the list of additional features) 
# 1. Moving Objects (Piranhas, Pufferfish) 
# 2. Disappearing Platforms (Bubbles)
# 3. Different Levels
# 4. Fail Condition
# 5. Win Condition
# 6. Score
# 7. Animated Sprites (Crab, Clam, Bubble)
# 8. (Bonus) Varying light levels, sprites get brighter as you progress upwards
# 
# Link to video demonstration for final submission: 
# - (insert YouTube / MyMedia / other URL here). Make sure we can view it! 
# 
# Are you OK with us sharing the video with people outside course staff? 
# - yes / no / yes, and please share this project github link as well! 
# 
# Any additional information that the TA needs to know: 
# - Playing this game on different devices, I noticed a serious difference in 
#   difficulty. My desktop was a lot harder to play on than my laptop. This could
#   be either because it has a faster processor or because there is more of an input 
#   delay on my keyboard. Anyway, increase SLEEP_DUR a bit if it seems hard. 
# - Also noticed that MARS gets slow after running for a while, until restarted.
# 
#####################################################################

.eqv	WIDTH		256		# Width of display
.eqv	SLEEP_DUR	40		# Sleep duration between loops
.eqv	INIT_POS	31640		# Initial position of the crab (offset from $gp)
.eqv	KEYSTROKE	0xffff0000	# Address storing keystrokes & values
.eqv	SEA_COL_4	0x000b3e8a	# Sea colour, darkest
.eqv	SEA_COL_3	0x000d47a1	#	:
.eqv	SEA_COL_2	0x001052b5	#	:
.eqv	SEA_COL_1	0x00125dcc	#	:
.eqv	SEA_COL_0	0x001467db	# Sea colour, lightest
.eqv	DARKNESS	0x00050505	# amount to darken colours by, per level
.eqv	NUM_STARS	8		# Maximum number of sea stars		
.eqv	NUM_PLATFORMS	6		# Maximum number of platforms
.eqv	CRAB_UP_DIST	7		# Duration of crab jump ascension
.eqv	HORIZ_DIST	8		# Distance moved left/right per screen refresh
.eqv	UPPER_LIMIT	0x10009000	# Height that, if surpassed, moves to next level 
.eqv	POP_TIME	10		# Number of screen refreshes before a popped bubble dissipates
.eqv	BUBBLE_REGEN	100		# Number of screen refreshes before bubble regenerates. BUBBLE_REGEN > POP_TIME
.eqv	MAX_TIME	512		# Max time to complete level and still get time bonus
.eqv	STAR_PTS	10		# Number of points earned per sea star collected
.eqv	CLAM_PTS	100		# Number of points earned per clam collected
.eqv	SEAHORSE_PTS	100		# Number of points earned per seahorse collected	

.data
frame_buffer: 	.space		32768
crab:		.space		12
# struct crab {
#	int position; 	# holds address of pixel it is at
#	int state; 	# 0-walk_0, 1-walk_1, 2-jump/fall, 3-dead
#	int jump_timer; # counts down frames of rising, before falling down
# } crab;
world:		.space		8
# struct world {
#	int level:	# 0,1,2,3,4,5,6... However many I end up making
#	int darkness:	# 4, 3, 2, 1, 0
# }
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
platforms:	.space		48	# Stores pairs of (position, length) for platforms
					# length==0 implies the platform does not exist
					# Set = to NUM_PLATFORMS * 8

.text
.globl main

########## Register Assignment for main() ##########
# $s0 - `world` data pointer
# $s1 - `crab` data pointer
# $s2 - Last crab location
# $s3 - Score
# $s4 -
# $s5 - background colour
# $s6 - timer: number of screen refreshes since level start
# $s7 - dead/alive flag: 0=alive, 1=dead
# $t0 - temporary values

########## Initialize Game Values ##########
main:	la   $s0, world
	la   $s1, crab
	li   $s3, 0
	li   $s5, SEA_COL_4
	li   $s6, 0
	li   $s7, 0
	
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

next_level: # Update `world` struct:
	lw   $t0, 0($s0)	# $t0 = world.level
	addi $t0, $t0, 1	# $t0 = world.level + 1
	sw   $t0, 0($s0)	# world.level = world.level + 1
	
	# Setup data for next level
	jal  gen_next_level
	li   $s6, 0		# Reset timer to 0
	
	# Display new level
	jal  generate_background
	jal  stamp_platforms
	
########## Update Display ##########

update_display:
	jal  do_jumps		# Move crab up or down
	
	# Flicker prevention: only unstamp crab if it moved
	lw   $t9, 0($s1)		# $t9 = crab.position
	beq  $s2, $t9, update_display2	# if new pos == old pos, skip next line
	jal  unstamp_crab		# remove old crab from display

update_display2:
	# Entities, if they move, are removed from display in update_positions()
	jal  update_positions	# Update positions of all entities
	jal  stamp_platforms
	jal  stamp_bubble
	jal  stamp_stars
	jal  stamp_clam
	jal  stamp_seahorse
	jal  stamp_crab	
	jal  stamp_piranha
	jal  stamp_pufferfish
	jal  display_score
	
	jal  detect_collisions
	
########## Game Over? ##########

	bne  $s7, 1, sleep	# If alive, skip this step
	li   $s5, 0		# set bg color to black
	jal generate_background
	# TODO: Show game over screen
	
game_over_loop:	
	li   $t9, KEYSTROKE
	lw   $t9, 0($t9) 	# $t0 = 1 if key hit, 0 otherwise
	
	li   $a0, SLEEP_DUR	# Sleep a bit
	li   $v0, 32
	syscall
	
	beqz $t9, game_over_loop # loop until a key is pressed
	li   $t9, KEYSTROKE
	lw   $t9, 4($t9)  	 # $t9 = last key hit 
	bne  $t9, 0x70, game_over_loop # if `p` was not pressed, loop again
	j    main
	
########## Sleep and Repeat ##########

sleep:	addi $s6, $s6, 1	# add 1 to timer
	# Sleep for `SLEEP_DUR` milliseconds
	li   $a0, SLEEP_DUR
	li   $v0, 32
	syscall
	
	j    main_loop	# Jump back to main loop, checking for next key press

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
	# TODO: some kind of display/notification
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
	
dj_down: # Must first determine if we are on/would fall through a platform
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
	move $a0, $t2		# Store old position in $a0
	addi $t2, $t2, WIDTH
	sw   $t2, 4($t0)	# puffer.pos = 1 pixel below old puffer.pos
	jal  unstamp_pufferfish	# Remove puffer from display
	la   $t0, pufferfish	# Re-obtain puffer position after function call
	lw   $t2, 4($t0)	# $t2 = new position
	addi $t7, $gp, 32512	# If new pos is at bottom of display, change its direction
	blt  $t2, $t7, update_piranha1
	li   $t7, 1
	sw   $t7, 0($t0) # Change state to 1 (ascending)
	j    update_piranha1
	
move_puff_up: # Move Puffer Up
	move $a0, $t2		# Store old position in $a0
	addi $t2, $t2, -WIDTH
	sw   $t2, 4($t0)	# puffer.pos = 1 pixel above old puffer.pos
	jal  unstamp_pufferfish	# Remove puffer from display
	la   $t0, pufferfish	# Re-obtain puffer position after function call
	lw   $t2, 4($t0)	# $t2 = new position
	addi $t7, $gp, 256	# If new pos is at top of display, change its direction
	bgt  $t2, $t7, update_piranha1
	li   $t7, 2
	sw   $t7, 0($t0) # Change state to 2 (descending)

update_piranha1: # Update piranha1
	la   $t0, piranha1	# $t0 = *piranha1
	lw   $t1, 0($t0)	# $t1 = piranha1.state
	lw   $t2, 4($t0)	# $t2 = piranha1.pos
	
	beq  $t1, 0 update_piranha2	# if piranha.state == 0, is invisible; skip it
	beq  $t1, 1, move_piran1_left	# If piranha.state == 1, move it left
					# Otherwise, move it right
					
	# Move Piranha1 Right
	move $a0, $t2		# Store old position in $a0
	addi $t2, $t2, 4
	sw   $t2, 4($t0)	# piranha1.pos = 1 pixel right of old piranh1.pos
	jal  unstamp_piranha	# Remove piranha from display 
	la   $t0, piranha1	# Re-obtain piranha1 position after function call
	lw   $t2, 4($t0)	# $t2 = new position
	
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
	j    update_piranha2
	
move_piran1_left: # Move Piranha1 Left
	move $a0, $t2		# Store old position in $a0
	addi $t2, $t2, -4
	sw   $t2, 4($t0)	# piranha1.pos = 1 pixel left of old piranh1.pos
	jal  unstamp_piranha	# Remove piranha from display 
	la   $t0, piranha1	# Re-obtain piranha1 position after function call
	lw   $t2, 4($t0)	# $t2 = new position
	
	# If new pos is at right of display, change its direction
	addi $t7, $t2, -28	# $t7 = left-most pixel of piranha
	sub  $t7, $t7, $gp	# $t7 = left-most pixel as an offset from $gp
	li   $t8, WIDTH		# $t8 = number of bytes in 1 row of pixels
	div  $t7, $t8		# hi = $t7 % $t8
	mfhi $t8		# $t8 = modulo(position, WIDTH)
	bgtz  $t8, update_piranha2 # if remainder is > 0, don't change its direction
	li   $t7, 2
	sw   $t7, 0($t0) # Change state to 2 (right-facing)
	
update_piranha2: # Update piranha2
	la   $t0, piranha2	# $t0 = *piranha2
	lw   $t1, 0($t0)	# $t1 = piranha2.state
	lw   $t2, 4($t0)	# $t2 = piranha2.pos
	
	beq  $t1, 0 update_bubble1	# if piranha.state == 0, is invisible; skip it
	beq  $t1, 1, move_piran2_left	# If piranha.state == 1, move it left
					# Otherwise, move it right
					
	# Move Piranha2 Right
	move $a0, $t2		# Store old position in $a0
	addi $t2, $t2, 4
	sw   $t2, 4($t0)	# piranha2.pos = 1 pixel right of old piranha.pos
	jal  unstamp_piranha	# Remove piranha from display 
	la   $t0, piranha2	# Re-obtain piranha2 position after function call
	lw   $t2, 4($t0)	# $t2 = new position
	
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
	j    update_bubble1
	
move_piran2_left: # Move Piranha1 Left
	move $a0, $t2		# Store old position in $a0
	addi $t2, $t2, -4
	sw   $t2, 4($t0)	# piranha2.pos = 1 pixel left of old piranha.pos
	jal  unstamp_piranha	# Remove piranha from display 
	la   $t0, piranha2	# Re-obtain piranha2 position after function call
	lw   $t2, 4($t0)	# $t2 = new position
	
	# If new pos is at right of display, change its direction
	addi $t7, $t2, -28	# $t7 = left-most pixel of piranha
	sub  $t7, $t7, $gp	# $t7 = left-most pixel as an offset from $gp
	li   $t8, WIDTH		# $t8 = number of bytes in 1 row of pixels
	div  $t7, $t8		# hi = $t7 % $t8
	mfhi $t8		# $t8 = modulo(position, WIDTH)
	bgtz  $t8, update_bubble1 # if remainder is > 0, don't change its direction
	li   $t7, 2
	sw   $t7, 0($t0) # Change state to 2 (right-facing)

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
	
	ble  $t1, 1, update_done # If state <= 1, skip it
	
	addi $t1, $t1, POP_TIME
	blt  $s6, $t1, update_done # if current time < time of dissipation, dont do anything
				      # otherwise, unstamp bubble and check state

	lw   $a0, 4($t0)	# $a0 = bubble2.pos
	jal  unstamp_bubble
	
	la   $t0, bubble2	# $t0 = *bubble2
	lw   $t1, 0($t0)	# $t1 = bubble2.state
	addi $t1, $t1, BUBBLE_REGEN
	blt  $s6, $t1, update_done   # if current time < time of regen, don't reset state
					# Otherwise, reset state to 1 (intact)
	li   $t1, 1
	sw   $t1, 0($t0)	# bubble2.state = 1

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
		
	addi $t6, $t8, 732	# $t6 = lower left hitbox
	addi $t7, $t9, 804	# $t7 = lower right hitbox
	li   $t3, 0		# $t3 = j =0
	dccpu_hitbox_check:
		beq  $t3, 16, dc_check_piranhas	# Exit loop after 16 rows checked
		# if clam.pos not within $t6 - $t7, check next row up
		bgt  $t1, $t7, dccpu_hitbox_update
		blt  $t1, $t6, dccpu_hitbox_update
		
		# Otherwise, crab has collided with puffer.
		li   $s7, 1	# set alive/dead flag to dead
		
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
		
		addi $t6, $t8, 2544	# $t6 = lower left hitbox
		addi $t7, $t9, 2576	# $t7 = lower right hitbox
		li   $t3, 0		# $t3 = j =0
		dccpi_hitbox_check:
			beq  $t3, 8, dccpi_update	# Exit loop after 8 rows checked
			# if piranha.pos not within $t6 - $t7, check next row up
			bgt  $t1, $t7, dccpi_hitbox_update
			blt  $t1, $t6, dccpi_hitbox_update
			
			# Otherwise, crab has collided with piranha.
			li   $s7, 1	# set alive/dead flag to dead
			
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
		beq  $t3, 3, dc_check_bubbles	# Exit loop after 3 rows checked
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
		lw   $t1, 4($t0)	# $t1 = bubble.pos
		
		addi $t6, $t8, 2544	# $t6 = lower left hitbox
		addi $t7, $t9, 2576	# $t7 = lower right hitbox
		li   $t3, 0		# $t3 = j =0
		dccb_hitbox_check:
			beq  $t3, 10, dccb_update	# Exit loop after 8 rows checked
			# if bubble.pos not within $t6 - $t7, check next row up
			bgt  $t1, $t7, dccb_hitbox_update
			blt  $t1, $t6, dccb_hitbox_update
			
			# Otherwise, crab has collided with a bubble.
			sw   $s6, 0($t0)	# set bubble.state to level timer
			move $a0, $t1		# $a0 = bubble.pos
			jal  unstamp_bubble
			li   $t1, CRAB_UP_DIST
			sw   $t1, 8($s1)	# set crab.jump_timer to CRAB_UP_DIST
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

	# world data
	li   $t0, 0
	sw   $t0, 0($s0)	# world.level = 0
	li   $t0, 4
	sw   $t0, 4($s0)	# world.darkness = 4

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
	addi $t0, $gp, 21676 # = platform_2.pos
	sw   $t0, 8($t1)
	li   $t0, 5 # = platform_2.len
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
#	Sets up the structs according to the level specified in world.level
gen_next_level:
	lw   $t0, 0($s0)	# $t0 = world.level
	
	# Calculate time bonus for level
	li   $t1, MAX_TIME
	sub  $t1, $t1, $s6	# $t1 = MAX_TIME - (time to complete level)
	blez $t1, gen_level_select # Skip if negative
	sra  $t1, $t1, 2	# $t1 = $t1/4
	add  $s3, $s3, $t1	# Add time bonus to score

gen_level_select:
	# Branch to correct level setup:
	beq  $t0, 1, gen_level_1
	beq  $t0, 2, gen_level_2
	beq  $t0, 3, gen_level_1
	beq  $t0, 4, gen_level_1
	beq  $t0, 5, gen_level_1
	beq  $t0, 6, gen_level_1
	# TODO: WIN CONDITION: Deal with the last level differently

gen_level_1: ##### LEVEL ONE #####
	# crab data
	lw   $t0, 0($s1)
	add  $t0, $t0, 28928	# Move crab down to bottom of display
	sw   $t0, 0($s1)
	
	# Bubbles
	la   $t1, bubble1
	li   $t0, 1 # = bubble1.state
	sw   $t0, 0($t1)
	addi $t0, $gp, 27860 # = bubble1.pos
	sw   $t0, 4($t1)
	la   $t1, bubble2
	li   $t0, 1 # = bubble2.state
	sw   $t0, 0($t1)
	addi $t0, $gp, 27692 # = bubble2.pos
	sw   $t0, 4($t1)

	# Platforms
	la   $t1, platforms
	addi $t0, $gp, 31836 # = platform_1.pos
	sw   $t0, 0($t1)
	li   $t0, 5 # = platform_1.len
	sw   $t0, 4($t1)
	addi $t0, $gp, 19804 # = platform_2.pos
	sw   $t0, 8($t1)
	li   $t0, 5 # = platform_2.len
	sw   $t0, 12($t1)
	addi $t0, $gp, 12924 # = platform_3.pos
	sw   $t0, 16($t1)
	li   $t0, 8 # = platform_3.len
	sw   $t0, 20($t1)	
	addi $t0, $gp, 6912 # = platform_4.pos
	sw   $t0, 24($t1)	
	li   $t0, 8 # = platform_4.len
	sw   $t0, 28($t1)	
	addi $t0, $gp, 3740 # = platform_5.pos
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
	li   $t0, 0 # = star_4.state = invisible
	sw   $t0, 24($t1)

	jr   $ra
	
gen_level_2: ##### LEVEL TWO #####
	# world data
	li   $t0, 3
	sw   $t0, 4($s0)	# world.darkness = 3
	li   $s5, SEA_COL_3	# Store current BG color

	# crab data
	lw   $t0, 0($s1)
	add  $t0, $t0, 28160	# Move crab down to bottom of display
	sw   $t0, 0($s1)
		
	# clam data
	la   $t1, clam
	li   $t0, 1 # = clam.state = open
	sw   $t0, 0($t1)
	li   $t0, 15152 # = clam.pos
	add  $t0, $t0, $gp
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
	li   $t0, 1
	sw   $t0, 0($t1)	# pufferfish.state = ascending
	addi $t0, $gp, 13448
	sw   $t0, 4($t1)

	# Platforms
	la   $t1, platforms
	li   $t0, 3676 # = platform_1.pos
	add  $t0, $t0, $gp
	sw   $t0, 0($t1)
	li   $t0, 6 # = platform_1.len
	sw   $t0, 4($t1)
	li   $t0, 10956 # = platform_2.pos
	add  $t0, $t0, $gp
	sw   $t0, 8($t1)
	li   $t0, 3 # = platform_2.len
	sw   $t0, 12($t1)
	li   $t0, 15360 # = platform_3.pos
	add  $t0, $t0, $gp
	sw   $t0, 16($t1)
	li   $t0, 7 # = platform_3.len
	sw   $t0, 20($t1)	
	li   $t0, 18108 # = platform_4.pos
	add  $t0, $t0, $gp
	sw   $t0, 24($t1)	
	li   $t0, 4 # = platform_4.len
	sw   $t0, 28($t1)	
	li   $t0, 25020 # = platform_5.pos
	add  $t0, $t0, $gp
	sw   $t0, 32($t1)	
	li   $t0, 3 # = platform_5.len
	sw   $t0, 36($t1)
	li   $t0, 31900 # = platform_6.pos
	add  $t0, $t0, $gp
	sw   $t0, 40($t1)	
	li   $t0, 4 # = platform_6.len
	sw   $t0, 44($t1)
	

	# Sea Stars
	la   $t1, stars
	li   $t0, 1 # = star_1.state = visible
	sw   $t0, 0($t1)
	li   $t0, 24276 # = star_1.pos
	add  $t0, $t0, $gp
	sw   $t0, 4($t1)
	li   $t0, 1 # = star_2.state = visible
	sw   $t0, 8($t1)
	li   $t0, 17380 # = star_2.pos
	add  $t0, $t0, $gp
	sw   $t0, 12($t1)
	li   $t0, 1 # = star_3.state = visible
	sw   $t0, 16($t1)
	li   $t0, 10212 # = star_3.pos
	add  $t0, $t0, $gp
	sw   $t0, 20($t1)

	jr   $ra
	
gen_level_3: ##### LEVEL THREE #####
	jr   $ra
	
gen_level_4: ##### LEVEL FOUR #####
	jr   $ra
# ---------------------------------------------------------------------------------------


#########################################################################
#	PAINTING FUNCTIONS						#
#########################################################################

# generate_background():
#	Fills the display with a background colour
# 	$t0: index, $t1: max_index, $t2: pixel_address
generate_background:		
	# Set up indices of iteration
	li   $t0, 0		# $t0 = i
	li   $t1, 32768		# $t1 = 32768 (128*64*4)

bg_loop:
	beq  $t0, $t1, bg_end	# branch to `bg_end` if i == 32768
	
	# Colour the ith pixel
	add  $t2, $gp, $t0	# $t2 = addr($gp) + i
	sw   $s5, ($t2)		# Set pixel at addr($gp) + i to bg color
	
	# Update i and loop again
	addi $t0, $t0, 4	# i = i + 4
	j    bg_loop		# jump back to start

bg_end:	jr   $ra
# ---------------------------------------------------------------------------------------


# _build_platform(*start, int length):
#	Builds a horizontal platform starting at `*start`, with `length` units of length
#	$t0: pixel_address, $t1-$t2: colours, $t3: length, $t6: world.darkness, $t7: temp
_build_platform:
	# Pop parameters from stack
	lw   $t3, 0($sp)	# $t3 = length
	lw   $t0, 4($sp)	# $t0 = address of pixel
	addi $sp, $sp, 8	# reclaim space on stack

	# Prepare colours
	li  $t1, 0x00ff429d	# $t1 = pink
	li  $t2, 0x00ffe785	# $t2 = yellow
	
	# Determine darkening factor
	lw   $t6, 4($s0)	# $t6 = world.darkness
	li   $t7, DARKNESS	# 
	mul  $t7, $t7, $t6	# $t7 = $t7 * world.darkness
	
	# Darken colors based on darkening factor
	sub  $t1, $t1, $t7
	sub  $t2, $t2, $t7
	
_bp_loop:
	beq  $t3, 0, _bp_exit	# if length == 0, branch to `bp_exit`
	move $t7, $t0		# $t7 = pixel address (will be overwritten)
	
	# Draw one "unit" of platform
	sw   $t1, 4($t7)
	sw   $t1, 8($t7)
	sw   $t1, 12($t7)
	addi $t7, $t7, WIDTH
	sw   $t1, 0($t7)
	sw   $t1, 4($t7)
	sw   $t2, 8($t7)
	sw   $t1, 12($t7)
	sw   $t1, 16($t7)
	addi $t7, $t7, WIDTH
	sw   $t1, 0($t7)
	sw   $t2, 4($t7)
	sw   $t1, 8($t7)
	sw   $t2, 12($t7)
	sw   $t1, 16($t7)
	addi $t7, $t7, WIDTH
	sw   $t1, 0($t7)
	sw   $t1, 4($t7)
	sw   $t2, 8($t7)
	sw   $t1, 12($t7)
	sw   $t1, 16($t7)
	addi $t7, $t7, WIDTH
	sw   $t1, 4($t7)
	sw   $t1, 8($t7)
	sw   $t1, 12($t7)

	# Update before looping
	addi $t0, $t0, 16	# $t0 = pixel address + 16
	addi $t3, $t3, -1	# $t3 = length - 1
	j    _bp_loop

_bp_exit: # Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


# stamp_platforms():
#	Builds the platforms of the level, based on what is in `platforms` array
#	$t4: platform struct, $t5: plat location, $t6: length, $t7: temp, $t8: index
stamp_platforms:
	li   $t8, 0		# i = 0
	la   $t4, platforms	# $t4 = addr(platforms)
	
splat_loop: # while i <= NUM_PLATFORMS :
	beq  $t8, NUM_PLATFORMS, splat_exit	# if i==NUM_PLATFORMS, branch to `splat_exit`
	
	# Get values for this platform
	sll  $t7, $t8, 3	# $t7 = 8 * i
	add  $t7, $t4, $t7	# $t7 = addr(platforms) + 8*i
	lw   $t5, 0($t7)	# $t5 = platform.position
	lw   $t6, 4($t7)	# $t6 = platform.length
	
	# Push parameters for _build_platform() to stack
	addi $sp, $sp, -12	# Make room on stack
	sw $ra, 8($sp)		# Push return address
	sw $t5, 4($sp)		# Push position
	sw $t6, 0($sp)		# Push length
	
	# Build this platform
	jal _build_platform
	
	# Pop old return address from stack
	lw $ra, 0($sp)	
	addi $sp, $sp, 4
	
	# Update index
	addi $t8, $t8, 1	# i = i + 1
	j splat_loop		# Restart loop

splat_exit:
	jr   $ra
# ---------------------------------------------------------------------------------------


# stamp_crab():
# 	"Stamps" the crab onto the display at crab.position
#	$t0: pixel_address, $t1-$t4: colours, $t5: world.darkness, $t6: temp
stamp_crab:
	li $t1, 0x00cc552d	# $t1 = crab base
	li $t2, 0x00a33615	# $t2 = crab shell
	li $t3, 0x00ffffff	# $t3 = white
	li $t4, 0x00000000	# $t4 = black
	
	# Determine darkening factor
	lw $t5, 4($s0)		# $t5 = world.darkness
	li $t6, DARKNESS	# 
	mul $t6, $t6, $t5	# $t6 = $t6 * world.darkness
	
	# Darken colors based on darkening factor
	sub $t1, $t1, $t6
	sub $t2, $t2, $t6
	sub $t3, $t3, $t6

	# Get pixel address and crab state
	lw $t0, 0($s1)		# $t0 = crab.position
	lw $t6, 4($s1)		# $t6 = crab.state
	
	beq $t6, 1, crab_walk1	# if crab.state == 1, draw walk_1 sprite
	
	# else, draw walk_0 sprite
	sw $t1, -16($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, -0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -28($t0)
	sw $t2, -24($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t3, -24($t0)
	sw $t2, -20($t0)
	sw $t2, -12($t0)
	sw $t4, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t4, 8($t0)
	sw $t2, 12($t0)
	sw $t3, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t3, -24($t0)
	sw $t2, -20($t0)
	sw $t4, -8($t0)
	sw $t4, 8($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t2, -20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t2, -24($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -28($t0)
	sw $t2, -24($t0)
	sw $t2, -20($t0)
	j crab_exit
	
crab_walk1: # draw walk_1 sprite
	sw $t1, -12($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, -0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -28($t0)
	sw $t2, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t1, 16($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t3, -24($t0)
	sw $t2, -20($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t3, 20($t0)
	sw $t2, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t3, -24($t0)
	sw $t2, -20($t0)
	sw $t2, -12($t0)
	sw $t4, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t4, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t2, -20($t0)
	sw $t4, -8($t0)
	sw $t4, 8($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t2, -24($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -28($t0)
	sw $t2, -24($t0)
	sw $t2, -20($t0)
	
crab_exit:
	# Return to caller			
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_clam():
# 	"Stamps" a clam shell onto the display
#	$t0: pixel_address, $t1-$t5: colors, $t6: world.darkness, $t7: temp
stamp_clam:
	li $t1, 0x00c496ff	# $t1 = shell midtone
	li $t2, 0x00c7a3f7	# $t2 = shell highlight
	li $t3, 0x009a7ac7	# $t3 = shell lo-light
	li $t4, 0x00ffffff	# $t4 = pearl
	li $t5, 0x00faf9e3	# $t5 = pearl shadow
	
	# Determine darkening factor
	lw $t6, 4($s0)		# $t6 = world.darkness
	li $t7, DARKNESS	# 
	mul $t7, $t7, $t6	# $t7 = $t7 * world.darkness
	
	# Darken colors based on darkening factor
	sub $t1, $t1, $t7
	sub $t2, $t2, $t7
	sub $t3, $t3, $t7
	
	# Get pixel address and clam state
	la $t7, clam		# $t7 = addr(clam struct)
	lw $t0, 4($t7)		# $t0 = clam.position
	lw $t7 0($t7)		# $t7 = clam.state
	beq $t7, 0, sc_exit	# if clam.state == 0, branch to `sc_exit`
	beq $t7, 2, sc_closed	# if clam.state == 2, branch to `sc_closed`
				# else, clam is open
	
	# Stamp an OPEN clam
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t3, -16($t0)
	sw $t3, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t3, -12($t0)
	sw $t3, -8($t0)
	sw $t5, -4($t0)
	sw $t5, 0($t0)
	sw $t5, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t5, -4($t0)
	sw $t4, 0($t0)
	sw $t4, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -8($t0)
	sw $t5, -4($t0)
	sw $t4, 0($t0)
	sw $t4, 4($t0)
	sw $t1, 8($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t2, -12($t0)
	sw $t1, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	j sc_exit
	
sc_closed:
	# Stamp a CLOSED clam
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t3, -16($t0)
	sw $t3, -12($t0)
	sw $t1, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t3, -20($t0)
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t3, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t3, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t3, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -20($t0)
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -20($t0)
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -8($t0)
	sw $t2, -4($t0)
	sw $t1, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	
sc_exit:
	# Return to caller
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_piranha():
# 	"Stamps" the piranhas onto the display
#	$t0: pixel_address, $t1-$t4: colors, $t5: piranha, 
#	$t6: world.darkness, $t7: temp, $t8: loop index
stamp_piranha:
	li $t1, 0x00312e73	# $t1 = base color
	li $t2, 0x00661a1f	# $t2 = belly color
	li $t3, 0x009595ad	# $t3 = teeth color
	li $t4, 0x00000000	# $t4 = black
	
	# Determine darkening factor
	lw $t6, 4($s0)		# $t6 = world.darkness
	li $t7, DARKNESS	# 
	mul $t7, $t7, $t6	# $t7 = $t7 * world.darkness
	
	# Darken colors based on darkening factor
	sub $t1, $t1, $t7
	sub $t2, $t2, $t7
	sub $t3, $t3, $t7
	
	# Loop twice: stamp each piranha
	li   $t8, 0		# $t8 = 0; loop index
	la $t5, piranha1	# $t5 = *piranha1
sp_loop:
	beq  $t8, 2, sp_exit	# if $t8 == 2, return

	# Determine if piranha is visible, and if it faces left or right 
	lw $t7 0($t5)		# $t7 = piranha.state
	beq $t7, 0, sp_update	# if piranha.state == 0, it's invisible - skip it
	lw $t0, 4($t5)		# $t0 = piranha.position
	beq $t7, 1, sp_left	# if piranha.state == 1, branch to `sp_left`
				# else, facing right
			
	# Stamp a right-facing piranha
	addi $t0, $t0, -WIDTH
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)	
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t2, -24($t0)
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t2, -20($t0)
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t3, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t3, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t4, 8($t0)
	sw $t4, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t2, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	j sp_update
				
sp_left: # Stamp a left-facing piranha
	addi $t0, $t0, -WIDTH
	sw $t1, 12($t0)
	sw $t1, 8($t0)
	sw $t1, 4($t0)	
	addi $t0, $t0, -WIDTH
	sw $t1, 28($t0)
	sw $t1, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t2, -4($t0)
	sw $t2, -8($t0)
	sw $t2, -12($t0)
	sw $t2, -16($t0)
	sw $t2, -20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, 28($t0)
	sw $t2, 24($t0)
	sw $t2, 16($t0)
	sw $t2, 12($t0)
	sw $t2, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t2, -8($t0)
	sw $t2, -12($t0)
	sw $t2, -16($t0)
	sw $t2, -20($t0)
	sw $t2, -24($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, 28($t0)
	sw $t1, 24($t0)
	sw $t2, 20($t0)
	sw $t2, 16($t0)
	sw $t2, 12($t0)
	sw $t2, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t1, -8($t0)
	sw $t1, -12($t0)
	sw $t2, -28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, 24($t0)
	sw $t1, 20($t0)
	sw $t1, 16($t0)
	sw $t1, 12($t0)
	sw $t1, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t1, -8($t0)
	sw $t1, -12($t0)
	sw $t3, -16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, 28($t0)
	sw $t1, 24($t0)
	sw $t1, 20($t0)
	sw $t1, 16($t0)
	sw $t1, 12($t0)
	sw $t1, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t1, -8($t0)
	sw $t1, -12($t0)
	sw $t1, -16($t0)
	sw $t3, -20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, 28($t0)
	sw $t1, 24($t0)
	sw $t1, 12($t0)
	sw $t1, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t4, -8($t0)
	sw $t4, -12($t0)
	sw $t1, -16($t0)
	sw $t1, -20($t0)
	sw $t1, -24($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, 28($t0)
	sw $t1, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t1, -8($t0)
	sw $t1, -12($t0)
	sw $t1, -16($t0)
	sw $t1, -20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, 12($t0)
	sw $t2, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t1, -8($t0)
	sw $t1, -12($t0)
	sw $t1, -16($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, 16($t0)
	sw $t2, 12($t0)
	sw $t2, 8($t0)
	sw $t2, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t1, -8($t0)
	
sp_update:
	# Update pointer and index
	addi $t8, $t8, 1	# $t8 = i + 1
	addi $t5, $t5, 8	# $t5 = *piranha[i+1]
	j    sp_loop
	
sp_exit:
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_pufferfish():
# 	"Stamps" a pufferfish onto the display
#	$t0: pixel_address, $t1-$t5: colors, $t6: world.darkness, $t7: temp, $t8: *pufferfish,
stamp_pufferfish:
	li   $t1, 0x00a8c267	# $t1 = base color
	li   $t2, 0x00929644	# $t2 = fin/spikes color
	li   $t3, 0x00ffffff	# $t3 = belly color
	li   $t4, 0x00d1d1d1	# $t4 = belly spikes color
	li   $t5, 0x00000000	# $t5 = black
	
	# Determine darkening factor
	lw   $t6, 4($s0)	# $t6 = world.darkness
	li   $t7, DARKNESS	# 
	mul  $t7, $t7, $t6	# $t7 = $t7 * world.darkness
	
	# Darken colors based on darkening factor
	sub  $t1, $t1, $t7
	sub  $t2, $t2, $t7
	sub  $t3, $t3, $t7
	sub  $t4, $t4, $t7
	
	# Get pixel address and state of pufferfish
	la   $t8, pufferfish
	lw   $t7, 0($t8)	# $t7 = puffefish.state
	beq  $t7, 0, spuff_done	# if state==0, is invisible; don't display it
	lw   $t0, 4($t8)	# $t0 = address of pixel
	
	# Color the pixels appropriately
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t5, -8($t0)
	sw $t5, -4($t0)
	sw $t5, 0($t0)
	sw $t5, 4($t0)
	sw $t5, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t2, 36($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t2, 36($t0)
	sw $t2, 40($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -36($t0)
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t5, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t5, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -40($t0)
	sw $t2, -36($t0)
	sw $t2, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t5, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t5, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t2, 32($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t2, 32($t0)
	sw $t2, 36($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t2, 40($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -28($t0)
	sw $t2, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -20($t0)
	sw $t2, -16($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -20($t0)
	sw $t2, 0($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, 0($t0)
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	sw $t2, -52($t0)
	sw $t2, -48($t0)
	sw $t2, -44($t0)
	sw $t2, -40($t0)
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t5, -8($t0)
	sw $t5, -4($t0)
	sw $t5, 0($t0)
	sw $t5, 4($t0)
	sw $t5, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t2, 40($t0)
	sw $t2, 44($t0)
	sw $t2, 48($t0)
	sw $t2, 52($t0)
	addi $t0, $t0, WIDTH
	sw $t2, -48($t0)
	sw $t2, -44($t0)
	sw $t2, -40($t0)
	sw $t2, -36($t0)
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t3, -8($t0)
	sw $t5, -4($t0)
	sw $t5, 0($t0)
	sw $t5, 4($t0)
	sw $t3, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t2, 36($t0)
	sw $t2, 40($t0)
	sw $t2, 44($t0)
	sw $t2, 48($t0)
	addi $t0, $t0, WIDTH
	sw $t2, -48($t0)
	sw $t2, -44($t0)
	sw $t2, -40($t0)
	sw $t2, -36($t0)
	sw $t2, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t3, -16($t0)
	sw $t3, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t2, 32($t0)
	sw $t2, 36($t0)
	sw $t2, 40($t0)
	sw $t2, 44($t0)
	sw $t2, 48($t0)
	addi $t0, $t0, WIDTH
	sw $t2, -44($t0)
	sw $t2, -40($t0)
	sw $t2, -36($t0)
	sw $t3, -28($t0)
	sw $t3, -24($t0)
	sw $t3, -20($t0)
	sw $t3, -16($t0)
	sw $t3, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t3, 28($t0)
	sw $t2, 36($t0)
	sw $t2, 40($t0)
	sw $t2, 44($t0)
	addi $t0, $t0, WIDTH
	sw $t2, -44($t0)
	sw $t2, -40($t0)
	sw $t3, -24($t0)
	sw $t3, -20($t0)
	sw $t3, -16($t0)
	sw $t3, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t3, 24($t0)
	sw $t2, 40($t0)
	sw $t2, 44($t0)
	addi $t0, $t0, WIDTH
	sw $t2, -44($t0)
	sw $t4, -28($t0)
	sw $t4, -24($t0)
	sw $t3, -20($t0)
	sw $t3, -16($t0)
	sw $t3, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t3, 20($t0)
	sw $t4, 24($t0)
	sw $t4, 28($t0)
	sw $t2, 44($t0)
	addi $t0, $t0, WIDTH
	sw $t4, -32($t0)
	sw $t3, -16($t0)
	sw $t3, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $t4, 32($t0)
	addi $t0, $t0, WIDTH
	sw $t4, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t4, 12($t0)
	addi $t0, $t0, WIDTH
	sw $t4, -16($t0)
	sw $t4, 16($t0)

spuff_done:
	# Return to caller
	jr $ra
# ---------------------------------------------------------------------------------------
	
	
# stamp_seahorse():
# 	"Stamps" a seahorse onto the display
#	$t0: pixel_address, $t1-$t3: colors, $t5: *seahorse, $t6: world.darkness, $t7: temp
stamp_seahorse:
	li   $t1, 0x00ff9815	# $t1 = seahorse colour
	li   $t2, 0x00ffeb3b	# $t2 = fin colour
	li   $t3, 0x00000000	# $t3 = black
	
	# Determine darkening factor
	lw   $t6, 4($s0)	# $t6 = world.darkness
	li   $t7, DARKNESS	# 
	mul  $t7, $t7, $t6	# $t7 = $t7 * world.darkness
	
	# Darken colors based on darkening factor
	sub  $t1, $t1, $t7
	sub  $t2, $t2, $t7

	# Get pixel address and state
	la   $t5, seahorse
	lw   $t7, 0($t5)	# $t7 = seahorse.state
	beq  $t7, 0, ssh_done	# if state==0, is invisible; don't display it
	lw   $t0, 4($t5)	# $t0 = address of pixel
	
	# Color the pixels appropriately
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 8($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -8($t0)
	sw $t1, -4($t0)
	sw $t3, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, 0($t0)

ssh_done:	
	# Return to caller			
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_bubble():
#	"Stamps" the bubbles onto the display at the position in bubble.position
#	Uses "popped" sprite for POP_TIME time counts after the time in bubble.state
#	After BUBBLE_REGEN time since the time in bubble.state, it resets to whole bubble
#	$t0: pixel_address, $t1: color, $t5: bubble, $t6: world.darkness, $t7: temp, $t8: loop index
stamp_bubble:
	li   $t1, 0x00ffffff	# $t1 = white
	li   $t2, 0x000a0a0a	
	add  $t2, $t2, $s5	# $t2 = inner bubble color, slightly lighter than BG
	
	# Determine darkening factor
	lw   $t6, 4($s0)		# $t6 = world.darkness
	li   $t7, DARKNESS	# 
	mul  $t7, $t7, $t6	# $t7 = $t7 * world.darkness
	
	# Darken colors based on darkening factor
	sub  $t1, $t1, $t7
	
	# Loop twice: stamp each bubble
	li   $t8, 0		# $t8 = 0; loop index
	la   $t5, bubble1	# $t5 = *bubble1

sb_loop:
	beq  $t8, 2, sb_exit	# if $t8 == 2, return

	# Determine if bubble is visible, its position, and the sprite to use
	lw   $t7 0($t5)		# $t7 = bubble.state
	beq  $t7, 0, sb_update	# if bubble.state == 0, it's invisible - skip it
	lw   $t0, 4($t5)	# $t0 = bubble.position
	beq  $t7, 1, sb_bubble	# if bubble.state == 1, stamp intact bubble
				# Else, bubble has been popped. But how long ago?
	# Current time = $s6,  Time of pop = $t7
	addi $t7, $t7, POP_TIME
	ble  $s6, $t7, sb_popped # If current time <= bubble's time of death + POP_TIME, draw popped 
	j    sb_update	 	 # Otherwise don't draw a bubble
				
sb_bubble:
	# Stamp an intact bubble
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t2, 20($t0)
	sw   $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t2, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t2, 20($t0)
	sw   $t2, 24($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t2, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t2, 20($t0)
	sw   $t2, 24($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t2, -28($t0)
	sw   $t2, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t2, 20($t0)
	sw   $t2, 24($t0)
	sw   $t2, 28($t0)
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t2, -28($t0)
	sw   $t2, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t2, 20($t0)
	sw   $t2, 24($t0)
	sw   $t2, 28($t0)
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t2, -28($t0)
	sw   $t2, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t2, 20($t0)
	sw   $t2, 24($t0)
	sw   $t2, 28($t0)
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t2, -28($t0)
	sw   $t2, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t2, 20($t0)
	sw   $t2, 24($t0)
	sw   $t2, 28($t0)
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t2, -28($t0)
	sw   $t2, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t1, 20($t0)
	sw   $t2, 24($t0)
	sw   $t2, 28($t0)
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t2, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t2, 20($t0)
	sw   $t2, 24($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t2, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t1, 12($t0)
	sw   $t2, 16($t0)
	sw   $t2, 20($t0)
	sw   $t2, 24($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -24($t0)
	sw   $t2, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t2, 20($t0)
	sw   $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -20($t0)
	sw   $t2, -16($t0)
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	sw   $t2, 16($t0)
	sw   $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	j    sb_update
	
sb_popped:
	# Stamp a popped bubble
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	sw   $t1, 0($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -8($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -20($t0)
	sw   $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -12($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -24($t0)
	sw   $t1, 4($t0)
	sw   $t1, 20($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	addi $t0, $t0, -WIDTH
	sw   $t1, -24($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -36($t0)
	sw   $t1, 20($t0)
	sw   $t1, 36($t0)
	addi $t0, $t0, -WIDTH
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, 32($t0)
	sw   $t1, 40($t0)
	addi $t0, $t0, -WIDTH
	addi $t0, $t0, -WIDTH
	sw   $t1, -36($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t1, -12($t0)
	sw   $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t1, 0($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, 8($t0)
	sw   $t1, 16($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -12($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, 8($t0)

sb_update:
	# Update pointer and index
	addi $t8, $t8, 1	# $t8 = i + 1
	addi $t5, $t5, 8	# $t5 = *bubble[i+1]
	j    sb_loop
	
sb_exit:
	jr   $ra
# ---------------------------------------------------------------------------------------


# stamp_stars():
# 	"Stamps" all the sea stars onto the display, given what is stored in `stars`
#	$t0: pixel_address, $t1-$t2: color, $t4: stars struct
#	$t6: world.darkness, $t7: temp, $t8: index
stamp_stars:
	li   $t1, 0x00ffeb3b	# $t1 = star colour
	li   $t2, 0x00502800	# $t2 = glow amount
	
	# Determine darkening factor
	lw   $t6, 4($s0)	# $t6 = world.darkness
	li   $t7, DARKNESS	# 
	mul  $t7, $t7, $t6	# $t7 = $t7 * world.darkness
	
	# Alter colors based on darkening factor and glow amount
	sub  $t1, $t1, $t7
	add  $t2, $s5, $t2

	li   $t8, 0		# i = 0
	la   $t4, stars		# $t4 = addr(stars)
	
sss_loop: # while i <= NUM_STARS :
	beq  $t8, NUM_STARS, sss_exit	# if i==NUM_PLATFORMS, branch to `ss_exit`
	
	# Get values for this star
	sll  $t7, $t8, 3	# $t7 = 8 * i
	add  $t7, $t4, $t7	# $t7 = addr(stars) + 8*i
	lw   $t0, 4($t7)	# $t0 = star.position
	lw   $t7, 0($t7)	# $t7 = star.state
	
	beqz $t7, sss_update	# if star.state == 0, it is invisible; skip it

	# Stamp a sea star on the display
	addi $t0, $t0, WIDTH
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	addi $t0, $t0, -WIDTH
	sw   $t2, -8($t0)
	sw   $t1, -4($t0)
	sw   $t2, 0($t0)
	sw   $t1, 4($t0)
	sw   $t2, 8($t0)
	addi $t0, $t0, -WIDTH
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	addi $t0, $t0, -WIDTH
	sw   $t2, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t2, 12($t0)
	addi $t0, $t0, -WIDTH
	sw   $t2, -12($t0)
	sw   $t2, -8($t0)
	sw   $t2, -4($t0)
	sw   $t1, 0($t0)
	sw   $t2, 4($t0)
	sw   $t2, 8($t0)
	sw   $t2, 12($t0)
	addi $t0, $t0, -WIDTH
	sw   $t2, -4($t0)
	sw   $t2, 0($t0)
	sw   $t2, 4($t0)

sss_update:
	# Update index
	addi $t8, $t8, 1	# i = i + 1
	j    sss_loop		# Restart loop

sss_exit:
	# Return to caller			
	jr   $ra
# ---------------------------------------------------------------------------------------


# display_score():
#	Displays the score at the top-right corner
display_score:
	jr   $ra
# ---------------------------------------------------------------------------------------

#########################################################################
#	UN-PAINTING FUNCTIONS						#
#########################################################################

# _get_bg_color():
#	Returns $v0 = bg_color
#	Given the values in the struct `world`, determines the 
#	correct background color, stores it in $v0
#	$t3: world.darkness
#	[CURRENTLY UNUSED, KEEPING IT FOR BACKUP]
_get_bg_color:
	lw   $t3, 4($s0)		# $t3 = world.darkness
	beq  $t3, 0, gbc_level_0	# branch if world.darkness == 0
	beq  $t3, 1, gbc_level_1	# branch if world.darkness == 1
	beq  $t3, 2, gbc_level_2	# branch if world.darkness == 2
	beq  $t3, 3, gbc_level_3	# branch if world.darkness == 3
	li   $v0, SEA_COL_4	# $v0 = bg color 4
	j    gbc_exit
gbc_level_0:
	li   $v0, SEA_COL_0	# $v0 = bg color 0
	j    gbc_exit
gbc_level_1:
	li   $v0, SEA_COL_1	# $v0 = bg color 1
	j    gbc_exit
gbc_level_2:
	li   $v0, SEA_COL_2	# $v0 = bg color 2
	j    gbc_exit
gbc_level_3:
	li   $v0, SEA_COL_3	# $v0 = bg color 3
gbc_exit:
	jr   $ra
# ---------------------------------------------------------------------------------------


# unstamp_crab():
# 	Removes the crab from the display at the position in $s2
#	$t0: crab_position, $t1: bg_color
unstamp_crab:
	move $t0, $s2		# Put last crab.pos into $t0
	move $t1, $s5		# Put bg colour into $t1
	
	# Color the pixels appropriately
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, -0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -8($t0)
	sw   $t1, 8($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)

	# Return to caller			
	jr $ra
# ---------------------------------------------------------------------------------------


# unstamp_clam()
# 	Removes the clam from the display at the position in $s2
#	$t0: clam_position, $t1: bg_color
unstamp_clam:
	move $t0, $a0		# Put clam pos into $t0
	move $t1, $s5		# Put bg colour into $t1

	# Color pixels appropriately
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	
	# Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


# unstamp_piranha($a0 = *position)
# 	Removes piranha from the display at $a0
#	$t0: piranha_position, $t1: bg_color
unstamp_piranha:
	move $t0, $a0		# Put piranha pos into $t0
	move $t1, $s5		# Put bg colour into $t1
	
	# Color the pixels appropriately
	addi $t0, $t0, -WIDTH
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 4($t0)	
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
				
	# Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


# unstamp_pufferfish($a0 = *pixel):
# 	Removes pufferfish from the display at $a0
#	$t0: puffer_position, $t1: bg_color
unstamp_pufferfish:
	move $t0, $a0		# Put pufferfish pos into $t0
	move $t1, $s5		# Put bg colour into $t1
	
	# Color the pixels appropriately
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	sw $t1, 40($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -36($t0)
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -40($t0)
	sw $t1, -36($t0)
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 40($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -20($t0)
	sw $t1, 0($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, 0($t0)
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	sw $t1, -52($t0)
	sw $t1, -48($t0)
	sw $t1, -44($t0)
	sw $t1, -40($t0)
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 40($t0)
	sw $t1, 44($t0)
	sw $t1, 48($t0)
	sw $t1, 52($t0)
	addi $t0, $t0, WIDTH
	sw $t1, -48($t0)
	sw $t1, -44($t0)
	sw $t1, -40($t0)
	sw $t1, -36($t0)
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	sw $t1, 40($t0)
	sw $t1, 44($t0)
	sw $t1, 48($t0)
	addi $t0, $t0, WIDTH
	sw $t1, -48($t0)
	sw $t1, -44($t0)
	sw $t1, -40($t0)
	sw $t1, -36($t0)
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	sw $t1, 40($t0)
	sw $t1, 44($t0)
	sw $t1, 48($t0)
	addi $t0, $t0, WIDTH
	sw $t1, -44($t0)
	sw $t1, -40($t0)
	sw $t1, -36($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 36($t0)
	sw $t1, 40($t0)
	sw $t1, 44($t0)
	addi $t0, $t0, WIDTH
	sw $t1, -44($t0)
	sw $t1, -40($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 40($t0)
	sw $t1, 44($t0)
	addi $t0, $t0, WIDTH
	sw $t1, -44($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 44($t0)
	addi $t0, $t0, WIDTH
	sw $t1, -32($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 32($t0)
	addi $t0, $t0, WIDTH
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, WIDTH
	sw $t1, -16($t0)
	sw $t1, 16($t0)
	
	# Return to caller
	jr $ra
# ---------------------------------------------------------------------------------------


# unstamp_seahorse($a0=*position)
# 	Removes seahorse from the display at $a0
#	$t0: seahorse_position, $t1: bg_color
unstamp_seahorse:
	move $t0, $a0		# Put seahorse pos into $t0
	move $t1, $s5		# Put bg colour into $t1
	
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 8($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, 0($t0)
	
	# Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


# unstamp_bubble($a0=*position)
# 	Removes bubble from the display at $a0
#	$t0: bubble_position, $t1: bg_color
unstamp_bubble:
	move $t0, $a0		# Put bubble pos into $t0
	move $t1, $s5		# Put bg colour into $t1
	
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	sw   $t1, 0($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -8($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -20($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 16($t0) 
	addi $t0, $t0, -WIDTH
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -36($t0)
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	sw   $t1, 32($t0)
	sw   $t1, 36($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	sw   $t1, 32($t0)
	sw   $t1, 40($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -36($t0)
	sw   $t1, -32($t0)
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	sw   $t1, 32($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -24($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	sw   $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -28($t0)
	sw   $t1, -20($t0)
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -16($t0)
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	sw   $t1, 16($t0)
	sw   $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, 8($t0)
	
	# Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


# unstamp_star($a0=*position)
# 	Removes star from the display at $a0
#	$t0: star_position, $t1: bg_color
unstamp_star:
	move $t0, $a0		# Put sea star pos into $t0
	move $t1, $s5		# Put bg colour into $t1

	# Remove a sea star from the display
	addi $t0, $t0, WIDTH
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -12($t0)
	sw   $t1, -8($t0)
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	sw   $t1, 8($t0)
	sw   $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw   $t1, -4($t0)
	sw   $t1, 0($t0)
	sw   $t1, 4($t0)
	
	jr   $ra
# ---------------------------------------------------------------------------------------
