-- This file is copyright by Grant Searle 2014
-- You are free to use this file in your own projects but must never charge for it nor use it without
-- acknowledgement.
-- Please ask permission from Grant Searle before republishing elsewhere.
-- If you use this file or any part of it, please add an acknowledgement to myself and
-- a link back to my main web site http://searle.hostei.com/grant/    
-- and to the UK101 page at http://searle.hostei.com/grant/uk101FPGA/index.html
--
-- Please check on the above web pages to see if there are any updates before using this file.
-- If for some reason the page is no longer available, please search for "Grant Searle"
-- on the internet to see if I have moved to another web hosting service.
--
-- Grant Searle
-- eMail address available on my main web page link above.

-- Initial port to Altera DE0_CV by Leslie Ayling - 8th April 2015

library ieee;
use ieee.std_logic_1164.all;
use  IEEE.STD_LOGIC_ARITH.all;
use  IEEE.STD_LOGIC_UNSIGNED.all;

entity uk101 is
	port(
		n_reset		: in std_logic;
		clk			: in std_logic;	-- 50MHz
		rxd			: in std_logic;
		txd			: out std_logic;
		--rts		: out std_logic;
		--videoSync	: out std_logic;
		--video		: out std_logic;
		ps2Clk		: in std_logic;
		ps2Data		: in std_logic;
		SW			: in std_logic_vector(9 downto 0);			-- control switches
		LEDR		: inout std_logic_vector(9 downto 0);		-- Red status leds (inout so can be driven by 6821 outputs)

		VGA_R		: out std_logic_vector(3 downto 0);
		VGA_G		: out std_logic_vector(3 downto 0);
		VGA_B		: out std_logic_vector(3 downto 0);
		VGA_HS		: out std_logic;
		VGA_VS		: out std_logic
	);
end uk101;

