
module sd_card_sec_read_write
#(
	parameter  SPI_LOW_SPEED_DIV = 248,         // spi clk speed = clk speed /((SPI_LOW_SPEED_DIV + 2) * 2 )
	parameter  SPI_HIGH_SPEED_DIV = 0           // spi clk speed = clk speed /((SPI_HIGH_SPEED_DIV + 2) * 2 )
)
(
	input            clk,
 output wire short_block,
	input            rst,
	output reg       sd_init_done,
	input            sd_sec_read,
    input            read_stream,
	input[31:0]      sd_sec_read_addr,
	output[7:0]      sd_sec_read_data,
	output           sd_sec_read_data_valid,
	output           sd_sec_read_end,
	input            sd_sec_write,
	input[31:0]      sd_sec_write_addr,
	input[7:0]       sd_sec_write_data,
	output           sd_sec_write_data_req,
	output           sd_sec_write_end,

	output reg[15:0] spi_clk_div,
	output reg       cmd_req,
	input            cmd_req_ack,
	input            cmd_req_error,
	output reg[47:0] cmd,
	output reg[7:0]  cmd_r1,
	output reg[15:0] cmd_data_len,
	output reg       block_read_req,
	input            block_read_valid,
	input[7:0]       block_read_data,
	input            block_read_req_ack,
	output reg       block_write_req,
	output[7:0]      block_write_data,
	input            block_write_data_rd,
	input            block_write_req_ack
);
reg[7:0] read_data;
reg[31:0] timer;

localparam S_IDLE               = 0;
localparam S_CMD0               = 1;
localparam S_CMD8               = 2;
localparam S_CMD55              = 3;
localparam S_CMD41              = 4;
localparam S_CMD17              = 5;
localparam S_READ               = 6;
localparam S_CMD24              = 7;
localparam S_WRITE              = 8;
localparam S_ERR                = 14;
localparam S_WRITE_END          = 15;
localparam S_READ_END           = 16;
localparam S_WAIT_READ_WRITE    = 17;
localparam S_CMD16              = 18;
localparam S_STOP_STREAM        = 19;
localparam S_HS_CMD=20,S_HS_DATA=21,S_HS_STATUS=22;
 reg[6:0]hs_index;reg[3:0]hs_result;
reg stream_active,pending_write;reg [31:0] stream_next;

reg[4:0]                       state;
 assign short_block=state==S_HS_DATA;
reg[31:0]                      sec_addr;
assign sd_sec_read_data_valid = (state == S_READ) && block_read_valid;
assign sd_sec_read_data = block_read_data;
assign sd_sec_read_end = (state == S_READ_END);
assign sd_sec_write_data_req = (state == S_WRITE) && block_write_data_rd;
assign block_write_data = sd_sec_write_data;
assign sd_sec_write_end = (state == S_WRITE_END);

