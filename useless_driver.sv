// John Lee [johlee@g.hmc.edu] | Jingnan Shi [jshi@g.hmc.edu] | David E Olumese [dolumese@g.hmc.edu]
// November 17th 2018

/////////////////////////////////////////////
// useless_driver
//  Top-level module for the USELESS machine
/////////////////////////////////////////////
module useless_driver(input  logic       clk, reset,
                      input  logic [3:0] digit,
                      input  logic       load, instrEn,
                      output logic       hSync, vSync, R, G, B,
                      output logic       A1, A2, B1, B2,
                      output logic       PWM1, PWM2);

  logic [3:0] curr_digit;

  gpio_interface    gi(clk, load, digit, curr_digit);
  step_motor_drive  smd(clk, reset, load, curr_digit, A1, A2, B1, B2, PWM1, PWM2);
  vga_digit_display vdd(clk, reset, curr_digit, load, instrEn, hSync, vSync, R, G, B);

endmodule 

///////////////////////////////////////////// 
// gpio_interface  
//  GPIO interface.  Reads in the digit & hold it.  
/////////////////////////////////////////////
module gpio_interface(input  logic       clk, load,
                      input  logic [3:0] digit,
                      output logic [3:0] current_digit)	

  // store digit 
  always_ff @(posedge clk)
    if (load) current_digit <= digit;
    else      current_digit <= current_digit; 

endmodule