architecture struct of uk101 is

	signal n_WR					: std_logic;
	signal cpuAddress			: std_logic_vector(15 downto 0);
	signal cpuDataOut			: std_logic_vector(7 downto 0);
	signal cpuDataIn			: std_logic_vector(7 downto 0);

	signal basRomData			: std_logic_vector(7 downto 0);
	signal ramDataOut			: std_logic_vector(7 downto 0);
	signal monitorRomData		: std_logic_vector(7 downto 0);
	signal aciaData				: std_logic_vector(7 downto 0);

	signal n_memWR				: std_logic;
	
	signal n_dispRamCS			: std_logic;
	signal n_colourRamCS		: std_logic;
	signal n_ramCS				: std_logic;
	signal n_HiresRamCS			: std_logic;	-- hiresRam
	signal n_basRomCS			: std_logic;
	signal n_monitorRomCS		: std_logic;
	signal n_aciaCS				: std_logic;
	signal n_kbCS				: std_logic;
	signal n_modeDECS			: std_logic;
	signal n_diskPiaCS			: std_logic;
	signal n_diskAciaCS			: std_logic;

	
	signal dispAddrB 			: std_logic_vector(10 downto 0);
	signal dispRamDataOutA		: std_logic_vector(7 downto 0);
	signal dispRamDataOutB		: std_logic_vector(7 downto 0);
	signal colourAddrB 			: std_logic_vector(10 downto 0);	-- 2Kb
	signal colourRamDataOutA	: std_logic_vector(7 downto 0);
	signal colourRamDataOutB	: std_logic_vector(7 downto 0);
	signal HiresAddrB 			: std_logic_vector(13 downto 0);	-- 16kb
	signal HiresRamDataOutA		: std_logic_vector(7 downto 0);
	signal HiresRamDataOutB		: std_logic_vector(7 downto 0);
	signal charAddr 			: std_logic_vector(10 downto 0);
	signal charData 			: std_logic_vector(7 downto 0);
	signal diskpiaout 			: std_logic_vector(7 downto 0);
	signal diskaciaout 			: std_logic_vector(7 downto 0);
	
	-- DiskRAM signals
	
	signal diskRAMWE			: std_logic := '0';
	signal diskRAMAddr	 		: std_logic_vector(17 downto 0) := (others => '0');	-- Disk RAM current memory location pointer
	signal diskRAMDataOut 		: std_logic_vector(7 downto 0);						-- Output from Disk RAM memory
	signal n_indexPulse			: std_logic;
	signal indexClkCount		: std_logic_vector(13 downto 0);					-- Counts 200ms in 20ns pulses , 0 to 10000 ($2710)

	-- written from $DEXX. Bits: 5 = Hires+TEXT mix, 4 = Text/Hires, 2 = Colour Off/On , 1 = Sound Off/On, 0 = 32/64
	
	signal ModeDE	 			: std_logic_vector(7 downto 0) := "00000011";	-- powers up with hires off, colour off, sound on, 64x32 screen

	signal serialClkCount	: std_logic_vector(14 downto 0); 
	signal cpuClkCount	: std_logic_vector(5 downto 0); 
	signal cpuClock		: std_logic;
	signal serialClock	: std_logic;

	signal kbReadData 	: std_logic_vector(7 downto 0);
	signal kbRowSel 	: std_logic_vector(7 downto 0);
	
	signal clk50		: std_logic;
	signal clk25		: std_logic;	-- for VGA 640x480  60Hz screen mode
	signal clk65		: std_logic;	-- for XGA 1024x768 60Hz screen mode
	signal clk65_180	: std_logic;	-- 65MHz , 180 degrees out for clocking internal rams in XGA mode
	
	-- allow 4 different switch selectable speeds
	type speed is array(0 to 3, 0 to 1) of integer range 0 to 49;
	constant speed_array : speed :=
	(
	(25,49), -- 1 MHz
	(11,24), -- 2 MHz
	(6,12), -- 4 MHz *approx
	(3,6)  -- 8 MHz *approx
	);


	component PLL5_25 is
	port (
		refclk   : in  std_logic := 'X'; -- clk_in
		rst      : in  std_logic := 'X'; -- reset
		outclk_0 : out std_logic;        -- clk_out
		outclk_1 : out std_logic;        -- clk_out
		outclk_2 : out std_logic;        -- clk_out
		outclk_3 : out std_logic        -- clk_out
		);
	end component PLL5_25;

begin

	pll25 : PLL5_25
	port map (
		refclk   => clk,		-- 50MHz in
		rst      => '0',		-- not n_reset,
		outclk_0 => clk50,		-- 50MHz out
		outclk_1 => clk25,		-- 25MHz out
		outclk_2 => clk65,		-- 65MHz out
		outclk_3 => clk65_180	-- 65MHz out 180 degrees behind
		);
	
	n_memWR <= not(cpuClock) nand (not n_WR);

	n_modeDECS		<= '0' when cpuAddress(15 downto 8) = "11011110" else '1';		   								-- 256byte $DE00-$DEFF   Mode control byte location
	n_dispRamCS		<= '0' when cpuAddress(15 downto 11) = "11010" else '1';		   								-- 2K      $D000-$D7FF
	n_colourRamCS	<= '0' when cpuAddress(15 downto 11) = "11100" else '1';		   								-- 2K      $E000-$E7FF
	n_basRomCS		<= '0' when cpuAddress(15 downto 13) = "101" else '1'; 			   								-- 8K      $A000-$BFFF
	
--	n_monitorRomCS	<= '0' when cpuAddress(15 downto 11) = "11111" else '1';	   									-- 2K      $F800-$FFFF  UK101/C1

	n_monitorRomCS	<= '0' when (cpuAddress(15 downto 11) = "11111" and cpuAddress(11 downto 8) /= "1100") else		-- 2K      $F800-$FFFF  (except $FC00-$FCFF)  C2/C4
					   '0' when cpuAddress(15 downto 8)  = "11110100" else	   										-- 256byte $F400-$F4FF  (relocated FC00-FCFF block)
					   '1';
	
	n_ramCS			<= '0' when cpuAddress(15)= '0' else '1';			   											-- 32K     $0000-$7FFF
	n_HiresRamCS	<= '0' when cpuAddress(15 downto 14) = "10" else '1';			   								-- 16K     $8000-$BFFF
	