always@(posedge clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		state <= S_IDLE;hs_index<=0;hs_result<=15;
        stream_active<=0;stream_next<=0;pending_write<=0;
		cmd_req <= 1'b0;
		cmd_data_len <= 16'd0;
		cmd_r1 <= 8'd0;
		cmd <= 48'd0;
		spi_clk_div <= SPI_LOW_SPEED_DIV[15:0];
		block_write_req <= 1'b0;
		block_read_req <= 1'b0;
		sec_addr <= 32'd0;
		sd_init_done <= 1'b0;
	end
	else
		case(state)
			S_IDLE:
			begin
				state <= S_CMD0;
				sd_init_done <= 1'b0;
				spi_clk_div <= SPI_LOW_SPEED_DIV[15:0];
			end
			S_CMD0:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD8;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h01;
					cmd <= {8'd0,8'h00,8'h00,8'h00,8'h00,8'h95};
				end
			end
			S_CMD8:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD55;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd4;
					cmd_r1 <= 8'h01;
					cmd <= {8'd8,8'h00,8'h00,8'h01,8'haa,8'h87};
				end
			end
			S_CMD55:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD41;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h01;
					cmd <= {8'd55,8'h00,8'h00,8'h00,8'h00,8'hff};
				end
			end
			S_CMD41:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD16;
					cmd_req <= 1'b0;
					sd_init_done <= 1'b0;
					spi_clk_div <= 16'd0;
				end
				else if(cmd_req_ack)
				begin
					state <= S_CMD55;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd41,8'h40,8'h00,8'h00,8'h00,8'hff};
				end
			end
			S_CMD16:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_HS_CMD;
					cmd_req <= 1'b0;
					sd_init_done <= 1'b0;
					spi_clk_div <= 16'd0;
				end
				else if(cmd_req_ack)
				begin
					state <= S_CMD55;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd16,32'd512,8'hff};
				end
			end			
            S_HS_CMD:begin
                if(cmd_req_ack)begin
                    cmd_req<=0;
                    if(cmd_req_error)state<=S_ERR;
                    else begin hs_index<=0;hs_result<=15;state<=S_HS_DATA;end
                end else begin cmd_req<=1;cmd_data_len<=0;cmd_r1<=0;cmd<={8'd6,32'h80fffff1,8'hff};end
            end
            S_HS_DATA:begin
                if(block_read_valid)begin
                    if(hs_index==16)hs_result<=block_read_data[3:0];
                    hs_index<=hs_index+1'b1;
                end
                if(block_read_req_ack)begin
                    block_read_req<=0;
                    state<=hs_result==1?S_HS_STATUS:S_ERR;
                end else block_read_req<=1;
            end
            // CMD13 at 25MHz supplies the settling clocks after CMD6 status,
            // and confirms the card is still responsive before enabling 50MHz.
            S_HS_STATUS:begin
                if(cmd_req_ack)begin
                    cmd_req<=0;
                    if(cmd_req_error)state<=S_ERR;
                    else begin sd_init_done<=1;spi_clk_div<=16'hffff;state<=S_WAIT_READ_WRITE;end
                end else begin cmd_req<=1;cmd_data_len<=1;cmd_r1<=0;cmd<={8'd13,32'd0,8'hff};end
            end
			S_WAIT_READ_WRITE:
			begin
				if(sd_sec_write ==  1'b1)
				begin
					pending_write<=1;
                    state <= stream_active?S_STOP_STREAM:S_CMD24;
					sec_addr <= sd_sec_write_addr;
				end
				else if(sd_sec_read == 1'b1)
				begin
					pending_write<=0;
                    if(stream_active && read_stream && sd_sec_read_addr==stream_next)begin
                        state<=S_READ;stream_next<=stream_next+1'b1;
                    end else state<=stream_active?S_STOP_STREAM:S_CMD17;
					sec_addr <= sd_sec_read_addr;
				end

				spi_clk_div <= 16'hffff;
			end
			S_CMD24:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_WRITE;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd24,sec_addr,8'hff};

				end
			end
			S_WRITE:
			begin
				if(block_write_req_ack == 1'b1)
				begin
					block_write_req <= 1'b0;
					state <= S_WRITE_END;
				end
				else
					block_write_req <= 1'b1;
			end
			S_CMD17:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_READ;
                    stream_active<=read_stream;stream_next<=sec_addr+1'b1;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {read_stream?8'd18:8'd17,sec_addr,8'hff};
				end
			end
            S_STOP_STREAM:begin
                if(cmd_req_ack && !cmd_req_error)begin
                    cmd_req<=0;stream_active<=0;
                    state<=pending_write?S_CMD24:S_CMD17;
                end else begin
                    cmd_req<=1;cmd_data_len<=0;cmd_r1<=0;cmd<={8'd12,32'd0,8'hff};
                end
            end
			S_READ:
			begin
				if(block_read_req_ack)
				begin
					state <= S_READ_END;
					block_read_req <= 1'b0;
				end
				else
				begin
					block_read_req <= 1'b1;
				end
			end
			S_WRITE_END:
			begin
				state <= S_WAIT_READ_WRITE;
			end
			S_READ_END:
			begin
				state <= S_WAIT_READ_WRITE;
			end
			default:
				state <= S_IDLE;
		endcase
end
endmodule
