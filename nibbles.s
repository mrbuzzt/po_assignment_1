# Globals
.globl start_game

.set    FIELD_X,        80
.set    FIELD_Y,        50
.set    FIELD_SIZE,     FIELD_X * FIELD_Y 
.set    BUFFER_SIZE,    FIELD_SIZE * 2 * 4
.set    WORM_TILE,      'O'
.set    APPLE_TILE,     '@'
.set    SLEEP_TIME,     100000
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
    movl    $-1, worm_head   # worm_head = -8
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
    # The game loop
    # sleep at first
    pushl   $SLEEP_TIME
    call    usleep
    addl    $4, %esp

    # read the keyboard
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
/*
    # Calculate the x position: worm_head_x = (worm[worm_head] + worm_dx) % $FIELD_X
    movl    worm_head, %ecx
    movl    $worm, %edx
    movl    (%edx, %ecx, 8), %eax
    addl    worm_dx, %eax
    xorl    %edx, %edx
    movl    $FIELD_X, %ebx
    idivl    %ebx
    movl    %edx, worm_head_x
    # Calculate the y position = worm_head_y = (worm[worm_head + 4] + worm_dy) % $FIELD_Y
    movl    $worm, %edx
    movl    worm_head, %ecx
    movl    4(%edx, %ecx, 8), %eax
    addl    worm_dy, %eax
    xorl    %edx, %edx
    movl    $FIELD_Y, %ebx
    idivl    %ebx
    movl    %edx, worm_head_y
*/
    # Calculate the x position: worm_head_x = worm[worm_head] + worm_dx
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
    # Calculate the y position = worm_head_y = (worm[worm_head + 4] + worm_dy) % $FIELD_Y
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

    # To do:
    # - Probe the position for colision
    # - save the head and move forward
    # - grow or remove the tail part

    ## Grow the worm
    pushl   $WORM_TILE                  # Push $WORM_TILE for nib_put_scr
    # Calculate the new worm_head: worm_head = (worm_head + 1) % FIELD_SIZE
    movl    worm_head, %eax             # %eax = worm_head
    incl    %eax                        # %eax++
    xorl    %edx, %edx                  # %edx = 0
    movl    $FIELD_SIZE, %ecx           # %ecx = $FIELD_SIZE
    divb    %cl                         # %ah = %ax % %cl
    shll    $0x8, %eax                  # %eax >> 8 (bring the %ah value in place)
    movl    %edx, worm_head             # worm_head = %edx
    # Relocate the worm: worm[worm_head + 1] = worm_head_y
    movl    $worm, %eax                 # %eax = $worm_head
    movl    worm_head_y, %ebx           # %ebx = worm_head_y
    movl    %ebx, 4(%eax, %edx, 8)
    pushl   %ebx                        # push the y coordinate for nib_put_scr
    # Relocate the worm: worm[worm_head] = worm_head_x
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
