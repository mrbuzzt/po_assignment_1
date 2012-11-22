# Globals
.globl start_game

.set    FIELD_X,        80
.set    FIELD_Y,        50
.set    BUFFER_SIZE,    2 * FIELD_X * FIELD_Y 
.set    WORM_TILE,      'O'
.set    APPLE_TILE,     '@'
.set    FLOOR_TILE,     ' '
.set    SLEEP_TIME,     100000
.set    DOWN_KEY,       258   
.set    UP_KEY,         259
.set    LEFT_KEY,       260
.set    RIGHT_KEY,      261
.set    NO_KEY,         -1

.section .data
d_values:
    .byte   0x00
    .byte   0x01
    .byte   0x00
    .byte   0xFF
    .byte   0xFF
    .byte   0x00
    .byte   0x01
    .byte   0x00
worm_d:
    .byte   0x00
    .byte   0xFF


.section .bss
worm_head:
    .long   0
worm_tail:
    .long   0
worm_head_pos:
worm_head_x:
    .byte   0
worm_head_y:
    .byte   0
grow_worm:
    .byte   0
    .lcomm  apples, BUFFER_SIZE
    .lcomm  worm, BUFFER_SIZE


.section .text

# Implementation of start_game(int len, int num_apples)
start_game:
    pushl   %ebp        # save the base pointer in order to be able to return
    movl    %esp, %ebp  # capture the new base pointer
    call    nib_init    # nib_init()

    # Add len initial worm parts.
    movb    $FIELD_X / 2, %bl      # %esi = $FIELD_X / 2
    movb    8(%ebp), %bh           # %ecx = len
    addb    $FIELD_Y / 2, %bh      # %eax = %eax + FIELD_Y / 2
loop_init_worm:       # Iterate to add all parts
    call    add_worm_part
    decb    %bh
    cmpb    $FIELD_Y / 2, %bh
    jg      loop_init_worm

    # Initialize the apples.
    movl    12(%ebp), %ecx  # %ecx = num_apples
loop_init_apples:   # Set up the initial apples.
    call    create_apple
    loop    loop_init_apples        # if (--%ecx == 0) jump to loop_init_apples
    
game_loop:
    ## The game loop
    # sleep at first
    pushl   $SLEEP_TIME
    call    usleep
    addl    $4, %esp

    ## Read the keyboard and evaluate the key.
    call    nib_poll_kbd            # %eax = nib_poll_keyboard()
    cmpl    $RIGHT_KEY, %eax        # if (%eax - $RIGHT_KEY
    jg      no_key                  #       > 0) goto no_key
    subl    $DOWN_KEY, %eax         # %eax -= $DOWN_KEY
    js      no_key                  # if (%eax < 0) goto no_key
    movl    $d_values, %ecx         #
    movw    (%ecx, %eax, 2), %bx    #
    movw    %bx, worm_d             #
no_key:  # end of selection

    ## Calculate the new worm head
    # Calculate the x position: worm_head_x = worm[worm_head].x + worm_dx
    movl    worm_head, %ecx
    movl    $worm, %edx
    movw    (%edx, %ecx, 2), %ax
    movw    worm_d, %bx
    addb    %bl, %al
    addb    %bh, %ah
    movw    %ax, worm_head_pos
    # Probe for wall colision
    cmpb    $0, %al
    jb      game_over
    cmpb    $FIELD_X, %al
    jae     game_over
    cmpb    $0, %ah
    jb      game_over
    cmpb    $FIELD_Y, %ah
    jae     game_over


    ## Probe for collision with apples.
    movb    $0, grow_worm
    # Initialize the loop counter.
    movl    12(%ebp), %ecx              # %ecx = num_apples
1:  # begin of loop: Iterate over all apples.
    # Check whether the worm head is at a position of the current apple
    movl    $apples, %ebx               # %eax = apples[%ecx - 1].x
    movw    -2(%ebx, %ecx, 2), %dx     
    cmp     %dx, worm_head_pos           # if (worm_head_x - %eax
    jne     2f                          #       != 0) goto 2f
    call    create_apple
    # Remember to let the worm grow.
    incb    grow_worm
