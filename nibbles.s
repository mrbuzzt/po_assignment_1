# Globals
.globl start_game

.set    FIELD_X,        80
.set    FIELD_Y,        50
.set    FIELD_SIZE,     FIELD_X * FIELD_Y 
.set    BUFFER_SIZE,    FIELD_SIZE * 2 * 4
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
    .long   0
    .long   1
    .long   0
    .long   -1
    .long   -1
    .long   0
    .long   1
    .long   0
worm_dy:
    .long   -1
worm_head:
    .long   -1


.section .bss
worm_tail:
    .long   0
worm_dx:
    .long   0
worm_head_x:
    .long   0
worm_head_y:
    .long   0
grow_worm:
    .long   0
    .lcomm  worm, BUFFER_SIZE
    .lcomm  apples, BUFFER_SIZE


.section .text

# Implementation of start_game(int len, int num_apples)
start_game:
    pushl   %ebp        # save the base pointer in order to be able to return
    movl    %esp, %ebp  # capture the new base pointer
    call    nib_init    # nib_init()

    # Add len initial worm parts.
    movl    $FIELD_X / 2, %esi      # %esi = $FIELD_X / 2
    movl    8(%ebp), %edi           # %ecx = len
    addl    $FIELD_Y / 2, %edi      # %eax = %eax + FIELD_Y / 2
loop_init_worm:       # Iterate to add all parts
    call    add_worm_part
    decl    %edi
    cmpl    $FIELD_Y / 2, %edi
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
    movl    $d_values, %ebx         #
    movl    (%ebx, %eax, 8), %ecx   #
    movl    %ecx, worm_dx           #
    movl    4(%ebx, %eax, 8), %ecx  #
    movl    %ecx, worm_dy           #
no_key:  # end of selection

    ## Calculate the new worm head
    # Calculate the x position: worm_head_x = worm[worm_head].x + worm_dx
    movl    worm_head, %ecx
    movl    $worm, %edx
    movl    (%edx, %ecx, 8), %eax
    addl    worm_dx, %eax
    movl    %eax, worm_head_x
    # Probe for wall colision
    cmpl    $0, %eax
    jb      game_over
    cmpl    $FIELD_X, %eax
    jae     game_over
    # Calculate the y position = worm_head_y = (worm[worm_head].y + worm_dy) % $FIELD_Y
    movl    $worm, %edx
    movl    worm_head, %ecx
    movl    4(%edx, %ecx, 8), %eax
    addl    worm_dy, %eax
    movl    %eax, worm_head_y
    # Probe for wall colision
    cmpl    $0, %eax
    jb      game_over
    cmpl    $FIELD_Y, %eax
    jae     game_over

    ## Probe for collision with apples.
    movl    $0, grow_worm
    # Initialize the loop counter.
    movl    12(%ebp), %ecx              # %ecx = num_apples
1:  # begin of loop: Iterate over all apples.
    # Check whether the worm head is at a position of the current apple
    movl    $apples, %ebx               # %eax = apples[%ecx - 1].x
    movl    -8(%ebx, %ecx, 8), %eax     
    cmp     %eax, worm_head_x           # if (worm_head_x - %eax
    jne     2f                          #       != 0) goto 2f
    movl    -4(%ebx, %ecx, 8), %eax     # %eax = apples[%ecx - 1].y
    cmp     %eax, worm_head_y           # if (worm_head_y - %eax
    jne     2f                          #       != 0) goto 2f
    call    create_apple
    # Remember to let the worm grow.
    incl    grow_worm
2:    
    loop    1b
   
    ## Pull the tail of the worm
    # Check if we want to grow the worm.
    cmp     $0, grow_worm               # if (grow_worm
    jg      2f                          #       > 0) goto 2f
    # Push floor tile on stack to draw it with nib_put_scr
    pushl   $FLOOR_TILE     
    # Push the tail's y coordinate
    movl    worm_tail, %ebx
    movl    $worm, %ecx
    pushl   4(%ecx, %ebx, 8)
    # Push the tail's x coordinate
    pushl   (%ecx, %ebx, 8)
    # Call nib_put_scr
    call    nib_put_scr
    addl     $12, %esp
    # Calculate the new worm_tail: worm_tail = (worm_tail + 1) % FIELD_SIZE
    movl    worm_tail, %edx             # %eax = worm_tail
    call    move_worm_index
    movl    %edx, worm_tail             # worm_tail = %edx
