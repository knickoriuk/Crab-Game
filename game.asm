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
# 1. (fill in the feature, if any) 
# 2. (fill in the feature, if any) 
# 3. (fill in the feature, if any) 
# ... (add more if necessary) 
# 
# Link to video demonstration for final submission: 
# - (insert YouTube / MyMedia / other URL here). Make sure we can view it! 
# 
# Are you OK with us sharing the video with people outside course staff? 
# - yes / no / yes, and please share this project github link as well! 
# 
# Any additional information that the TA needs to know: 
# - (write here, if any) 
# 
#####################################################################

.eqv	WIDTH		256		# Width of display
.eqv	SLEEP_DUR	50		# Sleep duration between loops
.eqv	INIT_POS	31640		# Initial position of the crab (offset from $gp)
.eqv	KEYSTROKE	0xffff0000	# Address storing keystrokes & values
.eqv	SEA_COL_4	0x000b3e8a	# Sea colour, darkest
.eqv	SEA_COL_3	0x000d47a1	#	:
.eqv	SEA_COL_2	0x001052b5	#	:
.eqv	SEA_COL_1	0x00125dcc	#	:
.eqv	SEA_COL_0	0x001467db	# Sea colour, lightest
.eqv	DARKNESS	0x00050505	# amount to darken colours by, per level
.eqv	NUM_PLATFORMS	6		# Maximum number of platforms
.eqv	CRAB_UP_DIST	10		# Height of crab jump

.data
frame_buffer: 	.space		32768
crab:		.space		12
# struct crab {
#	int position; 	# holds address of pixel it is at
#	int state; 	# 0-walk_0, 1-walk_1, 2-jump/fall, 3-dead
#	int jump_timer; # counts down frames of rising, before falling down
# } crab;
world:		.space		12
# struct world {
#	int level:	# 0,1,2,3,4,5,6... However many I end up making
#	int darkness:	# 4, 3, 2, 1, 0
#	int score;	# Holds score (?)
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
platforms:	.double		NUM_PLATFORMS	# Stores pairs of (position, length) for platforms
						# length==0 implies the platform does not exist

.text
.globl main

########## Register Assignment for main() ##########
# $s0 - `world` data pointer
# $s1 - `crab` data pointer
# $s2 - Last crab location
# $s3 -
# $s4 -
# $s5 -
# $s6 - 
# $s7 - dead/alive flag: 0=alive, 1=dead
# $t0 - temporary values

########## Initialize Game Values ##########
main:	la   $s0, world
	la   $s1, crab
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
	li   $t0, KEYSTROKE
	lw   $t0, 0($t0) 		# $t0 = 1 if key hit, 0 otherwise
	bne  $t0, 1, update_display	# if no key was hit, branch to `update_display` 
	jal  key_pressed		# Update position in `crab` struct
	
	
	# If top of level was reached, build next level
	# blt $position, $upper_limit, next_level
	
########## Construct Next Level ##########

next_level:
	# update level in `world`
	# Run appropriate worldbuilding function
	# then go on to update_display
	
########## Update Display ##########

update_display:
	jal  do_jumps		# Move crab up or down
	
	# Flicker prevention: only unstamp crab if it moved
	lw   $t9, 0($s1)		# $t9 = crab.position
	beq  $s2, $t9, update_display2	# if new pos == old pos, skip next line
	jal  unstamp_crab		# remove old crab from display

update_display2:
	# Remove all moving entities
	# jal  unstamp_piranha
	# jal  unstamp_pufferfish
	# jal  update_positions	# Update positions of all entities
	jal  stamp_platforms	# Re-add platforms
	jal  stamp_crab		# Add crab to display
	jal  stamp_piranha	# Add all entities
	jal  stamp_clam
	# jal  stamp_seahorse
	# jal  stamp_pufferfish
	
########## Sleep and Repeat ##########

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
#	$t2: crab_pos, $t3: crab_state, $t9: key_input
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

