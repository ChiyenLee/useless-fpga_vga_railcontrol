// vga_digit_display.sv
//   David E Olumese | Nov. 26th 2018
// 
/////////////////////////////////////////////  
// vga_digit_display  
//   Top-level module of VGA digit display. Control the SRT VGA digit,
//   displaying the detected number to the screen along with a pseudo-randomly
//   selected text message. If the instruction request button is press, the
//   instruction text is displayed.
///////////////////////////////////////////// 
module vga_digit_display(input  logic       clk, reset,
			 input  logic [3:0] digit,
			 input  logic       digitEn, instrEn,
			 output logic       hSync, vSync, R, G, B);

  logic [9:0] x, y;
  logic       valid;
  
  // Create 25.175 MHz pixel clock for the VGA
  vga_pll vga_pll(.inclk0(clk), .c0(pixClk));
	
  // driver module
  vga_driver driver(pixClk, reset, hSync, vSync, x, y, valid);

  // generate video
  video_gen video(clk, reset, digit, digitEn, instrEn, x, y, R, G, B);
endmodule 


/////////////////////////////////////////////  
// vga_driver
//  VGA display interface. Produces the synchroziation signals and the current
//  pixel location (x, y). Uses a 25.175 MHz pixel clock generating a 60 Hz
//  screen refresh rate.
//  Notes:
//    Horizontal => Pixels
//    Vertical => Lines
//  VGA Timing data: http://martin.hinner.info/vga/timing.html
///////////////////////////////////////////// 
module vga_driver#(parameter H_AV  = 10'd640, // AV  => Active Video
                             H_FP  = 10'd16,  // FP  => Front Porch
                             H_SP  = 10'd96,  // SP  => Sync Pulse
                             H_BP  = 10'd48,  // BP  => Back Porch
                             H_END = H_AV + H_FP + H_SP + H_BP, // END => Total pixels
                             V_AV  = 10'd480,
                             V_FP  = 10'd11,
                             V_SP  = 10'd2,
                             V_BP  = 10'd32,
                             V_END = V_AV + V_FP + V_SP + V_BP)
                 (input  logic       pixClk, reset,
                  output logic       hSync, vSync,
                  output logic [9:0] x, y,
                  output logic       valid);
						
  // Set hSync & vSync low during their sync pulses
  assign hSync = ~((x >= (H_AV + H_FP)) & (x < (H_AV + H_FP + H_SP)));
  assign vSync = ~((y >= (V_AV + V_FP)) & (y < (V_AV + V_FP + V_SP)));

  // Video is only valid within the x & y active video ranges
  assign valid = (x < H_AV) & (y < V_AV);

  // Generate x and y
  always @(posedge pixClk, posedge reset) begin
    if (reset) begin
      x <= 0;
      y <= 0;
    end else begin
      x <= x + 10'd1;           // increment pixel count
      if (x >= H_END) begin
        x <= 0;                 // reset pixel count
        y <= y + 10'd1;         // increment line count 

        if (y >= V_END) y <= 0; // reset line count
      end
    end
  end
endmodule

/////////////////////////////////////////////  
// video_gen
//   Generates the video signals. Digit displayed in  white and the text in 
//   cyan.
///////////////////////////////////////////// 
module video_gen(input  logic       clk, reset,
		 input  logic [3:0] digit,
		 input  logic       digitEn, instrEn,
		 input  logic [9:0] x, y,
		 output logic       R, G, B);

  logic       digPix, txtPix;
  logic [3:0] txtSelect;      // chooses which of the 10 strings to display

  text_select_lfsr_rng tslr(clk, reset, digit, txtSelect);

  dig_gen_rom dgr(digit, digitEn, instrEn, x, y, digPix);
  txt_gen_rom tgr(txtSelect, instrEn, x, y, txtPix);

  // Produce RGB signals
  assign {R, G, B} = {digPix, (digPix | txtPix), (digPix | txtPix)};

endmodule

