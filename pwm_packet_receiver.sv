`timescale 1ns/1ps
`define REG_DELAY #0.2

module pwm_packet_receiver (
	input wire clk, // 1ns system clock
	input wire rstz, // Asynchronous active-low reset
	input wire RX_P, // Differential positive input
	input wire RX_N, // Differential negative input
	output reg valid, // High for 1 clk after valid packet
	output reg [3:0] data // Decoded 4-bit data
	);

	// Internal signals
	reg [2:0] RX_P_sync_ff;
	reg [2:0] RX_N_sync_ff;
	wire RX_P_sync;
	wire RX_N_sync;

	reg [6:0] high_cnt, low_cnt;      // For SOP/EOP
	reg [6:0] diff0_latched;
	reg [6:0] diff1_latched;
	reg [6:0] diff1_cnt, diff0_cnt;   // For PWM symbol
	reg [6:0] duration_cnt;
	reg [6:0] last_duration;
	reg [2:0] bit_cnt;
	reg [3:0] shift_reg;
	reg [6:0] ratio;
	reg shift_ready;

	reg [2:0] symbol_phase; // 0: idle, 1: counting diff1, 2: counting diff0
	reg [2:0] prev_symbol_phase;

	typedef enum reg [2:0] {
		IDLE = 3'b000,
		WAIT_SOP = 3'b001,
		RECEIVE = 3'b010,
		WAIT_EOP = 3'b011,
		OUTPUT_VALID = 3'b100,
		OUTPUT_INVALID = 3'b101
	} state_t;

	state_t state, next_state, prev_state;

	reg [6:0] ratio_calc;

	wire symbol_phase_fell_2_to_1 = (prev_symbol_phase == 3'd2 && symbol_phase == 3'd1);

	wire receive_done = (prev_state == RECEIVE && state == WAIT_EOP);


	// Input synchronizers
	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			RX_P_sync_ff <= `REG_DELAY 2'b00;
		end else begin
			RX_P_sync_ff <= `REG_DELAY {RX_P_sync_ff[1], RX_P_sync_ff[0], RX_P};
		end
	end

	//counter for pwm duration
	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			duration_cnt <= `REG_DELAY 0;
		end else begin
			if(state == RECEIVE)
				duration_cnt = duration_cnt + 1;
		end
	end

	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			RX_N_sync_ff <= `REG_DELAY 2'b00;
		end else begin
			RX_N_sync_ff <= `REG_DELAY {RX_N_sync_ff[0], RX_N};
		end
	end

	/*assign RX_P_sync = RX_P_sync_ff[1];
	assign RX_N_sync = RX_N_sync_ff[1];*/
	
	assign RX_P_sync = RX_P;
	assign RX_N_sync = RX_N;

	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			state <= `REG_DELAY IDLE;
		end else begin
			state <= `REG_DELAY next_state;
		end
	end

	always @(posedge clk or negedge rstz) begin
	if (!rstz)
		prev_state <= `REG_DELAY IDLE;
	else
		prev_state <= `REG_DELAY state;
	end

	// SOP detection
	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			low_cnt <= `REG_DELAY 0;
		end else begin
			if (!RX_P_sync && !RX_N_sync)
				low_cnt <= `REG_DELAY low_cnt + 1;
			else
				low_cnt <= `REG_DELAY 0;
			end
	end

	// EOP detection
	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			high_cnt <= `REG_DELAY 0;
		end else begin
			if (RX_P_sync && RX_N_sync)
				high_cnt <= `REG_DELAY high_cnt + 1;
			else
				high_cnt <= `REG_DELAY 0;
			end	
	end


	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			symbol_phase <= `REG_DELAY 0;
		end else begin
			if(state == RECEIVE) begin
				if (RX_P_sync && !RX_N_sync)
					symbol_phase <= `REG_DELAY 1;
				
				if (!RX_P_sync && RX_N_sync)
					symbol_phase <= `REG_DELAY 2;
			end else begin
				symbol_phase <= `REG_DELAY 0;
			end
		
		end
	end

	always @(posedge clk or negedge rstz) begin
	if (!rstz)
		prev_symbol_phase <= `REG_DELAY 0;
	else
		prev_symbol_phase <= `REG_DELAY symbol_phase;
	end

	// Symbol phase and duration tracking
	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			//symbol_phase <= `REG_DELAY 0;
			diff1_cnt <= `REG_DELAY 0;
			diff0_cnt <= `REG_DELAY 0;
		end else begin
			case(state)
				RECEIVE: begin
					case (symbol_phase)
						0: begin
							if (RX_P_sync && !RX_N_sync) begin
								diff1_cnt <= `REG_DELAY 1;
								diff0_cnt <= `REG_DELAY 0;
							end
						end
						1: begin
							if (RX_P_sync && !RX_N_sync) begin
								diff1_cnt <= `REG_DELAY diff1_cnt + 1;
							end else if (!RX_P_sync && RX_N_sync) begin
								diff0_cnt <= `REG_DELAY 1;
							end
						end
						2: begin
							if (!RX_P_sync && RX_N_sync) begin
								diff0_cnt <= `REG_DELAY diff0_cnt + 1;
							end else if (RX_P_sync && !RX_N_sync) begin
								diff1_cnt <= `REG_DELAY 1;
							end
						end
					endcase
				end
				default: begin
					//symbol_phase <= `REG_DELAY 0;
					diff1_cnt <= `REG_DELAY 0;
					diff0_cnt <= `REG_DELAY 0;
				end
			endcase
		end
	end

	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			diff0_latched <= `REG_DELAY 0;
			diff1_latched <= `REG_DELAY 0;
		end else if ((!RX_N && RX_P) || receive_done) begin
			diff0_latched <= `REG_DELAY diff0_cnt;
			diff1_latched <= `REG_DELAY diff1_cnt;
		end
	end

	// Ratio calculation
	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			ratio <= `REG_DELAY 0;
		end else begin
			if (shift_ready) begin
					ratio <= ratio_calc;
			end
		end
	end

	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			ratio_calc <= `REG_DELAY 0;
			shift_ready <= `REG_DELAY 0;
		end 
		if (symbol_phase_fell_2_to_1) begin
				ratio_calc <= `REG_DELAY (diff1_latched * 100) / (diff1_latched + diff0_latched) ;
				shift_ready <= `REG_DELAY 1;
		end
		else if (next_state == WAIT_EOP) begin
			ratio_calc <= `REG_DELAY (diff1_cnt * 100) / (diff1_cnt + diff0_cnt) ;
			shift_ready <= `REG_DELAY 1;
		end
	end

	// Bit counter and shift register
	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			shift_reg <= `REG_DELAY 0;
		end else begin

			if (state == IDLE) begin
				shift_reg <= `REG_DELAY 0;
			end else if(state == RECEIVE || WAIT_EOP) begin
				if (shift_ready && bit_cnt <= 4) begin
					if (ratio_calc >= 11 && ratio_calc <= 40 && last_duration >=10 && last_duration <=40) begin
						shift_reg <= `REG_DELAY {shift_reg[2:0], 1'b0};
						shift_ready <= `REG_DELAY 0;
					end else if (ratio_calc >= 53 && ratio_calc <= 75 && last_duration >=10 && last_duration <=40) begin
						shift_reg <= `REG_DELAY {shift_reg[2:0], 1'b1};
						shift_ready <= `REG_DELAY 0;
					end else if (ratio_calc < 11 || ratio_calc > 40 &&  ratio_calc < 53 || ratio_calc > 75 || last_duration < 10 || last_duration > 40)  begin
						next_state = OUTPUT_INVALID;
						shift_ready <= `REG_DELAY 0;
					end
				end
			end
		end
	end

	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			bit_cnt <= `REG_DELAY 0;
		end else begin
			if (state == RECEIVE && (symbol_phase_fell_2_to_1 || receive_done)) begin
				bit_cnt <= `REG_DELAY bit_cnt + 1;
				last_duration <= duration_cnt;
				duration_cnt <= `REG_DELAY 0;
			end else begin
				if (state == WAIT_SOP) begin
					bit_cnt <= `REG_DELAY 1;
					duration_cnt <= `REG_DELAY 0;
				end
			end
		end
	end

	// Output logic
	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			data <= `REG_DELAY 0;
		end else begin
			if (state == OUTPUT_VALID)
				data <= `REG_DELAY shift_reg;
		end
	end

	always @(posedge clk or negedge rstz) begin
		if (!rstz) begin
			valid <= `REG_DELAY 0;
		end else begin
			if (state == OUTPUT_VALID) begin
				valid <= `REG_DELAY 1;
				shift_ready <= `REG_DELAY 0;
			end else 
				valid <= `REG_DELAY 0;
		end
	end

	// FSM Next State Logic
	always @(*) begin
		next_state = state;
		case (state)
			IDLE:
				next_state = WAIT_SOP;

			WAIT_SOP:
				if (low_cnt >= 80)
					next_state = RECEIVE;

			RECEIVE:
				if (bit_cnt == 4 && RX_P_sync && RX_N_sync)
					next_state = WAIT_EOP;

			WAIT_EOP:
				if (high_cnt >= 80)
					next_state = OUTPUT_VALID;

			OUTPUT_VALID:
				next_state = IDLE;

			OUTPUT_INVALID:
				next_state = IDLE;
		endcase
	end

endmodule
