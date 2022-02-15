----------------------------------------------------------------------------------
-- Company: 
-- Engineer:       JASON NEUS
-- 
-- Create Date:    09:42:54 02/13/2022 
-- Design Name:    "HIGH" CPLD
-- Module Name:    MAIN_HIGH - Behavioral 
-- Project Name:   N2630
-- Target Devices: XC9572 64 PIN
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: MUCH OF THIS LOGIC AND COMMENTS ARE LIFTED STRAIGHT FROM THE PAL LOGIC FROM DAVE HAYNIE 
--                      (THANKS DAVE! HOPE YOU ARE DOING WELL.)
--                      EDITS FOR THE N2630 PROJECT MADE BY JASON NEUS
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity MAIN_HIGH is
    Port ( 
	 
		FC : IN STD_LOGIC_VECTOR (2 downto 0); --FCn FROM 68030
		AL : IN STD_LOGIC_VECTOR (6 downto 1); --ADDRESS BUS BITS 6..1
		AH : IN STD_LOGIC_VECTOR (23 downto 13); --ADDRESS BUS BITS 23..16
		CPUCLK : IN STD_LOGIC; --68030 CLOCK
		nAS : IN STD_LOGIC; --680x0 ADDRESS STROBE
		nDS : IN STD_LOGIC; --680x0 DATA STROBE
		RnW : IN STD_LOGIC; --680x0 READ/WRITE
		nBGACK : IN STD_LOGIC; --AMIGA BUS GRANT ACK
		nSENSE : IN STD_LOGIC; --6888x PRESENCE
		--EXTSEL : IN STD_LOGIC; --IS THE EXPANSION RAM SELECTED?
		OSMODE : IN STD_LOGIC; --HIGH FOR AMIGA OS, LOW FOR UNIX
		--PHANTOMHI : IN STD_LOGIC; --PHANTOM HI DATA
		--PHANTOMLO : IN STD_LOGIC; --PHANTOM LO DATA
		nBOSS : IN STD_LOGIC; --ARE WE BOSS?
		nCPURESET : IN STD_LOGIC; --RESET FOR THE 68030
		RESENB : IN STD_LOGIC; -- RESET ENABLED
		AUTO : IN STD_LOGIC; --SHOULD I AUTOCONFIG?
		--ROMCONF : IN STD_LOGIC; --ROM HAS BEEN CONFIGURED
		--RAMCONF : IN STD_LOGIC; --RAM HAS BEEN CONFIGURED
		
	 
		DAC : INOUT STD_LOGIC_VECTOR (31 downto 28):= "ZZZZ"; --DATA BUS FOR THE AUTOCONFIG PROCESS
		CONFIGED : INOUT STD_LOGIC; --HAS AUTOCONFIG COMPLETED?
		nRESET : INOUT STD_LOGIC; --QUALIFIED SYSTEM RESET SIGNAL 
		--nROMCLK : INOUT STD_LOGIC; --CLOCK FOR U303
	 
	 	nFPUCS : OUT STD_LOGIC; --FPU CHIP SELECT
		nBERR : OUT STD_LOGIC; --BUS ERROR
		nCIIN : OUT STD_LOGIC; --68030 CACHE ENABLE
		nAVEC : OUT STD_LOGIC; --AUTO VECTORING
		nCSROM : OUT STD_LOGIC --ROM CHIP SELECT		
		--nRAMCLK : OUT STD_LOGIC --CLOCK FOR U302
		
		
		);
		
end MAIN_HIGH;

