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
# - Milestone 2
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
# - GitHub Link: https://github.com/knickoriuk/Crab-Game
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
.eqv	DEATH_PAUSE	1024		# Sleep duration after death
.eqv	INIT_POS	31640		# Initial position of the crab (offset from $gp)
.eqv	KEYSTROKE	0xffff0000	# Address storing keystrokes & values
.eqv	SEA_COL_9	0x0015298D	# Sea colour, darkest
.eqv	SEA_COL_8	0x00133396	#	:
.eqv	SEA_COL_7	0x00103E9E	#	:
.eqv	SEA_COL_6	0x000E48A7	#	:
.eqv	SEA_COL_5	0x000C53B0	#	:
.eqv	SEA_COL_4	0x00095DB8	#	:
.eqv	SEA_COL_3	0x000768C1	#	:
.eqv	SEA_COL_2	0x000572CA	#	:
.eqv	SEA_COL_1	0x00027DD2	# 	:
.eqv	SEA_COL_0	0x000087DB	# Sea colour, lightest
.eqv	DARKNESS	0x00060302	# amount to darken colours by, per level
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
# $s0 - Current level (starting at 9, working towards 0)
# $s1 - `crab` data pointer
# $s2 - Last crab location
# $s3 - Score
# $s4 -
# $s5 - background colour
# $s6 - timer: number of screen refreshes since level start
# $s7 - dead/alive flag: 0=alive, 1=dead
# $t0 - temporary values

########## Initialize Game Values ##########
main:	li   $s0, 9	# $s0 = Level
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
	
	# Flicker prevention: only unstamp crab if it moved
	lw   $t9, 0($s1)		# $t9 = crab.position
	beq  $s2, $t9, update_display2	# if new pos == old pos, skip next line
	jal  unstamp_crab		# remove old crab from display

update_display2:
	# Entities, if they move, are removed from display in update_positions() or detect_collisions()
	jal  update_positions	# Update positions of all entities
	jal  detect_collisions
	
	jal  stamp_piranha
	jal  stamp_pufferfish
	jal  stamp_platforms
	jal  stamp_bubble
	jal  stamp_stars
	jal  stamp_clam
	jal  stamp_seahorse
	jal  stamp_crab
	addi $a0, $gp, 940	# $a0 = *position for scoreboard
	jal  display_score
	
	bne  $s7, 1, sleep	# If alive, skip to `sleep`
	
########## Game Over? ##########

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
	
	li   $t9, KEYSTROKE
	lw   $t9, 0($t9) 	# $t0 = 1 if key hit, 0 otherwise
	
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
	move $a0, $t2		# $a0 = original piranha.pos
	
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
	
move_piran2_left: # Move Piranha1 Left
	addi $t2, $t2, -4
	sw   $t2, 4($t0)	# piranha2.pos = 1 pixel left of old piranha.pos
	jal  unstamp_piranha	# Remove piranha from display 
	
	# If new pos is at right of display, change its direction
	addi $t7, $t2, -28	# $t7 = left-most pixel of piranha
	sub  $t7, $t7, $gp	# $t7 = left-most pixel as an offset from $gp
	li   $t8, WIDTH		# $t8 = number of bytes in 1 row of pixels
	div  $t7, $t8		# hi = $t7 % $t8
	mfhi $t8		# $t8 = modulo(position, WIDTH)
	bgtz  $t8, update_bubble1 # if remainder is > 0, don't change its direction
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
	li   $s5, SEA_COL_9	# Store current BG color
	
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
#	Sets up the structs according to the level specified in $s0
gen_next_level:	
	# Calculate time bonus for level
	li   $t1, MAX_TIME
	sub  $t1, $t1, $s6	# $t1 = MAX_TIME - (time to complete level)
	blez $t1, gen_level_select # Skip if negative
	sra  $t1, $t1, 2	# $t1 = $t1/4
	add  $s3, $s3, $t1	# Add time bonus to score

gen_level_select:
	# Branch to correct level setup:
	beq  $s0, 8, gen_level_1
	beq  $s0, 7, gen_level_2
	beq  $s0, 6, gen_level_3
	beq  $s0, 5, gen_level_4
	beq  $s0, 4, gen_level_5
	beq  $s0, 3, gen_level_6
	beq  $s0, 2, gen_level_7
	beq  $s0, 1, gen_level_8
	beq  $s0, 0, gen_level_9
	bltz $s0, win_screen

gen_level_1: ##### LEVEL ONE #####
	li   $s5, SEA_COL_8	# Store current BG color
	
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
	li   $s5, SEA_COL_7	# Store current BG color

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
	j    gen_level_1 # temporary
	jr   $ra
	
gen_level_4: ##### LEVEL FOUR #####
	jr   $ra
	
gen_level_5: ##### LEVEL FIVE #####
	jr   $ra
	
gen_level_6: ##### LEVEL SIX #####
	jr   $ra
	
gen_level_7: ##### LEVEL SEVEN #####
	jr   $ra
	
gen_level_8: ##### LEVEL EIGHT #####
	jr   $ra
	
gen_level_9: ##### LEVEL NINE #####
	jr   $ra
	
win_screen: ##### WIN SCREEN #####
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
#	$t0: pixel_address, $t1-$t2: colours, $t3: length, $t7: temp
_build_platform:
	# Pop parameters from stack
	lw   $t3, 0($sp)	# $t3 = length
	lw   $t0, 4($sp)	# $t0 = address of pixel
	addi $sp, $sp, 8	# reclaim space on stack

	# Prepare colours
	li  $t1, 0x00ff429d	# $t1 = pink
	li  $t2, 0x00ffe785	# $t2 = yellow
	
	# Determine darkening factor
	li   $t7, DARKNESS
	mul  $t7, $t7, $s0	# $t7 = $t7 * level
	
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
#	$t0: pixel_address, $t1-$t4: colours, $t6: temp
stamp_crab:
	li $t1, 0x00e35e32	# $t1 = crab base
	li $t2, 0x00b0351c	# $t2 = crab shell
	li $t3, 0x00ffffff	# $t3 = white
	li $t4, 0x00000000	# $t4 = black
	
	# Determine darkening factor
	li $t6, DARKNESS	# 
	mul $t6, $t6, $s0	# $t6 = $t6 * level
	
	# Darken colors based on darkening factor
	sub $t1, $t1, $t6
	sub $t2, $t2, $t6
	sub $t3, $t3, $t6

	# Get pixel address and crab state
	lw $t0, 0($s1)		# $t0 = crab.position
	lw $t6, 4($s1)		# $t6 = crab.state
	
	beq $t6, 1, crab_walk1	# if crab.state == 1, draw walk_1 sprite
	beq $t6, 3, crab_dead	# if crab.state == 3, draw dead sprite
	
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
	j crab_exit