2:    
    loop    1b

   
    ## Pull the tail of the worm
    # Check if we want to grow the worm.
    cmpb    $0, grow_worm               # if (grow_worm
    jg      after_grow                          #       > 0) goto 2f
    # Calculate the new worm_tail: worm_tail = (worm_tail + 1) % FIELD_SIZE
    movl    worm_tail, %edx             # %eax = worm_tail
    call    move_worm_index
    movl    %edx, worm_tail             # worm_tail = %edx
    # Draw floor where the tail points now (tail is exclusive)
    movl    $worm, %ecx
    movw    (%ecx, %edx, 2), %bx
    movl    $FLOOR_TILE, %eax
    call    draw
after_grow:

    ## Probe for collision with the worm itself
    movl    $worm, %eax                 # %eax = &worm
    movl    worm_tail, %edx             # %ebx = worm_tail
loop_self_collision:  # Loop over all worm tiles.
    # Check loop condition: worm_tail != worm_head
    cmpl    %edx, worm_head
    je      3f
    # Move iterator (%edx) forward and compare pointed worm part with worm_head_pos
    call    move_worm_index
    movw    (%eax, %edx, 2), %cx        # %cx = worm[%edx]
    cmpw    %cx, worm_head_pos           # if (worm_head_x - %ecx
    jne     2f                          #       != 0) goto 2f
    # End the game on collision.
    jmp     game_over
2:  # End of the loop body, beginning of loop condition.
    jmp     loop_self_collision  
3:  #End of the loop
    ## Grow the worm
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
    pushl   %ecx
    # Generate the y coordinate and store it into %esi.
    call    rand                        # %eax = rand()
    xorb    %ah, %ah
    movb    $FIELD_Y, %cl              # %edi = $FIELD_Y
    divb    %cl                        # %edx = %edx:%eax & %edi
    movb    %ah, %bh                  # %esi = %edx
    # Generate the x coordinate and store it into %edi.
    call    rand                        # %eax = rand(), use as x coordinate
    xorb    %ah, %ah
    movb    $FIELD_X, %cl              # %edi = $FIELD_Y
    divb    %cl                        # %edx = %edx:%eax & %edi
    movb    %ah, %bl                  # %esi = %edx
    # Draw the new apple.
    movl    $APPLE_TILE, %eax
    call    draw
    popl    %ecx                        # Restore %ecx.
    # Store the new coordinates.
    movl    $apples, %eax
    movw    %bx, -2(%eax, %ecx, 2)     # apples[%ecx - 1].x = %edi
    ret

# Stores the given worm part in the worm array, moving worm_head forward.
# Additionally it draws the worm part.
# Params:   %bl    x coordinate
#           %bh    y coordinate
add_worm_part:
    movl    $worm, %eax             # %edi = $worm
    # Compute and add the y component.
    movl    worm_head, %edx         # %edx = worm_head
    # Move the worm_head forward before saving the new component.
    call    move_worm_index         # move_worm_index()
    movl    %edx, worm_head         # worm_head = %edx
    movw    %bx, (%eax, %edx, 2)
    movl    $WORM_TILE, %eax
    call    draw
    ret

# Moves an index pointer to the worm array one position forward.
# Params:   %edx    index in the worm array
move_worm_index:
    incl    %edx                        # %edx++
    cmpl    $BUFFER_SIZE / 2, %edx           # if (%edx - $FIELD_SIZE
    jl      1f                             #       < 0) skip instruction
    xorl    %edx, %edx                  # %edx = 0
1:
    ret

debug_sleep:
    pushl   %eax
    pushl   %ecx
    pushl   %edx    
    pushl   $2000000
    call    usleep
    addl    $4, %esp
    popl    %edx
    popl    %ecx
    popl    %eax
    ret

# Draws...
# Params:   %bl/%bh Coordinates
#           %eax    Character
draw:
    pushl   %eax
    xorl    %eax, %eax
    movb    %bh, %al
    pushl   %eax
    movb    %bl, %al
    pushl   %eax
    # Call nib_put_scr(x, y, WORM_TILE)    
    call    nib_put_scr
    addl    $12, %esp               # Restore the stack
    ret

