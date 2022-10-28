--This work is shared under the Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0) License
--https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
	
--You are free to:
--Share - copy and redistribute the material in any medium or format
--Adapt - remix, transform, and build upon the material

--Under the following terms:

--Attribution - You must give appropriate credit, provide a link to the license, and indicate if changes were made. 
--You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.

--NonCommercial - You may not use the material for commercial purposes.

--ShareAlike - If you remix, transform, or build upon the material, you must distribute your contributions under the 
--same license as the original.

--No additional restrictions - You may not apply legal terms or technological measures that legally restrict others 
--from doing anything the license permits.

----------------------------------------------------------------------------------
-- Engineer:       JASON NEUS
-- 
-- Create Date:    October 25, 2022 
-- Design Name:    N2630 U602 CPLD
-- Project Name:   N2630
-- Target Devices: XC95144 144 PIN
-- Tool versions: 
-- Description: INCLUDES LOGIC FOR ZORRO 3 AUTOCONFIG, ZORRO 3 SDRAM CONTROLLER, AND GAYLE IDE CONTROLLER
--
-- Hardware Revision: 2.2
-- Additional Comments: 
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

entity U602 is
    Port ( 
				A : IN  STD_LOGIC_VECTOR (31 DOWNTO 0);
				RnW : IN STD_LOGIC; --READ/WRITE SIGNAL FROM 680x0
				nAS : IN STD_LOGIC; --ADDRESS STROBE
				IORDY : IN STD_LOGIC; --IDE I/O READY
				INTRQ : IN STD_LOGIC; --IDE INTERUPT REQUEST
				--MODE68K : IN STD_LOGIC; --ARE WE IN 68000 MODE?
				CPUCLK : IN STD_LOGIC; --25MHz CPU CLOCK
				A7M : IN STD_LOGIC; --7MHz AMIGA CLOCK
				nRESET : IN STD_LOGIC; --SYSTEM RESET SIGNAL VALID IN 68000 AND 68030 MODE
				nGRESET : IN STD_LOGIC; --68030 ONLY RESET SIGNAL
				nIDEDIS : IN STD_LOGIC; --IDE DISABLE
				nZ3DIS : IN STD_LOGIC; --ZORRO 3 RAM DISABLE
				nDS : IN STD_LOGIC; --68030 DATA STROBE
				FC : IN STD_LOGIC_VECTOR (2 DOWNTO 0); --68030 FUNCTION CODES
				SIZ : IN STD_LOGIC_VECTOR (1 DOWNTO 0); --68030 TRANSFER SIZE SIGNALS
				nBGACK : IN STD_LOGIC; --680x0 BUS GRANT ACK
				RAMSIZE : IN STD_LOGIC_VECTOR (2 DOWNTO 0); --RAM SIZE JUMPERS
	    		--nCBREQ : IN STD_LOGIC; --68030 CACHE BURST REQUEST
				--nIO16 : IN STD_LOGIC; --IDE IO16 SIGNAL, NOT USED.
				
				D : INOUT  STD_LOGIC_VECTOR (31 DOWNTO 28);
				nMEMZ3 : OUT STD_LOGIC; --SIGNALS THE OTHER LOGIC THAT WE ARE RESPONDING TO THE RAM ADDRESS SPACE		
				nIDEACCESS : INOUT STD_LOGIC; --SIGNALS THE OTHER LOGIC THAT WE ARE RESPONDING TO THE IDE ADDRESS SPACE
				nINT2 : INOUT STD_LOGIC; --INT2 DRIVEN BY IDE INTRQ
				nDIOR : INOUT STD_LOGIC; --IDE READ SIGNAL
				nDIOW : INOUT STD_LOGIC; --IDE WRITE SIGNAL
				
				Z3CONFIGED : INOUT STD_LOGIC; --HAS ZORRO 3 RAM BEEN AUTOCONFIGed? ACTIVE HIGH				
				nCS0 : OUT STD_LOGIC; --IDE CHIP SELECT 0
				nCS1 : OUT STD_LOGIC; --IDE CHIP SELECT 1
				DA : OUT STD_LOGIC_VECTOR (2 DOWNTO 0); --IDE ADDRESS LINES
				IDEDIR : OUT STD_LOGIC; --IDE BUFFER DIRECTION
				nIDEEN : OUT STD_LOGIC; --IDE BUFFER ENABLE
				nIDERST : OUT STD_LOGIC; --IDE RESET
				
				--nDSACK0 : OUT STD_LOGIC; --68030 ASYNC PORT SIZE SIGNAL
				nDSACK1 : INOUT STD_LOGIC; --68030 ASYNC PORT SIZE SIGNAL
				--nDTACK : OUT STD_LOGIC; --68000 DATA SIGNAL
				nUUBE : OUT STD_LOGIC; --68030 DYNAMIC BUS SIZING OUTPUT
				nUMBE : OUT STD_LOGIC; --68030 DYNAMIC BUS SIZING OUTPUT
				nLMBE : OUT STD_LOGIC; --68030 DYNAMIC BUS SIZING OUTPUT
				nLLBE : OUT STD_LOGIC; --68030 DYNAMIC BUS SIZING OUTPUT
				EMA : OUT STD_LOGIC_VECTOR (12 DOWNTO 0); --ZORRO 3 MEMORY BUS
				BANK0 : OUT STD_LOGIC; --SDRAM BANK0
				BANK1 : OUT STD_LOGIC; --SDRAM BANK1
				nEMCAS : OUT STD_LOGIC; --CAS LOW BANK
				nEMRAS : OUT STD_LOGIC; --RAS LOW BANK
				nEMWE : OUT STD_LOGIC; --WRITE ENABLE LOW BANK
				EMCLKE : OUT STD_LOGIC; --CLOCK ENABLE LOW BANK
				nEM0CS : OUT STD_LOGIC; --CHIP SELECT LOW BANK
				nEM1CS : OUT STD_LOGIC; --CHIP SELECT HIGH BANK
				nSTERM : INOUT STD_LOGIC --68030 SYNCRONOUS TERMINATION SIGNAL
	    		--nCBACK : OUT STD_LOGIC --68030 CACHE BURST ACK
				--nBERR : OUT STD_LOGIC; --BUS ERROR FOR BURST MODE
			);