crab_dead: # draw dead sprite
	addi $t0, $t0, WIDTH
	addi $t0, $t0, WIDTH
	sw $t2, -28($t0)
	sw $t2, -24($t0)
	sw $t2, -20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t2, -24($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t2, 20($t0)
	sw $t2, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t2, -20($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t3, -24($t0)
	sw $t2, -20($t0)
	sw $t3, -8($t0)
	sw $t3, 8($t0)
	sw $t2, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $t3, -24($t0)
	sw $t2, -20($t0)
	sw $t2, -12($t0)
	sw $t3, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t3, 8($t0)
	sw $t2, 12($t0)
	sw $t3, 24($t0)
	sw $t2, 28($t0)
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
	sw $t1, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, -0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -16($t0)
	sw $t1, 16($t0)
	
crab_exit:
	# Return to caller			
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_clam():
# 	"Stamps" a clam shell onto the display
#	$t0: pixel_address, $t1-$t5: colors, $t7: temp
stamp_clam:
	li $t1, 0x00c496ff	# $t1 = shell midtone
	li $t2, 0x00c7a3f7	# $t2 = shell highlight
	li $t3, 0x009a7ac7	# $t3 = shell lo-light
	li $t4, 0x00ffffff	# $t4 = pearl
	li $t5, 0x00faf9e3	# $t5 = pearl shadow
	
	# Determine darkening factor
	li   $t7, DARKNESS
	mul  $t7, $t7, $s0	# $t7 = DARKNESS * level
	
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
#	$t0: pixel_address, $t1-$t4: colors, $t5: piranha, $t7: temp, $t8: loop index
stamp_piranha:
	li $t1, 0x00312e73	# $t1 = base color
	li $t2, 0x00661a1f	# $t2 = belly color
	li $t3, 0x009595ad	# $t3 = teeth color
	li $t4, 0x00000000	# $t4 = black
	
	# Determine darkening factor
	li   $t7, DARKNESS
	mul  $t7, $t7, $s0	# $t7 = DARKNESS * level
	
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
	sw $s5, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)	
	addi $t0, $t0, -WIDTH
	sw $s5, -32($t0)
	sw $t1, -28($t0)
	sw $s5, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, -32($t0)
	sw $t1, -28($t0)
	sw $t2, -24($t0)
	sw $s5, -20($t0)
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
	sw $s5, -32($t0)
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
	sw $s5, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, -28($t0)
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
	sw $s5, -32($t0)
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
	sw $s5, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $s5, -16($t0)
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
	sw $s5, -32($t0)
	sw $t1, -28($t0)
	sw $s5, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, -20($t0)
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t2, -8($t0)
	sw $t2, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	j sp_update
				
sp_left: # Stamp a left-facing piranha
	sw $s5, 16($t0)
	sw $t1, 12($t0)
	sw $t1, 8($t0)
	sw $t1, 4($t0)	
	addi $t0, $t0, -WIDTH
	sw $s5, 32($t0)
	sw $t1, 28($t0)
	sw $s5, 12($t0)
	sw $t1, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t2, -4($t0)
	sw $t2, -8($t0)
	sw $t2, -12($t0)
	sw $t2, -16($t0)
	sw $t2, -20($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, 32($t0)
	sw $t1, 28($t0)
	sw $t2, 24($t0)
	sw $s5, 20($t0)
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
	sw $s5, 32($t0)
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
	sw $s5, -24($t0)
	sw $t2, -28($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, 28($t0)
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
	sw $s5, 32($t0)
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
	sw $s5, 32($t0)
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
	sw $s5, 32($t0)
	sw $t1, 28($t0)
	sw $s5, 12($t0)
	sw $t1, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t1, -8($t0)
	sw $t1, -12($t0)
	sw $t1, -16($t0)
	sw $t1, -20($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, 16($t0)
	sw $t2, 12($t0)
	sw $t2, 8($t0)
	sw $t1, 4($t0)
	sw $t1, 0($t0)
	sw $t1, -4($t0)
	sw $t1, -8($t0)
	sw $t1, -12($t0)
	sw $t1, -16($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, 20($t0)
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
#	$t0: pixel_address, $t1-$t5: colors, $t7: temp, $t8: *pufferfish,
stamp_pufferfish:
	li   $t1, 0x00a8c267	# $t1 = base color
	li   $t2, 0x00929644	# $t2 = fin/spikes color
	li   $t3, 0x00ffffff	# $t3 = belly color
	li   $t4, 0x00d1d1d1	# $t4 = belly spikes color
	li   $t5, 0x00000000	# $t5 = black
	
	# Determine darkening factor
	li   $t7, DARKNESS
	mul  $t7, $t7, $s0	# $t7 = DARKNESS * level
	
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
	sw $s5, -52($t0)
	sw $s5, -48($t0)
	sw $s5, -44($t0)
	sw $s5, -40($t0)
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
	sw $s5, 40($t0)
	sw $s5, 44($t0)
	sw $s5, 48($t0)
	sw $s5, 52($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, -36($t0)
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
	sw $s5, -40($t0)
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
	sw $s5, 36($t0)
	sw $s5, 40($t0)
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
	sw $s5, 36($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, -40($t0)
	sw $s5, -36($t0)
	sw $s5, -32($t0)
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
	sw $s5, 40($t0)
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
	sw $s5, 28($t0)
	sw $s5, 32($t0)
	sw $s5, 36($t0)
	sw $t2, 40($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, -32($t0)
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
	sw $s5, 40($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -32($t0)
	sw $t2, -28($t0)
	sw $s5, -24($t0)
	sw $s5, -20($t0)
	sw $t1, -16($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $s5, 20($t0)
	sw $s5, 24($t0)
	sw $t2, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, -32($t0)
	sw $s5, -28($t0)
	sw $s5, -20($t0)
	sw $t2, -16($t0)
	sw $t2, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t2, 12($t0)
	sw $t2, 16($t0)
	sw $s5, 20($t0)
	sw $s5, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -20($t0)
	sw $t2, -16($t0)
	sw $s5, -12($t0)
	sw $s5, -8($t0)
	sw $t2, -4($t0)
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $s5, 8($t0)
	sw $s5, 12($t0)
	sw $t2, 16($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $t2, -20($t0)
	sw $s5, -16($t0)
	sw $s5, -4($t0)
	sw $t2, 0($t0)
	sw $s5, 4($t0)
	sw $s5, 16($t0)
	sw $t2, 20($t0)
	addi $t0, $t0, -WIDTH
	sw $s5, -20($t0)
	sw $t2, 0($t0)
	sw $s5, 20($t0)
	sw $s5, -WIDTH($t0)
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
	sw $s5, -36($t0)
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
	sw $s5, 36($t0)
	sw $t2, 40($t0)
	sw $t2, 44($t0)
	sw $t2, 48($t0)
	sw $t2, 52($t0)
	addi $t0, $t0, WIDTH
	sw $s5, -52($t0)
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
	sw $s5, 52($t0)
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
	sw $s5, -48($t0)
	sw $t2, -44($t0)
	sw $t2, -40($t0)
	sw $t2, -36($t0)
	sw $s5, -32($t0)
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
	sw $s5, 32($t0)
	sw $t2, 36($t0)
	sw $t2, 40($t0)
	sw $t2, 44($t0)
	sw $s5, 48($t0)
	addi $t0, $t0, WIDTH
	sw $t2, -44($t0)
	sw $t2, -40($t0)
	sw $s5, -36($t0)
	sw $s5, -28($t0)
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
	sw $s5, 28($t0)
	sw $s5, 36($t0)
	sw $t2, 40($t0)
	sw $t2, 44($t0)
	addi $t0, $t0, WIDTH
	sw $t2, -44($t0)
	sw $s5, -40($t0)
	sw $s5, -32($t0)
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
	sw $s5, 32($t0)
	sw $s5, 40($t0)
	sw $t2, 44($t0)
	addi $t0, $t0, WIDTH
	sw $s5, -44($t0)
	sw $t4, -32($t0)
	sw $s5, -28($t0)
	sw $s5, -24($t0)
	sw $s5, -20($t0)
	sw $t3, -16($t0)
	sw $t3, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t3, 12($t0)
	sw $t3, 16($t0)
	sw $s5, 20($t0)
	sw $s5, 24($t0)
	sw $s5, 28($t0)
	sw $t4, 32($t0)
	sw $s5, 44($t0)
	addi $t0, $t0, WIDTH
	sw $s5, -32($t0)
	sw $s5, -16($t0)
	sw $t4, -12($t0)
	sw $t3, -8($t0)
	sw $t3, -4($t0)
	sw $t3, 0($t0)
	sw $t3, 4($t0)
	sw $t3, 8($t0)
	sw $t4, 12($t0)
	sw $s5, 16($t0)
	sw $s5, 32($t0)
	addi $t0, $t0, WIDTH
	sw $t4, -16($t0)
	sw $s5, -12($t0)
	sw $s5, -8($t0)
	sw $s5, -4($t0)
	sw $s5, 0($t0)
	sw $s5, 4($t0)
	sw $s5, 8($t0)
	sw $s5, 12($t0)
	sw $t4, 16($t0)
	addi $t0, $t0, WIDTH
	sw $s5, -16($t0)
	sw $s5, 16($t0)

spuff_done:
	# Return to caller
	jr $ra
# ---------------------------------------------------------------------------------------
	
	
# stamp_seahorse():
# 	"Stamps" a seahorse onto the display
#	$t0: pixel_address, $t1-$t3: colors, $t5: *seahorse, $t7: temp
stamp_seahorse:
	li   $t1, 0x00ff9815	# $t1 = seahorse colour
	li   $t2, 0x00ffeb3b	# $t2 = fin colour
	li   $t3, 0x00000000	# $t3 = black
	
	# Determine darkening factor
	li   $t7, DARKNESS
	mul  $t7, $t7, $s0	# $t7 = DARKNESS * level
	
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
#	$t0: pixel_address, $t1: color, $t5: bubble, $t7: temp, $t8: loop index
stamp_bubble:
	li   $t1, 0x00ffffff	# $t1 = white
	li   $t2, 0x000a0a0a	
	add  $t2, $t2, $s5	# $t2 = inner bubble color, slightly lighter than BG
	
	# Determine darkening factor
	li   $t7, DARKNESS
	mul  $t7, $t7, $s0	# $t7 = DARKNESS * level
	
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
#	$t0: pixel_address, $t1-$t2: color, $t4: stars struct, $t7: temp, $t8: index
stamp_stars:
	li   $t1, 0x00ffeb3b	# $t1 = star colour
	li   $t2, 0x00402000	# $t2 = glow amount
	
	# Determine darkening factor
	li   $t7, DARKNESS
	mul  $t7, $t7, $s0	# $t7 = DARKNESS * level
	
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


# display_score($a0 = *position):
#	Displays the 5-digit score at the position $a0
#	$t0: temp, $t1-$t4: modulos of the score, $t5: *position
display_score:
	# Store $ra on stack
	addi $sp, $sp, -4
	sw   $ra, 0($sp)
	
	# Calculate the digits to print
	li   $t0, 10
	div  $s3, $t0
	mfhi $t1	# $t1 = $s3 % 10
	li   $t0, 100
	div  $s3, $t0
	mfhi $t2	# $t2 = $s3 % 100
	li   $t0, 1000
	div  $s3, $t0
	mfhi $t3	# $t3 = $s3 % 1000
	li   $t0, 10000
	div  $s3, $t0
	mfhi $t4	# $t4 = $s3 % 10000
	
	move $t5, $a0

	# First Digit
	sub  $a1, $s3, $t4	
	div  $a1, $a1, 10000	# $a1 = 1st digit of score
	move $a0, $t5		# $a0 = position of 1st digit
	jal  _display_number
	
	# Second Digit
	sub  $a1, $t4, $t3	
	div  $a1, $a1, 1000	# $a1 = 2nd digit of score
	add  $a0, $t5, 16	# $a0 = position of 2nd digit
	jal  _display_number
	
	# Third Digit
	sub  $a1, $t3, $t2	
	div  $a1, $a1, 100	# $a1 = 3rd digit of score
	add  $a0, $t5, 32	# $a0 = position of 3rd digit
	jal  _display_number
	
	# Fourth Digit
	sub  $a1, $t2, $t1	
	div  $a1, $a1, 10	# $a1 = 4th digit of score
	add  $a0, $t5, 48	# $a0 = position of 4th digit
	jal  _display_number
	
	# Fourth Digit	
	move $a1, $t1		# $a1 = 5th digit of score
	add  $a0, $t5, 64	# $a0 = position of 5th digit
	jal  _display_number
	
	# Restore $ra from stack
	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	
	# Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


# _display_number($a0=*position, $a1=number):
#	Displays the number in $a1 at the position $a0
#	Number must be in 0-9
#	Cannot overwrite $t1-$t5!
_display_number:
	# Set up color
	li   $t0, 0x00ffffff	# $t0 = white
	
	# Branch to appropriate digit
	beq  $a1, 1, _display_1
	beq  $a1, 2, _display_2
	beq  $a1, 3, _display_3
	beq  $a1, 4, _display_4
	beq  $a1, 5, _display_5
	beq  $a1, 6, _display_6
	beq  $a1, 7, _display_7
	beq  $a1, 8, _display_8
	beq  $a1, 9, _display_9
	
	# Print a Zero
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	j    _display_done
	
_display_1: # Print a One
	sw   $s5, 0($a0)
	sw   $t0, 4($a0)
	sw   $s5, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $s5, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $t0, 4($a0)
	sw   $s5, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $t0, 4($a0)
	sw   $s5, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	j    _display_done
	
_display_2: # Print a Two
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $s5, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	j    _display_done
	
_display_3: # Print a Three
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	j    _display_done
	
_display_4: # Print a Four
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	j    _display_done
	
_display_5: # Print a Five
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $s5, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	j    _display_done
	
_display_6: # Print a Six
	sw   $s5, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $s5, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	j    _display_done
	
_display_7: # Print a Seven
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	j    _display_done
	
_display_8: # Print an Eight
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	j    _display_done
	
_display_9: # Print a Nine
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $s5, 0($a0)
	sw   $s5, 4($a0)
	sw   $t0, 8($a0)
	addi $a0, $a0, WIDTH
	sw   $t0, 0($a0)
	sw   $t0, 4($a0)
	sw   $s5, 8($a0)
	
_display_done:
	jr   $ra
# ---------------------------------------------------------------------------------------


# display_gameover():
#	Adds "GAME OVER" to the display.
#	Assumes crab.state == 3 (dead) and background is set to black
#	$t0: colour & temp
display_gameover:
	li   $t0, 0x00ffffff	# $t0 = white
	
	# "GAME"
	sw   $t0, 9792($gp)	# 1st Row
	sw   $t0, 9796($gp)
	sw   $t0, 9800($gp)
	sw   $t0, 9804($gp)
	sw   $t0, 9808($gp)
	sw   $t0, 9832($gp)
	sw   $t0, 9836($gp)
	sw   $t0, 9840($gp)
	sw   $t0, 9864($gp)
	sw   $t0, 9888($gp)
	sw   $t0, 9904($gp)
	sw   $t0, 9908($gp)
	sw   $t0, 9912($gp)
	sw   $t0, 9916($gp)
	sw   $t0, 9920($gp)
	sw   $t0, 9924($gp)
	sw   $t0, 9928($gp)
	sw   $t0, 9932($gp)
	sw   $t0, 10040($gp)	# 2nd Row
	sw   $t0, 10044($gp)
	sw   $t0, 10048($gp)
	sw   $t0, 10052($gp)
	sw   $t0, 10056($gp)
	sw   $t0, 10060($gp)
	sw   $t0, 10064($gp)
	sw   $t0, 10068($gp)
	sw   $t0, 10084($gp)
	sw   $t0, 10088($gp)
	sw   $t0, 10092($gp)
	sw   $t0, 10096($gp)
	sw   $t0, 10100($gp)
	sw   $t0, 10116($gp)
	sw   $t0, 10120($gp)
	sw   $t0, 10144($gp)
	sw   $t0, 10148($gp)
	sw   $t0, 10156($gp)
	sw   $t0, 10160($gp)
	sw   $t0, 10164($gp)
	sw   $t0, 10168($gp)
	sw   $t0, 10172($gp)
	sw   $t0, 10176($gp)
	sw   $t0, 10180($gp)
	sw   $t0, 10184($gp)
	sw   $t0, 10188($gp)
	sw   $t0, 10292($gp)	# 3rd Row
	sw   $t0, 10296($gp)
	sw   $t0, 10300($gp)
	sw   $t0, 10320($gp)
	sw   $t0, 10324($gp)
	sw   $t0, 10336($gp)
	sw   $t0, 10340($gp)
	sw   $t0, 10344($gp)
	sw   $t0, 10348($gp)
	sw   $t0, 10352($gp)
	sw   $t0, 10356($gp)
	sw   $t0, 10360($gp)
	sw   $t0, 10372($gp)
	sw   $t0, 10376($gp)
	sw   $t0, 10380($gp)
	sw   $t0, 10396($gp)
	sw   $t0, 10400($gp)
	sw   $t0, 10404($gp)
	sw   $t0, 10412($gp)
	sw   $t0, 10416($gp)
	sw   $t0, 10444($gp)
	sw   $t0, 10548($gp)	# 4th Row
	sw   $t0, 10552($gp)
	sw   $t0, 10592($gp)
	sw   $t0, 10596($gp)
	sw   $t0, 10600($gp)
	sw   $t0, 10604($gp)
	sw   $t0, 10608($gp)
	sw   $t0, 10612($gp)
	sw   $t0, 10616($gp)
	sw   $t0, 10628($gp)
	sw   $t0, 10632($gp)
	sw   $t0, 10636($gp)
	sw   $t0, 10652($gp)
	sw   $t0, 10656($gp)
	sw   $t0, 10660($gp)
	sw   $t0, 10668($gp)
	sw   $t0, 10672($gp)
	sw   $t0, 10804($gp)	# 5th Row
	sw   $t0, 10808($gp)
	sw   $t0, 10824($gp)
	sw   $t0, 10828($gp)
	sw   $t0, 10832($gp)
	sw   $t0, 10836($gp)
	sw   $t0, 10844($gp)
	sw   $t0, 10848($gp)
	sw   $t0, 10852($gp)
	sw   $t0, 10868($gp)
	sw   $t0, 10872($gp)
	sw   $t0, 10876($gp)
	sw   $t0, 10884($gp)
	sw   $t0, 10888($gp)
	sw   $t0, 10892($gp)
	sw   $t0, 10896($gp)
	sw   $t0, 10904($gp)
	sw   $t0, 10908($gp)
	sw   $t0, 10912($gp)
	sw   $t0, 10916($gp)
	sw   $t0, 10924($gp)
	sw   $t0, 10928($gp)
	sw   $t0, 10932($gp)
	sw   $t0, 10936($gp)
	sw   $t0, 10940($gp)
	sw   $t0, 10944($gp)
	sw   $t0, 11060($gp)	# 6th Row
	sw   $t0, 11064($gp)
	sw   $t0, 11080($gp)
	sw   $t0, 11084($gp)
	sw   $t0, 11088($gp)
	sw   $t0, 11092($gp)
	sw   $t0, 11100($gp)
	sw   $t0, 11104($gp)
	sw   $t0, 11128($gp)
	sw   $t0, 11132($gp)
	sw   $t0, 11140($gp)
	sw   $t0, 11144($gp)
	sw   $t0, 11148($gp)
	sw   $t0, 11152($gp)
	sw   $t0, 11160($gp)
	sw   $t0, 11164($gp)
	sw   $t0, 11168($gp)
	sw   $t0, 11172($gp)
	sw   $t0, 11180($gp)
	sw   $t0, 11184($gp)
	sw   $t0, 11316($gp)	# 7th Row
	sw   $t0, 11320($gp)
	sw   $t0, 11324($gp)
	sw   $t0, 11344($gp)
	sw   $t0, 11348($gp)
	sw   $t0, 11356($gp)
	sw   $t0, 11360($gp)
	sw   $t0, 11384($gp)
	sw   $t0, 11388($gp)
	sw   $t0, 11396($gp)
	sw   $t0, 11400($gp)
	sw   $t0, 11404($gp)
	sw   $t0, 11408($gp)
	sw   $t0, 11412($gp)
	sw   $t0, 11416($gp)
	sw   $t0, 11420($gp)
	sw   $t0, 11424($gp)
	sw   $t0, 11428($gp)
	sw   $t0, 11436($gp)
	sw   $t0, 11440($gp)
	sw   $t0, 11468($gp)
	sw   $t0, 11572($gp)	# 8th Row
	sw   $t0, 11576($gp)
	sw   $t0, 11580($gp)
	sw   $t0, 11584($gp)
	sw   $t0, 11588($gp)
	sw   $t0, 11592($gp)
	sw   $t0, 11596($gp)
	sw   $t0, 11600($gp)
	sw   $t0, 11604($gp)
	sw   $t0, 11612($gp)
	sw   $t0, 11616($gp)
	sw   $t0, 11620($gp)
	sw   $t0, 11624($gp)
	sw   $t0, 11628($gp)
	sw   $t0, 11632($gp)
	sw   $t0, 11636($gp)
	sw   $t0, 11640($gp)
	sw   $t0, 11644($gp)
	sw   $t0, 11652($gp)
	sw   $t0, 11656($gp)
	sw   $t0, 11660($gp)
	sw   $t0, 11664($gp)
	sw   $t0, 11668($gp)
	sw   $t0, 11672($gp)
	sw   $t0, 11676($gp)
	sw   $t0, 11680($gp)
	sw   $t0, 11684($gp)
	sw   $t0, 11692($gp)
	sw   $t0, 11696($gp)
	sw   $t0, 11700($gp)
	sw   $t0, 11704($gp)
	sw   $t0, 11708($gp)
	sw   $t0, 11712($gp)
	sw   $t0, 11716($gp)
	sw   $t0, 11720($gp)
	sw   $t0, 11724($gp)
	sw   $t0, 11828($gp)	# 9th Row
	sw   $t0, 11832($gp)
	sw   $t0, 11836($gp)
	sw   $t0, 11840($gp)
	sw   $t0, 11844($gp)
	sw   $t0, 11848($gp)
	sw   $t0, 11852($gp)
	sw   $t0, 11856($gp)
	sw   $t0, 11860($gp)
	sw   $t0, 11868($gp)
	sw   $t0, 11872($gp)
	sw   $t0, 11876($gp)
	sw   $t0, 11880($gp)
	sw   $t0, 11884($gp)
	sw   $t0, 11888($gp)
	sw   $t0, 11892($gp)
	sw   $t0, 11896($gp)
	sw   $t0, 11900($gp)
	sw   $t0, 11908($gp)
	sw   $t0, 11912($gp)
	sw   $t0, 11920($gp)
	sw   $t0, 11924($gp)
	sw   $t0, 11928($gp)
	sw   $t0, 11936($gp)
	sw   $t0, 11940($gp)
	sw   $t0, 11948($gp)
	sw   $t0, 11952($gp)
	sw   $t0, 11956($gp)
	sw   $t0, 11960($gp)
	sw   $t0, 11964($gp)
	sw   $t0, 11968($gp)
	sw   $t0, 11972($gp)
	sw   $t0, 11976($gp)
	sw   $t0, 11980($gp)
	sw   $t0, 12084($gp)	# 10th Row
	sw   $t0, 12088($gp)
	sw   $t0, 12092($gp)
	sw   $t0, 12096($gp)
	sw   $t0, 12100($gp)
	sw   $t0, 12104($gp)
	sw   $t0, 12108($gp)
	sw   $t0, 12112($gp)
	sw   $t0, 12116($gp)
	sw   $t0, 12124($gp)
	sw   $t0, 12128($gp)
	sw   $t0, 12152($gp)
	sw   $t0, 12156($gp)
	sw   $t0, 12164($gp)
	sw   $t0, 12168($gp)
	sw   $t0, 12180($gp)
	sw   $t0, 12192($gp)
	sw   $t0, 12196($gp)
	sw   $t0, 12204($gp)
	sw   $t0, 12208($gp)
	sw   $t0, 12212($gp)
	sw   $t0, 12216($gp)
	sw   $t0, 12220($gp)
	sw   $t0, 12224($gp)
	sw   $t0, 12228($gp)
	sw   $t0, 12232($gp)
	sw   $t0, 12236($gp)
	sw   $t0, 12344($gp)	# 11th Row
	sw   $t0, 12348($gp)
	sw   $t0, 12352($gp)
	sw   $t0, 12356($gp)
	sw   $t0, 12360($gp)
	sw   $t0, 12364($gp)
	sw   $t0, 12368($gp)
	sw   $t0, 12380($gp)
	sw   $t0, 12384($gp)
	sw   $t0, 12408($gp)
	sw   $t0, 12412($gp)
	sw   $t0, 12420($gp)
	sw   $t0, 12424($gp)
	sw   $t0, 12428($gp)
	sw   $t0, 12444($gp)
	sw   $t0, 12448($gp)
	sw   $t0, 12452($gp)
	sw   $t0, 12464($gp)
	sw   $t0, 12468($gp)
	sw   $t0, 12472($gp)
	sw   $t0, 12476($gp)
	sw   $t0, 12480($gp)
	sw   $t0, 12484($gp)
	sw   $t0, 12488($gp)

	# "OVER"
	sw   $t0, 13120($gp)	# 1st Row
	sw   $t0, 13124($gp)
	sw   $t0, 13128($gp)
	sw   $t0, 13148($gp)
	sw   $t0, 13152($gp)
	sw   $t0, 13176($gp)
	sw   $t0, 13180($gp)
	sw   $t0, 13192($gp)
	sw   $t0, 13196($gp)
	sw   $t0, 13200($gp)
	sw   $t0, 13204($gp)
	sw   $t0, 13208($gp)
	sw   $t0, 13212($gp)
	sw   $t0, 13216($gp)
	sw   $t0, 13220($gp)
	sw   $t0, 13232($gp)
	sw   $t0, 13236($gp)
	sw   $t0, 13240($gp)
	sw   $t0, 13244($gp)
	sw   $t0, 13248($gp)
	sw   $t0, 13368($gp)	# 2nd Row
	sw   $t0, 13372($gp)
	sw   $t0, 13376($gp)
	sw   $t0, 13380($gp)
	sw   $t0, 13384($gp)
	sw   $t0, 13388($gp)
	sw   $t0, 13392($gp)
	sw   $t0, 13404($gp)
	sw   $t0, 13408($gp)
	sw   $t0, 13432($gp)
	sw   $t0, 13436($gp)
	sw   $t0, 13444($gp)
	sw   $t0, 13448($gp)
	sw   $t0, 13452($gp)
	sw   $t0, 13456($gp)
	sw   $t0, 13460($gp)
	sw   $t0, 13464($gp)
	sw   $t0, 13468($gp)
	sw   $t0, 13472($gp)
	sw   $t0, 13476($gp)
	sw   $t0, 13484($gp)
	sw   $t0, 13488($gp)
	sw   $t0, 13492($gp)
	sw   $t0, 13496($gp)
	sw   $t0, 13500($gp)
	sw   $t0, 13504($gp)
	sw   $t0, 13508($gp)
	sw   $t0, 13512($gp)
	sw   $t0, 13620($gp)	# 3rd Row
	sw   $t0, 13624($gp)
	sw   $t0, 13628($gp)
	sw   $t0, 13644($gp)
	sw   $t0, 13648($gp)
	sw   $t0, 13652($gp)
	sw   $t0, 13660($gp)
	sw   $t0, 13664($gp)
	sw   $t0, 13688($gp)
	sw   $t0, 13692($gp)
	sw   $t0, 13700($gp)
	sw   $t0, 13704($gp)
	sw   $t0, 13732($gp)
	sw   $t0, 13740($gp)
	sw   $t0, 13744($gp)
	sw   $t0, 13764($gp)
	sw   $t0, 13768($gp)
	sw   $t0, 13772($gp)
	sw   $t0, 13876($gp)	# 4th Row
	sw   $t0, 13880($gp)
	sw   $t0, 13904($gp)
	sw   $t0, 13908($gp)
	sw   $t0, 13916($gp)
	sw   $t0, 13920($gp)
	sw   $t0, 13944($gp)
	sw   $t0, 13948($gp)
	sw   $t0, 13956($gp)
	sw   $t0, 13960($gp)
	sw   $t0, 13996($gp)
	sw   $t0, 14000($gp)
	sw   $t0, 14024($gp)
	sw   $t0, 14028($gp)
	sw   $t0, 14132($gp)	# 5th Row
	sw   $t0, 14136($gp)
	sw   $t0, 14160($gp)
	sw   $t0, 14164($gp)
	sw   $t0, 14172($gp)
	sw   $t0, 14176($gp)
	sw   $t0, 14180($gp)
	sw   $t0, 14196($gp)
	sw   $t0, 14200($gp)
	sw   $t0, 14204($gp)
	sw   $t0, 14212($gp)
	sw   $t0, 14216($gp)
	sw   $t0, 14220($gp)
	sw   $t0, 14224($gp)
	sw   $t0, 14228($gp)
	sw   $t0, 14232($gp)
	sw   $t0, 14252($gp)
	sw   $t0, 14256($gp)
	sw   $t0, 14280($gp)
	sw   $t0, 14284($gp)
	sw   $t0, 14388($gp)	# 6th Row
	sw   $t0, 14392($gp)
	sw   $t0, 14416($gp)
	sw   $t0, 14420($gp)
	sw   $t0, 14428($gp)
	sw   $t0, 14432($gp)
	sw   $t0, 14436($gp)
	sw   $t0, 14452($gp)
	sw   $t0, 14456($gp)
	sw   $t0, 14460($gp)
	sw   $t0, 14468($gp)
	sw   $t0, 14472($gp)
	sw   $t0, 14508($gp)
	sw   $t0, 14512($gp)
	sw   $t0, 14532($gp)
	sw   $t0, 14536($gp)
	sw   $t0, 14540($gp)
	sw   $t0, 14644($gp)	# 7th Row
	sw   $t0, 14648($gp)
	sw   $t0, 14652($gp)
	sw   $t0, 14668($gp)
	sw   $t0, 14672($gp)
	sw   $t0, 14676($gp)
	sw   $t0, 14684($gp)
	sw   $t0, 14688($gp)
	sw   $t0, 14692($gp)
	sw   $t0, 14696($gp)
	sw   $t0, 14704($gp)
	sw   $t0, 14708($gp)
	sw   $t0, 14712($gp)
	sw   $t0, 14716($gp)
	sw   $t0, 14724($gp)
	sw   $t0, 14728($gp)
	sw   $t0, 14756($gp)
	sw   $t0, 14764($gp)
	sw   $t0, 14768($gp)
	sw   $t0, 14772($gp)
	sw   $t0, 14776($gp)
	sw   $t0, 14780($gp)
	sw   $t0, 14784($gp)
	sw   $t0, 14788($gp)
	sw   $t0, 14792($gp)
	sw   $t0, 14796($gp)
	sw   $t0, 14900($gp)	# 8th Row
	sw   $t0, 14904($gp)
	sw   $t0, 14908($gp)
	sw   $t0, 14912($gp)
	sw   $t0, 14916($gp)
	sw   $t0, 14920($gp)
	sw   $t0, 14924($gp)
	sw   $t0, 14928($gp)
	sw   $t0, 14932($gp)
	sw   $t0, 14944($gp)
	sw   $t0, 14948($gp)
	sw   $t0, 14952($gp)
	sw   $t0, 14956($gp)
	sw   $t0, 14960($gp)
	sw   $t0, 14964($gp)
	sw   $t0, 14968($gp)
	sw   $t0, 14980($gp)
	sw   $t0, 14984($gp)
	sw   $t0, 14988($gp)
	sw   $t0, 14992($gp)
	sw   $t0, 14996($gp)
	sw   $t0, 15000($gp)
	sw   $t0, 15004($gp)
	sw   $t0, 15008($gp)
	sw   $t0, 15012($gp)
	sw   $t0, 15020($gp)
	sw   $t0, 15024($gp)
	sw   $t0, 15028($gp)
	sw   $t0, 15032($gp)
	sw   $t0, 15036($gp)
	sw   $t0, 15040($gp)
	sw   $t0, 15044($gp)
	sw   $t0, 15048($gp)
	sw   $t0, 15156($gp)	# 9th Row
	sw   $t0, 15160($gp)
	sw   $t0, 15164($gp)
	sw   $t0, 15168($gp)
	sw   $t0, 15172($gp)
	sw   $t0, 15176($gp)
	sw   $t0, 15180($gp)
	sw   $t0, 15184($gp)
	sw   $t0, 15188($gp)
	sw   $t0, 15200($gp)
	sw   $t0, 15204($gp)
	sw   $t0, 15208($gp)
	sw   $t0, 15212($gp)
	sw   $t0, 15216($gp)
	sw   $t0, 15220($gp)
	sw   $t0, 15224($gp)
	sw   $t0, 15236($gp)
	sw   $t0, 15240($gp)
	sw   $t0, 15244($gp)
	sw   $t0, 15248($gp)
	sw   $t0, 15252($gp)
	sw   $t0, 15256($gp)
	sw   $t0, 15260($gp)
	sw   $t0, 15264($gp)
	sw   $t0, 15268($gp)
	sw   $t0, 15276($gp)
	sw   $t0, 15280($gp)
	sw   $t0, 15284($gp)
	sw   $t0, 15288($gp)
	sw   $t0, 15292($gp)
	sw   $t0, 15296($gp)
	sw   $t0, 15300($gp)
	sw   $t0, 15412($gp)	# 10th Row
	sw   $t0, 15416($gp)
	sw   $t0, 15420($gp)
	sw   $t0, 15424($gp)
	sw   $t0, 15428($gp)
	sw   $t0, 15432($gp)
	sw   $t0, 15436($gp)
	sw   $t0, 15440($gp)
	sw   $t0, 15444($gp)
	sw   $t0, 15460($gp)
	sw   $t0, 15464($gp)
	sw   $t0, 15468($gp)
	sw   $t0, 15472($gp)
	sw   $t0, 15476($gp)
	sw   $t0, 15492($gp)
	sw   $t0, 15496($gp)
	sw   $t0, 15500($gp)
	sw   $t0, 15504($gp)
	sw   $t0, 15508($gp)
	sw   $t0, 15512($gp)
	sw   $t0, 15516($gp)
	sw   $t0, 15520($gp)
	sw   $t0, 15524($gp)
	sw   $t0, 15532($gp)
	sw   $t0, 15536($gp)
	sw   $t0, 15548($gp)
	sw   $t0, 15552($gp)
	sw   $t0, 15556($gp)
	sw   $t0, 15560($gp)
	sw   $t0, 15672($gp)	# 11th Row
	sw   $t0, 15676($gp)
	sw   $t0, 15680($gp)
	sw   $t0, 15684($gp)
	sw   $t0, 15688($gp)
	sw   $t0, 15692($gp)
	sw   $t0, 15696($gp)
	sw   $t0, 15724($gp)
	sw   $t0, 15752($gp)
	sw   $t0, 15756($gp)
	sw   $t0, 15760($gp)
	sw   $t0, 15764($gp)
	sw   $t0, 15768($gp)
	sw   $t0, 15772($gp)
	sw   $t0, 15776($gp)
	sw   $t0, 15788($gp)
	sw   $t0, 15792($gp)
	sw   $t0, 15808($gp)
	sw   $t0, 15812($gp)
	sw   $t0, 15816($gp)
	sw   $t0, 15820($gp)

	# "Score:"
	sw   $t0, 16940($gp)	# 1st Row
	sw   $t0, 16944($gp)
	sw   $t0, 16948($gp)
	sw   $t0, 16960($gp)
	sw   $t0, 16964($gp)
	sw   $t0, 16972($gp)
	sw   $t0, 16976($gp)
	sw   $t0, 16980($gp)
	sw   $t0, 16988($gp)
	sw   $t0, 16992($gp)
	sw   $t0, 16996($gp)
	sw   $t0, 17004($gp)
	sw   $t0, 17008($gp)
	sw   $t0, 17012($gp)
	sw   $t0, 17196($gp)	# 2nd Row
	sw   $t0, 17212($gp)
	sw   $t0, 17228($gp)
	sw   $t0, 17236($gp)
	sw   $t0, 17244($gp)
	sw   $t0, 17252($gp)
	sw   $t0, 17260($gp)
	sw   $t0, 17276($gp)
	sw   $t0, 17452($gp)	# 3rd Row
	sw   $t0, 17456($gp)
	sw   $t0, 17460($gp)
	sw   $t0, 17468($gp)
	sw   $t0, 17484($gp)
	sw   $t0, 17492($gp)
	sw   $t0, 17500($gp)
	sw   $t0, 17504($gp)
	sw   $t0, 17516($gp)
	sw   $t0, 17520($gp)
	sw   $t0, 17716($gp)	# 4th Row
	sw   $t0, 17724($gp)
	sw   $t0, 17740($gp)
	sw   $t0, 17748($gp)
	sw   $t0, 17756($gp)
	sw   $t0, 17764($gp)
	sw   $t0, 17772($gp)
	sw   $t0, 17788($gp)
	sw   $t0, 17964($gp)	# 5th Row
	sw   $t0, 17968($gp)
	sw   $t0, 17972($gp)
	sw   $t0, 17984($gp)
	sw   $t0, 17988($gp)
	sw   $t0, 17996($gp)
	sw   $t0, 18000($gp)
	sw   $t0, 18004($gp)
	sw   $t0, 18012($gp)
	sw   $t0, 18020($gp)
	sw   $t0, 18028($gp)
	sw   $t0, 18032($gp)
	sw   $t0, 18036($gp)

	# "Press [P]"
	sw   $t0, 22172($gp)	# 1st Row
	sw   $t0, 22176($gp)
	sw   $t0, 22180($gp)
	sw   $t0, 22184($gp)
	sw   $t0, 22188($gp)
	sw   $t0, 22192($gp)
	sw   $t0, 22196($gp)
	sw   $t0, 22200($gp)
	sw   $t0, 22204($gp)
	sw   $t0, 22428($gp)	# 2nd Row
	sw   $t0, 22460($gp)
	sw   $t0, 22596($gp)	# 3rd Row
	sw   $t0, 22600($gp)
	sw   $t0, 22604($gp)
	sw   $t0, 22612($gp)
	sw   $t0, 22616($gp)
	sw   $t0, 22620($gp)
	sw   $t0, 22628($gp)
	sw   $t0, 22632($gp)
	sw   $t0, 22636($gp)
	sw   $t0, 22644($gp)
	sw   $t0, 22648($gp)
	sw   $t0, 22652($gp)
	sw   $t0, 22660($gp)
	sw   $t0, 22664($gp)
	sw   $t0, 22668($gp)
	sw   $t0, 22684($gp)
	sw   $t0, 22696($gp)
	sw   $t0, 22700($gp)
	sw   $t0, 22704($gp)
	sw   $t0, 22716($gp)
	sw   $t0, 22852($gp)	# 4th Row
	sw   $t0, 22860($gp)
	sw   $t0, 22868($gp)
	sw   $t0, 22876($gp)
	sw   $t0, 22884($gp)
	sw   $t0, 22900($gp)
	sw   $t0, 22916($gp)
	sw   $t0, 22940($gp)
	sw   $t0, 22952($gp)
	sw   $t0, 22960($gp)
	sw   $t0, 22972($gp)
	sw   $t0, 23108($gp)	# 5th Row
	sw   $t0, 23112($gp)
	sw   $t0, 23116($gp)
	sw   $t0, 23124($gp)
	sw   $t0, 23128($gp)
	sw   $t0, 23140($gp)
	sw   $t0, 23144($gp)
	sw   $t0, 23156($gp)
	sw   $t0, 23160($gp)
	sw   $t0, 23164($gp)
	sw   $t0, 23172($gp)
	sw   $t0, 23176($gp)
	sw   $t0, 23180($gp)
	sw   $t0, 23196($gp)
	sw   $t0, 23208($gp)
	sw   $t0, 23212($gp)
	sw   $t0, 23216($gp)
	sw   $t0, 23228($gp)
	sw   $t0, 23364($gp)	# 6th Row
	sw   $t0, 23380($gp)
	sw   $t0, 23388($gp)
	sw   $t0, 23396($gp)
	sw   $t0, 23420($gp)
	sw   $t0, 23436($gp)
	sw   $t0, 23452($gp)
	sw   $t0, 23464($gp)
	sw   $t0, 23484($gp)
	sw   $t0, 23620($gp)	# 7th Row
	sw   $t0, 23636($gp)
	sw   $t0, 23644($gp)
	sw   $t0, 23652($gp)
	sw   $t0, 23656($gp)
	sw   $t0, 23660($gp)
	sw   $t0, 23668($gp)
	sw   $t0, 23672($gp)
	sw   $t0, 23676($gp)
	sw   $t0, 23684($gp)
	sw   $t0, 23688($gp)
	sw   $t0, 23692($gp)
	sw   $t0, 23708($gp)
	sw   $t0, 23720($gp)
	sw   $t0, 23740($gp)
	sw   $t0, 23964($gp)	# 8th Row
	sw   $t0, 23996($gp)
	sw   $t0, 24220($gp)	# 9th Row
	sw   $t0, 24224($gp)
	sw   $t0, 24228($gp)
	sw   $t0, 24232($gp)
	sw   $t0, 24236($gp)
	sw   $t0, 24240($gp)
	sw   $t0, 24244($gp)
	sw   $t0, 24248($gp)
	sw   $t0, 24252($gp)
	sw   $t0, 24476($gp)	# 10th Row
	sw   $t0, 24480($gp)
	sw   $t0, 24484($gp)
	sw   $t0, 24488($gp)
	sw   $t0, 24492($gp)
	sw   $t0, 24496($gp)
	sw   $t0, 24500($gp)
	sw   $t0, 24504($gp)
	sw   $t0, 24508($gp)

	# Add Crab and Score:
	addi $sp, $sp, -4
	sw   $ra, 0($sp)	# Save return address on stack

	addi $a0, $gp, 17036	# $a0 = position for score
	jal  display_score
	addi $t0, $gp, 20864
	sw   $t0, 0($s1)	# crab.position = $gp + 20864
	jal  stamp_crab
	
	lw   $ra, 0($sp)	# Restore return address
	addi $sp, $sp, 4

	# Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


#########################################################################
#	UN-PAINTING FUNCTIONS						#
#########################################################################


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
