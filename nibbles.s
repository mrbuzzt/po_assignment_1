# Globals
.globl start_game

.set    FIELD_X,        80
.set    FIELD_Y,        50
.set    FIELD_SIZE,     FIELD_X * FIELD_Y 
.set    BUFFER_SIZE,    FIELD_SIZE * 2 * 4
.set    WORM_TILE,      'O'
.set    APPLE_TILE,     '@'
.set    FLOOR_TILE,     ' '
.set    SLEEP_TIME,     250000
.set    DOWN_KEY,       258   
.set    UP_KEY,         259
.set    LEFT_KEY,       260
.set    RIGHT_KEY,      261
.set    NO_KEY,         -1

.section .data
debug:
    .asciz "--> %d\n"

.section .bss
worm_head:
    .long   0
worm_tail:
    .long   0
worm_dx:
    .long   0
worm_dy:
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

    # Initialize the worm.
    movl    $0, worm_dx
    movl    $-1, worm_dy
    movl    $-1, worm_head   # worm_head = -1
    movl    $0, worm_tail   # worm_tail = 0
    # Add len initial worm parts.
    movl    8(%ebp), %ecx   # %ecx = len
loop1:       # Iterate to add all parts
    pushl   %ecx
    pushl   $WORM_TILE              # push WORM_TILE on stack for later nib_put_scr call
    movl    $worm, %edi             # %edi = $worm
    # Compute and add the y component.
    movl    %ecx, %eax              # %eax = %ecx
    addl    $FIELD_Y / 2, %eax      # %eax = %eax + FIELD_Y / 2
    pushl   %eax                    # push %eax on the stack for later nib_put_scr call
    movl    worm_head, %edx         # %edx = worm_head
    # Move the worm_head forward before saving the new component.
    incl    %edx                    # %edx++
    movl    %edx, worm_head         # worm_head = %edx
    movl    $worm, %edi             # %edi = $worm
    movl    %eax, 4(%edi, %edx, 8)  # worm[worm_head + 4] = %eax
    # Add the x component
    movl    $FIELD_X / 2, %eax      # %eax = $FIELD_X / 2
    pushl   %eax                    # push %eax again on the stack for nib_put_scr
    movl    %eax, (%edi, %edx, 8)   # worm[worm_head] = % eax
    # Call nib_put_scr(x, y, WORM_TILE)    
    call    nib_put_scr
    addl    $12, %esp               # Restore the stack
    popl    %ecx
    loop    loop1                   # Continue loop

    # Initialize the apples.
    movl    12(%ebp), %ecx  # %ecx = num_apples
loop_init_apples:   # Set up the initial apples.
    pushl   %ecx
    pushl   $APPLE_TILE             # already push the $WORM_TILE for the coming nib_put_scr call
    # Randomize a y position.
    call    rand                    # %eax = rand()
    movl    $FIELD_Y, %edi          # %ebx = $FIELD_Y
    xorl    %edx, %edx              # %edx = 0
    divl    %edi                    # %edx = %eax MOD FIELD_Y (i.e. the y position)
    pushl   %edx                    # push it on the stack for upcoming nib_put_scr call
    movl    $apples, %ebx           # %ebx = $apples
    movl    8(%esp), %ecx           # %ecx = top of stack
    movl    %edx, -4(%ebx, %ecx, 8) # apples[8 * %ecx - 4] = %edx
    # Randomize an x position.
    call    rand                    # %eax = rand()
    movl    $FIELD_X, %edi          # %ebx = $FIELD_X
    xorl    %edx, %edx              # %edx = 0
    divl    %edi                    # %edx = %eax MOD FIELD_X (i.e. the x position)
    pushl   %edx                    # push it on the stack for upcoming nib_put_scr call
    movl    12(%esp), %ecx          # %ecx = top of stack
    movl    %edx, -8(%ebx, %ecx, 8) # apples[8 * %ecx - 8] = %edx
    # Call nib_put_scr
    call    nib_put_scr             # call nib_put_scr(x, y, APPLE_TILE)
    addl    $12, %esp               # reset the stack
    # Continue the loop.
    popl    %ecx                    # pop %ecx
    loop    loop_init_apples        # if (--%ecx == 0) jump to loop_init_apples
    
game_loop:
    ## The game loop
    # sleep at first
    pushl   $SLEEP_TIME
    call    usleep
    addl    $4, %esp

    ## Read the keyboard and evaluate the key.
    call    nib_poll_kbd       # %eax = nib_poll_keyboard()
    cmpl    $NO_KEY, %eax
    je      2f
    cmpl    $DOWN_KEY, %eax
    jne     1f
    movl    $0, worm_dx
    movl    $1, worm_dy
    jmp     2f
1:
    cmpl    $UP_KEY, %eax
    jne     1f
    movl    $0, worm_dx
    movl    $-1, worm_dy
    jmp     2f
1:
    cmpl    $LEFT_KEY, %eax
    jne     1f
    movl    $-1, worm_dx
    movl    $0, worm_dy
    jmp     2f
1:
    cmpl    $RIGHT_KEY, %eax
    jne     2f
    movl    $1, worm_dx
    movl    $0, worm_dy
2:  # end of selection

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
    # Generate new apple coordinates.
    pushl   %ecx                        # Save %ecx because of function calls.
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
    movl    %edx, -8(%ebx, %ecx, 8)     # apples[%ecx - 1].x = %edx
    movl    %esi, -4(%ebx, %ecx, 8)     # apples[%ecx - 1].y = %esi

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
    incl    %edx                        # %eax++
    cmpl    $FIELD_SIZE, %edx           # (%edx - $FIELD_SIZE)
    jl      1f                          # skip next instruction if < 0
    movl    $0, %edx                    # then %eax = 0
1:
    movl    %edx, worm_tail             # worm_tail = %edx
2:

    ## Probe for collision with the worm itself
   
    ## Grow the worm
    pushl   $WORM_TILE                  # Push $WORM_TILE for nib_put_scr
    # Calculate the new worm_head: worm_head = (worm_head + 1) % FIELD_SIZE
    movl    worm_head, %edx             # %eax = worm_head
    incl    %edx                        # %eax++
    cmpl    $FIELD_SIZE, %edx           # (%edx - $FIELD_SIZE)
    jl      1f                          # skip next instruction if < 0
    movl    $0, %edx                    # then %eax = 0
1:
    movl    %edx, worm_head             # worm_head = %edx
    # Relocate the worm: worm[worm_head].y = worm_head_y
    movl    $worm, %eax                 # %eax = $worm_head
    movl    worm_head_y, %ebx           # %ebx = worm_head_y
    movl    %ebx, 4(%eax, %edx, 8)
    pushl   %ebx                        # push the y coordinate for nib_put_scr
    # Relocate the worm: worm[worm_head].x = worm_head_x
    movl    worm_head_x, %ebx
    movl    %ebx, (%eax, %edx, 8)
    pushl   %ebx                        # push the x coordinate for nib_put_scr
    # Draw the new worm head
    call    nib_put_scr                 # nib_put_scr(worm_head_x, worm_head_y, $WORM_TILE)
    addl    $12, %esp
 
    # Restart the game loop
    jmp     game_loop

game_over:
    call    nib_end