--	n_aciaCS		<= '0' when cpuAddress(15 downto 1) = "111100000000000" else '1';  								-- 2BYTES  $F000-$F001  UK101/C1
	n_aciaCS		<= '0' when cpuAddress(15 downto 1) = "111111000000000" else '1';  								-- 2BYTES  $FC00-$FC01  C2/C4
	n_kbCS			<= '0' when cpuAddress(15 downto 10) = "110111" else '1';          								-- 1K      $DC00-$DFFF  only really need $DC00 itself
	
	n_diskPiaCS		<= '0' when cpuAddress(15 downto 2) = "11000000000000" else '1';  								-- 4BYTES  $C000-$C003  C2/C4 DISK PIA
	n_diskAciaCS	<= '0' when cpuAddress(15 downto 1) = "110000000001000" else '1';  								-- 2BYTES  $C010-$C011  C2/C4 DISK ACIA
 
	cpuDataIn <=
		basRomData			when n_basRomCS = '0' 		else
		monitorRomData		when n_monitorRomCS = '0' 	else
		aciaData			when n_aciaCS = '0' 		else
		ramDataOut			when n_ramCS = '0' 			else
		dispRamDataOutA 	when n_dispRamCS = '0' 		else
		colourRamDataOutA 	when n_colourRamCS = '0' 	else
		HiresRamDataOutA 	when n_HiresRamCS = '0' 	else
		ModeDE			 	when n_modeDECS = '0' 		else		-- single byte mode register
		kbReadData			when n_kbCS ='0'			else 
		diskpiaout			when n_diskPiaCS = '0'      else
		diskaciaout			when n_diskAciaCS = '0'		else x"FF";
		
	u1 : entity work.T65
	port map(
		Enable	=> '1',
		Mode	=> "00",
		Res_n	=> n_reset,
		Clk		=> cpuClock,
		Rdy		=> '1',
		Abort_n => '1',
		IRQ_n	=> '1',
		NMI_n	=> '1',
		SO_n	=> '1',
		R_W_n	=> n_WR,
		A(15 downto 0) => cpuAddress,
		DI	=> cpuDataIn,
		DO	=> cpuDataOut);
			

	u2 : entity work.BasicRom 					-- 8KB      $A000-$BFFF
	port map(
		address => cpuAddress(12 downto 0),
		clock => clk50,
		q => basRomData
	);

	u3: entity work.ProgRam 
	port map
	(
		address => cpuAddress(14 downto 0),		-- ony 48Kb is valid
		clock => clk50,
		data => cpuDataOut,
		wren => not(n_memWR or n_ramCS),
		q => ramDataOut
	);
	
	u4: entity work.CegmonRom
	port map
	(
		address => cpuAddress(10 downto 0),
		q => monitorRomData
	);

	u5: entity work.bufferedUART
	port map(
		n_wr => n_aciaCS or cpuClock or n_WR,
		n_rd => n_aciaCS or cpuClock or (not n_WR),
		regSel => cpuAddress(0),
		dataIn => cpuDataOut,
		dataOut => aciaData,
		rxClock => serialClock,
		txClock => serialClock,
		rxd => rxd,
		txd => txd,
		n_cts => '0',
		n_dcd => '0',
		n_rts => open
	);

	process (clk50)		-- 50MHz , period = 20ns
	
	variable speed_setting	: integer range 0 to 3;
	
	begin
		
		speed_setting := conv_integer(UNSIGNED(SW(1 downto 0)));
		
		if n_reset = '0' then 
			ModeDE <= x"03";					-- "00000011";				-- reset to (5-4) hires off, (2)colour off, (1)sound on, (0)64x32 screen
		elsif rising_edge(clk50) then
		
			--============================================================================
			-- CPU Clock 
			
			if cpuClkCount < speed_array(speed_setting,1) then
				cpuClkCount <= cpuClkCount + 1;		-- count 0 to 49, -> 0 etc.
			else
				cpuClkCount <= (others=>'0');
			end if;
			-- generate 1MHz CPU clock
			if cpuClkCount < speed_array(speed_setting,0) then
				cpuClock <= '0';			--  0 to 24 = 25 x 20ns == 500ns low
			else
				cpuClock <= '1';			-- 25 to 49 = 25 x 20ns == 500ns high
			end if;	
			
			--============================================================================
			-- Serial BAUD rate generator
			
