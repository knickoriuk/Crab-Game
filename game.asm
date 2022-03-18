##################################################################### 
# 
# CSCB58 Winter 2022 Assembly Final Project 
# University of Toronto, Scarborough 
# 
# Student: Kate Nickoriuk, 1003893691, nickoriu, k.nickoriuk@mail.utoronto.ca 
# 
# Bitmap Display Configuration: 
# - Unit width in pixels: 4 (update this as needed)  
# - Unit height in pixels: 4 (update this as needed) 
# - Display width in pixels: 256 (update this as needed) 
# - Display height in pixels: 512 (update this as needed) 
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
.eqv	SLEEP_DUR	20		# Sleep duration between loops
.eqv	INIT_POS	32700		# Initial position of the crab (offset from $gp)
.eqv	KEYSTROKE	0xffff0000	# Address storing keystrokes & values
.eqv	SEA_COL_4	0x000b3e8a	# Sea colour, darkest
.eqv	SEA_COL_3	0x000d47a1	#	:
.eqv	SEA_COL_2	0x001052b5	#	:
.eqv	SEA_COL_1	0x00125dcc	#	:
.eqv	SEA_COL_0	0x001467db	# Sea colour, lightest
.eqv	DARKNESS	0x00050505	# amount to darken colours by, per level

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
#	int level:	# 4, 3, 2, 1, 0
#	int score;	# Holds score (?)
# }
clam:		.space		12
# struct clam {
#	int visible;	# 0 if invisible, 1 if visible
#	int position;	# Pixel address of position of clam
#	int state;	# 0 if closed, 1 if open
# }

.text
.globl main

########## Register Assignment for main() ##########
# $s0 - `world` data pointer	# todo: if this stays the same, do we need to load it in 
				# functions? what is allowed? do they allow things? let's 
				# find out.
# $s1 - `crab` data pointer
# $s2 -
# $s3 -
# $s4 -
# $s5 -
# $s6 -
# $s7 -
# $t0 - temporary values

########## Initialize Game Values ##########
main:	# `world` initial data
	la $s0, world
	li $t0, 4
	sw $t0, ($s0)		# world.level = 4
	
	# `crab` initial data
	la $s1, crab
	li $t0, INIT_POS
	add $t0, $t0, $gp
	sw $t0, ($s1)		# crab.pos = addr($gp) + INIT_POS
	li $t0, 0
	sw $t1, 4($s1)		# crab.state = 0
	
	# Fill in background
	jal generate_background
	jal stamp_crab
	
########## Get Keyboard Input ##########

main_loop:
	li $t0, KEYSTROKE
	lw $t0, 0($t0) 			# $t0 = 1 if key hit, 0 otherwise
	bne $t0, 1, update_display	# if no key was hit, branch to `update_display` 
				
				# If it reaches here, a key was hit.
	jal unstamp_crab	# remove crab before we modify its location
	jal key_pressed		# Update position in `crab` struct	

########## Update Display ##########

update_display:
	jal stamp_crab		# Add crab to display
	
########## Sleep and Repeat ##########

	# Sleep for `SLEEP_DUR` milliseconds
	li $a0, SLEEP_DUR
	li $v0, 32
	syscall
	
	j main_loop	# Jump back to main loop, checking for next key press

########## Testing Functions, For Now #########
		
	# Seahorse
	addi $sp, $sp, -4	# make room on stack
	li $t2, 7000		# $t2 = 7000
	add $t2, $t2, $gp	# $t2 = position
	sw $t2, 0($sp)		# push to stack
	jal stamp_seahorse
	
	# Clam
	addi $sp, $sp, -4	
	li $t2, 32600		
	add $t2, $t2, $gp	
	sw $t2, 0($sp)		
	jal stamp_clam
	
	# Pufferfish
	addi $sp, $sp, -4
	li $t2, 12988		
	add $t2, $t2, $gp	
	sw $t2, 0($sp)		
	jal stamp_pufferfish
	
	
exit:	li  $v0, 10
	syscall

#########################################################################
#	KEYBOARD INPUT FUNCTIONS					#
#########################################################################

# key_pressed():
#	Determines and updates new position for the crab given the current key pressed.
#	$t1: addr(crab), $t2: crab_pos, $t3: crab_state, $t9: key_input
key_pressed:
	li $t9, KEYSTROKE  	# $t9 
	lw $t9, 4($t9) 		# $t9 = last key hit 
	
	# Get crab data
	la $t1, crab	# $t1 = addr(crab)
	lw $t2, 0($t1)	# $t2 = crab.position
	lw $t3, 4($t1)	# $t3 = crab.state
	
	# If dead (state 3), don't change anything.
	beq $t3, 3, key_input_done
	
	# Check which key pressed
	beq $t9, 0x61, key_a  	# If $t9 == 'a', branch to `key_a`
	beq $t9, 0x64, key_d  	# If $t9 == 'd', branch to `key_d`
	beq $t9, 0x77, key_w  	# If $t9 == 'w', branch to `key_w`
	beq $t9, 0x70, key_p  	# If $t9 == 'p', branch to `key_p`
	j key_input_done	# Otherwise, treat like no key pressed

