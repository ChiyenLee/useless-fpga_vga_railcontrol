/* Stepper motor driver 
johlee@g.hmc.edu Nov. 17, 2018 */

module step_motor_drive(input logic clk, reset, en, load,
						input logic [3:0] digit,
								//input logic [7:0] num_steps,
								output logic A1, A2, B1, B2);
	
	// if dir = 1, move forward 
	// if dir = 0, move backward
	// if en = 1, move motor. otherwise hold
	
	logic increment, stop; // flag to tell to count the step or not
	logic [3:0] current_digit;
	logic [18:0] q;
	logic signed [13:0] steps; 
	logic signed [13:0] delta_steps;
	
	// temporary
	logic signed [13:0] num_steps;
	logic slow_clk;
	
	assign slow_clk = q[18];
	assign delta_steps = steps - num_steps; // steps to increment
	assign dir = delta_steps[13];

	// store digit 
	always_ff @(posedge clk)
		if (load) current_digit <= digit;
		else current_digit <= current_digit; 

	// modulate a slower clock
	always_ff @(posedge clk, posedge reset)
		if (reset) q <= 0;
		else q <= q + 19'd1; 
	
	// define state that controls the steps 
	typedef enum logic [4:0] {S0, S1, S2, S3, S4} statetype;
	statetype state, nextstate; 
	
	// state transition
	always_ff @(posedge slow_clk, posedge reset)
		if (reset) begin state <= S0; steps <= 0; end
		else begin
			state <= nextstate;
			if (increment) steps <= steps + {dir, 13'sd1};
		end
	
	assign stop = (steps >= num_steps) ? 1'b1 : 1'b0;
	
	// nextstate logic
	always_comb 
		case(state)
			S0: if (en & dir & ~stop) nextstate = S1;
				 else if (en & ~dir & ~stop) nextstate = S4; 
				 else if (stop) nextstate = S0;
				 else nextstate = S0;
			S1: if (en & dir & ~stop) nextstate = S2;
				 else if (en & ~dir & ~stop) nextstate = S4; 
				 else if (stop) nextstate = S0;
				 else nextstate = S0;
			S2: if (en & dir & ~stop) nextstate = S3;
				 else if (en & ~dir & ~stop) nextstate = S1; 
				 else if (stop) nextstate = S0;
				 else nextstate = S0;
			S3: if (en & dir & ~stop) nextstate = S4;
				 else if (en & ~dir & ~stop) nextstate = S2; 
				 else if (stop) nextstate = S0;
				 else nextstate = S0;
			S4: if (en & dir & ~stop) nextstate = S1;
				 else if (en & ~dir & ~stop) nextstate = S3; 
				 else if (stop) nextstate = S0;
				 else nextstate = S0;
			default: nextstate = S0; // always go back to S0 if enable is off
		endcase
	
	// output logic 
	always_comb
		case(state)
			S0: begin {A1, B1, A2, B2} = 4'b0000; increment = 0; end
			S1: begin {A1, B1, A2, B2} = 4'b1100; if (~dir) increment = 1; else increment = 0; end
			S2: begin {A1, B1, A2, B2} = 4'b0110; increment = 0; end
			S3: begin {A1, B1, A2, B2} = 4'b0011; increment = 0; end
			S4: begin {A1, B1, A2, B2} = 4'b1001; if (dir) increment = 1; else increment = 0; end
		endcase

	// run different number of steps according to the digit
	always_comb 
		case(current_digit)
			4'd0: num_steps = 14'sd0;
			4'd1: num_steps = 14'sd0;
			4'd2: num_steps = 14'sd50;
			4'd3: num_steps = 14'sd50;
			4'd4: num_steps = 14'sd100;
			4'd5: num_steps = 14'sd100;
			4'd6: num_steps = 14'sd150;
			4'd7: num_steps = 14'sd150;
			4'd8: num_steps = 14'sd200;
			4'd9: num_steps = 14'sd200;
		endcase

endmodule 

module testbench();
	logic clk, reset, step_size, dir, en;
	logic [3:0] stepper_out;
	logic [8:0] count;
	logic [7:0] num_steps;
	
	step_motor_drive dut(clk, reset, dir, en, stepper_out[3], stepper_out[2], stepper_out[1], stepper_out[0]);
	
	initial 
		forever begin
			clk = 1'b0; #5;
			clk = 1'b1; #5; 
		end
		
	initial begin 
		reset = 1'b1;
		dir = 0;
		en = 1;
		count = 0;
		num_steps = 20;
	end
	
	always @(posedge clk) 
	begin
		if (count > 5) reset = 1'b0;
		count = count + 1;
	end

endmodule
