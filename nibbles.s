### Globals ###
.globl start_game

### Constants ###
.set    FIELD_X,        80
.set    FIELD_Y,        50
.set    BUFFER_SIZE,    2 * FIELD_X * FIELD_Y 
.set    WORM_TILE,      'O'
.set    APPLE_TILE,     '@'
.set    FLOOR_TILE,     ' '
.set    SLEEP_TIME,     50000
.set    DOWN_KEY,       258   
.set    UP_KEY,         259
.set    LEFT_KEY,       260
.set    RIGHT_KEY,      261
.set    NO_KEY,         -1

### Initialized data ###
.section .data

# Array with key-direction mapping
key_to_direction:
    .byte   0
    .byte   1
    .byte   0
    .byte   FIELD_Y - 1
    .byte   FIELD_X - 1
    .byte   0
    .byte   1
    .byte   0

# Worm direction (initially going up)
worm_d:
    .byte   0
    .byte   FIELD_Y - 1

### Zero-initialized data ###
.section .bss

# End and start index in the worm buffer
worm_head:
    .long   0
worm_tail:
    .long   0

# Stores the future worm's position
worm_head_pos:
    .byte   0
    .byte   0

# Stores whether the worm ate an apple each round
grow_worm:
    .byte   0

# Buffer for apple positions
    .lcomm  apples, BUFFER_SIZE

# Buffer for worm part positions
    .lcomm  worm, BUFFER_SIZE

### Code ###
.section .text

# Implementation of start_game(int len, int num_apples)
start_game:
    # At first, we need to set up the initial game state.
    # Call nib_init().
    call    nib_init
    
    # Misuse the %ebp register to store the worm array start.
    movl    $worm, %ebp

    # Add len initial worm parts so that the head is in the 
    # middle of the field.
    movb    $FIELD_X / 2, %bl
    movb    4(%esp), %bh        # %bh = len (Argument)
    addb    $FIELD_Y / 2, %bh
loop_init_worm:       # Add one worm part in each iteration
    call    add_worm_part
    decb    %bh
    cmpb    $FIELD_Y / 2, %bh
    jg      loop_init_worm

    # Initialize the apples.
    movl    8(%esp), %ecx  # %ecx = num_apples
loop_init_apples:
    call    create_apple
    loop    loop_init_apples        # if (--%ecx == 0) 
                                    # jump to loop_init_apples
    
# Now the game is set up and the recurring game logic comes.
# Each iteration of the game loop moves the worm by one field.
game_loop:
    # Sleep at first to get a reasonable game speed.
    pushl   $SLEEP_TIME
    call    usleep
    addl    $4, %esp

    # Read the keyboard and evaluate the key.
    call    nib_poll_kbd            # %eax = nib_poll_kbd()
    # If key code corresponds to an arrow key then calculate an
    # index into key_to_direction to it.
    cmpl    $RIGHT_KEY, %eax  
    jg      no_key 
    subl    $DOWN_KEY, %eax
    js      no_key
    # At this point, the keycode is converted into an index into 
    # the key_to_direction array in %eax.
    movl    $key_to_direction, %ecx 
    movw    (%ecx, %eax, 2), %bx    # %bx = key_to_direction[%eax]
    movw    %bx, worm_d             # Store the d_value in worm_d.
no_key:  # end of selection

    # Calculate the new position:
    # worm_head_pos = worm[worm_head] + worm_d
    movl    worm_head, %esi
    movw    (%ebp, %esi, 2), %ax
    addw    worm_d, %ax
    # worm_head_pos.x %= FIELD_X
    subb    $FIELD_X, %al
    jns     1f
    addb    $FIELD_X, %al
    # worm_head_pos.y %= FIELD_Y
1:  subb    $FIELD_Y, %ah
    jns     2f
    addb    $FIELD_Y, %ah
    # Store the new position
2:  movw    %ax, worm_head_pos
    


    # Probe for collision with apples.
    movb    $0, grow_worm
    movl    8(%esp), %ecx               # %ecx = num_apples
