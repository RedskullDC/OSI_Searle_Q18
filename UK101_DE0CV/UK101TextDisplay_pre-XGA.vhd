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

-- VGA out 640x480 by Leslie Ayling - 8th April 2015
-- C2/C4 mode support by L.A. - June 2017


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use ieee.std_logic_unsigned.all;

entity UK101TextDisplay is
	port (
		-- in
		clk    		: in  std_logic;						-- 25.175MHz
		mode64		: in  std_logic;						-- 0 = 32  , 1 = 64 wide screen mode
		colour_enbl	: in  std_logic;						-- 0 = mono, 1 = colour
		charData	: in std_LOGIC_VECTOR(7 downto 0);		-- char gen data in
		dispData	: in std_LOGIC_VECTOR(7 downto 0);		-- display ram data in
		colourData	: in std_LOGIC_VECTOR(7 downto 0);		-- colour ram data in
		
		-- out
		charAddr	: out std_LOGIC_VECTOR(10 downto 0);	-- char gen address - 256chars x 8 bits x 8 lines/char = 2KBx8
		dispAddr	: out std_LOGIC_VECTOR(10 downto 0);	-- 2Kb for C2/4  (1kb for C1P)
		colourAddr	: out std_LOGIC_VECTOR(10 downto 0);	-- 2Kb for C2/4
		
		-- 4-bit vga outputs
		red		  : out std_LOGIC_VECTOR(3 downto 0);
		green	  : out std_LOGIC_VECTOR(3 downto 0);
		blue	  : out std_LOGIC_VECTOR(3 downto 0);
		h_sync	  : out std_logic;
		v_sync	  : out std_logic
   );
end UK101TextDisplay;

architecture rtl of UK101TextDisplay is

	signal  hSync   : std_logic;
	signal  vSync   : std_logic;

	signal  vActive   : std_logic := '0';
	signal  hActive   : std_logic := '0';

	signal  video_out	: std_logic;

	signal	pixelCount: STD_LOGIC_VECTOR(2 DOWNTO 0); 		-- 0 to 7
	
	signal	horizCount: STD_LOGIC_VECTOR(9 DOWNTO 0); 		-- 0 to 1023 (only counts 0 to 799)
	signal	vertLineCount: STD_LOGIC_VECTOR(9 DOWNTO 0);	-- 0 to 1023 (only counts 0 to 524)

	signal	charVert: STD_LOGIC_VECTOR(4 DOWNTO 0); 		-- 0 to 31
	signal	charScanLine: STD_LOGIC_VECTOR(2 DOWNTO 0); 	-- 0 to 7

	signal	charHoriz: STD_LOGIC_VECTOR(5 DOWNTO 0); 		-- 0 to 63
	signal	charBit: STD_LOGIC_VECTOR(3 DOWNTO 0); 			-- 0 to 15

begin
	
--	h_sync	<= hSync;
--	v_sync	<= vSync;
--	
--	red		<= (others => '0');
--	green	<= video_out & video_out & video_out & video_out;	-- green screen
--	blue	<= (others => '0');
	
	dispAddr <= charVert & charHoriz;			-- linear screen.  ** change for C4P 32 column mode**
	charAddr <= dispData & charScanLine;		-- 8 x 8 chars
	
	PROCESS (clk)
	BEGIN
		if rising_edge(clk) then
			IF horizCount < 799 THEN
				horizCount <= horizCount + 1;
--				if (horizCount < 144) or (horizCount > 656) then
				if (horizCount < 208) or (horizCount > 720) then
					hActive <= '0';
					charHoriz <= (others => '0');
				else
					hActive <= '1';
				end if;
			else
				horizCount <= (others => '0');
				pixelCount <= (others => '0');
				charHoriz  <= (others => '0');
				if vertLineCount > 523 then
					vertLineCount <= (others => '0');
				else
					if vertLineCount < 38 or vertLineCount > 293 then
						vActive <= '0';
						charVert <= (others => '0');
						charScanLine <= (others => '0');
					else
						vActive <= '1';
						if charScanLine = 7 then
							charScanLine <= (others => '0');
							charVert <= charVert + 1;
						else
							if vertLineCount /= 38 then
								charScanLine <= charScanLine + 1;
							end if;
						end if;
					end if;
					vertLineCount <=vertLineCount + 1;
				end if;
			END IF;
			
			-- sync control
			if horizCount < 96 then
				hSync <= '0';
			else
				hSync <= '1';
			end if;
			if vertLineCount < 2 then
				vSync <= '0';
			else
				vSync <= '1';
			end if;
			
			-- video out
			if hActive='1' and vActive = '1' then
				video_out <= charData(7-to_integer(unsigned(pixelCount)));
				if pixelCount = 7 then
					charHoriz <= charHoriz + 1;
				end if;
				pixelCount <= pixelCount + 1;	-- wrap at 7 back to 0
			else
				video_out <= '0';	-- blank video out
			end if;

			-- register all outputs
			h_sync	<= hSync;
			v_sync	<= vSync;
			red		<= (others => '0');
			green	<= video_out & video_out & video_out & video_out;	-- green screen
			blue	<= (others => '0');
		end if;
	END PROCESS;	
end rtl;

-- UK101 display...
-- 64 bytes per line (48 chars displayed)	
-- 16 lines of characters
-- 8x8 per char

-- Grant starts each line at *beginning* of sync pulse:

-- Horiz:

--    0     96      144    (640 visible)     783    799
--     SYNC    BP               VID              FP
--          --------|-------------------------|-------
--          |                                        |
--          |                                        |
-- HS -------                                        - etc.

-- Vert:

--    0     2       35     (480 visible)     514    524
--     SYNC    BP               VID              FP
--          --------|-------------------------|-------
--          |                                        |
--          |                                        |
-- HS -------                                        - etc.

-- current design only uses visible: 512h x 256v (double height)

-- change to VGA params with a 25.175MHz clock:

--Horizontal timing (line)		
--Polarity of horizontal sync pulse is negative.		
--Scanline part	Pixels	Time [µs]
--Visible area		640	25.42204568
--Front porch		16	0.635551142
--Sync pulse		96	3.813306852
--Back porch		48	1.906653426
--Whole line		800	31.7775571
--		
--Vertical timing (frame)		
--Polarity of vertical sync pulse is negative.		
--Frame part		Lines	Time [ms]
--Visible area		480	15.25322741
--Front porch		10	0.317775571
--Sync pulse		2	0.063555114
--Back porch		33	1.048659384
--Whole frame		525	16.68321748

--====================================================
--XGA Signal 1024 x 768 @ 60 Hz timing
--
--General timing
--
--Screen refresh rate 60 Hz 
--Vertical refresh 48.363095238095 kHz 
--Pixel freq. 65.0 MHz 
--
--Horizontal timing (line)
--Polarity of horizontal sync pulse is negative.
--
--Scanline part 	Pixels 	Time [µs] 
--Visible area 		1024 	15.753846153846 
--Front porch 		24 		0.36923076923077 
--Sync pulse 		136 	2.0923076923077 
--Back porch 		160 	2.4615384615385 
--Whole line 		1344 	20.676923076923 
--
--
--Vertical timing (frame)
--Polarity of vertical sync pulse is negative.
--
--Frame part 		Lines 	Time [ms] 
--Visible area 		768 	15.879876923077 
--Front porch 		3 		0.062030769230769 
--Sync pulse 		6 		0.12406153846154 
--Back porch 		29 		0.59963076923077 
--Whole frame 		806 	16.6656 



