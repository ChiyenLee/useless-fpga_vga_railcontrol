/* Stepper motor driver 
johlee@g.hmc.edu Nov. 17, 2018 */

module step_motor_drive(input logic clk, reset, dir, en,
								//input logic [7:0] num_steps,
								output logic A1, A2, B1, B2);
	
	// if dir = 1, move forward 
	// if dir = 0, move backward
	// if en = 1, move motor. otherwise hold
	
	logic increment, stop; // flag to tell to count the step or not
	logic [18:0] q;
	logic [13:0] steps; 
	
	// temporary
	logic [13:0] num_steps;
	logic slow_clk;
	
	assign slow_clk = q[18];
	
	assign num_steps = 14'd220;
	
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
			if (increment) steps <= steps + 14'd1;
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
