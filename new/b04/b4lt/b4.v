module b04(RESTART,AVERAGE,ENABLE,DATA_IN,DATA_OUT,RESET,CLOCK, testmode);  // *** TPI
// *** Added testmode input
input testmode;

input CLOCK;
input RESET;
input RESTART;
input AVERAGE;
input ENABLE;
input signed [7:0] DATA_IN;

output [7:0] DATA_OUT;

reg signed [7:0] DATA_OUT;

parameter sA = 0;
parameter sB = 1;
parameter sC = 2;

// ORIGINAL registers
reg [1:0] stato_original;              // *** TPI
reg signed [31:0] RMAX_original;       // *** TPI
reg signed [31:0] RMIN_original;       // *** TPI
reg signed [31:0] REGD_original;       // *** TPI

// Shadow scan FF registers (control points)
reg [1:0] stato_scanFF;                // *** TPI
reg signed [31:0] RMAX_scanFF;         // *** TPI
reg signed [31:0] RMIN_scanFF;         // *** TPI
reg signed [31:0] REGD_scanFF;         // *** TPI

// Mux override versions
wire [1:0] stato = testmode ? stato_scanFF : stato_original;
wire signed [31:0] RMAX = testmode ? RMAX_scanFF : RMAX_original;
wire signed [31:0] RMIN = testmode ? RMIN_scanFF : RMIN_original;
wire signed [31:0] REGD = testmode ? REGD_scanFF : REGD_original;

// All untouched registers
reg signed [31:0] RLAST, REG1, REG2, REG3, REG4, test;
reg signed [31:0] temp;
reg RES, AVE, ENA;

always @(posedge CLOCK, posedge RESET) begin 
    
    if (RESET == 1'b1) begin

        // ----------------------
        // RESET ORIGINALS
        // ----------------------
        stato_original <= sA;
        RMAX_original <= 0;
        RMIN_original <= 0;
        REGD_original <= 127;

        // ----------------------
        // RESET SCAN FF MIRRORS
        // ----------------------
        stato_scanFF <= sA;         // *** TPI
        RMAX_scanFF <= 0;          // *** TPI
        RMIN_scanFF <= 0;          // *** TPI
        REGD_scanFF <= 127;        // *** TPI

        // Remaining original design registers
        RLAST <= 0;
        REG1 <= 0;
        REG2 <= 0;
        REG3 <= 0;
        REG4 <= 0;
        temp <= 0;
        DATA_OUT <= 0;
        RES <= 0;
        ENA <= 0;
        AVE <= 0;

    end else begin

        RES = RESTART;
        ENA = ENABLE;
        AVE = AVERAGE;

        case (stato)

            sA : begin
                stato_original <= sB;      // uses muxed stato for next state decision
            end

            sB : begin
                RMAX_original <= DATA_IN;
                RMIN_original <= DATA_IN;
                REG1 <= 0;
                REG2 <= 0;
                REG3 <= 0;
                REG4 <= 0;
                RLAST <= 0;
                DATA_OUT <= 0;
                stato_original <= sC;
            end

            sC : begin
                if (ENA == 1'b1)
                    RLAST <= DATA_IN;

                if (RES == 1'b1) begin

                    test = (RMAX + RMIN);
                    REGD_original <= test[6:0];

                    temp = RMAX + RMIN;
                    if (temp >= 0)
                        DATA_OUT <= REGD / 2;
                    else
                        DATA_OUT <= -((-REGD) / 2);

                end else if (ENA == 1'b1) begin

                    if (AVE == 1'b1) begin
                        DATA_OUT <= REG4;
                    end else begin
                        test = DATA_IN + REG4;
                        REGD_original <= test[6:0];

                        temp = DATA_IN + REG4;
                        if (temp >= 0)
                            DATA_OUT <= REGD / 2;
                        else
                            DATA_OUT <= -((-REGD) / 2);
                    end

                end else begin
                    DATA_OUT <= RLAST;
                end

                // Update MAX/MIN using muxed versions
                if (DATA_IN > RMAX)
                    RMAX_original <= DATA_IN;

                else if (DATA_IN < RMIN)
                    RMIN_original <= DATA_IN;

                REG4 <= REG3;
                REG3 <= REG2;
                REG2 <= REG1;
                REG1 <= DATA_IN;

                stato_original <= sC;
            end
        endcase

    end
end

endmodule

