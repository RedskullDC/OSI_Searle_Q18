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
		clk    		: in  std_logic;						-- 65.000MHz XGA 
		mode64		: in  std_logic;						-- 0 = 32  , 1 = 64 wide screen mode
		colour_enbl	: in  std_logic;						-- 0 = mono, 1 = colour
		hires_enbl	: in  std_logic;						-- 0 = TEXT, 1 = HIRES
		hires_mix	: in  std_logic;						-- 0 = HIRES, 1 = HIRES + TEXT
		charData	: in std_LOGIC_VECTOR(7 downto 0);		-- char gen data in
		dispData	: in std_LOGIC_VECTOR(7 downto 0);		-- display ram data in
		colourData	: in std_LOGIC_VECTOR(7 downto 0);		-- colour ram data in, *** top 4 bits for expansion **
		HiresData	: in std_LOGIC_VECTOR(7 downto 0);		-- Hires ram data in,
		
		-- out
		charAddr	: out std_LOGIC_VECTOR(10 downto 0);	-- char gen address - 256chars x 8 bits x 8 lines/char = 2KBx8
		dispAddr	: out std_LOGIC_VECTOR(10 downto 0);	-- 2Kb for C2/4  (1kb for C1P)
		colourAddr	: out std_LOGIC_VECTOR(10 downto 0);	-- 2Kb for C2/4
		HiresAddr	: out std_LOGIC_VECTOR(13 downto 0);	-- 16Kb area for Mittendorf
		
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

	signal	pixelCount: STD_LOGIC_VECTOR(4 DOWNTO 0); 		-- 0 to 31	(0-15 for 64x32, 0-31 for 32x32)
	
	signal	horizCount: STD_LOGIC_VECTOR(10 DOWNTO 0); 		-- 0 to 2047 (only counts 0 to 1343)
	signal	vertLineCount: STD_LOGIC_VECTOR(9 DOWNTO 0);	-- 0 to 1023 (only counts 0 to 805)

	signal	charVert: STD_LOGIC_VECTOR(4 DOWNTO 0); 		-- 0 to 31
	signal	charScanLine: STD_LOGIC_VECTOR(2 DOWNTO 0); 	-- 0 to 7
	signal	scanLineTriple : STD_LOGIC_VECTOR(1 DOWNTO 0); 	-- 0 to 3	(only counts 0 to 2)

	signal	charHoriz: STD_LOGIC_VECTOR(5 DOWNTO 0); 		-- 0 to 63
	signal	charBit: STD_LOGIC_VECTOR(3 DOWNTO 0); 			-- 0 to 15
	
	subtype colour_index is integer range 0 to 15;			-- used as array index for colour table
	
	type	rgb4 is array(0 to 15, 0 to 2) of STD_LOGIC_VECTOR(3 DOWNTO 0);	-- array of colours. 8 foreground, 8 background, individual colour mask R4,G4,B4
	constant colour_table : rgb4 :=
	(
	(x"F",x"F",x"0"), -- yellow
	(x"F",x"0",x"0"), -- red
	(x"0",x"F",x"0"), -- green
	(x"9",x"C",x"0"), -- olive green	maybe 9,D,0?
	(x"0",x"0",x"F"), -- blue
	(x"C",x"0",x"F"), -- purple
	(x"8",x"C",x"F"), -- sky blue
	(x"F",x"F",x"F"), -- white
	
	(x"0",x"0",x"0"), -- black
	(x"0",x"0",x"0"),
	(x"0",x"0",x"0"),
	(x"0",x"0",x"0"),
	(x"0",x"0",x"0"),
	(x"0",x"0",x"0"),
	(x"0",x"0",x"0"),
	(x"0",x"0",x"0")
	);
	

begin
	
	dispAddr 	<= charVert & charHoriz;					-- linear screen.  ** change for C1P 32 column mode**
	colourAddr 	<= charVert & charHoriz;					-- linear screen.  ** change for C1P 32 column mode**
	charAddr 	<= dispData & charScanLine;					-- 8 x 8 chars
	HiresAddr   <= charVert & charScanLine & charHoriz;		-- 5 + 3 + 6 = 14 bits == 16Kb
	
	PROCESS (clk)
		
		variable  video_out		: std_logic;
		variable  hires_out		: std_logic;
		variable  pixel_out		: std_logic;
		variable  inverse		: std_logic;
		variable  curr_colour	: colour_index; 		-- 0 to 7
	
	BEGIN
		if rising_edge(clk) then
			IF horizCount < 1343 THEN
				horizCount <= horizCount + 1;