key_a:	# MOVE LEFT		# Update position stored in `crab`
	addi $t2, $t2, -4	# $t2 = crab.position - 4
	sw $t2, 0($t1)		# crab.position = crab.position - 4

	bge $t3, 2, key_input_done	# If currently jumping (state 2), don't toggle walk state
	j key_toggle_check		# Toggle between walk states (state 1 and 0)

key_d:	# MOVE RIGHT		# Update position stored in `crab`
	addi $t2, $t2, 4	# $t2 = crab.position + 4
	sw $t2, 0($t1)		# crab.position = crab.position + 4

	bge $t3, 2, key_input_done	# If currently jumping (state 2), don't toggle walk state
	j key_toggle_check		# Toggle between walk states (state 1 and 0)

key_w:	# JUMP			# Update position stored in `crab`
	addi $t2, $t2, -WIDTH	# $t2 = crab.position - WIDTH
	sw $t2, 0($t1)		# crab.position = crab.position - WIDTH
	li $t3, 2		# $t3 = 2
	sw $t3, 4($t1)		# crab.state = 2
	j key_input_done

key_p:	# RESET
	# TODO
	j key_input_done
	
key_toggle_check:
	beq $t3, 0, key_toggle_1	# If state==0, toggle walk state from 0 -> 1
	
	# Toggle crab.state from 1 to 0
	li $t3, 0
	sw $t3, 4($t1)		# crab.state = 0
	j key_input_done
	
key_toggle_1:
	# Toggle crab.state from 0 to 1
	li $t3, 1
	sw $t3, 4($t1)		# crab.state = 1

key_input_done:
	jr $ra
# ---------------------------------------------------------------------------------------


#########################################################################
#	PAINTING FUNCTIONS						#
#########################################################################

# generate_background():
#	Fills the display with a background colour
# 	$t0: index, $t1: max_index, $t2: pixel_address, $t9: bg_color
generate_background:	
	# Push return address onto stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# Obtain background color based on level in `world` struct
	jal get_bg_color
	
	# Pop result and old return address from stack
	lw $t9, 0($sp)		# $t9 = sea colour
	lw $ra, 4($sp)		# $ra = old return address
	addi $sp, $sp, 8
	
	# Set up indices of iteration
	li $t0, 0		# $t0 = i
	li $t1, 32768		# $t1 = 32768 (128*64*4)

bg_loop:
	beq $t0, $t1, bg_end	# branch to `bg_end` if i == 32768
	
	# Colour the ith pixel
	add $t2, $gp, $t0	# $t2 = addr($gp) + i
	sw $t9, ($t2)		# Set pixel at addr($gp) + i to primary bg color
	
	# Update i and loop again
	addi $t0, $t0, 4	# i = i + 4
	j bg_loop		# jump back to start

bg_end:	jr $ra
# ---------------------------------------------------------------------------------------


# build_platform(*start, int length):
#	Builds a horizontal platform starting at `*start`, with `length` pixels of length
build_platform:
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_crab():
# 	"Stamps" the crab onto the display at crab.position
#	$t0: pixel_address, $t1-$t4: colours, $t5: world, $t6: temp
stamp_crab:
	li $t1, 0x00cc552d	# $t1 = crab base
	li $t2, 0x00a33615	# $t2 = crab shell
	li $t3, 0x00ffffff	# $t3 = white
	li $t4, 0x00000000	# $t4 = black
	
	# Determine darkening factor
	la $t5, world
	lw $t5, ($t5)		# $t5 = world.level
	li $t6, DARKNESS	# 
	mul $t6, $t6, $t5	# $t6 = $t6 * world.level
	
	# Darken colors based on darkening factor
	sub $t1, $t1, $t6
	sub $t2, $t2, $t6
	sub $t3, $t3, $t6

	# Get pixel address
	la $t0, crab		# $t0 = addr(crab struct)
	lw $t0, 0($t0)		# $t0 = crab.position
	
	# Color the pixels appropriately
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
	
	# Return to caller			
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_clam(*pixel):
# 	"Stamps" a clam shell onto the display given it is positioned at *pixel
#	$t0: pixel_address, $t1-$t5: colors, $t6: world, $t7: temp
stamp_clam:
	li $t1, 0x00c496ff	# $t1 = shell midtone
	li $t2, 0x00c7a3f7	# $t2 = shell highlight
	li $t3, 0x009a7ac7	# $t3 = shell lo-light
	li $t4, 0x00ffffff	# $t4 = pearl
	li $t5, 0x00faf9e3	# $t5 = pearl shadow
	
	# Determine darkening factor
	la $t6, world
	lw $t6, ($t6)		# $t6 = world.level
	li $t7, DARKNESS	# 
	mul $t7, $t7, $t6	# $t7 = $t7 * world.level
	
	# Darken colors based on darkening factor
	sub $t1, $t1, $t7
	sub $t2, $t2, $t7
	sub $t3, $t3, $t7
	
	# Pop pixel address from stack
	lw $t0, 0($sp)		# $t0 = address of pixel
	addi, $sp, $sp, 4	# reclaim space on stack
	
	# Determine if clam is open or closed
	la $t7, clam
	lw $t7 8($t7)		# $t7 = clam.state
	beq $t7, 0, sc_closed	# if clam.state == 0, branch to `sc_closed`
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