key_a:	# MOVE LEFT

	# First need to check if it is at the left wall
	addi $t4, $t2, -32	# $t4 = position of left-most edge of crab
	sub  $t4, $t4, $gp	# $t4 = left-most pixel - $gp
	li   $t5, WIDTH		# $t5 = WIDTH (probably 256)
	div  $t4, $t5		# hi = $t4 % $t5
	mfhi $t5
	beq  $t5, 0, key_input_done	# if remainder is 0, do not move further left.
	
	# Update position stored in `crab`
	addi $t2, $t2, -HORIZ_DIST	# $t2 = crab.position - HORIZ_DIST
	sw   $t2, 0($s1)		# crab.position = crab.position - HORIZ_DIST

	bge  $t3, 2, key_input_done	# If currently jumping (state 2), don't toggle walk state
	j    key_toggle_check		# Toggle between walk states (state 1 and 0)

key_d:	# MOVE RIGHT		

	# First need to check if it is at the right wall
	addi $t4, $t2, 28	# $t4 = position of right-most edge of crab
	sub  $t4, $t4, $gp	# $t4 = right-most pixel - $gp
	li   $t5, WIDTH		# $t5 = WIDTH
	div  $t4, $t5		# hi = $t4 % $t5
	addi $t4, $t5, -4	# $t4 = WIDTH - 4
	mfhi $t5		# $t5 = modulo(position, WIDTH)
	beq  $t5, $t4, key_input_done	# if remainder is WIDTH-4, do not move further right.

	# Update position stored in `crab`
	addi $t2, $t2, HORIZ_DIST	# $t2 = crab.position + HORIZ_DIST
	sw   $t2, 0($s1)		# crab.position = crab.position + HORIZ_DIST

	bge  $t3, 2, key_input_done	# If currently jumping (state 2), don't toggle walk state
	j    key_toggle_check		# Toggle between walk states (state 1 and 0)

key_w:	# JUMP

	# Check if crab is already jumping
	beq  $t3, 2, key_input_done
	
	# Set state to `jumping` (2)
	li   $t3, 2		# $t3 = 2
	sw   $t3, 4($s1)	# crab.state = 2
	li   $t3, CRAB_UP_DIST	# $t3 = CRAB_UP_DIST
	sw   $t3, 8($s1)	# crab.jump_timer = CRAB_UP_DIST
	j    key_input_done
	
key_p:	# RESET
	# TODO: some kind of display/notification
	j    main
	