--				if (horizCount < 552) or (horizCount > 1064) then
				if (horizCount < 296) or (horizCount > 1319) then
					hActive <= '0';
					charHoriz <= (others => '0');
				else
					hActive <= '1';
				end if;
			else
				horizCount <= (others => '0');
				pixelCount <= (others => '0');
				charHoriz  <= (others => '0');
				if vertLineCount > 804 then
					vertLineCount <= (others => '0');
				else
					if vertLineCount < 35 or vertLineCount > 802 then
						vActive <= '0';
						charVert <= (others => '0');
						charScanLine <= (others => '0');
						scanLineTriple <= (others => '0');
					else
						vActive <= '1';
						if scanLineTriple = 2 then						-- make every vertical pixel repeat 3 times
							if charScanLine = 7 then
								charScanLine <= (others => '0');
								charVert <= charVert + 1;
							else
								if vertLineCount /= 35 then
									charScanLine <= charScanLine + 1;
								end if;
							end if;
							scanLineTriple <= (others => '0');
						else
							scanLineTriple <= scanLineTriple + 1;
						end if;
					end if;
					vertLineCount <=vertLineCount + 1;
				end if;
			END IF;
			
			-- sync control
			if horizCount < 136 then
				hSync <= '0';
			else
				hSync <= '1';
			end if;
			if vertLineCount < 6 then
				vSync <= '0';
			else
				vSync <= '1';
			end if;
			
			-- video out
			if hActive='1' and vActive = '1' then
				curr_colour := to_integer(unsigned(colourData(3 downto 1)));				-- ** bits 7 : 4 for future expansion **
				inverse		:= colourData(0);												-- reverse colour scheme

				-- determine video out for 64 and 32 bit modes				
				if mode64 = '1' then
--					video_out 	:= charData(7-to_integer(unsigned(pixelCount(3 downto 1)))); 	-- UK101 reversed byte order
					video_out 	:= charData(to_integer(unsigned(pixelCount(3 downto 1))));		-- OSI
					hires_out 	:= HiresData(to_integer(unsigned(pixelCount(3 downto 1))));		-- OSI Hires
					if pixelCount = 15 then
						charHoriz <= charHoriz + 1;
						pixelCount <= (others => '0');
					else
						pixelCount <= pixelCount + 1;
					end if;
				else
--					video_out 	:= charData(7-to_integer(unsigned(pixelCount(4 downto 2)))); 	-- UK101 reversed byte order
					video_out 	:= charData(to_integer(unsigned(pixelCount(4 downto 2))));		-- OSI
					hires_out 	:= HiresData(to_integer(unsigned(pixelCount(4 downto 2))));		-- OSI Hires
					if pixelCount = 31 then
						charHoriz <= charHoriz + 1;
						pixelCount <= (others => '0');
					else
						pixelCount <= pixelCount + 1;
					end if;
				end if;
				
				-- select TEXT, HIRES, or MIXED
				
				if hires_enbl = '1' then
					if hires_mix = '1' then
						pixel_out := hires_out or video_out;		-- hires + text mix
					else
						pixel_out := hires_out;						-- hires only
					end if;				
				else
					pixel_out := video_out;							-- text only
				end if;
				
				-- Map pixels to colour guns
				
				if colour_enbl = '1' then								-- colour out
					if inverse = '0' then								-- black text on colour backbround
						if pixel_out = '1' then
							red		<= (others => '0'); 
							green	<= (others => '0'); 
							blue	<= (others => '0'); 
						else
							red		<= colour_table(curr_colour,0);
							green	<= colour_table(curr_colour,1);
							blue	<= colour_table(curr_colour,2);
						end if;			
					else												-- colour text on black backbround
						if pixel_out = '1' then
							red		<= colour_table(curr_colour,0);
							green	<= colour_table(curr_colour,1);		-- green
							blue	<= colour_table(curr_colour,2);
						else
							red		<= (others => '0'); 
							green	<= (others => '0'); 
							blue	<= (others => '0'); 
						end if;			
					end if;
				else 										-- monochrome (green screen)
					if pixel_out = '1' then
						red		<= colour_table(2,0);
						green	<= colour_table(2,1);		-- green
						blue	<= colour_table(2,2);
					else
						red		<= (others => '0'); 
						green	<= (others => '0'); 
						blue	<= (others => '0'); 
					end if;			
				end if;
			else
				red		<= (others => '0'); -- blank video out
				green	<= (others => '0'); 
				blue	<= (others => '0'); 
			end if;

			-- register outputs
			h_sync	<= hSync;
			v_sync	<= vSync;
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

-- Horiz:

--    0    136     296   (1024 visible)      1319   1343
--     SYNC    BP               VID              FP
--          --------|-------------------------|-------
--          |                                        |
--          |                                        |
-- HS -------                                        - etc.

-- Vert:

--    0     6       35     (768 visible)     802    805
--     SYNC    BP               VID              FP
--          --------|-------------------------|-------
--          |                                        |
--          |                                        |
-- HS -------                                        - etc.


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



