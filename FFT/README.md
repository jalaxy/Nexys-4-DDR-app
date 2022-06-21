# parallel FFT

This directory contains an example of a parallel FFT, with configurable parallel unit count $M$ and sample point count $N$.

The code requires a previous implementation of floating point calculation (addition, subtraction, multiplication), trigonometric functions and memory, including RAM. It has been tested on Nexys 4 DDR with IP cores of floating points and on-chip block memory.