architecture Behavioral of MAIN_HIGH is

	----------------------
	-- INTERNAL SIGNALS --
	----------------------
	
	--All internal signals are active HIGH!
	SIGNAL baseaddress : STD_LOGIC_VECTOR ( 2 downto 0 ):="000"; --BASE ADDRESS ASSIGNED FOR 2630
	SIGNAL baseaddress_ZORRO2RAM : STD_LOGIC_VECTOR ( 2 downto 0 ):="000"; --BASE ADDRESS ASSIGNED FOR ZORRO 2 RAM
	SIGNAL baseaddress_ZORRO3RAM : STD_LOGIC_VECTOR ( 2 downto 0 ):="000"; --BASE ADDRESS ASSIGNED FOR ZORRO 3 RAM
	--SIGNAL baseramaddress : STD_LOGIC_VECTOR ( 2 downto 0 ):="000"; --BASE ADDRESS ASSIGNED FOR ZORRO 2 RAM SPACE
	SIGNAL autoconfigspace : STD_LOGIC:='0'; --ARE WE IN THE AUTOCONFIG ADDRESS SPACE?
	SIGNAL chipram : STD_LOGIC:='0';
	SIGNAL ciaspace : STD_LOGIC:='0';
	SIGNAL chipregs : STD_LOGIC:='0';
	SIGNAL iospace	 : STD_LOGIC:='0';
	SIGNAL userdata : STD_LOGIC:='0';
	SIGNAL superdata : STD_LOGIC:='0';
	SIGNAL interruptack : STD_LOGIC:='0';
	SIGNAL cpuspace : STD_LOGIC:='0';
	SIGNAL coppercom : STD_LOGIC:='0';
	SIGNAL mc68881 : STD_LOGIC:='0';
	
	SIGNAL D_2630 : STD_LOGIC_VECTOR ( 3 downto 0 ):="0000";
	SIGNAL D_ZORRO2RAM : STD_LOGIC_VECTOR ( 3 downto 0 ):="0000";
	SIGNAL D_ZORRO3RAM : STD_LOGIC_VECTOR ( 3 downto 0 ):="0000";
	SIGNAL autoconfigcomplete_2630 : STD_LOGIC := '0'; --HAS 68030 BOARD BEEN AUTOCONFIGed?
	SIGNAL autoconfigcomplete_ZORRO2RAM : STD_LOGIC := '0'; --HAS 68030 BOARD BEEN AUTOCONFIGed?
	SIGNAL autoconfigcomplete_ZORRO3RAM : STD_LOGIC := '0'; --HAS 68030 BOARD BEEN AUTOCONFIGed?
	
	SIGNAL icsrom : STD_LOGIC:='0';
	SIGNAL hirom : STD_LOGIC:='0';
	SIGNAL lorom : STD_LOGIC:='0';
	--SIGNAL addr : STD_LOGIC_VECTOR( 23 downto 15 ) := (others => '0'); --CONNECTED TO 68030 ADDRESS BUS
	--SIGNAL readcycle : STD_LOGIC:='0';
	--SIGNAL romaddr : STD_LOGIC := '0';
	--SIGNAL ramaddr : STD_LOGIC := '0';
	--SIGNAL writecycle : STD_LOGIC := '0';
	--SIGNAL csauto : STD_LOGIC := '0';
	--SIGNAL icsauto : STD_LOGIC:='0';
	
	
	SIGNAL EXTSEL : STD_LOGIC:='0'; --THIS IS A TEMPORARY MEASURE UNTIL WE IMPLEMENT THE EXPANSION MEMORY
	                                --THIS ALLOWS ME TO IMPLEMENT THE LOGIC WITHOUT ACTUALLY CONNECTING ANYTHING
	