/////////////////////////////////////////////  
// text_select_lfsr_rng  
//   A 5-bit LFSR puesdo-number generator. Holds the selection until the digit
//   changes. The maximal LFSR polynomial from:
//     https://www.eetimes.com/document.asp?doc_id=1274550&page_number=2 => for maximal LFSR polynomial
///////////////////////////////////////////// 
module text_select_lfsr_rng#(parameter OPTIONS = 4'd10) // Number strings to be selected from
			   (input  logic       clk, reset,
			    input  logic [3:0] digit,
			    output logic [3:0] txtSelect);

  logic [4:0] q;
  logic [3:0] digitPrev;
  logic [2:0] p;
  logic       en, sclk;

  // generate a slower clk (10MHz)
  always_ff @(posedge clk, posedge reset)
    if (reset) p <= 3'd0;
    else       p <= p + 3'd1;
  assign sclk = p[2];

  // remember the previous digit
  always_ff @(negedge sclk)
    digitPrev <= digit;

  assign en = digitPrev != digit; // select new text if digit changes

  always_ff @(posedge clk, posedge reset) begin
    if (reset)   q <= 4'd3;                  // initial seed (non-zero)
    else if (en) q <= {q[3:0], q[4] ^ q[1]}; // polynomial for maximal LFSR
    else         q <= q;
  end

  assign txtSelect = ((q[3:0] > 4'd0 & q[3:0] < OPTIONS) ?
                       q[3:0] : {1'b0, q[3:1]});

endmodule

/////////////////////////////////////////////  
// dig_gen_rom
//   Generates the 320x320 digit pixels using a 10 digit 6x8 ROM from a text
//   file. The digit is horizontally centered on screen and in the top 3/4th
//   section of the screen. 
///////////////////////////////////////////// 
module dig_gen_rom#(parameter SIZE    = 10'd320,
                              X_START = 10'd160,
                              X_END   = X_START + SIZE - 10'd2, // offset due to division resolution
                              X_DIV   = 10'd53,  // SIZE / 6 (cols of digit)
                              Y_START = 10'd20,
                              Y_END   = Y_START + SIZE,
                              Y_DIV   = 10'd40)  // SIZE / 8 (rows of digit)
                  (input  logic [3:0] digit,
                   input  logic       digitEn, instrEn,
                   input  logic [9:0] x, y,
                   output logic       pixel);

  logic [5:0] digrom[79:0]; // digit generator ROM (8 lines/digit * 10 digit)
  logic [5:0] line;         // a line of the digit
  logic [2:0] xoff, yoff;   // current position in the digit
  logic       valid;

  // initialize the digit ROM from file
  initial    $readmemb("roms/digrom.txt", digrom);

  assign valid = (x >= X_START & x < X_END) &
                 (y >= Y_START & y < Y_END);

  // scale the digit to 320x320 using divider
  assign xoff = (valid) ? ((x - X_START) / X_DIV) : 3'd0;
  assign yoff = (valid) ? ((y - Y_START) / Y_DIV) : 3'd0;

  // extract the current line from the desired digit
  //  6x8 digit; digit * 8 + curr_y gives the line from ROM
  assign line = (digitEn & ~instrEn) ? {digrom[yoff+{digit, 3'b000}]} : 6'd0;

  // reverse the bit order and extract current pixel
  assign pixel = (valid) ? line[3'd5 - xoff] : 1'd0;

endmodule

/////////////////////////////////////////////  
// txt_gen_rom
//   Generates the 12x16 character pixels using a 29 character 6x8 ROM from
//   a text file. The sequence of characters are horizontally centered on
//   screen and in the bottom 1/4th section of the screen. 
///////////////////////////////////////////// 
module txt_gen_rom#(parameter SCALE    = 10'd2,
                              WIDTH    = 10'd12,
                              HEIGHT   = 10'd16,
                              X_END    = 10'd636, // WIDTH * TXT_SIZE
                              Y_START  = 10'd412, // DIGIT_Y_END + 52
                              Y_END    = Y_START + HEIGHT,
                              TXT_SIZE = 6'd53)
                  (input  logic [3:0] txtSelect,
                   input  logic       instrEn,
                   input  logic [9:0] x, y,
                   output logic       pixel);

  logic [5:0] charrom[231:0]; // character generator ROM (8 lines/char * 29 char)
  logic [5:0] line;           // a line of the character
  logic [7:0] txtrom[541:0];  // formatted text ROM (number of lines in file)
  logic [7:0] char;           // character to display
  logic [5:0] charPos;        // position of character screen
  logic [9:0] txtPos;         // position of text in ROM
  logic [2:0] xoff, yoff;
  logic       valid;

  // initialize character and text ROMs from file
  initial    $readmemb("roms/charrom.txt", charrom);
  initial    $readmemh("roms/textrom.txt", txtrom);

  assign valid = x < X_END & (y >= Y_START & y < Y_END);

  // scale the char by factor of 2
  assign xoff = (valid) ? ((x % WIDTH)   / SCALE) : 3'd0;
  assign yoff = (valid) ? ((y - Y_START) / SCALE) : 3'd0;

  // determine the character to be displayed
  assign charPos = x / WIDTH;
  assign txtPos  = (instrEn) ? 10'd0        // 0 for instructions
                             : txtSelect * TXT_SIZE;
  assign char    = {txtrom[txtPos+charPos]};

  // extract the current line from the desired character
  //  6x8 character; char * 8 + curr_y gives the line from ROM
  assign line = {charrom[yoff+{char, 3'b000}]};

  // reverse the bit order and extract current pixel
  assign pixel = (valid) ? line[3'd5 - xoff] :  1'd0;

endmodule


/////////////////////////////////////////////  
// gen_red_square
//   [Simple test module] Draws a red square on the screen
///////////////////////////////////////////// 
module gen_red_square(input  logic [9:0] x, y,
                      output logic       R, G, B);

  assign R = ((x > 10'd200) && (y > 10'd120) && (x < 10'd360) && (y < 10'd280));
  assign G = 0;
  assign B = 0;

endmodule

