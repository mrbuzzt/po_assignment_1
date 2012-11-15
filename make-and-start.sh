#!/bin/bash

make
if [ $? == 0 ]; then
    ./nibbles_asm $@
fi
