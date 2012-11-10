# Globals
.globl start_game

.set    FIELD_X, 50
.set    FIELD_Y, 80
.set    WORM_BUFFER_SIZE, FIELD_X * FIELD_Y * 2

.section .data
my_string:
    .asciz  "Apples %x, worm: %x\n"

.section .bss
worm_head:
    .long   0
worm_tail:
    .long   0
worm_dx:
    .byte   0
worm_dy:
    .byte   0
worm:
    .space  WORM_BUFFER_SIZE
apples:
    .space  WORM_BUFFER_SIZE


.section .text

start_game:
    pushl   %ebp        # save the base pointer in order to be able to return
    movl    %esp, %ebp  # capture the new base pointer

    call    nib_init

    # Initialize the worm
    movl    $0, worm_head   # worm_head = 0
    movl    $0, worm_tail   # worm_tail = 0
    movl    8(%ebp), %ecx  # %ecx = len
loop1:
    # Find initial y position.
    movl    %ecx, %eax      # %eax = %ecx
    addl    $FIELD_Y / 2, %eax
                            # %eax = %eax + FIELD_SIZE_Y / 2
    movl    $worm_head, %edx # %edx = $worm_head
    movb    %al, 1(%edx)
    movb    $FIELD_X / 2, (%edx)

    loop    loop1

    #call    rand            # %eax = rand()
    #div     $FIELD_X        # %edx = %eax MOD FIELD_X
    #movb    %edx, (%ecx)    # (%ecx) = %edx
    
    
    # call printf("Apples %d, length %d", apples, worm);
    pushl   8(%ebp)
    pushl   12(%ebp)
    pushl   $my_string
    call    printf
    addl    $12, %esp

    call    nib_end

    leave
    ret