begin

	----------------------------
	-- INTERNAL SIGNAL DEFINE --
	----------------------------

	--field cpuaddr	= [A23..13] ;			/* Normal CPU space stuff */
	chipram <= '1' WHEN AH(23 downto 13) >= "00000000000" AND AH(23 downto 13) <= "00011111111"  ELSE '0';
	--chipram		= (cpuaddr:[000000..1fffff]) ;    /* All Chip RAM */
	--busspace	= (cpuaddr:[200000..9fffff]) ;    /* Main expansion bus */
	ciaspace <= '1' WHEN AH(23 downto 13) >= "10100000000" AND AH(23 downto 13) <= "10111111111" ELSE '0';
	--ciaspace	= (cpuaddr:[a00000..bfffff]) ;    /* VPA decode */
	--extraram	= (cpuaddr:[c00000..cfffff]) ;    /* Motherboard RAM */
	chipregs <= '1' WHEN AH(23 downto 13) >= "11010000000" AND AH(23 downto 13) <= "11011111111" ELSE '0';
	--chipregs	= (cpuaddr:[d00000..dfffff]) ;    /* Custom chip registers */
	iospace <= '1' WHEN AH(23 downto 13) >= "11101000000" AND AH(23 downto 13) <= "11101111111" ELSE '0';
	--iospace		= (cpuaddr:[e80000..efffff]) ;    /* I/O expansion bus */
	--romspace	= (cpuaddr:[f80000..ffffff]) ;    /* All ROM */
	
	--field spacetype	= [A19..16] ;
	--interruptack	= (spacetype:f0000) ;
	--coppercom	= (spacetype:20000) ;
	--breakpoint	= (spacetype:00000) ;
	interruptack <= '1' WHEN AH( 19 downto 16 ) = "1111" ELSE '0';
	coppercom <= '1' WHEN AH( 19 downto 16 ) = "0010" ELSE '0';
	mc68881 <= '1' WHEN AH( 15 downto 13 ) = "001" ELSE '0';
	
	userdata	<= '1' WHEN FC( 2 downto 0 ) = "001" ELSE '0'; --(cpustate:1)
	superdata <= '1' WHEN FC( 2 downto 0 ) = "101" ELSE '0'; --(cpustate:5)
	cpuspace <= '1' WHEN FC(2 downto 0) = "111" ELSE '0'; --(cpustate:7)
	
	--addr <= AH( 23 downto 15 );
	--Low memory ROM space, used for mapping of ROMs on reset.
	lorom <= '1' WHEN AH( 23 downto 15 ) >= "000000000" AND AH( 23 downto 15 ) <= "111111111" ELSE '0'; --addr:[000000..00ffff]
	--High memory rom space, where ROMs normally reside when available.
	hirom <= '1' WHEN AH( 23 downto 15 ) >= "111110000" AND AH( 23 downto 15 ) <= "111110001" ELSE '0'; --addr:[f80000..f8ffff]	
	--icsrom		= hirom & !PHANHI & readcycle		# lorom & !PHANLO & readcycle;
	--icsrom <= '1' WHEN ( hirom = '1' AND PHANTOMHI = '0' AND readcycle = '1' ) OR ( lorom = '1' AND PHANTOMLO = '0' AND readcycle = '1' ) ELSE '0';
	icsrom <= '1' WHEN ( hirom = '1' AND RnW = '1' AND nAS = '0' ) OR ( lorom = '1' AND RnW = '1' AND nAS = '0' ) ELSE '0';
	--romaddr		= addr:40;
	--romaddr <= '1' WHEN AL(6 downto 1) = "100000" ELSE '0'; --01000000
	--ramaddr		= addr:48;
	--ramaddr <= '1' WHEN AL(6 downto 1) = "100100" ELSE '0'; --01001000
	
	
	--readcycle <= '1' WHEN RnW = '1' AND nAS = '0' ELSE '0';
	
	--CSAUTO		= icsauto		# CSAUTO & AS;
	--csauto <= '1' WHEN ( icsauto = '1' ) OR ( csauto = '0' AND nAS = '0') ELSE '0';
	--writecycle	= CSAUTO & !PRW & DS & !CPURESET;
	--writecycle <= '1' WHEN csauto = '1' AND RnW = '0' AND nDS ='0' AND nCPURESET = '1' ELSE '0';
	
	--This is the basic autoconfig chip select logic.  The special register
	--always shows up first, the standard RAM register doesn't show up if 
	--we're inhibiting autoconfiguration.

	--icsauto		= autocon & AS & !RAMCONF &  AUTO 		# autocon & AS & !ROMCONF & !AUTO;
	--icsauto <= '1' WHEN ( autoconfigspace = '1' AND nAS = '0' AND RAMCONF = '0' AND AUTO = '1' ) OR ( autoconfigspace = '1' AND nAS = '0' AND ROMCONF = '0' AND AUTO = '0' ) ELSE '0';



	----------------
	-- AUTOCONFIG --
	----------------

	--We have three boards we need to autoconfig, in this order
	--1. The 68030 board itself with BOOT ROM
	--2. The 68030 base memory (up to 8MB) without BOOT ROM in the Zorro 2 space
	--3. The expansion memory (up to 112MB) in the Zorro 3 space	

	--A good explaination of the autoconfig process is given in the Amiga Hardware Reference Manual from Commodore
	--https://archive.org/details/amiga-hardware-reference-manual-3rd-edition	
	
	--ARE WE IN THE AUTOCONFIG ADDRESS SPACE?
	
	autoconfigspace <= '1'
		WHEN 
			AH(23 downto 16) = "11101000" AND nAS = '0' --x"E8" & 0000 hexadecimal 
		ELSE
			'0';	

	--THIS CODE BASICALLY DUMPS THE AUTOCONFIG DATA ON TO D(31..28) DEPENDING ON WHAT WE ARE AUTOCONFIGing	
	DAC(31 downto 28) <= 
		D_2630 WHEN autoconfigcomplete_2630 = '0' AND autoconfigspace ='1' AND CONFIGED = '0' ELSE
		D_ZORRO2RAM WHEN autoconfigcomplete_ZORRO2RAM = '0' AND autoconfigspace ='1' AND CONFIGED = '0' ELSE
		D_ZORRO3RAM WHEN autoconfigcomplete_ZORRO3RAM = '0' AND autoconfigspace ='1' AND CONFIGED = '0' ELSE
		"ZZZZ";
		
			
	--Here it is in all its glory...the AUTOCONFIG sequence
	PROCESS ( CPUCLK, nRESET ) BEGIN
		IF nRESET = '0' THEN
			CONFIGED <= '0';
			baseaddress <= "000";
			baseaddress_ZORRO2RAM <= "000";
			baseaddress_ZORRO3RAM <= "000";
		ELSIF ( FALLING_EDGE (CPUCLK)) THEN
			IF ( autoconfigspace = '1' AND CONFIGED = '0' ) THEN
				IF ( RnW = '1' ) THEN
				
					CASE AL(6 downto 1) IS

						--offset $00
						WHEN "000000" => 
							D_ZORRO2RAM <= "1110"; --er_type: Zorro 2 card without BOOT ROM

						--offset $02
						WHEN "000001" => 
							D_ZORRO2RAM <= "0111"; --er_type: 4MB

						--offset $04
						WHEN "000010" => 
							D_ZORRO2RAM <= "1010"; --Product Number Hi Nibble, we are stealing the A2630 product number

						--offset $06
						WHEN "000011" => 
							D_ZORRO2RAM <= "1000"; --Product Number Lo Nibble				

						--offset $08
						WHEN "000100" => 
							D_ZORRO2RAM <= "0010"; --er_flags: I/O device, can't be shut up, reserved, reserved

						--offset $0A
						--WHEN "000101" => D(31 downto 28) <= "0000"; --er_flags: Reserved, must be zeroes

						--offset $0C
						--THE A2630 CONFIGURES THIS NIBBLE AS "1000" WHEN UNIX, "0000" WHEN AMIGA OS
						WHEN "000110" => 
							D_2630 <= NOT OSMODE & "000"; 
							D_ZORRO2RAM <= "0000"; --Reserved: must be zeroes				

						--offset $0E
						--WHEN "000111" => D(31 downto 28) <= "0000"; --Reserved: must be zeroes	

						--offset $10
						WHEN "001000" => 
							D_ZORRO2RAM <= "0100"; --Product Number, high nibble hi byte. Just for fun, lets put C= in here!

						--offset $12
						--WHEN "001001" => D(31 downto 28) <= "0000"; --Product Number, low nibble hi byte. Just for fun, lets put C= in here!

						--offset $14
						--WHEN "001010" => D(31 downto 28) <= "0000"; --Product Number, high nibble low byte. Just for fun, lets put C= in here!

						--offset $16
						WHEN "001011" => 
							D_ZORRO2RAM <= "0100"; --Product Number, low nibble low byte. Just for fun, lets put C= in here!

						--offset $18
						--WHEN "001100" => D(31 downto 28) <= "0000"; --Serial number byte 0 high nibble

						--offset $1A
						--WHEN "001101" => D(31 downto 28) <= "0000"; --Serial number byte 0 low nibble				

						WHEN OTHERS => 
							D_ZORRO2RAM <= "0000"; --Reserved offsets and unused offset values are all zeroes

					END CASE;
					
				--Is this one our base address? If yes, we are done with AUTOCONFIG
				ELSIF ( RnW = '0' AND nDS = '0' ) THEN	
				
					IF ( AL(6 downto 1) = "100100" ) THEN
					
						IF ( autoconfigcomplete_2630 = '0' ) THEN
							--BASE ADDRESS FOR THE 68030 BOARD
							baseaddress <= DAC(31 downto 29);
							--THE 68030 BOARD IS CONFIGED
							autoconfigcomplete_2630 <= '1'; 
						ELSIF ( autoconfigcomplete_ZORRO2RAM = '0' ) THEN
							--BASE ADDRESS FOR THE ZORRO 2 RAM
							baseaddress_ZORRO2RAM <= DAC(31 downto 29); 
							--THE ZORRO 2 RAM IS CONFIGED
							autoconfigcomplete_ZORRO2RAM <= '1'; 
						ELSIF ( autoconfigcomplete_ZORRO3RAM = '0' ) THEN
							--BASE ADDRESS FOR THE ZORRO 3 RAM
							baseaddress_ZORRO3RAM <= DAC(31 downto 29); 
							 --THE ZORRO 3 RAM IS CONFIGED
							autoconfigcomplete_ZORRO3RAM <= '1';
						END IF;
						
						IF ((AUTO = '0') OR autoconfigcomplete_ZORRO2RAM = '1') THEN
							--We always autoconfig the 2630 ROM, so do that no matter what
							--AUTO is driven by a jumper on the board, if it is logic 0, the user does not want to use the 
							--on board Zorro 2 RAM. Thus, we will stop after the 2630 ROM is autoconfiged.
							CONFIGED <= '1'; 
						END IF;
						
					END IF;			
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	---------------------
	-- ROM CHIP SELECT --
	---------------------
	
	--This is the basic ROM chip select logic.  We want ROM to pay attention
	--to the phantom signals, and only show up on reads.
	
	--CSROM		= icsrom;
	nCSROM <= '0' WHEN icsrom = '1' ELSE '1';
	
	------------------------
	-- 68030 CACHE ENABLE --
	------------------------
	
	--This is the cache control signal.  We want the cache enabled when we're
	--in memory, but it can't go for CHIP memory, since Agnus can also write
	--to that memory.  Expansion bus memory, $C00000 memory, and ROM are prime
	--targets for caching.  CHIP RAM, all chip registers, and the space we leave
	--aside for I/O devices shouldn't be cached.  This isn't prefect, as it's
	--certainly possible to place I/O devices in the normal expansion space, or
	--RAM in the I/O space.  Note that we always want to cache program, just not
	--always data.  The "wanna be cached" term doesn't fit, so here's the 
	--"don't wanna be cached" terms, with inversion. U306
	
	nCIIN <= '1' 
		WHEN
			(chipram = '1' AND ( userdata = '1' OR superdata = '1' ) AND EXTSEL = '0') OR
			--!CACHE = chipram & (userdata # superdata) & !EXTSEL
			(ciaspace = '1' AND EXTSEL = '0') OR
			--ciaspace & !EXTSEL
			(chipregs = '1' AND EXTSEL = '0') OR
			--chipregs & !EXTSEL
			(iospace = '1' AND EXTSEL = '0')
			--iospace & !EXTSEL
		ELSE
			'0';		

	-----------------------
	-- 6888x CHIP SELECT --
	-----------------------
	
	--This selects the 68881 or 68882 math chip, as long as there's no DMA 
	--going on.  If the chip isn't there, we want a bus error generated to 
	--force an F-line emulation exception.  Add in AS as a qualifier here
	--if the PAL ever turns out too slow to make FPUCS before AS.

	nFPUCS <= '0' WHEN ( cpuspace = '1' AND coppercom = '1' AND mc68881 = '1' AND nBGACK = '1' ) ELSE '1';

	nBERR <= '0' WHEN ( cpuspace = '1' AND coppercom = '1' AND mc68881 = '1' AND nBGACK = '1' AND nSENSE = '1' ) ELSE 'Z';
	
	--------------------
	-- AUTO VECTORING --
	--------------------
	
	--This forces all interrupts to be serviced by autovectoring.  None
	--of the built-in devices supply their own vectors, and the system is
	--generally incompatible with supplied vectors, so this shouldn't be
	--a problem working all the time.  During DMA we don't want any AVEC
	--generation, in case the DMA device is like a Boyer HD and doesn't
	--drive the function codes properly. U306

	--AVEC		= cpuspace & interruptack & !BGACK;
	nAVEC <= '0' WHEN (cpuspace = '1' AND interruptack = '1' AND nBGACK = '1') ELSE '1';
	
	
	-----------
	-- RESET --
	-----------
	
	--The RESET output feeds to the /RST signal from the A2000
	--motherboard.  Which in turn enables the assertion of the /BOSS
	--line when you're on a B2000.  Which in turn creates the
	--/CPURESET line.  Together these make the RESET output.	In
	--order to eliminate the glitch on RESET that this loop makes,
	--the RESENB input is gated into the creation of RESET.  What
	--this implies is that the 68020 can't reset the system until
	--we're RESENB, OK?.  Make sure to consider the effects of this
	--gated reset on any special use of the ROM configuration register.
	--Using JMODE it's possible to reset the ROM configuration register
	--under CPU control, but not if the RESENB line is negated.
	
	--RESET		= BOSS & CPURESET & RESENB;
	nRESET <= '0' WHEN nBOSS = '0' AND nCPURESET ='0' AND RESENB = '1' ELSE '1';


	---------------------------------
	-- CLOCKS FOR FF U302 AND U303 --
	---------------------------------
	
	--I DON'T KNOW...THIS ALL LOOKS LIKE AUTOCONFIG STUFF...I DON'T NEED THE AUTOCONFIG LOGIC...
	
	--ROMCLK		= writecycle & romaddr & !CONFIGED		# ROMCLK & DS;
	--nROMCLK <= '0' WHEN ( writecycle = '1' AND romaddr = '1' AND CONFIGED = '0' ) OR ( nROMCLK = '1' AND nDS = '0' ) ELSE '1';

	--RAMCLK		= writecycle & ramaddr & !ROMCLK		# !CPURESET & RAMCLK;	
	--nRAMCLK <= '0' WHEN ( writecycle = '1' AND ramaddr = '1' AND nROMCLK = '1' ) OR (nCPURESET = '1' AND nROMCLK = '1' ) ELSE '1';

end Behavioral;

