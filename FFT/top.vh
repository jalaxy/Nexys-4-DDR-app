`define logS 1 // logarithm of stage number
// logN = logM + logNpM
`define logN 10 // logarithm of sample number
`define logM 2 // logarithm of parallel groups number
`define logNpM 8 // logarithm of sample number in a group
`define logCyc 3 // logarithm of cycles within one time of calculation
// N = M * NpM
`define N 1024 // sample number
`define M 4 // parallel groups number
`define NpM 256 // sample number in a group
`define Cyc 4 // cycles within one time of calculation
`define CW 128 // complex number width
`define FW 64 // floating point number width
`define r(x) x[63:0]
`define i(x) x[127:64]