key_toggle_check: # If state==0, toggle walk state from 0 -> 1
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
	# # Get pixel that crab is expected to fall to next
	# mul  $t4, $t3, WIDTH	# $t4 = jump_timer * WIDTH
	# sub  $t4, $t2, $t4	# $t4 = crab.pos - crab.jump_timer * WIDTH
	# addi $t4, $t2, WIDTH	# $t4 = jump_timer rows below crab pos
	
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
		addi $t7, $t7, 8	# $t3 = *platforms[i+1]
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
#	$t0: entity pointer, $t1: entity state, $t2: entity position
update_positions:

	# Update puffer
	la   $t0, pufferfish	# $t0 = *puffer
	lw   $t1, 0($t0)	# $t1 = puffer.state
	lw   $t2, 4($t0)	# $t2 = puffer.pos
	
	# Update piranha1
	la   $t0, piranha1	# $t0 = *piranha1
	lw   $t1, 0($t0)	# $t1 = piranha1.state
	lw   $t2, 4($t0)	# $t2 = piranha1.pos
	
	# Update piranha2
	la   $t0, piranha2	# $t0 = *piranha2
	lw   $t1, 0($t0)	# $t1 = piranha2.state
	lw   $t2, 4($t0)	# $t2 = piranha2.pos
	
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
	li   $t0, INIT_POS
	add  $t0, $t0, $gp
	sw   $t0, 0($s1)	# crab.pos = addr($gp) + INIT_POS
	li   $t0, 0
	sw   $t0, 4($s1)	# crab.state = 0 (walk state 0)
	sw   $t0, 8($s1)	# crab.jump_timer = 0
	
	# piranha data
	la   $t1, piranha1	# $t1 = piranha1
	li   $t0, 0
	sw   $t0, 0($t1)	# piranha1.state = 0
	la   $t1, piranha2	# $t1 = piranha2
	li   $t0, 0
	sw   $t0, 0($t1)	# piranha2.state = 0
	
	# pufferfish data
	la   $t1, pufferfish
	li   $t0, 0
	sw   $t0, 0($t1)	# pufferfish.visible = 0
	
	# clam data
	la   $t1, clam
	li   $t0, 1
	sw   $t0, 0($t1)	# clam.state = 1 (open)
	li   $t0, 14888
	add  $t0, $t0, $gp
	sw   $t0, 4($t1)	# clam.pos = addr($gp) + INIT_POS
	#la   $t1, clam
	#li   $t0, 0
	#sw   $t0, 0($t1)	# clam.state = 0 (invisible)
	
	# seahorse data
	la   $t1, seahorse
	li   $t0, 0
	sw   $t0, 0($t1)	# seahorse.state = 0
	
	# Platforms
	la   $t1, platforms
	li   $t0, 25600
	add  $t0, $t0, $gp
	sw   $t0, 0($t1)	# platform_1.pos = 25600 + $gp
	li   $t0, 4
	sw   $t0, 4($t1)	# platform_1.len = 4
	li   $t0, 21676
	add  $t0, $t0, $gp
	sw   $t0, 8($t1)	# platform_2.pos = 21676 + $gp
	li   $t0, 5
	sw   $t0, 12($t1)	# platform_2.len = 5
	li   $t0, 15104
	add  $t0, $t0, $gp
	sw   $t0, 16($t1)	# platform_3.pos = 15104 + $gp
	li   $t0, 10
	sw   $t0, 20($t1)	# platform_3.len = 10
	li   $t0, 7936
	add  $t0, $t0, $gp
	sw   $t0, 24($t1)	# platform_4.pos = 7936 + $gp
	li   $t0, 3
	sw   $t0, 28($t1)	# platform_4.len = 3
	li   $t0, 4000
	add  $t0, $t0, $gp
	sw   $t0, 32($t1)	# platform_5.pos = 4000 + $gp
	li   $t0, 4
	sw   $t0, 36($t1)	# platform_5.len = 4
	li   $t0, 31744
	add  $t0, $t0, $gp
	sw   $t0, 40($t1)	# platform_6.pos = 31744 + $gp
	li   $t0, 16
	sw   $t0, 44($t1)	# platform_6.len = 16
	
	# Return to caller
	jr   $ra
# ---------------------------------------------------------------------------------------


#########################################################################
#	PAINTING FUNCTIONS						#
#########################################################################

# generate_background():
#	Fills the display with a background colour
# 	$t0: index, $t1: max_index, $t2: pixel_address, $t3: in _get_bg_color, $t9: bg_color
generate_background:	
	# Push return address onto stack
	addi $sp, $sp, -4
	sw   $ra, 0($sp)
	
	# Obtain background color based on level in `world` struct
	jal  _get_bg_color
	move $t9, $v0		# get result from $v0
	
	# Pop result and old return address from stack
	lw   $ra, 0($sp)	# $ra = old return address
	addi $sp, $sp, 4
	
	# Set up indices of iteration
	li   $t0, 0		# $t0 = i
	li   $t1, 32768		# $t1 = 32768 (128*64*4)

bg_loop:
	beq  $t0, $t1, bg_end	# branch to `bg_end` if i == 32768
	
	# Colour the ith pixel
	add  $t2, $gp, $t0	# $t2 = addr($gp) + i
	sw   $t9, ($t2)		# Set pixel at addr($gp) + i to primary bg color
	
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
#	TODO: Display the second piranha. It only displays the first, for now.
#	$t0: pixel_address, $t1-$t4: colors, $t5: piranha, $t6: world.darkness, $t7: temp
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
	
	# Determine if piranha is visible, and if it faces left or right 
	la $t5, piranha1
	lw $t7 0($t5)		# $t7 = piranha.state
	beq $t7, 0, sp_exit	# if piranha.state == 0, branch to `sp_exit`
	lw $t0, 4($t5)		# $t0 = piranha.position
	beq $t7, 1, sp_left	# if piranha.state == 1, branch to `sp_left`
				# else, facing right
				
				# idea, at end, la $t7 piranha2, then loop back to after la $t7 piranha1,
				# add a branch if $t7 == piranha1, see if this works
			
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
	j sp_exit
				
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
	