end U602;

architecture Behavioral of U602 is
	
	--AUTOCONFIG SIGNALS
	SIGNAL Z3RAM_BASE_ADDR : STD_LOGIC_VECTOR(3 DOWNTO 0);	
	SIGNAL AUTOCONFIG_SPACE :STD_LOGIC; --ARE WE IN THE ZORRO 3 AUTOCONFIG ADDRESS SPACE?
	SIGNAL addr : STD_LOGIC_VECTOR (5 DOWNTO 0);
	
	-- DATA BUS SIGNALS
	SIGNAL DATAOUTAC : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => 'Z');
	--SIGNAL DATAOUT : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => 'Z');
	SIGNAL DATAOUTGAYLE : STD_LOGIC := 'Z';
	
	--IDE RELATED SIGNALS
	SIGNAL IDE_SPACE : STD_LOGIC; --ARE WE IN THE IDE BASE ADDRESS SPACE?
	SIGNAL idesacken : STD_LOGIC; --DSACK FOR THE IDE SPACE
	SIGNAL gayleregistered : STD_LOGIC; --HAS OUR GAYLE EMULATOR BEEN REGISTERED?
	SIGNAL gayle_space : STD_LOGIC; --ARE WE IN ANY OF THE GAYLE REGISTER SPACES?
	SIGNAL gayleid_space : STD_LOGIC;
	SIGNAL gaylereg_space : STD_LOGIC;
	SIGNAL ideintenable : STD_LOGIC; --IDE INTERRUPTS ENABLED
	SIGNAL intreq : STD_LOGIC; --TRACKS THE PREVIOUS STATE OF THE IDE INTERRUPT REQUEST
	SIGNAL intlast : STD_LOGIC; --TRACKS THE PREVIOUS STATE OF THE IDE INTERRUPT REQUEST
	SIGNAL CLRINT : STD_LOGIC; --HAS THE IDE INTERRUPT BEEN CLEARED?
	SIGNAL INTCHG : STD_LOGIC; --HAS THE IDE INTERRUPT CHANGED?
	SIGNAL GAYLEID : STD_LOGIC_VECTOR (3 DOWNTO 0) := "1101"; --THIS IS THE GAYLE ID VALUE
	SIGNAL idesackenabled : STD_LOGIC; --IS THE DSACK PROCESS ENABLED?

	--MEMORY SIGNALS
	SIGNAL MEMORY_SPACE : STD_LOGIC := '0'; --READY TO START RAM CYCLE?
	SIGNAL MEMSEL : STD_LOGIC := '0'; --ARE WE IN THE ZORRO 3 MEMORY SPACE?
	SIGNAL CS_MEMORY_SPACE : STD_LOGIC := '0'; --ARE WE IN THE UPPER SDRAM PAIR?
	SIGNAL COUNT : INTEGER RANGE 0 TO 2 := 0; --COUNTER FOR SDRAM STARTUP ACTIVITIES
	SIGNAL Z3RAM_CONFIGED : STD_LOGIC := '0'; --HAS ZORRO 3 RAM BEEN AUTOCONFIGed? ACTIVE HIGH
	SIGNAL ROWAD : STD_LOGIC_VECTOR (12 DOWNTO 0) := "0000000000000";
	SIGNAL BANKAD : STD_LOGIC_VECTOR (1 DOWNTO 0) := "00";
	SIGNAL COLAD : STD_LOGIC_VECTOR (9 DOWNTO 0) := "0000000000";
	SIGNAL datamask : STD_LOGIC_VECTOR (3 DOWNTO 0); --DATA MASK
	SIGNAL refresh : STD_LOGIC; --SIGNALS TIME TO REFRESH
	SIGNAL refreset : STD_LOGIC; --RESET THE REFRESH COUNTER
	SIGNAL REFRESH_COUNTER : INTEGER RANGE 0 TO 127 := 0;
	CONSTANT REFRESH_DEFAULT : INTEGER := 54; --7MHz REFRESH COUNTER
	SIGNAL memcycle : STD_LOGIC;
	SIGNAL sdramcom : STD_LOGIC_VECTOR (3 DOWNTO 0); --SDRAM COMMAND
	SIGNAL stermen : STD_LOGIC; --ENABLE _STERM
	
	--THE SDRAM COMMAND CONSTANTS ARE: _RAS, _CAS, _WE
	CONSTANT ramstate_NOP : STD_LOGIC_VECTOR (3 DOWNTO 0) := "1111"; --SDRAM NOP
	CONSTANT ramstate_PRECHARGE : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0010"; --SDRAM PRECHARGE ALL;
	CONSTANT ramstate_BANKACTIVATE : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0011";
	CONSTANT ramstate_READ : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0101";
	CONSTANT ramstate_WRITE : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0100";
	CONSTANT ramstate_AUTOREFRESH : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0001";
	CONSTANT ramstate_MODEREGISTER : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0000";	
	
	--DEFINE THE SDRAM STATE MACHINE STATES
	TYPE SDRAM_STATE IS ( PRESTART, POWERUP, POWERUP_PRECHARGE, MODE_REGISTER, AUTO_REFRESH, AUTO_REFRESH_CYCLE, RUN_STATE, RAS_STATE, CAS_STATE );	
	SIGNAL CURRENT_STATE : SDRAM_STATE;
	SIGNAL SDRAM_START_REFRESH_COUNT : STD_LOGIC := '0'; --WE NEED TO REFRESH TWICE UPON STARTUP	

