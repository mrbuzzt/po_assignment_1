#!/bin/sh

while [ $# -ne 0 ]; do
    echo -n "$1: "
    readelf -S $1 | egrep " .text| .data" | sed 's/ 0/ 0x/g' | mawk 'BEGIN{sum = 0}{sum = sum + $7}END{print sum}'
    shift
done