2:

    ## Probe for collision with the worm itself
    movl    $worm, %eax                 # %eax = &worm
    movl    worm_tail, %ebx             # %ebx = worm_tail
1:  # Loop over all worm tiles.
    # Check if worm_head_x and worm_head_y correspond to the current tile.
    movl    (%eax, %ebx, 8), %ecx       # %ecx = worm[%ebx].x
    cmpl    %ecx, worm_head_x           # if (worm_head_x - %ecx
    jne     2f                          #       != 0) goto 2f
    movl    4(%eax, %ebx, 8), %ecx      # %ecx = worm[%ebx].y
    cmpl    %ecx, worm_head_y           # if (worm_head_y - %ecx
    jne     2f                          #       != 0) goto 2f
    # End the game on collision.
    jmp     game_over
2:  # End of the loop body, beginning of loop condition.
    cmpl    %ebx, worm_head             # if (worm_head - %ebx
    je      3f                          #       == 0) goto 3f
    incl    %ebx                        # %ebx++
    xorl    %edx, %edx
    cmpl    $FIELD_SIZE, %ebx
    cmovel  %edx, %ebx
    jmp     1b  
3:  #End of the loop

    ## Grow the worm
    movl    worm_head_x, %esi
    movl    worm_head_y, %edi
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
    movl    $apples, %ebx
    pushl   %ecx
    # Generate the y coordinate and store it into %esi.
    call    rand                        # %eax = rand()
    xorl    %edx, %edx                  # %edx = 0
    movl    $FIELD_Y, %edi              # %edi = $FIELD_Y
    divl    %edi                        # %edx = %edx:%eax & %edi
    movl    %edx, %esi                  # %esi = %edx
    # Generate the x coordinate and store it into %edi.
    call    rand                        # %eax = rand(), use as x coordinate
    xorl    %edx, %edx                  # %edx = 0
    movl    $FIELD_X, %edi              # %edi = $FIELD_X
    divl    %edi                        # %edx = %edx:%eax % %edi
    movl    %edx, %edi                  # %edi = %edx
    # Draw the new apple.
    pushl   $APPLE_TILE
    pushl   %esi
    pushl   %edi
    call    nib_put_scr
    addl    $12, %esp
    popl    %ecx                        # Restore %ecx.
    # Store the new coordinates.
    movl    %edi, -8(%ebx, %ecx, 8)     # apples[%ecx - 1].x = %edi
    movl    %esi, -4(%ebx, %ecx, 8)     # apples[%ecx - 1].y = %esi
    ret

# Stores the given worm part in the worm array, moving worm_head forward.
# Additionally it draws the worm part.
# Params:   %esi    x coordinate
#           %edi    y coordinate
add_worm_part:
    pushl   $WORM_TILE              # push WORM_TILE on stack for later nib_put_scr call
    movl    $worm, %eax             # %edi = $worm
    # Compute and add the y component.
    movl    worm_head, %edx         # %edx = worm_head
    # Move the worm_head forward before saving the new component.
    call    move_worm_index         # move_worm_index()
    movl    %edx, worm_head         # worm_head = %edx
    pushl   %edi                    #
    movl    %edi, 4(%eax, %edx, 8)  # worm[worm_head + 4] = %eax
    pushl   %esi                    # push %eax again on the stack for nib_put_scr
    movl    %esi, (%eax, %edx, 8)   # worm[worm_head] = % eax
    # Call nib_put_scr(x, y, WORM_TILE)    
    call    nib_put_scr
    addl    $12, %esp               # Restore the stack
    ret

# Moves an index pointer to the worm array one position forward.
# Params:   %edx    index in the worm array
move_worm_index:
    incl    %edx                        # %edx++
    cmpl    $FIELD_SIZE, %edx           # if (%edx - $FIELD_SIZE
    jl      1f                          #       < 0) skip instruction
    xorl    %edx, %edx                  # %edx = 0
1:
    ret