begin

	---------------------
	-- DATA BUS OUTPUT --
	---------------------
	
	--WE ARE USING THE SAME DATA BITS IN SEVERAL PLACES.
	--THIS CREATES A SINGLE OUTPUT POINT, WHICH KEEPS EVERYTHING HAPPY
	--SIMULATES OK
	
	D(31 DOWNTO 28) <= 
			DATAOUTAC WHEN AUTOCONFIG_SPACE = '1' AND nAS = '0' AND RnW = '1'
		ELSE 
			DATAOUTGAYLE & "ZZZ" WHEN GAYLE_SPACE = '1' AND nAS = '0' AND RnW = '1'
		ELSE
			"ZZZZ"; 
	
	------------------------------------
	-- ASYNCHRONOUS DATA TRANSFER ACK --
	------------------------------------
	
	--THIS COVERS AUTOCONFIG AND IDE MEMORY SPACES.
	
	PROCESS (CPUCLK) BEGIN
	
		IF FALLING_EDGE (CPUCLK) THEN
			
			IF AUTOCONFIG_SPACE = '1' THEN
			
				--WE ARE IN THE AUTOCONFIG ADDRESS SPACE
				
				IF nAS = '0' THEN
				
					nDSACK1 <= '0';
					
				ELSE
				
					nDSACK1 <= '1';
					
				END IF;
					
			ELSIF gayle_space = '1' THEN
				
				IF nAS = '0' THEN
										
						nDSACK1 <= '0';
				ELSE
									
						nDSACK1 <= '1';
						
				END IF;
				
			ELSIF ide_space = '1' THEN
			
				IF idesacken = '1' OR nDSACK1 = '0' THEN
				
					nDSACK1 <= '0';
					
				ELSE
				
					nDSACK1 <= '1';
					
				END IF;
				
			ELSE
			
				nDSACK1 <= 'Z';
				
			END IF;
			
		END IF;
		
	END PROCESS;
	
	------------------------------------
	-- SYNCHRONOUS DATA TRANSFER ACK --
	------------------------------------
	
	--THIS COVERS THE ZORRO 3 SDRAM MEMORY SPACES.
	
	PROCESS (CPUCLK) BEGIN
	
		IF RISING_EDGE (CPUCLK) THEN
		
			IF MEMSEL = '1' THEN
		
				IF stermen = '1' OR nSTERM = '0' THEN
				
					nSTERM <= '0';
					
				ELSE
				
					nSTERM <= '1';
					
				END IF;
			
			ELSE
			
				nSTERM <= 'Z';
			
			END IF;				
			
		END IF;
		
	END PROCESS;		

	----------------
	-- AUTOCONFIG --
	----------------
	
	--WE AUTOCONFIG THE ZORRO 3 RAM (UP TO 256MB) HERE
	--BECAUSE THIS IS IN THE ZORRO 3 SPACE, AUTOCONFIG IS DIFFERENT THAN THE ZORRO 2 AUTOCONFIG FOUND IN U601.
	--THE ZORRO 3 AUTCONFIG SPACE IS AT ADDRESS $FF00xxxx
	--WE ONLY AUTOCONFIG IF THE 68030 IS NOT IN (G)RESET, THE USER WANTS IT, AND IT HAS NOT YET BEEN COMPLETED
	--WE AUTOCONFIG HERE BECAUSE THE ZORRO 3 RAM IS TECHNICALLY OPTIONAL.
	
	--SIGNAL U601 WHEN WE ARE DONE AUTOCONFIGing.
	--THIS IS EITHER AFTER WE HAVE AUTOCONFIGED OR THE USER HAS DISABLED THE Z3 RAM VIA J305.
	Z3CONFIGED <= '1' WHEN Z3RAM_CONFIGED = '1' OR nZ3DIS = '0' ELSE '0';
	
	--ARE WE IN THE Z3 AUTOCONFIG MEMORY SPACE?
	AUTOCONFIG_SPACE <= '1' WHEN A(31 DOWNTO 24) = x"FF" AND Z3CONFIGED = '0' ELSE '0';
	
	--MAP THE ADDRESS BITS FOR Z3 AUTOCONFIG.
	--MAPPING A8 AS A1 RESULTS IN THE BITS LINING UP THE SAME AS THEY WOULD IN Z2 AUTOCONFIG.
	addr <= A(6 DOWNTO 2) & A(8);
	
	PROCESS (CPUCLK, nGRESET) BEGIN
	
		--USING _GRESET HERE INSTEAD OF _RESET HOLDS THE ZORRO 3 RAM UNCONFIGURED
		--WHILE WE ARE IN 68000 MODE. NOT THAT IT WOULD CONFIGURE ANYHOW...
		
		IF nGRESET = '0' THEN
		
			Z3RAM_CONFIGED <= '0';
		
		ELSIF RISING_EDGE(CPUCLK) THEN
		
			--START ZORRO 3 AUTOCONFIG
			
			IF AUTOCONFIG_SPACE = '1' THEN
				
				IF RnW = '1' AND nAS = '0' THEN
					--READ REGISTERS
			
					CASE addr IS
					
						--$00
						WHEN "000000" => DATAOUTAC <= "1010"; --ZORRO 3 CARD
						
						--$02
						WHEN "000001" => DATAOUTAC <= "0011"; --256MB MAX
						
						--$04
						--WHEN "000010" => D(31 DOWNTO 28) <= "1111"; --PRODUCT NUMBER	
						
						--$06
						--WHEN "000011" => DATAOUTAC <= "1111";
						
						--WHEN "001001" => 
						--	D_ZORRO2RAM <= "1101"; --MANUFACTURER Number, high byte, low nibble hi byte. Just for fun, lets put C= in here!

						--offset $16 INVERTED
						--WHEN "001011" => 
						--	D_ZORRO2RAM <= "1101"; --MANUFACTURER Number, low nibble low byte. Just for fun, lets put C= in here!
						
						--$08
						--INVERTED
						WHEN "000100" => DATAOUTAC <= "0000"; --Mem device, can't be shut up.
						
						--$0A
						--INVERTED
						WHEN "000101" => DATAOUTAC <= "1100"; --AUTOSIZED BY THE OPERATING SYSTEM					
					
						--EVERYTHING ELSE
						WHEN OTHERS => DATAOUTAC <= "1111";
					
					END CASE;
					
					
					
				ELSIF addr = "100010" AND nDS = '0' THEN	
					--WRITE REGISTER
					
					--$FF000044
					--11111111000000000000000001000100.
					--THIS IS THE BASE ADDRESS OF THE Z3 RAM. SHOULD ALWAYS BE 0001?											

					Z3RAM_BASE_ADDR <= D(31 DOWNTO 28);
					Z3RAM_CONFIGED <= '1';
					
				END IF;										
					
			END IF;
					
		END IF;
	END PROCESS;

	---------------------
	-- GAYLE REGISTERS --
	---------------------
   
	---------------------------
	--WE ARE USING THE AMIGA OS GAYLE IDE INTERFACE SUPPORTING PIO WITH UP TO 2 DRIVES.
	--IT IS SIMPLE TO IMPLEMENT AND READY OUT OF THE BOX WITH KS => 37.300.
	--COMPATABILITY CAN BE ADDED TO EARLIER KICKSTARTS BY ADDING THE APPROPRIATE SCSI.DEVICE TO ROM.

	--TO TRICK AMIGA OS INTO THINKING WE HAVE A GAYLE ADDRESS DECODER, WE NEED TO RESPOND TO GAYLE SPECIFIC REGISTERS.
	--SEE THE GAYLE SPECIFICATIONS FOR MORE DETAILS.
	--WE DISABLE THE IDE PORT BY SIMPLY IGNORING THE GAYLE CONFIGURATION REGISTERS, WHICH TELLS AMIGA OS THERE IS NO GAYLE HERE.
	---------------------------
	
	--CHECKS IF THE CURRENT ADDRESS IS IN THE GAYLE REGISTER SPACE.
	gaylereg_space <= '1' WHEN A(23 DOWNTO 16) = x"DA" AND nIDEDIS = '1' ELSE '0';
	
	gayleid_space <= '1' WHEN A(23 DOWNTO 12) = x"DE1" AND nIDEDIS = '1' ELSE '0';
	
	gayle_space <= '1' WHEN gaylereg_space = '1' OR gayleid_space = '1' ELSE '0';	
	
	--GAYLE REGISTER PROCESS
	PROCESS (nDS, nGRESET) BEGIN
	
		IF nGRESET = '0' THEN
		
			ideintenable <= '0';
			gayleregistered <= '0';
	
		ELSIF (FALLING_EDGE (nDS)) THEN
			
			IF gayle_space = '1' AND nAS = '0' THEN
					
				IF gayleid_space = '1' THEN
				
					--11010000 = $D0 = ECS Gayle, 11010001 = $D1 = AGA Gayle
					--GAYLE_ID CONFIGURATION REGISTER IS AT $DE1000. WHEN ADDRESS IS $DE1000 AND R_W IS READ, BIT 7 IS READ.
					--BELOW IS A SIMPLE SHIFT REGISTER TO LOAD THE GAYLE ID VALUE, OF WHICH ONLY THE HIGH NIBBLE IS CONSIDERED.
					--IF $00 IS WRITTEN TO $DE1000, THAT MEANS THE REGISTER HAS BEEN RESET AND WE NEED TO RE-ESTABLISH GAYLE.
					
					IF (RnW = '1') THEN
						
						DATAOUTGAYLE <= GAYLEID(3);
						GAYLEID <= GAYLEID (2 DOWNTO 0) & GAYLEID(3);
						gayleregistered <= '1';
					
					END IF;	
					
				ELSE	--gaylereg_space
					
					CASE A(15 DOWNTO 12) IS
					
						--THE REGISTER AT $DAA000 ENABLES IDE INTERRUPTS AND IS SET BY AMIGA OS.					
						WHEN x"A" => 
						
							IF RnW = '0' THEN
								ideintenable <= D(31); --1 = ENABLE, 0 = DISABLE
							ELSE
								DATAOUTGAYLE <= ideintenable;
							END IF;		
						
						--THE REGISTER AT $DA8000 IDENTIFIES THE IDE DEVICE AS THE SOURCE OF THE IRQ.						
						WHEN x"8" =>
							
							IF RnW = '1' AND ideintenable = '1' THEN
								DATAOUTGAYLE <= intreq;
							END IF;											
						
						--WHEN THERE IS A NEW IDE IRQ, WE SET THIS TO '1'. AMIGA OS SETS TO '0' WHEN IT IS DONE HANDLING THE IRQ.
						WHEN x"9" =>

							IF RnW = '1' THEN
								DATAOUTGAYLE <= INTCHG;
							ELSE
								CLRINT <= NOT D(31);
							END IF;	
							
						WHEN OTHERS =>
						
							DATAOUTGAYLE <= 'Z';
						
					END CASE;
					
				END IF;
				
			END IF;
			
		END IF;
		
	END PROCESS;
	
	------------------------------------------------------
	-- GAYLE COMPATABLE HARD DRIVE CONTROLLER INTERFACE --
	------------------------------------------------------
	
	--THE FOLLOWING LOGIC HANDLES THE IDE INTERRUPT REQEUSTS.
	--WHEN INTRQ = '1', WE SIGNAL THE INTERRUPT REQUEST ON REGISTER $DA8000 AND $DA9000 AND ASSERT _INT2.
	--WHEN AMIGA OS IS DONE HANDLING THE REQUEST, IT NEGATES THE IDE INT ON $DA9000 AND WE THEN NEGATE _INT2.
	
	--PASS THE IDE DEVICE INTRQ SIGNAL TO _INT2 WHEN INTERRUPTS ARE ENABLED
	nINT2 <= '0' WHEN INTCHG = '1' AND ideintenable = '1' AND nIDEDIS = '1' ELSE 'Z';
	
	--GET THE CURRENT IDE INTERUPT STATE
	PROCESS (CPUCLK, nGRESET) BEGIN
	
		IF nGRESET = '0' THEN
		
			intreq <= '0';
			intlast <= '0';
			
		ELSIF RISING_EDGE (CPUCLK) THEN
		
			intreq <= INTRQ;
			intlast <= intreq;
			
		END IF;
		
	END PROCESS;
	
	--CHECK FOR A CHANGE IN THE IDE INTERRUPT SIGNAL
	PROCESS (CPUCLK, CLRINT) BEGIN
	
		IF CLRINT = '1' THEN
		
			INTCHG <= '0';
			
		ELSIF RISING_EDGE (CPUCLK) THEN
		
			IF intreq = '1' AND intlast = '0' THEN
			
				INTCHG <= '1';
				
			END IF;
			
		END IF;
		
	END PROCESS;
	
	--ARE WE IN THE ASSIGNED ADDRESS SPACE FOR THE IDE CONTROLLER?
	--GAYLE IDE CHIP SELECT ADDRESS SPACE IS $DA0000 - $DA3FFF. THE ADDRESS SPACE IS HARD CODED IN GAYLE.
	--SPACE $0DA4000 - $0DA4FFF IS IDE RESERVED. I FIND NO EVIDENCE IT WAS EVER IMPLEMENTED.
	--WE CONSIDER _BGACK BECAUSE WE DON'T WANT TO RESPOND TO DMA GENERATED ADDRESSES.
	
	--IDE_SPACE <= '1' WHEN (A(23 DOWNTO 12) >= x"DA0" AND A(23 DOWNTO 12) <= x"DA3") AND nAS = '0' AND nBGACK = '1' ELSE '0';	
	nIDEACCESS <= '0' WHEN gayleregistered = '1' AND gaylereg_space = '1' AND A(15 DOWNTO 12) < x"4" AND nBGACK = '1' ELSE '1';	
	ide_space <= '1' WHEN nIDEACCESS = '0' AND nAS = '0' ELSE '0';
	
	--ENABLE THE IDE BUFFERS
	nIDEEN <= '0' WHEN ide_space = '1' ELSE '0';
	
	--SETS THE DIRECTION OF THE IDE BUFFERS
	IDEDIR <= NOT RnW;
	
	--WE PASS THE COMPUTER RESET SIGNAL TO THE IDE DRIVE
	nIDERST <= nRESET;
	
	--GAYLE SPECS TELL US WHEN THE IDE CHIP SELECT LINES ARE ACTIVE
	
	nCS0 <= '0' WHEN A(12) = '0' AND ide_space = '1' ELSE '1';			
	nCS1 <= '0' WHEN A(12) = '1' AND ide_space = '1' ELSE '1';
	
	--READ/WRITE SIGNALS
	nDIOR <= '0' WHEN ide_space = '1' AND RnW = '1' ELSE '1';
	nDIOW <= '0' WHEN ide_space = '1' AND RnW = '0' AND nDS = '0' ELSE '1';
			
	--GAYLE EXPECTS IDE DA2..0 TO BE CONNECTED TO A4..2
	
	DA(0) <= A(2);
	DA(1) <= A(3);
	DA(2) <= A(4);	
	
	--GAYLE IDE CONTROLLER PROCESS
	PROCESS (CPUCLK, nGRESET) BEGIN
	
		IF (nGRESET = '0') THEN
		
			--AMIGA HAS RESET, START OVER
			--nDIOR <= '1';
			--nDIOW <= '1';
			idesacken <= '0';
			idesackenabled <= '0';
		
		ELSIF RISING_EDGE(CPUCLK) THEN			
		
			IF ide_space = '1' AND IORDY = '1' THEN			
				--WE ARE IN THE IDE ADDRESS SPACE 
				
