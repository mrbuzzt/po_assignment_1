# Export the _start label to define the program entry point.
.globl _start

# Define some values for the number of apples and the worm length.
.set    NUM_APPLES, 15
.set    WORM_LEN, 3

.section .text

# Define the _start label.
_start:
    # Call start_game(WORM_LEN, NUM_APPLES) following the C call convention.
    pushl   $NUM_APPLES # push the second argument onto the stack    
    pushl   $WORM_LEN   # push the first argument onto the stack
    call    start_game  # call the function
    
    # start_game is expected to never return, so let's return a special termination
    # code in case we take the branch.
    addl    $8, %esp    # reset the stack pointer
    pushl   $42         # argument for exit: this is an unusual way, to exit the program
    call    exit        # call the exit function
    
