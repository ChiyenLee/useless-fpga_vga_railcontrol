/* Stepper motor driver 
johlee@g.hmc.edu Nov. 17, 2018 */

module step_motor_drive(input logic clk, reset, load,
			input logic [3:0] digit,
			output logic A1, A2, B1, B2,
			output logic PWM1, PWM2); 
	
	// if dir = 1, move forward 
	// if dir = 0, move backward
	// if en = 1, move motor. otherwise hold
		
	logic        increment, stop, dir, stop_flag, flip_digit; // flag to tell to count the step or not
	logic [3:0]  current_digit;
	logic [18:0] q;
	logic        en; assign en = 1;
	logic signed [13:0] steps; 
	logic signed [13:0] delta_steps;
	logic signed [13:0] step_increment;
	
	servo_control s1(clk, reset, flip_digit, digit, PWM1, PWM2);
	
	// temporary
	logic signed [13:0] num_steps;
	logic slow_clk;
	
	assign slow_clk = q[18];
	assign delta_steps = steps - num_steps; // steps to increment
	assign dir = delta_steps[13];
	assign step_increment = (dir) ? 14'sd1 : -14'sd1; 
	
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
			if (increment & ~stop) steps <= steps + step_increment;
		end
	
	assign stop = (steps == num_steps) ? 1'b1 : 1'b0;
	assign flip_digit = (stop & load);
	
	// nextstate logic
	always_comb 
		case(state)
			S0: if (en & dir & ~stop) nextstate = S1;
				 else if (en & ~dir & ~stop) nextstate = S4; 
				 else if (stop) nextstate = S0;
				 else nextstate = S0;
			S1: if (en & dir & ~stop) nextstate = S2;
				 else if (en & ~dir & ~stop) nextstate = S4; 
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
			S4: begin {A1, B1, A2, B2} = 4'b1001; if (dir) increment = 1; else increment = 0;end
		endcase

	// run different number of steps according to the digit
	always_comb 
		case(current_digit)
			4'd0:    num_steps = 14'sd0;
			4'd1:    num_steps = 14'sd0;
			4'd2:    num_steps = 14'sd50;
			4'd3:    num_steps = 14'sd50;
			4'd4:    num_steps = 14'sd100;
			4'd5:    num_steps = 14'sd100;
			4'd6:    num_steps = 14'sd150;
			4'd7:    num_steps = 14'sd150;
			4'd8:    num_steps = 14'sd200;
			4'd9:    num_steps = 14'sd200;
			default: num_steps = 14'sd0;
		endcase
		
endmodule 

module servo_control(input  logic       clk, reset,
                     input  logic       start_push,
                     input  logic [3:0] digit,
                     output logic       servo_pwm1, servo_pwm2);
		
		logic [19:0] duty_cycle1, duty_cycle2, count, rest_dutycycle, engaged_dutycycle1, engaged_dutycycle2;
		logic [31:0] delay_count; 
		logic is_left_servo;
		logic engage, start_engaging; // delay it long enough for the servo to act
		logic push_pulse;
		
		// level2pulse converter 
		level2pulse L1(clk, reset, start_push, push_pulse);
		
		// wait for a bit before hitting
		// TODO: fix this delay. it's a bit unelegant.
		always_ff @(posedge clk)
			if (reset) delay_count = 0;
			else if (push_pulse) delay_count <= 0;
			else if ( ~(delay_count == 31'd40000001)) delay_count <= delay_count + 1;
			else delay_count <= delay_count;
		
		// engage 
		assign engage = (delay_count >= 31'd20000000 & delay_count <= 31'd40000000 & start_push);			
		
		assign rest_dutycycle     = 20'd64000;
		assign engaged_dutycycle1 = 20'd48000;
		assign engaged_dutycycle2 = 20'd80000;

		assign is_left_servo = (digit % 2) ? 1'd1 : 1'd0;
		
		// establishing a 20ms update rate
		always_ff @(posedge clk)
			if (reset || count == 20'd800000) count = 20'b0;
			else count <= count + 20'd1;
		
		// creating pwm 
		always_ff @(posedge clk)
			if (count < duty_cycle1) servo_pwm1 = 1'b1; 
			else servo_pwm1 = 1'b0;
			
		always_ff @(posedge clk)
			if (count < duty_cycle2) servo_pwm2 = 1'b1;
			else servo_pwm2 = 1'b0;
			
		// select the duty cycle 
		always_comb 
			case(engage)
				1'b1: if (is_left_servo) begin 
				        duty_cycle1 = engaged_dutycycle1;
						  duty_cycle2 = rest_dutycycle;
						end else begin
						  duty_cycle2 = engaged_dutycycle2;
						  duty_cycle1 = rest_dutycycle;
						end
				default: begin 
				           duty_cycle1 = rest_dutycycle;
							  duty_cycle2 = rest_dutycycle;
							end
			endcase
			
		
endmodule 

// Generate a pulse when level changes from low to high
module level2pulse(input  logic clk, reset,
                   input  logic level,
                   output logic pulse);
	typedef enum logic [1:0] {Low, Write, High} statetype;
	statetype state, nextstate;
	
	// State register
	always_ff @(posedge clk, posedge reset) 
		if (reset) state <= Low;
		else       state <= nextstate; 
	
	// next state logic 
   always_comb
		case(state)
			Low:if (level) nextstate=Write;
				 else nextstate=Low;
			Write:nextstate=High;
			High:if (level) nextstate=High;
				  else nextstate=Low;
			default:nextstate=Low;
		endcase 
	
	assign pulse=(state==Write);
	
endmodule 


module testbench();
	logic clk, reset, step_size, en, load;
	logic [3:0] digit;
	logic [3:0] stepper_out;
	logic [8:0] count;
	logic [7:0] num_steps;
	logic PWM1, PWM2;
	
	step_motor_drive dut(clk, reset, en, load, digit, stepper_out[3], stepper_out[2], stepper_out[1], stepper_out[0], PWM1, PWM2);
	
	initial 
		forever begin
			clk = 1'b0; #5;
			clk = 1'b1; #5; 
		end
		
	initial begin 
		reset = 1'b1;
		en = 1;
		load = 1;
		count = 0;
		digit = 4'd4;
		num_steps = 20;
	end
	
	always @(posedge clk) 
	begin
		if (count > 5) reset = 1'b0;
		
		if (count > 100) digit = 4'd4;
		
		count = count + 1;
	end

endmodule