--			if serialClkCount < 10416 then -- 300 baud
			if serialClkCount < 325 then -- 9600 baud
				serialClkCount <= serialClkCount + 1;
			else
				serialClkCount <= (others => '0');
			end if;
--			if serialClkCount < 5208 then -- 300 baud
			if serialClkCount < 162 then -- 9600 baud	-- period = 6480ms
				serialClock <= '0';			--    0 to 161 = 162 x 20ns == 3240ms low
			else
				serialClock <= '1';			--  162 to 325 = 162 x 20ns == 3240ms low
			end if;
			
			--============================================================================
			-- Index hole pulse. 4ms low every 200ms (300RPM 5.25" disk)
			
			if indexClkCount < 9999 then	-- 10000 x 20ns = 200ms
				indexClkCount <= indexClkCount + 1;
			else
				indexClkCount <= (others => '0');
			end if;

			if indexClkCount < 199 then		-- 200 x 20ns = 4ms
				n_indexPulse <= '0';
			else
				n_indexPulse <= '1';
			end if;
			
			--============================================================================
			-- update Screenmode byte
			if (n_memWR or n_modeDECS) = '0' then
				ModeDE <= cpuDataOut;
			end if;
		end if;
	end process;
	

	u6 : entity work.UK101TextDisplay
	port map (
		-- in
--		clk 		=> clk25,				-- 25.175 VGA
		clk 		=> clk65,				-- 65.000 XGA
		charData 	=> charData,
		dispData 	=> dispRamDataOutB,
		colourData	=> colourRamDataOutB,	-- C2/C4 colour ram data
		HiresData	=> HiresRamDataOutB,
		mode64		=> ModeDE(0),			-- 0 = 32  , 1 = 64 wide
		--sound_enbl => ModeDE(1),
		colour_enbl	=> ModeDE(2),			-- 0 = mono, 1 = colour 
		hires_enbl	=> ModeDE(4) or SW(2),	-- 0 = TEXT, 1 = HIRES
		hires_mix	=> ModeDE(5) or SW(3),	-- 0 = HIRES, 1 = HIRES + TEXT
		
		-- out
		charAddr 	=> charAddr,		
		dispAddr 	=> dispAddrB,
		colourAddr	=> colourAddrB,
		HiresAddr	=> HiresAddrB,			-- Mittendorf style Hires Area (16K @ $8000-$BFFF)
		
		-- VGA signals
		red			=> VGA_R,
		green		=> VGA_G,
		blue		=> VGA_B,
		h_sync		=> VGA_HS,
		v_sync		=> VGA_VS
	);

	u7: entity work.CharRom
	port map
	(
		address => charAddr,
		q => charData
	);

	-- displayRam	- 2KB @ $D000-$D7FF
	u8: entity work.DisplayRam 
	port map
	(
		address_a => cpuAddress(10 downto 0),
		address_b => dispAddrB,
		clock_a	=> clk50,
		clock_b	=> clk65_180,					-- Pixel clock 180 degrees out
		data_a	=> cpuDataOut,
		data_b	=> (others => '0'),
		wren_a	=> not(n_memWR or n_dispRamCS),
		wren_b	=> '0',
		q_a	=> dispRamDataOutA,
		q_b	=> dispRamDataOutB
	);
	
	-- ColourRam	- 2KB @ $E000-$E7FF
	u10: entity work.DisplayRam 
	port map
	(
		address_a => cpuAddress(10 downto 0),
		address_b => colourAddrB,
		clock_a	=> clk50,
		clock_b	=> clk65_180,					-- Pixel clock 180 degrees out
		data_a	=> cpuDataOut,
		data_b	=> (others => '0'),
		wren_a	=> not(n_memWR or n_colourRamCS),
		wren_b	=> '0',
		q_a	=> colourRamDataOutA,
		q_b	=> colourRamDataOutB
	);
	
	-- HiresRam	- 16KB @ $8000-$BFFF			$A000-$BFFF is write only, as shared with BASIC roms
	u11: entity work.HiresRam 
	port map
	(
		address_a => cpuAddress(13 downto 0),
		address_b => HiresAddrB,
		clock_a	=> clk50,
		clock_b	=> clk65_180,						-- Pixel clock 180 degrees out
		data_a	=> cpuDataOut,
		data_b	=> (others => '0'),
		wren_a	=> not(n_memWR or n_HiresRamCS),
		wren_b	=> '0',
		q_a	=> HiresRamDataOutA,
		q_b	=> HiresRamDataOutB						-- to video unit
	);

	u9 : entity work.UK101keyboard
	port map(
		CLK	 	 => clk50,
		nRESET	 => n_reset,
		PS2_CLK	 => ps2Clk,
		PS2_DATA => ps2Data,
		A	 	 => kbRowSel,
		KEYB	 => kbReadData
	);
	

	DISKRAM : work.DiskRAM PORT MAP (
		address	 => diskRAMAddr,
		clock	 => clk50,
		data	 => cpuDataOut,
		wren	 => diskRAMWE,
		q	 	 => open
	);

	
-- Jonathan Kent Modules follow.  From http://opencores.org/project,system09
	
	diskpia : entity work.pia6821
	port map(
	    --
		-- CPU Interface signals
		--
		clk       => cpuClock,
		rst       => not n_reset,
		cs        => not n_diskPiaCS,
		rw        => n_WR,						-- Read / Not Write
		addr      => cpuAddress(1 downto 0),
		data_in   => cpuDataOut,
		data_out  => diskpiaout,
		irqa      => open,
		irqb      => open,
	    --
		-- I/O PORT signals
		--
		pa        => LEDR(7 downto 0),			-- **** test output only ****
		ca1		  => '0',
		ca2       => open,
		pb        => open,
		cb1       => '0',
		cb2       => open
	);
	
	diskacia : entity work.acia6850
	port map(
	    --
		-- CPU Interface signals
		--
		clk      => cpuClock,               -- CPU clock
		rst      => not n_reset,            -- Reset input (active high)
		cs       => not n_diskAciaCS,       -- miniUART Chip Select
		addr     => cpuAddress(0),			-- Register Select
		rw       => n_WR,                   -- Read / Not Write
		data_in  => cpuDataOut,  			-- Data Bus In 
		data_out => diskaciaout,			-- Data Bus Out
		irq      => open,                   -- Interrupt Request out
		--
		-- RS232 Interface Signals
		--
		RxC   => '0',              			-- Receive Baud Clock
		TxC   => '0',              			-- Transmit Baud Clock
		RxD   => '1',              			-- Receive Data
		TxD   => open,              		-- Transmit Data
		DCD_n => '0',              			-- Data Carrier Detect
		CTS_n => '0',              			-- Clear To Send
		RTS_n => open               		-- Request To send
	);
	
	
	process (n_kbCS,n_memWR)
	begin
		if	n_kbCS='0' and n_memWR = '0' then
			kbRowSel <= cpuDataOut;
		end if;
	end process;
	
end;
