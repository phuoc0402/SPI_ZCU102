`timescale 1ns/1ps

module SPI_Slave
#(
	parameter	CLK_FREQUENCE	= 50_000_000		,	//system clk frequence
				SPI_FREQUENCE	= 50_000_000			,	//spi clk frequence
				DATA_WIDTH		= 8					,	//serial word length
				CPOL			= 1					,	//SPI mode selection (mode 0 default)
				CPHA			= 1					 	//CPOL = clock polarity, CPHA = clock phase
)
(
	input								clk			,	//system clk
	input								rst_n		,	//system reset
	input		[DATA_WIDTH-1:0]		data_in		,	//the data sent by miso
	input								sclk		,	//spi bus sclk
	input								cs_n		,	//spi bus slave select line
	input								mosi		,	//spi bus mosi input
	output								miso		,	//spi bus miso output
	output								data_valid	,	//the data received by mosi valid
	output	reg	[DATA_WIDTH-1:0]		data_out	 	//the data received by mosi,valid when data_valid is high
);

localparam	SFIFT_NUM = log2(DATA_WIDTH);

reg	[DATA_WIDTH-1:0]		data_reg	;	
reg	[ SFIFT_NUM-1:0]		sampl_num	;	
reg							sclk_a		;	
reg							sclk_b		;	
wire						sclk_posedge;	
wire						sclk_negedge;	
reg							cs_n_a		;	
reg							cs_n_b		;	
wire						cs_n_negedge;	
wire						shift_en	;	
wire						sampl_en	;	

//to capture the edge of sclk
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sclk_a <= CPOL;
		sclk_b <= CPOL;
	end else if (!cs_n) begin
		sclk_a <= sclk;
		sclk_b <= sclk_a;
	end
end

assign sclk_posedge = ~sclk_b & sclk_a;
assign sclk_negedge = ~sclk_a & sclk_b;

//to capture the edge of sclk
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		cs_n_a	<= 1'b1;
		cs_n_b	<= 1'b1;
	end else begin
		cs_n_a	<= cs_n		;
		cs_n_b	<= cs_n_a	;
	end
end

assign cs_n_negedge = ~cs_n_a & cs_n_b;

//==============GENERATE BLOCKS=================
generate
	case (CPHA)
		0: assign sampl_en = sclk_posedge;
		1: assign sampl_en = sclk_negedge;
		default: assign sampl_en = sclk_posedge;
	endcase
endgenerate

generate
 	case (CPHA)
		0: assign shift_en = sclk_negedge;
 		1: assign shift_en = sclk_posedge;
		default: assign shift_en = sclk_posedge;
	endcase
endgenerate


always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		data_reg <= 'd0;
	else if(cs_n_negedge)
		data_reg <= data_in;
	else if (!cs_n & shift_en) 
		data_reg <= {data_reg[DATA_WIDTH-2:0],1'b0};
	else
		data_reg <= data_reg;
end
//miso output MSB first
assign miso = !cs_n ? data_reg[DATA_WIDTH-1] : 1'd0;


always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		data_out <= 'd0;
	else if (!cs_n & sampl_en) 
		data_out <= {data_out[DATA_WIDTH-2:0],mosi};
	else
		data_out <= data_out;
end
//the counter to count the number of sampled data bit
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		sampl_num <= 'd0;
	else if (cs_n)
		sampl_num <= 'd0;
	else if (!cs_n & sampl_en) 
		if (sampl_num == DATA_WIDTH)
			sampl_num <= 'd1;
		else
			sampl_num <= sampl_num + 1'b1;
	else
		sampl_num <= sampl_num;
end
//the received data valid
assign data_valid = sampl_num == DATA_WIDTH;
//the function to get the width of data 
function integer log2(input integer v);
  begin
	log2=0;
	while(v>>log2) 
	  log2=log2+1;
  end
endfunction

endmodule
