# Globals
.globl start_game

.set    FIELD_X, 80
.set    FIELD_Y, 50
.set    BUFFER_SIZE, FIELD_X * FIELD_Y * 2 * 4 # i.e. 2 words for each tile
.set    WORM_TILE, 'O'
.set    APPLE_TILE, '@'

.section .data
debug:
    .asciz "--> %d\n"

.section .bss
worm_head:
    .long   0
worm_tail:
    .long   0
worm_dx:
    .byte   0
worm_dy:
    .byte   0
    .lcomm  worm, BUFFER_SIZE
    .lcomm  apples, BUFFER_SIZE


.section .text

# Implementation of start_game(int len, int num_apples)
start_game:
    pushl   %ebp        # save the base pointer in order to be able to return
    movl    %esp, %ebp  # capture the new base pointer
    call    nib_init    # nib_init()

    # Initialize the worm.
    movl    $0, worm_head   # worm_head = 0
    movl    $0, worm_tail   # worm_tail = 0
    # Add len initial worm parts.
    movl    8(%ebp), %ecx   # %ecx = len
loop1:       # Iterate to add all parts
    pushl   %ecx
    pushl   $WORM_TILE               # push WORM_TILE on stack for later nib_put_scr call
    movl    $worm, %edi             # %edi = $worm
    # Compute and add the y component.
    movl    %ecx, %eax              # %eax = %ecx
    addl    $FIELD_Y / 2, %eax      # %eax = %eax + FIELD_Y / 2
    pushl   %eax                    # push %eax on the stack for later nib_put_scr call
    movl    worm_head, %edx         # %edx = worm_head
    movl    $worm, %edi             # %edi = $worm
    movl    %eax, 4(%edi, %edx, 8)  # worm[worm_head + 4] = %eax
    # Add the x component
    movl    $FIELD_X / 2, %eax      # %eax = $FIELD_X / 2
    pushl   %eax                    # push %eax again on the stack for nib_put_scr
    movl    %eax, (%edi, %edx, 8)   # worm[worm_head] = % eax
    # Move the worm_head forward
    addl    $8, %edx
    movl    %edx, worm_head
    # Call nib_put_scr(x, y, WORM_TILE)    
    call    nib_put_scr
    addl    $12, %esp               # Restore the stack
    popl    %ecx
    loop    loop1                   # Continue loop

    # Initialize the apples.
    movl    12(%ebp), %ecx  # %ecx = num_apples
loop_init_apples:   # Set up the initial apples.
    pushl   %ecx
    pushl    $APPLE_TILE             # already push the $WORM_TILE for the coming nib_put_scr call
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
    movl    12(%esp), %ecx           # %ecx = top of stack
    movl    %edx, -8(%ebx, %ecx, 8) # apples[8 * %ecx - 8] = %edx
    # Call nib_put_scr
    call    nib_put_scr             # call nib_put_
    addl    $12, %esp
    # Continue the loop.
    popl    %ecx
    loop    loop_init_apples
    
    pushl   $5000000
    call    usleep
    call    nib_end

    leave
    ret