sp_exit:
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_pufferfish(*pixel):
# 	"Stamps" a pufferfish onto the display given it is positioned at *pixel
#	$t0: pixel_address, $t1-$t5: colors, $t6: world.darkness, $t7: temp
stamp_pufferfish:
	li $t1, 0x00a8c267	# $t1 = base color
	li $t2, 0x00929644	# $t2 = fin/spikes color
	li $t3, 0x00ffffff	# $t3 = belly color
	li $t4, 0x00d1d1d1	# $t4 = belly spikes color
	li $t5, 0x00000000	# $t5 = black
	
	# Determine darkening factor
	lw $t6, 4($s0)		# $t6 = world.darkness
	li $t7, DARKNESS	# 
	mul $t7, $t7, $t6	# $t7 = $t7 * world.darkness
	
	# Darken colors based on darkening factor
	sub $t1, $t1, $t7
	sub $t2, $t2, $t7
	sub $t3, $t3, $t7
	sub $t4, $t4, $t7
	
	# Pop pixel address from stack
	lw $t0, 0($sp)		# $t0 = address of pixel
	addi, $sp, $sp, 4	# reclaim space on stack
	
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
	
	# Return to caller
	jr $ra
# ---------------------------------------------------------------------------------------
	
	
# stamp_seahorse(*pixel):
# 	"Stamps" a seahorse onto the display given it is positioned at *pixel
#	$t0: pixel_address, $t1-$t3: colors, $t6: world.darkness, $t7: temp
stamp_seahorse:
	li $t1, 0x00ff9815	# $t1 = seahorse colour
	li $t2, 0x00ffeb3b	# $t2 = fin colour
	li $t3, 0x00000000	# $t3 = black
	
	# Determine darkening factor
	lw $t6, 4($s0)		# $t6 = world.darkness
	li $t7, DARKNESS	# 
	mul $t7, $t7, $t6	# $t7 = $t7 * world.darkness
	
	# Darken colors based on darkening factor
	sub $t1, $t1, $t7
	sub $t2, $t2, $t7

	# Pop pixel address from stack
	lw $t0, 0($sp)		# $t0 = address of pixel
	addi, $sp, $sp, 4	# reclaim space on stack
	
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
	
	# Return to caller			
	jr $ra
# ---------------------------------------------------------------------------------------

#########################################################################
#	UN-PAINTING FUNCTIONS						#
#########################################################################

# _get_bg_color():
#	Returns $v0 = bg_color
#	Given the values in the struct `world`, determines the 
#	correct background color, stores it in $v0
#	$t3: world.darkness
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


# unstamp_platforms()
unstamp_platforms:
	jr   $ra
# ---------------------------------------------------------------------------------------


# unstamp_crab():
# 	Removes the crab from the display at the position in $s2
#	$a0: crab_position, $t1: bg_color, $t3: in _get_bg_color
unstamp_crab:
	# Push return address onto stack
	addi $sp, $sp, -4
	sw   $ra, 0($sp)
	
	# Obtain background color
	jal  _get_bg_color
	move $t1, $v0		# $t1 = sea colour
	
	# Pop old return address from stack
	lw   $ra, 0($sp)	# $ra = old return address
	addi $sp, $sp, 4
	
	move $t0, $s2
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
unstamp_clam:
	jr   $ra
# ---------------------------------------------------------------------------------------


# unstamp_piranha()
unstamp_piranha:
	jr   $ra
# ---------------------------------------------------------------------------------------


# unstamp_pufferfish($a0 = *pixel):
# 	Removes pufferfish from the display at $a0
#	$a0: puffer_position, $t1: bg_color, $t3: in _get_bg_color
unstamp_pufferfish:
	# Push return address onto stack
	addi $sp, $sp, -4
	sw   $ra, 0($sp)
	
	# Obtain background color
	jal  _get_bg_color
	move $t1, $v0		# $t1 = sea colour
	
	# Pop old return address from stack
	lw   $ra, 0($sp)	# $ra = old return address
	addi $sp, $sp, 4
	
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


# unstamp_seahorse()
unstamp_seahorse:
	jr   $ra
# ---------------------------------------------------------------------------------------
