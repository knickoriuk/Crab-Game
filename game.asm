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
########## Initialize Game Values ##########
main:	# `world` initial data
	la $t0, world
	li $t1, 4
	sw $t1, ($t0)		# world.level = 4
	
	# `crab` initial data
	la $t0, crab
	li $t1, INIT_POS
	add $t1, $t1, $gp
	sw $t1, ($t0)		# crab.pos = addr($gp) + INIT_POS
	li $t1, 0
	sw $t1, 4($t0)		# crab.state = 0
	
	# Fill in background
	jal generate_background
	jal stamp_crab
	
########## Get Keyboard Input ##########

detect_keystroke:
	# KEYSTROKE
	#	+0: 1 if key hit, 0 if key not hit
	#	+4: ascii value of key that was hit

	li $t9, KEYSTROKE  	# $t9 
	lw $t8, 0($t9) 		
	bne $t8, 1, no_key_hit	# if no key was hit, branch to `no_key hit` 
				# If it reaches here, a key was hit.
	lw $t9, 4($t9) 		# $t9 = last key hit 
	beq $t9, 0x61, key_a  	# If $t9 == 'a', branch to `key_a`
	beq $t9, 0x64, key_d  	# If $t9 == 'd', branch to `key_d`
	beq $t9, 0x77, key_w  	# If $t9 == 'w', branch to `key_w`
	beq $t9, 0x70, key_p  	# If $t9 == 'p', branch to `key_p`
	j no_key_hit		# Otherwise, treat like no key pressed
	
########## Update Display ##########

key_a:	jal unstamp_crab
	jal pressed_a		# Move character left
	j key_input_done

key_d:	jal unstamp_crab
	jal pressed_d		# Move character right
	j key_input_done

key_w:	jal unstamp_crab
	jal pressed_w		# Jump character
	j key_input_done

key_p:	jal unstamp_crab #?
	jal pressed_p		# Reset Game
	j key_input_done

key_input_done:
	jal stamp_crab		# Add crab to display

no_key_hit:
	# Don't need to update character position
	
########## Sleep and Repeat ##########

	# Sleep for `SLEEP_DUR` milliseconds
	li $a0, SLEEP_DUR
	li $v0, 32
	syscall
	
	j detect_keystroke	# Check for next key

########## Testing Functions, For Now #########
	
	
	
	# Seahorse
	addi $sp, $sp, -4	# make room on stack
	li $t2, 7000		# $t2 = 7000
	add $t2, $t2, $gp	# $t2 = position
	sw $t2, 0($sp)		# push to stack
	jal stamp_seahorse
	
	# Closed Clam
	addi $sp, $sp, -4	
	li $t2, 32600		
	add $t2, $t2, $gp	
	sw $t2, 0($sp)		
	jal stamp_closed_clam
	
	# Open Clam
	addi $sp, $sp, -4
	li $t2, 26000		
	add $t2, $t2, $gp	
	sw $t2, 0($sp)		
	jal stamp_open_clam
	
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

# pressed_a():
#	Move crab left if applicable, update new location in `crab` struct
#	Additionally, toggle walk state between 0 and 1
#	TODO: Check for walls
pressed_a:
	la $t1, crab
	lw $t2, 0($t1)	# $t2 = crab.position
	lw $t3, 4($t1)	# $t3 = crab.state
	
	beq $t3, 2, pa_move_left	# If currently jumping (state 2), just move left
	beq $t3, 3, pa_exit		# If dead (state 3), don't change anything
	beq $t3, 0, pa_toggle_1		# If state==0, toggle walk state from 0 -> 1
	
	# Otherwise toggle walk state from 1 -> 0
	li $t3, 0		
	sw $t3, 4($t1)		# crab.state = 0
	j pa_move_left

pa_toggle_1:
	li $t3, 1
	sw $t3, 4($t1)		# crab.state = 1
	
pa_move_left:			# Update position stored in `crab`
	addi $t2, $t2, -4	# $t2 = crab.position - 4
	sw $t2, 0($t1)		# crab.position = crab.position - 4
pa_exit:
	jr $ra
# ---------------------------------------------------------------------------------------
	
# pressed_d():
#	Move crab right if applicable, update new location in `crab` struct
#	Additionally, toggle walk state between 0 and 1
#	TODO: Check for walls
pressed_d:
	la $t1, crab
	lw $t2, 0($t1)	# $t2 = crab.position
	lw $t3, 4($t1)	# $t3 = crab.state
	
	beq $t3, 2, pd_move_right	# If currently jumping (state 2), just move right
	beq $t3, 3, pd_exit		# If dead (state 3), don't change anything
	beq $t3, 0, pd_toggle_1		# If state==0, toggle walk state from 0 -> 1
	
	# Otherwise toggle walk state from 1 -> 0
	li $t3, 0		
	sw $t3, 4($t1)		# crab.state = 0
	j pd_move_right

pd_toggle_1:
	li $t3, 1
	sw $t3, 4($t1)		# crab.state = 1
	
pd_move_right:
	addi $t2, $t2, 4	# $t2 = crab.position + 4
	sw $t2, 0($t1)		# crab.position = crab.position + 4
pd_exit:
	jr $ra
# ---------------------------------------------------------------------------------------
	
