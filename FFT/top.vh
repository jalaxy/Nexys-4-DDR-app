// logN = logM + logNpM
`define logN 4 // logarithm of sample number
`define logM 2 // logarithm of parallel groups number
`define logNpM 2 // logarithm of sample number in a group
// N = M * NpM
`define N 16 // sample number
`define M 4 // parallel groups number (M between 2 to N/4)
`define NpM 4 // sample number in a group

`define logS 1 // logarithm of stage number
`define logCyc 3 // logarithm of cycles within one time of calculation
`define Cyc 4 // cycles within one time of calculation
`define CW 128 // complex number width
`define FW 64 // floating point number width
`define r(x) x[`FW-1:0]
`define i(x) x[`CW-1:`FW]