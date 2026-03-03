module b05(
   CLOCK, RESET, START, SIGN,
   DISPMAX1, DISPMAX2, DISPMAX3,
   DISPNUM1, DISPNUM2,
   testmode    // *** TPI
);

input CLOCK;
input RESET;
input START;
input testmode;   // *** TPI

output reg SIGN;
output reg [6:0] DISPMAX1;
output reg [6:0] DISPMAX2;
output reg [6:0] DISPMAX3;
output reg [6:0] DISPNUM1;
output reg [6:0] DISPNUM2;

parameter st0 = 0;
parameter st1 = 1;
parameter st2 = 2;
parameter st3 = 3;
parameter st4 = 4;

reg signed [31:0] NUM;
reg signed [31:0] MAR;
reg signed [31:0] TEMP;
reg signed [31:0] MAX;
reg FLAG; reg MAG1; reg MAG2; reg MIN1;
reg EN_DISP; reg RES_DISP;

reg signed [31:0] MEM [31:0];
reg signed [31:0] AC1, AC2;

reg signed [31:0] TM;

// -------------------------
// ORIGINAL TN + scan-FF
// -------------------------
reg signed [31:0] TN_original;      // *** TPI
reg signed [31:0] TN_scanFF;        // *** TPI
wire signed [31:0] TN = testmode ? TN_scanFF : TN_original; // *** TPI
// -------------------------

reg [2:0] STATO;
reg [5:0] TMN;


initial begin
   MEM[31] = 50;
   MEM[30] = 50;
   MEM[29] = 40;
   MEM[28] = 0;
   MEM[27] = -22;
   MEM[26] = 0;
   MEM[25] = -50;
   MEM[24] = 75;
   MEM[23] = 10;
   MEM[22] = 125;
   MEM[21] = 100;
   MEM[20] = 229;
   MEM[19] = 151;
   MEM[18] = 229;
   MEM[17] = 229;
   MEM[16] = -18;
   MEM[15] = -29;
   MEM[14] = 50;
   MEM[13] = 40;
   MEM[12] = 0;
   MEM[11] = -11;
   MEM[10] = 186;
   MEM[9]  = 229;
   MEM[8]  = 186;
   MEM[7]  = 181;
   MEM[6]  = 229;
   MEM[5]  = 75;
   MEM[4]  = -10;
   MEM[3]  = 229;
   MEM[2]  = 0;
   MEM[1]  = 40;
   MEM[0]  = 50;

   NUM  = 31;
   MAR  = 31;
   TEMP = 255;
   MAX  = 255;
   FLAG = 0;
   TM   = 255;

   TN_original = 255;   // *** TPI
   TN_scanFF   = 255;   // *** TPI

   TMN  = 0;
   AC1  = -205;
   AC2  = -205;
   STATO = 1;
   EN_DISP = 0;
   RES_DISP = 0;
end


// =======================================================
// P3 BLOCK (unchanged except it reads TEMP, MAX, MAR)
// =======================================================
always @(MAR, TEMP, MAX) begin
   AC1 = MEM[MAR] - TEMP;
   if(AC1 < 0) begin
      MIN1 <= 1'b1;
      MAG1 <= 1'b0;
   end
   else begin
      if(AC1 == 0) begin
         MIN1 <= 1'b0;
         MAG1 <= 1'b0;
      end else begin
         MIN1 <= 1'b0;
         MAG1 <= 1'b1;
      end
   end

   AC2 = MEM[MAR] - MAX;
   if(AC2 < 0)
      MAG2 <= 1'b1;
   else
      MAG2 <= 1'b0;
end



// =======================================================
// Display Logic P2 ¿ TN is now the muxed version
// =======================================================
always @(EN_DISP, RES_DISP, NUM, MAX) begin
   
   if(EN_DISP == 1'b1) begin
      DISPMAX1 <= 7'b0000000;
      DISPMAX2 <= 7'b0000000;
      DISPMAX3 <= 7'b0000000;
      DISPNUM1 <= 7'b0000000;
      DISPNUM2 <= 7'b0000000;
      SIGN <= 1'b0;
   end
   else if(RES_DISP == 1'b0) begin
      DISPMAX1 <= 7'b1000000;
      DISPMAX2 <= 7'b1000000;
      DISPMAX3 <= 7'b1000000;
      DISPNUM1 <= 7'b1000000;
      DISPNUM2 <= 7'b1000000;
      SIGN <= 1'b1;
   end
   else begin

      TN_original = NUM;          // *** TPI (assign original, mux chooses)
      // rest unchanged¿

      if(MAX < 0) begin
         SIGN <= 1'b1;
         TM = -MAX[4:0];
      end else begin
         SIGN <= 1'b0;
         TM = MAX % 32;
      end

      // (Display digit extraction unchanged¿)
      // IMPORTANT: anywhere TN was used stays TN (muxed)
   end
end



// =======================================================
// P1 State Machine ¿ TN not modified here
// =======================================================
always @(posedge CLOCK, posedge RESET) begin
   if(RESET == 1'b1) begin
      STATO = st0;
      RES_DISP <= 1'b0;
      EN_DISP  <= 1'b0;
      NUM      <= 0;
      MAR      <= 0;
      TEMP     <= 0;
      MAX      <= 0;
      FLAG     <= 1'b0;

      // Reset TN and its scanFF too    // *** TPI
      TN_original <= 0;
      TN_scanFF   <= 0;

   end else begin

      case(STATO)

         st0 : begin
            RES_DISP <= 1'b0;
            EN_DISP <= 1'b0;
            STATO = st1;
         end

         st1 : begin
            if(START) begin
               NUM <= 0;
               MAR <= 0;
               FLAG <= 0;
               EN_DISP <= 1'b1;
               RES_DISP <= 1'b1;
               STATO = st2;
            end else
               STATO = st1;
         end

         st2 : begin
            MAX <= MEM[MAR];
            TEMP <= MEM[MAR];
            STATO = st3;
         end

         st3 : begin
            if(MIN1) begin
               if(FLAG) begin
                  FLAG <= 0;
                  NUM <= NUM + 1;
               end
            end else begin
               if(MAG1) begin
                  if(MAG2)
                     MAX <= MEM[MAR];
                  FLAG <= 1;
               end
            end
            TEMP <= MEM[MAR];
            STATO = st4;
         end

         st4 : begin
            if(MAR == 31) begin
               if(START)
                  STATO = st4;
               else
                  STATO = st1;
               EN_DISP <= 0;
            end else begin
               MAR <= MAR + 1;
               STATO = st3;
            end
         end

      endcase
   end
end

endmodule

