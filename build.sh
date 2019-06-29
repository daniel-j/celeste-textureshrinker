#!/usr/bin/env bash

echo "Compiling Crunch..."
g++ -O3 -o crunch.bin -I crunch/crunch crunch/crunch/*.cpp

echo "Compiling Celeste Textureshrinker..."
nimble build --opt:speed -d:release

echo "Finished!"