--				IF RnW = '1' THEN
--				
--					--THIS IS A READ, WHICH CAN BE ASSERTED IMMEDIATELY
--					nDIOR <= '0';
--					
--				ELSE
--				
--					IF nDS = '0' THEN
--				
--						--THIS IS A WRITE, WHICH IS ASSERTED ONE CLOCK AFTER DATA STROBE
--						nDIOW <= '0';
--						
--					END IF;
--					
--				END IF;

--				IF IORDY = '1' THEN
				
					--IORDY IS ACTIVE HIGH BUT IS CALLED "_WAIT" IN THE GAYLE SPECS. 
					--WHEN HIGH, THE IDE DEVICE IS READY TO TRANSMIT OR RECEIVE DATA. 						
					--SIGNAL 16 BIT PORT TO 68030.
				
					--ACTIVATE THE nDSACK1 PROCESS ON THE FIRST TIME HERE. 
					--AFTER THAT, ALLOW THE PROCESS TO DO IT'S THING.
					IF idesackenabled = '0' THEN
					
						idesacken <= '1';
						
					ELSE
					
						idesacken <= '0';
						
					END IF;
					
					idesackenabled <= '1';
					
				--END IF;
					
			ELSE
			
				--SET IN A "NOP" STATE
				--nDIOR <= '1';
				--nDIOW <= '1';						
				idesackenabled <= '0';
					
			END IF;
		
		END IF;
	
	END PROCESS;
	
	---------------------------
	-- SDRAM REFRESH COUNTER --
	---------------------------
	
	--THE REFRESH OPERATION MUST BE PERFORMED 8192 TIMES EACH 64ms.
	--SO...8192 TIMES IN 64,000,000ns. THATS ONCE EVERY 7812.5ns.
	--7812.5ns IS EQUAL TO APPROX...
	
	--56 7.16MHz CLOCK CYCLES
	--185 25MHz CLOCK CYCLES
	--244 33MHz CLOCK CYCLES
	--296 40MHz CLOCK CYCLES
	--370 50MHz CLOCK CYCLES
	
	--WE USE THE 7MHz CLOCK TO DRIVE THE REFRESH COUNTER BECAUSE THAT 
	--WILL ALWAYS BE AVAILABLE NO MATTER OUR N2630 CONFIGURATION.
	--SINCE WE ARE JUMPING BETWEEN CLOCK DOMAINS, WE NEED TO HAVE
	--TWO PROCESSES TO ACCOMODATE THE JUMP.
	
	refreset <= '1' WHEN CURRENT_STATE = AUTO_REFRESH ELSE '0';
	
	PROCESS (A7M, refreset) BEGIN
	
		IF refreset = '1' THEN
		
			REFRESH_COUNTER <= 0;			
			
		ELSIF RISING_EDGE (A7M) THEN
		
			REFRESH_COUNTER <= REFRESH_COUNTER + 1;
			
		END IF;
		
	END PROCESS;
	
	
	PROCESS (CPUCLK, nGRESET) BEGIN
	
		IF nGRESET = '0' THEN
		
			refresh <= '0';
			
		ELSIF RISING_EDGE (CPUCLK) THEN
		
			IF REFRESH_COUNTER >= REFRESH_DEFAULT THEN
			
				refresh <= '1';
				
			ELSE
			
				refresh <= '0';
				
			END IF;
			
		END IF;
		
	END PROCESS;	

	------------------------------
	-- ZORRO 3 MEMORY CONTROLER --
	------------------------------
	
	--EXTSEL IS A SIGNAL THAT PREVENTS 68K STATE MACHINE ACTIVITIES IN U600. 
	--THERE ARE TWO INSTANCES ON THIS CPLD THAT WE ARE CONCERNED ABOUT. Z3 MEMORY OR IDE ACCESS.
	--THIS SHOULD NOT CONSIDER ADDRESS STROBE BECAUSE IT MAY ASSERT TOO LATE.
	--THE ADDRESS SPACES ARE, IN THIS ORDER, 16MB, 32MB, 64MB, 128MB, 256MB.
	
	--ZORRO 3 MEMORY MAP
	--$10000000 IS THE BASE ADDRESS
	
	--109876543210987654321098765432 10 ADDRESS BITS	
	--000100000000000000000000000000 00 $10000000
	
	MEMSEL <= '1' 
		WHEN 
			Z3RAM_CONFIGED = '1' AND FC(2 DOWNTO 0) /= "111" AND A(31 DOWNTO 28) = Z3RAM_BASE_ADDR			 
			--FC(2 DOWNTO 0) /= "111" AND A(31 DOWNTO 28) = "0001"
		ELSE 			 
			'0';	
	
	--SIGNAL U601 THAT WE ARE ACCESSING THE ZORRO 3 MEMORY
	nMEMZ3 <= NOT MEMSEL;
	
	--ARE WE ACCESSING THE Z3 MEMORY?
	MEMORY_SPACE <= '1' 
		WHEN 
			MEMSEL = '1' AND nAS = '0'
		ELSE 
			'0';
			
	--HERE WE DETERMINE WHERE WE ARE DIRECTING THE CHIP SELECT SIGNALING AND
	--THE ADDRESS LINES NEEDED FOR THE DIFFERENT SDRAM CONFIGURATIONS OF THE Z3 SDRAM.
	--THESE ARE DRIVEN BY JUMPERS SET BY THE USER THAT ALLOW US TO MAKE DECISIONS WITH THAT INFORMATION.
			
	PROCESS (CPUCLK) BEGIN
		IF RISING_EDGE(CPUCLK) AND MEMORY_SPACE = '1' THEN	
				
				CASE RAMSIZE (2 DOWNTO 0) IS
					
