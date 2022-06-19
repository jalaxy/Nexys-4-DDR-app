`define logS 1 // logarithm of stage number
// logN = logM + logNpM
`define logN 3 // logarithm of sample number
`define logM 1 // logarithm of parallel groups number
`define logNpM 2 // logarithm of sample number in a group
`define logCyc 3 // logarithm of cycles within one time of calculation
// N = M * NpM
`define N 8 // sample number
`define M 2 // parallel groups number
`define NpM 4 // sample number in a group
`define Cyc 4 // cycles within one time of calculation
`define CW 128 // complex number width
`define FW 64 // floating point number width
`define r(x) x[`FW-1:0]
`define i(x) x[`CW-1:`FW]