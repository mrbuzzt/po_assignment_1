# Makefile for the nibbles lab.
# ---> Compile with gamke on BSD systems! <---

all: nibbles_asm nibbles_asm_start

# Rule for compiling C source
.c.o:
	gcc -Os -march=i686 -Wall -g -c $<

# Rule for compiling assembly source
.S.o:
	as -gstabs $^ -o $@


# ASM game
nibbles_asm: main.o nibbles.o helpers.o
	gcc -o $@ $^ -lcurses 

# ASM game
nibbles_asm_start: start.o nibbles.o helpers.o workaround.o
	gcc -nostdlib -o $@ $^ -lcurses -lc

clean:
	rm -f *~
	rm -f *.o
	rm -f nibbles_asm_start nibbles_asm