# stamp_piranha(*pixel):
# 	"Stamps" a piranha onto the display given it is positioned at *pixel
#	$t0: pixel_address, $t1-$t4: colors, $t6: world, $t7: temp
stamp_piranha:
	li $t1, 0x00312e73	# $t1 = base color
	li $t2, 0x00661a1f	# $t2 = belly color
	li $t3, 0x009595ad	# $t3 = teeth color
	li $t4, 0x00000000	# $t4 = black
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_pufferfish(*pixel):
# 	"Stamps" a pufferfish onto the display given it is positioned at *pixel
#	$t0: pixel_address, $t1-$t5: colors, $t6: world, $t7: temp
stamp_pufferfish:
	li $t1, 0x00a8c267	# $t1 = base color
	li $t2, 0x00929644	# $t2 = fin/spikes color
	li $t3, 0x00ffffff	# $t3 = belly color
	li $t4, 0x00d1d1d1	# $t4 = belly spikes color
	li $t5, 0x00000000	# $t5 = black
	
	# Determine darkening factor
	la $t6, world
	lw $t6, ($t6)		# $t6 = world.level
	li $t7, DARKNESS	# 
	mul $t7, $t7, $t6	# $t7 = $t7 * world.level
	
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
#	$t0: pixel_address, $t1-$t3: colors, $t6: world, $t7: temp
stamp_seahorse:
	li $t1, 0x00ff9815	# $t1 = seahorse colour
	li $t2, 0x00ffeb3b	# $t2 = fin colour
	li $t3, 0x00000000	# $t3 = black
	
	# Determine darkening factor
	la $t6, world
	lw $t6, ($t6)		# $t6 = world.level
	li $t7, DARKNESS	# 
	mul $t7, $t7, $t6	# $t7 = $t7 * world.level
	
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

# get_bg_color():
#	Returns bg_color
#	Given the values in the struct `world`, pushes the 
#	correct background color onto the stack
#	$t1: bg_color, $t3: world
get_bg_color:
	la $t3, world
	lw $t3, ($t3)		# $t3 = world.level
	beq $t3, 0, gbc_level_0	# branch if world.level == 0
	beq $t3, 1, gbc_level_1	# branch if world.level == 1
	beq $t3, 2, gbc_level_2	# branch if world.level == 2
	beq $t3, 3, gbc_level_3	# branch if world.level == 3
	li $t1, SEA_COL_4	# $t1 = bg color 4
	j gbc_exit
gbc_level_0:
	li $t1, SEA_COL_0	# $t1 = bg color 0
	j gbc_exit
gbc_level_1:
	li $t1, SEA_COL_1	# $t1 = bg color 1
	j gbc_exit
gbc_level_2:
	li $t1, SEA_COL_2	# $t1 = bg color 2
	j gbc_exit
gbc_level_3:
	li $t1, SEA_COL_3	# $t1 = bg color 3
gbc_exit:
	# Push result onto stack
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	jr $ra
# ---------------------------------------------------------------------------------------


# unstamp_crab():
# 	Removes the crab from the display
#	$t0: crab_address, $t1: bg_color
unstamp_crab:
	# Push return address onto stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# Obtain background color
	jal get_bg_color
	
	# Pop result and old return address from stack
	lw $t1, 0($sp)		# $t1 = sea colour
	lw $ra, 4($sp)		# $ra = old return address
	addi $sp, $sp, 8

	# Get pixel address
	la $t0, crab		# $t0 = addr(crab struct)
	lw $t0, 0($t0)		# $t0 = crab.position
	
	# Color the pixels appropriately
	sw $t1, -16($t0)
	sw $t1, 16($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, -0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
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
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -12($t0)
	sw $t1, -8($t0)
	sw $t1, -4($t0)
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)
	sw $t1, -8($t0)
	sw $t1, 8($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -32($t0)
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	addi $t0, $t0, -WIDTH
	sw $t1, -28($t0)
	sw $t1, -24($t0)
	sw $t1, -20($t0)

	# Return to caller			
	jr $ra
# ---------------------------------------------------------------------------------------