loop_apple_collision:  # Iterate over all apples.
    # Check whether worm_head is at the position of the current
    # apple.
    movl    $apples, %ebx
    movw    -2(%ebx, %ecx, 2), %dx      # %dx = apples[%ecx - 1]
    cmp     %dx, worm_head_pos
    jne     1f
    call    create_apple
    # Remember to let the worm grow.
    incb    grow_worm
1:
    loop    loop_apple_collision        # while (--%ecx > 0)

   
    # Pull the tail of the worm if grow_worm == 0.
    cmpb    $0, grow_worm
    jg      after_grow
    # Calculate the new worm_tail:
    # worm_tail = (worm_tail + 1) % FIELD_SIZE
    movl    worm_tail, %edx
    call    move_worm_index
    movl    %edx, worm_tail
    # Draw floor where the tail points now (worm_tail is exclusive)
    movw    (%ebp, %edx, 2), %bx
    movl    $FLOOR_TILE, %eax
    call    draw
after_grow:

    # Probe for collision with the worm itself
    movl    worm_tail, %edx
loop_self_collision:  # Loop over all worm tiles.
    # Check loop condition: worm_tail != worm_head
    cmpl    %edx, worm_head
    je      3f
    # Move iterator (%edx) forward and compare pointed worm part 
    # with worm_head_pos.
    call    move_worm_index
    movw    (%ebp, %edx, 2), %cx        # %cx = worm[%edx]
    cmpw    %cx, worm_head_pos
    jne     2f
    # End the game on collision.
    jmp     game_over
2: 
    jmp     loop_self_collision  
3:  #End of the loop
    
    # Draw and save the new worm head.
    movw    worm_head_pos, %bx
    call    add_worm_part
 
    # Restart the game loop
    jmp     game_loop

game_over:
    call    nib_end

# Generates coordinated for a new apple, stores them in apples
# and draws it on the screen.
# Params:   %ecx    Index+1 in the apples array
# Uses:     %eax, %edx, %edi, %esi
create_apple:
    # This function shall not modify %ecx.
    pushl   %ecx
    # Generate the y coordinate and store it into %bh.
    call    rand                        # %eax = rand()
    xorb    %ah, %ah
    movb    $FIELD_Y, %cl
    divb    %cl                         # %ah = %ax % %cl
    movb    %ah, %bh
    # Generate the x coordinate and store it into %bl.
    call    rand                        # %eax = rand()
    xorb    %ah, %ah
    movb    $FIELD_X, %cl
    divb    %cl                         # %ah = %ax % %cl
    movb    %ah, %bl
    # Draw the new apple.
    movl    $APPLE_TILE, %eax
    call    draw
    popl    %ecx                        # Restore %ecx.
    # Store the new coordinates.
    movl    $apples, %eax
    movw    %bx, -2(%eax, %ecx, 2)      # apples[%ecx - 1] = %bx
    ret

# Stores the given worm part in the worm array, moving worm_head 
# forward. Additionally it draws the worm part.
# Params:   %bl    x coordinate
#           %bh    y coordinate
add_worm_part:
    movl    worm_head, %edx
    # Move the worm_head forward before saving the new component.
    call    move_worm_index
    movl    %edx, worm_head
    movw    %bx, (%ebp, %edx, 2)
    movl    $WORM_TILE, %eax
    call    draw
    ret

# Moves an index pointer to the worm array one position forward.
# Params:   %edx    index in the worm array
move_worm_index:
    # %edx = (%edx + 1) % (BUFFER_SIZE / 2)
    incl    %edx
    cmpl    $BUFFER_SIZE / 2, %edx
    jl      1f
    xorl    %edx, %edx                  # %edx = 0
1:
    ret

# Draws a character at the specified position.
# Params:   %bl/%bh Coordinates
#           %eax    Character
draw:
    # Call nib_put_scr(%bl, %bh, %eax).
    pushl   %eax
    xorl    %eax, %eax
    movb    %bh, %al
    pushl   %eax
    movb    %bl, %al
    pushl   %eax
    call    nib_put_scr                 
    addl    $12, %esp
    ret