--					WHEN "111" => --16MB 2Mx16
--						CS_MEMORY_SPACE <= '0';
--						ROWAD <= "00" & A(12 DOWNTO 2);
--						BANKAD <= A(14 DOWNTO 13);
--						COLAD <= "00" & A(22 DOWNTO 15);
--						
--					WHEN "010" => --32MB BOTH MEMORY BANKS POPULATED 2Mx16
--						CS_MEMORY_SPACE <= A(23);
--						ROWAD <= "00" & A(12 DOWNTO 2);
--						BANKAD <= A(14 DOWNTO 13);
--						COLAD <= "00" & A(22 DOWNTO 15);
--
--					WHEN "110" => --32MB 4Mx16
--						CS_MEMORY_SPACE <= '0';
--						ROWAD <= "0" & A(13 DOWNTO 2);
--						BANKAD <= A(15 DOWNTO 14);
--						COLAD <= "00" & A(23 DOWNTO 16);
--						
--					WHEN "001" => --64MB BOTH MEMORY BANKS POPULATED 4Mx16
--						CS_MEMORY_SPACE <= A(24);
--						ROWAD <= "0" & A(13 DOWNTO 2);
--						BANKAD <= A(15 DOWNTO 14);
--						COLAD <= "00" & A(23 DOWNTO 16);
--						
--					WHEN "101" => --64MB 8Mx16
--						CS_MEMORY_SPACE <= '0';
--						ROWAD <= "0" & A(13 DOWNTO 2);
--						BANKAD <= A(15 DOWNTO 14);
--						COLAD <= "0" & A(24 DOWNTO 16);
--							
--					WHEN "000" => --128MB BOTH MEMORY BANKS POPULATED 8Mx16
--						CS_MEMORY_SPACE <= A(25);
--						ROWAD <= "0" & A(13 DOWNTO 2);
--						BANKAD <= A(15 DOWNTO 14);
--						COLAD <= "0" & A(24 DOWNTO 16);
						
					WHEN "100" => --128MB 16Mx16
						CS_MEMORY_SPACE <= '0';
						COLAD <= A(11 DOWNTO 2);
						ROWAD <= "0" & A(23 DOWNTO 12);						
						BANKAD <= A(25 DOWNTO 24);
							
					WHEN "011" => --256MB BOTH MEMORY BANKS POPULATED 16Mx16
						CS_MEMORY_SPACE <= A(27);
						COLAD <= A(11 DOWNTO 2);
						ROWAD <= A(24 DOWNTO 12);						
						BANKAD <= A(26 DOWNTO 25);

					WHEN OTHERS => 
						--IF WE DON'T RECOGNIZE THE CONFIGURATION, TRY TO GO WITH 8MB.
						CS_MEMORY_SPACE <= '0';
						COLAD <= "00" & A(9 DOWNTO 2);
						ROWAD <= "00" & A(20 DOWNTO 10);							
						BANKAD <= A(22 DOWNTO 21);
								
				END CASE;				
		
		END IF;
	END PROCESS;	
	
	-----------------------------
	-- SDRAM DATA MASK ACTIONS --
	-----------------------------		
		
	nUUBE <= datamask(3);
	nUMBE <= datamask(2);
	nLMBE <= datamask(1);
	nLLBE <= datamask(0);	
	
	PROCESS ( CPUCLK, nGRESET ) BEGIN
	
		IF nGRESET = '0' THEN 
		
			datamask <= "1111";
		
		ELSIF ( RISING_EDGE (CPUCLK) ) THEN

			IF MEMORY_SPACE = '1' THEN		

				IF RnW = '0' THEN
				
					--FOR WRITES, WE ENABLE THE VARIOUS BYTES ON THE SDRAM DEPENDING 
					--ON WHAT THE ACCESSING DEVICE IS ASKING FOR. DISCUSSION OF PORT 
					--SIZE AND BYTE SIZING IS ALL IN SECTION 12 OF THE 68030 USER MANUAL
					--WE ALSO INCLUDE BYTE SELECTION FOR DMA.
					
					--UPPER UPPER BYTE ENABLE (D31..24)
					IF 
						A(1 downto 0) = "00"
					THEN			
						datamask(3) <= '0'; 
					ELSE 
						datamask(3) <= '1';
					END IF;

					--UPPER MIDDLE BYTE (D23..16)
					IF 
						(A(1 downto 0) = "01") OR
						(A(1) = '0' AND SIZ(0) = '0') OR
						(A(1) = '0' AND SIZ(1) = '1')
					THEN
						datamask(2) <= '0';
					ELSE
						datamask(2) <= '1';
					END IF;

					--LOWER MIDDLE BYTE (D15..8)
					IF 
						(A(1 downto 0) = "10") OR
						(A(1) = '0' AND SIZ(0) = '0' AND SIZ(1) = '0') OR
						(A(1) = '0' AND SIZ(0) = '1' AND SIZ(1) = '1') OR
						(A(0) = '1' AND A(1) = '0' AND SIZ(0) = '0')
					THEN
						datamask(1) <= '0';
					ELSE
						datamask(1) <= '1';
					END IF;

					--LOWER LOWER BYTE (D7..0)
					IF 
						(A(1 downto 0) = "11") OR
						(A(0) = '1' AND SIZ(0) = '1' AND SIZ(1) = '1') OR
						(SIZ(0) = '0' AND SIZ(1) = '0') OR
						(A(1) = '1' AND SIZ(1) ='1')
					THEN
						datamask(0) <= '0';
					ELSE
						datamask(0) <= '1';
					END IF;	
				
				ELSE
				
					--FOR READS, WE RETURN ALL 32 BITS
					datamask <= "0000";
					
				END IF;
				
			ELSE
			
				datamask <= "1111";

			END IF;	
			
		END IF;
		
	END PROCESS;
	
	
	---------------------------
	-- SDRAM COMMAND ACTIONS --
	---------------------------	
	
	--THE SDRAM CHIP SELECT SIGNALS ARE FOR THE TWO PAIRS OF Z3 SDRAM. IN THE EVENT WE HAVE ONLY ONE PAIR IN 
	--THE LOW BANK, _EM0CS IS ALWAYS ASSERTED EXCEPT IN THE EVENT OF A NOP COMMAND. WHEN THERE ARE TWO PAIRS, 
	--THE UPPER OR LOWER PAIR IS SELECTED BASED ON THE MOST SIGNIFICANT ADDRESS BIT FOR READ/WRITE COMMANDS.
	--WHEN PROGRAMMING THE REGISTER OR WHEN ISSUING A REFRESH COMMAND, BOTH PAIRS ARE ASSERTED SIMULTANEOUSLY.
	
	nEM0CS <= CS_MEMORY_SPACE WHEN memcycle = '1' AND sdramcom(3) = '0' ELSE '0' WHEN memcycle = '0' AND sdramcom(3) = '0' ELSE '1';
	nEM1CS <= NOT CS_MEMORY_SPACE WHEN memcycle = '1' AND sdramcom(3) = '0' ELSE '0' WHEN memcycle = '0' AND sdramcom(3) = '0' ELSE '1';	
	
	--THE SDRAM COMMANDS
	
	nEMRAS <= sdramcom(2);
	nEMCAS <= sdramcom(1);	
	nEMWE <= sdramcom(0);	
	
	--THE SDRAM STATE MACHINE
	
	PROCESS ( CPUCLK, nGRESET ) BEGIN
	
		IF (nGRESET = '0') THEN 
		
				--THE AMIGA HAS BEEN RESET OR JUST POWERED UP
				CURRENT_STATE <= PRESTART;				
				sdramcom <= ramstate_NOP;				
				SDRAM_START_REFRESH_COUNT <= '0';
				memcycle <= '0';
				
				EMCLKE <= '0';
						
				COUNT <= 0;
				stermen <= '0';
				
				EMA(12 DOWNTO 0) <= (OTHERS => '0');
				BANK0 <= '0';
				BANK1 <= '0';
		
		ELSIF ( FALLING_EDGE (CPUCLK) ) THEN
			
			--SDRAM is pretty fast. Most operations will complete in less than one 50MHz clock cycle. 
			--Only AUTOREFRESH takes more than one clock cycle at 60ns. 			
		
			--PROCEED WITH SDRAM STATE MACHINE
			--THE FIRST STATES ARE TO INITIALIZE THE SDRAM, WHICH WE ALWAYS DO.
			--THE LATER STATES ARE TO UTILIZE THE SDRAM, WHICH ONLY HAPPENS IF nMEMZ2 IS ASSERTED.
			--THIS MEANS THE ADDRESS STROBE IS ASSERTED, WE ARE IN THE ZORRO 2 ADDRESS SPACE, AND THE RAM IS AUTOCONFIGured.
			CASE CURRENT_STATE IS
			
				WHEN PRESTART =>
					--SET THE POWERUP SETTINGS SO THEY ARE LATCHED ON THE NEXT CLOCK EDGE
				
					CURRENT_STATE <= POWERUP;
					sdramcom <= ramstate_NOP;				
			
				WHEN POWERUP =>
					--First power up or warm reset

					CURRENT_STATE <= POWERUP_PRECHARGE;
					EMA(10 downto 0) <= ("10000000000"); --PRECHARGE ALL			
					sdramcom <= ramstate_PRECHARGE;
					EMCLKE <= '1';
					
				WHEN POWERUP_PRECHARGE =>
				
					CURRENT_STATE <= MODE_REGISTER;
					EMA(10 downto 0) <= "01000100000"; --PROGRAM THE SDRAM...NO READ OR WRITE BURST, CAS LATENCY=2
					sdramcom <= ramstate_MODEREGISTER;
				
				WHEN MODE_REGISTER =>
				
					--TWO CLOCK CYCLES ARE NEEDED FOR THE REGISTER TO, WELL, REGISTER
					
					IF (COUNT = 0) THEN
						--NOP ON THE SECOND CLOCK DURING MODE REGISTER
						sdramcom <= ramstate_NOP;
					ELSE
						--NOW NEED TO REFRESH TWICE
						CURRENT_STATE <= AUTO_REFRESH;
						sdramcom <= ramstate_AUTOREFRESH;
					END IF;
					
					COUNT <= COUNT + 1;
					
				WHEN AUTO_REFRESH =>
					--REFRESH the SDRAM
					--MUST BE FOLLOWED BY NOPs UNTIL REFRESH COMPLETE
					--Refresh minimum time is 60ns. We must NOP enough clock cycles to meet this requirement.
					--50MHz IS 20ns PER CYCLE, 40MHz IS 24ns, 33 IS 30ns, 25MHz IS 40ns.
					--SO, 3 CLOCK CYCLES FOR 50 AND 40 MHz AND 2 CLOCK CYCLES FOR 33 AND 25 MHz.					
					
					--ADD A CLOCK CYCLE TO ACHIEVE THE MINIMIM REFRESH TIME OF 60ns
					--THIS IS REALLY ONLY NEEDED AT 40MHz AND GREATER, BUT WE COMPROMISE HERE
					--AND APPLY TO EVERYTHING.
					COUNT <= 0;
					
					CURRENT_STATE <= AUTO_REFRESH_CYCLE;
					sdramcom <= ramstate_NOP;
					
				WHEN AUTO_REFRESH_CYCLE =>
					
					IF (COUNT = 1) THEN 
						--ENOUGH CLOCK CYCLES HAVE PASSED. WE CAN PROCEED.
						
						IF (SDRAM_START_REFRESH_COUNT = '0') THEN		
							--DO WE NEED TO REFRESH AGAIN (STARTUP)?
						
							CURRENT_STATE <= AUTO_REFRESH;
							sdramcom <= ramstate_AUTOREFRESH;
							
							SDRAM_START_REFRESH_COUNT <= '1';
							
						ELSE
						
							--GO TO OUR IDLE STATE AND WAIT.
							CURRENT_STATE <= RUN_STATE;
							sdramcom <= ramstate_NOP;
							
						END IF;
						
					END IF;		

					COUNT <= COUNT + 1;						
				
				WHEN RUN_STATE =>
				
					IF (refresh = '1') THEN
				
						--TIME TO REFRESH THE SDRAM, WHICH TAKES PRIORITY.	
						CURRENT_STATE <= AUTO_REFRESH;					
						EMA(12 downto 0) <= ("0010000000000"); --PRECHARGE ALL
						sdramcom <= ramstate_AUTOREFRESH;					
					
					ELSIF MEMORY_SPACE = '1' THEN 
						
						CURRENT_STATE <= RAS_STATE;
						sdramcom <= ramstate_BANKACTIVATE;
						memcycle <= '1';
						
						EMA(12 downto 0) <= ROWAD;
						BANK0 <= BANKAD(0);
						BANK1 <= BANKAD(1);	
						
						IF RnW = '0' THEN
						
							--IF THIS IS A WRITE ACTION, WE CAN IMMEDIATELY ASSERT STERM
							stermen <= '1';
							
						END IF;							
						
					END IF;
					
				WHEN RAS_STATE =>	
					
					--BANK ACTIVATE
					--SET CAS STATE VALUES SO THEY LATCH ON THE NEXT CLOCK EDGE
					CURRENT_STATE <= CAS_STATE;
					
					EMA(12 downto 0) <= "001" & COLAD; --WITH AUTO PRECHARGE
					
					IF RnW = '0' THEN
						--WRITE STATE
						sdramcom <= ramstate_WRITE;
					ELSE
						--READ STATE
						sdramcom <= ramstate_READ;
					END IF;	
					
					COUNT <= 0;
					
				WHEN CAS_STATE =>
					
					--IF THIS IS A READ ACTION, THE CAS LATENCY IS 2 CLOCK CYCLES.
					
					--WE NOP FOR THE REMAINING CYCLES.
					sdramcom <= ramstate_NOP;
					
					--IF _STERM IS NOT ENABLED FROM A 68030 WRITE CYCLE, ENABLE IT NOW.
					IF stermen = '0' AND COUNT = 0 THEN
					
						stermen <= '1';						
						
					ELSE
					
						stermen <= '0';
						
					END IF;
					
					--IF WE ARE NO LONGER IN THE ZORRO 3 MEM SPACE, GO BACK TO START.
					IF MEMORY_SPACE = '0' THEN					
											
						CURRENT_STATE <= RUN_STATE;	
						memcycle <= '0';						
						
					END IF;	
					
					COUNT <= 1;
				
			END CASE;
				
		END IF;
	END PROCESS;
	
end Behavioral;