# pressed_w():
#	Jump crab if applicable
#	Update new position in `crab` struct
#	TODO: Wall detection, gravity, falling, etc.
pressed_w:
	la $t1, crab
	lw $t2, 0($t1)	# $t2 = crab.position
	lw $t3, 4($t1)	# $t3 = crab.state
	
	beq $t3, 2, pw_move_up	# If currently jumping (state 2), just move up
	beq $t3, 3, pw_exit	# If dead (state 3), don't change anything
	
	# Ensure state is set to 2 (jumping)
	li $t3, 2		
	sw $t3, 4($t1)		# crab.state = 2
	
pw_move_up:
	addi $t2, $t2, -WIDTH	# $t2 = crab.position - WIDTH
	sw $t2, 0($t1)		# crab.position = crab.position + 1
pw_exit:
	jr $ra
# ---------------------------------------------------------------------------------------

# pressed_p():
#	Reset game. TBD
pressed_p:
	jr $ra
# ---------------------------------------------------------------------------------------


#########################################################################
#	PAINTING FUNCTIONS						#
#########################################################################

# generate_background():
#	Fills the display with a background colour
# 	Uses registers $t0, $t1, $t2, $t9
generate_background:
	li $t0, 0		# $t0 = i
	li $t1, 32768		# $t1 = 32768 (128*64*4)
	
	# Determine bg color based on level in `world` struct
	la $t3, world
	lw $t3, ($t3)		# $t3 = world.level
	beq $t3, 0, bg_level_0	# branch if world.level == 0
	beq $t3, 1, bg_level_1	# branch if world.level == 1
	beq $t3, 2, bg_level_2	# branch if world.level == 2
	beq $t3, 3, bg_level_3	# branch if world.level == 3
	li $t9, SEA_COL_4	# $t8 = bg color 4
	j bg_loop
bg_level_0:
	li $t9, SEA_COL_0	# $t8 = bg color 0
	j bg_loop
bg_level_1:
	li $t9, SEA_COL_1	# $t8 = bg color 1
	j bg_loop
bg_level_2:
	li $t9, SEA_COL_2	# $t8 = bg color 2
	j bg_loop
bg_level_3:
	li $t9, SEA_COL_3	# $t8 = bg color 3
	
bg_loop:
	beq $t0, $t1, bg_end	# branch to `bg_end` if i = 8192
	
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
#	Uses registers $t0, $t1, $t2, $t3, $t4
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


# stamp_open_clam(*pixel):
# 	"Stamps" a open clam shell onto the display given it is positioned at *pixel
#	Uses registers $t0-$t7
stamp_open_clam:
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
	
	# Color the pixels appropriately
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
	
	# Return to caller
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_closed_clam(*pixel):
# 	"Stamps" a closed clam shell onto the display given it is positioned at *pixel
#	Uses registers $t0-$t3, $t6, $t7
stamp_closed_clam:
	li $t1, 0x00c496ff	# $t1 = shell midtone
	li $t2, 0x00c7a3f7	# $t2 = shell highlight
	li $t3, 0x009a7ac7	# $t3 = shell lo-light
	
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
	
	# Color the pixels appropriately
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
	
	# Return to caller
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_piranha_L(*pixel):
# 	"Stamps" a left-facing piranha onto the display given it is positioned at *pixel
stamp_piranha_L:
	li $t1, 0x00312e73	# $t1 = base color
	li $t2, 0x00661a1f	# $t2 = belly color
	li $t3, 0x009595ad	# $t3 = teeth color
	li $t4, 0x00000000	# $t4 = black
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_piranha_R(*pixel):
# 	"Stamps" a right-facing piranha onto the display given it is positioned at *pixel
stamp_piranha_R:
	li $t1, 0x00312e73	# $t1 = base color
	li $t2, 0x00661a1f	# $t2 = belly color
	li $t3, 0x009595ad	# $t3 = teeth color
	li $t4, 0x00000000	# $t4 = black
	jr $ra
# ---------------------------------------------------------------------------------------


# stamp_pufferfish(*pixel):
# 	"Stamps" a pufferfish onto the display given it is positioned at *pixel
#	Uses registers $t0-$t7
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
#	Uses registers $t0-$t3, $t6, $t7
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
#	Helper function. Given the values in the struct `world`,
#	Sets the register $a0 to the background color.
#	Todo: see about what register I can use here
get_bg_color:
	la $t3, world
	lw $t3, ($t3)		# $t3 = world.level
	beq $t3, 0, gbc_level_0	# branch if world.level == 0
	beq $t3, 1, gbc_level_1	# branch if world.level == 1
	beq $t3, 2, gbc_level_2	# branch if world.level == 2
	beq $t3, 3, gbc_level_3	# branch if world.level == 3
	li $a0, SEA_COL_4	# $a0 = bg color 4
	j gbc_exit
gbc_level_0:
	li $a0, SEA_COL_0	# $a0 = bg color 0
	j gbc_exit
gbc_level_1:
	li $a0, SEA_COL_1	# $a0 = bg color 1
	j gbc_exit
gbc_level_2:
	li $a0, SEA_COL_2	# $a0 = bg color 2
	j gbc_exit
gbc_level_3:
	li $a0, SEA_COL_3	# $a0 = bg color 3
gbc_exit:
	jr $ra
# ---------------------------------------------------------------------------------------


# unstamp_crab():
# 	Removes the crab from the display
#	Uses registers $t0, $t1
unstamp_crab:
	li $t1, SEA_COL_4	# $t1 = sea colour

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
