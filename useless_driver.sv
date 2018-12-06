
module useless_driver(input  logic       clk, reset,
                      input  logic [3:0] digit,
                      input  logic       load, instrEn,
                      output logic       hSync, vSync, R, G, B,
                      output logic       A1, A2, B1, B2,
                      output logic       PWM1, PWM2);

  step_motor_drive  smd(clk, reset, load, digit, A1, A2, B1, B2, PWM1, PWM2);
  vga_digit_display vdd(clk, reset, digit, load, instrEn, hSync, vSync, R, G, B);

endmodule 
