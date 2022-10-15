module square(input [31:0] f_dHz, input clk, output reg soundbit = 0);
reg [31:0] n = 0;
always @(posedge clk)
begin
    n = n + 1;
    if (n >= 500_000_000 / f_dHz)
    begin
        n = 1;
        soundbit = ~soundbit;
    end
end
endmodule

module harmonic_pwm(input [31:0] f_dHz, input clk, output soundbit);
wire [63:0] N_0;
assign N_0 = 100_000_000_0 / f_dHz;
parameter N = 100;
wire [63:0] N_V;
// N_0: the total clk posedge times of a function period
// N: the clk posedge times between two adjacent sample points
// N_V: the up times in every sample period
// (N_V = N * f(t_sample), f(t) is the relative voltage at time t)
reg [63:0] n = N;
reg [63:0] n_0 = 0;
parameter pi_10000 = 31416;
// counters:
// n: the counter of clk (1 ~ N)
// n_0: the counter of sample periods (1 ~ N_0 / N)
assign soundbit = (n < N_V) ? 1 : 0;
// N_V = N * f(n_0 => 1 ~ N_0 / N)
reg [63:0] n_0_0 = 0;
reg [63:0] N_V_0 = 0;
reg [63:0] tmp = 0;
assign N_V = (100000 * N_0 / n_0 / N >= 200000) ? (N / 2 + N_V_0 / 2) : (N / 2 - N_V_0 / 2);
// n_0_0: the same or negative value in 1 ~ N_0 / 4 / N;
// N_V_0 = N * sin(n_0_0 => 1 ~ N_0 / N / 4)
// tmp is the intermediate variable used.
always @(posedge clk)
begin
    if (n >= N)
    begin
        n = 1;
        if (n_0 >= N_0 / N)
            n_0 = 1;
        else
            n_0 = n_0 + 1;

        if (100000 * N_0 / n_0 / N >= 400000)
            n_0_0 = n_0;
        else if (200000 * N_0 / n_0 / N >= 400000)
            n_0_0 = N_0 / N / 2 - n_0;
        else if (300000 * N_0 / n_0 / N >= 400000)
            n_0_0 = n_0 - N_0 / N / 2;
        else n_0_0 = N_0 / N - n_0;
        // N_V_0 = + 2 * pi ^ 1 / 1   * N / (N_0 / N / n_0_0) ^ 1
        //         - 4 * pi ^ 3 / 3   * N / (N_0 / N / n_0_0) ^ 3
        //         + 4 * pi ^ 5 / 15  * N / (N_0 / N / n_0_0) ^ 5
        //         - 8 * pi ^ 7 / 315 * N / (N_0 / N / n_0_0) ^ 7
        // x = N * n_0_0 / N_0, 0 ~ 1
        tmp = 2 * pi_10000 * N * N * n_0_0 / N_0 / 10000;
        N_V_0 = tmp;
        tmp = tmp * 2 * pi_10000 * pi_10000 / 3  / (10000 * N_0 / N / n_0_0) / (10000 * N_0 / N / n_0_0);
        N_V_0 = N_V_0 - tmp;
        tmp = tmp * 1 * pi_10000 * pi_10000 / 5  / (10000 * N_0 / N / n_0_0) / (10000 * N_0 / N / n_0_0);
        N_V_0 = N_V_0 + tmp;
        tmp = tmp * 2 * pi_10000 * pi_10000 / 21 / (10000 * N_0 / N / n_0_0) / (10000 * N_0 / N / n_0_0);
        N_V_0 = N_V_0 - tmp;
    end
    else
        n = n + 1;
end
endmodule