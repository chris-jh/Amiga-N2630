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
-- Create Date:    SEPTEMBER 19, 2022 
-- Design Name:    N2630 U601 CPLD
-- Project Name:   N2630 https://github.com/jasonsbeer/Amiga-N2630
-- Target Devices: XC95144 144 PIN
-- Tool versions: 
-- Description: INCLUDES LOGIC FOR ZORRO 2 AUTOCONFIG, ZORRO2 SDRAM CONTROLLER, AND GENERAL GLUE LOGIC
--
-- Revision: 2.2
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

entity U601 is

PORT
(

	RnW : IN STD_LOGIC; --680x0 READ/WRITE
	CPUCLK : IN STD_LOGIC; --68030 CLOCK
	A : IN STD_LOGIC_VECTOR (23 DOWNTO 0); --680x0 ADDRESS LINES, ZORRO 2 ADDRESS SPACE
	nAS : IN STD_LOGIC; --68030 ADDRESS STROBE
	nAAS : IN STD_LOGIC; --68000 ADDRESS STROBE
	nDS : IN STD_LOGIC; --68030 DATA STROBE
	nRESET : IN STD_LOGIC; --AMIGA RESET SIGNAL
	nBGACK : IN STD_LOGIC; --AMIGA BUS GRANT ACK
	--nUDS : IN STD_LOGIC; --68000 UPPER DATA STROBE
	--nLDS : IN STD_LOGIC; --68000 LOWER DATA STROBE
	SIZ : IN STD_LOGIC_VECTOR (1 downto 0); --SIZE BUS FROM 68030
	FC : IN STD_LOGIC_VECTOR (2 downto 0); --68030 FUNCTION CODES
	OSMODE : IN STD_LOGIC; --J304 UNIX/AMIGA OS
	nCPURESET : IN STD_LOGIC; --68030 RESET SIGNAL
	nHALT : IN STD_LOGIC; --68030 HALT
	Z2AUTO : IN STD_LOGIC; --J303 ZORRO 2 DISABLE
	DROM : IN STD_LOGIC_VECTOR (20 DOWNTO 16); --THIS IS FOR THE ROM SPECIAL REGISTER
	nMEMZ3 : IN STD_LOGIC; --ZORRO 3 RAM IS RESPONDING TO THE ADDRESS (WAS EXTSEL)
	nSENSE : IN STD_LOGIC; --68882 SENSE
	Z3CONFIGED : IN STD_LOGIC; --IS ZORRO 3 RAM CONFIGURED?	
	nIDEACCESS : IN STD_LOGIC; --IDE IS RESPONDING TO THE ADDRESS SPACE
	nBOSS : IN STD_LOGIC; --BOSS SIGNAL
	--A7M : IN STD_LOGIC; --AMIGA 7MHZ CLOCK
	
	nMEMZ2 : INOUT STD_LOGIC; --ARE WE ACCESSING ZORRO 2 RAM ADDRESS SPACE
	CONFIGED : INOUT STD_LOGIC; --ARE WE AUTOCONFIGED?
	D : INOUT STD_LOGIC_VECTOR (31 DOWNTO 28); --68030 DATA BUS
	nCSROM : INOUT STD_LOGIC; --ROM CHIP SELECT
	
	SMDIS : INOUT STD_LOGIC := '1'; --STATE MACHINE DISABLE (WAS nONBOARD)
	nFPUCS : OUT STD_LOGIC; --FPU CHIP SELECT
	nBERR : OUT STD_LOGIC; --BUS ERROR
	nCIIN : OUT STD_LOGIC; --68030 CACHE ENABLE
	nAVEC : OUT STD_LOGIC; --AUTO VECTORING
	MODE68K : OUT STD_LOGIC; --ARE WE IN 68000 MODE?	
	ZBANK0 : OUT STD_LOGIC := '1'; --BANK0 SIGNAL
	ZBANK1 : OUT STD_LOGIC := '1'; --BANK1 SIGNAL
	CLKE : OUT STD_LOGIC := '0'; --SDRAM CLOCK ENABLE
	ZMA : OUT STD_LOGIC_VECTOR (12 downto 0) := (OTHERS => '0'); --Z2 SDRAM ADDRESS BUS
	nZCS : OUT STD_LOGIC := '1'; --SDRAM CHIP SELECT
	nZWE : OUT STD_LOGIC := '1'; --SDRAM WRITE ENABLE
	nZCAS : OUT STD_LOGIC := '1'; --SDRAM CAS
	nZRAS : OUT STD_LOGIC := '1'; --SDRAM RAS
	nUUBE : OUT STD_LOGIC := '1'; --UPPER UPPER BYTE ENABLE
	nUMBE : OUT STD_LOGIC := '1'; --UPPER MIDDLE BYTE ENABLE
	nLMBE : OUT STD_LOGIC := '1'; --LOWER MIDDLE BYTE ENABLE
	nLLBE : OUT STD_LOGIC := '1'; --LOWER LOWER BYTE ENABLE
	nDTACK : OUT STD_LOGIC := 'Z'; --68000 DTACK FOR DMA
	nDSACK0 : INOUT STD_LOGIC := 'Z'; --68030 DSACK
	nDSACK1 : OUT STD_LOGIC := 'Z';
	nOVR : OUT STD_LOGIC := 'Z'; --DTACK OVERRIDE
	EMDDIR : OUT STD_LOGIC; --DIRECTION OF MEMORY DATA BUS BUFFERS
	nEMENA : OUT STD_LOGIC; --ENABLE THE MEMORY DATA BUS BUFFERS
	AADIR : OUT STD_LOGIC; --ADDRESS BUS BUFFER DIRECTION
	nAAENA : OUT STD_LOGIC --ADDRESS BUS BUFFER ENABLE

);

end U601;

architecture Behavioral of U601 is
	
	--MEMORY ACCESS SIGNALS
	SIGNAL dmaaccess : STD_LOGIC := '0'; --ARE WE IN A DMA MEMORY CYCLE?
	SIGNAL cpuaccess : STD_LOGIC := '0'; --ARE WE IN A CPU MEMORY CYCLE?
	SIGNAL dsacken : STD_LOGIC := '0'; --FEEDS THE 68030 DSACK SIGNALS
	SIGNAL datamask : STD_LOGIC_VECTOR (3 DOWNTO 0) := "1111"; --DATA MASK
	SIGNAL sdramcom : STD_LOGIC_VECTOR (3 DOWNTO 0) := "1111"; --SDRAM COMMAND
	
	--THE SDRAM COMMAND CONSTANTS ARE: _CS, _RAS, _CAS, _WE
	CONSTANT ramstate_NOP : STD_LOGIC_VECTOR (3 DOWNTO 0) := "1111"; --SDRAM NOP
	CONSTANT ramstate_PRECHARGE : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0010"; --SDRAM PRECHARGE ALL;
	CONSTANT ramstate_BANKACTIVATE : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0011";
	CONSTANT ramstate_READ : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0101";
	CONSTANT ramstate_WRITE : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0100";
	CONSTANT ramstate_AUTOREFRESH : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0001";
	CONSTANT ramstate_MODEREGISTER : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0000";
	
	--ADDRESS SPACES
	SIGNAL memaccess : STD_LOGIC := '0';
	SIGNAL onboard : STD_LOGIC := '0';
	
	--68030 FUNCTION CODES
	--SIGNAL userdata : STD_LOGIC:='0';
	--SIGNAL superdata : STD_LOGIC:='0';	
	--SIGNAL cpuspace : STD_LOGIC:='0';
	
	--INTERRUPT
	--SIGNAL interruptack : STD_LOGIC:='0';
	
	--FPU SIGNALS
	SIGNAL coppercom : STD_LOGIC:='0';
	SIGNAL mc68881 : STD_LOGIC:='0';
	
	--DEFINE THE SDRAM STATE MACHINE 
	TYPE SDRAM_STATE IS ( PRESTART, POWERUP, POWERUP_PRECHARGE, MODE_REGISTER, AUTO_REFRESH_PRECHARGE, AUTO_REFRESH, AUTO_REFRESH_CYCLE, RUN_STATE, RAS_STATE, CAS_STATE ); 
	SIGNAL CURRENT_STATE : SDRAM_STATE; --CURRENT SDRAM STATE
	SIGNAL SDRAM_START_REFRESH_COUNT : STD_LOGIC := '0'; --WE NEED TO REFRESH TWICE UPON STARTUP
	SIGNAL COUNT : INTEGER RANGE 0 TO 2 := 0; --COUNTER FOR SDRAM STARTUP ACTIVITIES
	SIGNAL refresh : STD_LOGIC := '0'; --SIGNALS TIME TO REFRESH
	SIGNAL REFRESH_COUNTER : INTEGER RANGE 0 TO 255 := 0;
	CONSTANT REFRESH_DEFAULT : INTEGER := 180; --25MHz REFRESH COUNTER 185

	--AUTOCONFIG SIGNALS
	SIGNAL autoconfigspace : STD_LOGIC := '0'; --AUTOCONFIG ADDRESS SPACE
	SIGNAL romconfiged : STD_LOGIC := '0'; --HAS THE ROM BEEN AUTOCONFIGED?
	SIGNAL ramconfiged : STD_LOGIC := '0'; --HAS THE Z2 RAM BEEN AUTOCONFIGED?
	SIGNAL boardconfiged : STD_LOGIC := '0'; --HAS THE ROM AND Z2 RAM FINISHED CONFIGURING?
	SIGNAL D_ZORRO2RAM : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0000"; --Z2 AUTOCONFIG DATA
	SIGNAL D_2630 : STD_LOGIC_VECTOR (3 DOWNTO 0) := "0000"; --ROM AUTOCONFIG DATA
	SIGNAL regreset : STD_LOGIC := '0'; --REGISTER RESET 
	SIGNAL jmode : STD_LOGIC := '0'; --JMODE
	SIGNAL phantomlo : STD_LOGIC := '0'; --PHANTOM LOW SIGNAL
	SIGNAL phantomhi : STD_LOGIC := '0'; --PHANTOM HIGH SIGNAL
	SIGNAL hirom : STD_LOGIC := '0'; --IS THE ROM IN THE HIGH ADDRESS SPACE?
	SIGNAL lorom : STD_LOGIC := '0'; --IS THE ROM IN THE LOW ADDRESS SPACE?
	CONSTANT rambaseaddress0 : STD_LOGIC_VECTOR (2 DOWNTO 0) := "100"; --RAM BASE ADDRESS	
	CONSTANT rambaseaddress1 : STD_LOGIC_VECTOR (2 DOWNTO 0) := "001"; --RAM BASE ADDRESS
	
	--ROM RELATED SIGNALS
	CONSTANT DELAYVALUE : INTEGER := 1;
	SIGNAL dsackdelay : STD_LOGIC_VECTOR ( DELAYVALUE DOWNTO 0 ) := (OTHERS => '0') ; --DELAY DSACK CYCLE
	
begin

	---------------------------
	-- MEMORY DATA DIRECTION --
	---------------------------
	
	--This sets the direction of the LVC data buffers between the 680x0 and the RAM
	--We simply go with the inverse of the RW signal.
	EMDDIR <= NOT RnW;
	
	--ENABLE/DISABLE THE SDRAM BUFFERS
	nEMENA <= '0' WHEN nMEMZ3 = '0' OR nMEMZ2 = '0' ELSE '1';
	
	---------------------
	-- ADDRESS BUFFERS --
	---------------------
	
	--THE AMIGA ADDRESS BUFFERS CONTROL THE FLOW OF THE ADDRESS BUS.
	--WHEN WE ARE BOSS, THE DATA FLOWS FROM THE 2630 TO THE AMIGA 2000.
	--WHEN WE ARE BOSS AND IN A DMA CYCLE, THE DATA FLOWS FROM THE AMIGA 2000 TO THE 2630.
	--WHEN IN 68K MODE, THE DATA FLOWS FROM THE AMIGA 2000 TO THE 2630.
	
	--THE ADDRESS BUFFER DIRECTION
	--AADIR <= '1' WHEN (nBOSS = '0' AND nBGACK = '1') ELSE '0';
	AADIR <= nBGACK;	
	
	--ENABLE THE ADDRESS BUFFERS WHEN WE ARE BOSS OR WHEN WE ARE IN 68K MODE.
	--LOOKING AT THE LOGIC BELOW, WE BASICALLY NEVER DISABLE THE BUFFERS.
	--THIS MEANS WE COULD TIE IT TO GROUND?
	--nAAENA <= '0' WHEN nBOSS = '0' OR MODE68K = '1' ELSE '1'; 
	nAAENA <= nBOSS;
	
	---------------------------
	-- SDRAM REFRESH COUNTER --
	---------------------------
	
	--The refresh operation must be performed 8192 times within 64ms.
	--SO...8192 TIMES IN 64,000,000ns. THATS ONCE EVERY 7812.5ns.
	--7812.5ns IS EQUAL TO APPROX...
	--56 7.16MHz CLOCK CYCLES
	--185 25MHz CLOCK CYCLES
	--244 33MHz CLOCK CYCLES
	--296 40MHz CLOCK CYCLES
	--370 50MHz CLOCK CYCLES
	--WE USE THE 7MHz CLOCK TO DRIVE THE REFRESH COUNTER BECAUSE THAT 
	--WILL ALWAYS BE AVAILABLE NO MATTER OUR N2630 CONFIGURATION.
	
	PROCESS (CPUCLK, nRESET) BEGIN
	
		IF nRESET = '0' THEN
		
			REFRESH_COUNTER <= 0;
			
		ELSIF RISING_EDGE (CPUCLK) THEN
		
			REFRESH_COUNTER <= REFRESH_COUNTER + 1;
				
			IF CURRENT_STATE = AUTO_REFRESH THEN
			
				refresh <= '0';
				
			ELSIF refresh = '1' OR (REFRESH_COUNTER = REFRESH_DEFAULT) THEN
			
				refresh <= '1';
				REFRESH_COUNTER <= 0;
				
			END IF;
			
		END IF;
		
	END PROCESS;
	
	
	---------------
	-- RAM STUFF --
	---------------

	--EITHER THE 68030 OR DMA FROM THE ZORRO 2 BUS CAN ACCESS ZORRO 2 RAM ON OUR CARD
	--SIMULATES OK
	
	--THE 8MB DATA SPACE USES UP TO (AND INCLUDING) A21.
	--THIS MEANS WHEN 8MBs ARE INSTALLED, WE RESPOND WHEN A23..21 = BASEADDRESS.
	--WITH 4MBs INSTALLED, WE RESPOND WHEN A23..20 = BASEADDRESS.
	--WITH 2MBs INSTALLED, WE RESPOND WHEN A23..19 = BASEADDRESS.
	--WITH 1MB INSTALLED, WE RESPOND WHEN A23..18 = BASEADDRESS.
	
	--THIS DETECTS A 68030 MEMORY ACCESS
	cpuaccess <= '1' 
		WHEN
			--( A(23 DOWNTO 21) = "100" OR A(23 DOWNTO 21) = "011" OR A(23 DOWNTO 21) = "010" OR A(23 DOWNTO 21) = "001" ) AND
			A(23 DOWNTO 21) = "001" AND
			--ramconfiged = '1' AND
			nBGACK = '1' AND 
			FC(2 downto 0) /= "111"
		ELSE
			'0';
	
	--THIS DETECTS A DMA MEMORY ACCESS
	dmaaccess <= '1'
		WHEN
			( A(23 DOWNTO 21) = rambaseaddress0 OR A(23 DOWNTO 21) = rambaseaddress1 ) AND
			ramconfiged = '1' AND 
			nAAS = '0' AND 
			nBGACK = '0'
		ELSE
			'0';
			
	nMEMZ2 <= '0' 
		WHEN
			(cpuaccess = '1' AND nAS = '0' AND nMEMZ3 = '1') OR dmaaccess = '1'
		ELSE
			'1';
			
	--The OVR signal must be asserted whenever on-board memory is selected
	--during a DMA cycle.  It tri-states GARY's DTACK output, allowing
	--one to be created by our memory logic.

	nOVR <= '0' 
		WHEN 
			dmaaccess = '1' 
		ELSE 
			'Z';	
	
	-----------------------------
	-- SDRAM DATA MASK ACTIONS --
	-----------------------------		
		
	nUUBE <= datamask(3);
	nUMBE <= datamask(2);
	nLMBE <= datamask(1);
	nLLBE <= datamask(0);	
	
	PROCESS ( CPUCLK, nRESET ) BEGIN
	
		IF nRESET = '0' THEN 
		
			datamask <= "1111";
		
		ELSIF ( RISING_EDGE (CPUCLK) ) THEN

			IF (nMEMZ2 = '0') THEN		

				IF RnW = '0' THEN
				
					--FOR WRITES,
					--ENABLE THE VARIOUS BYTES ON THE SDRAM DEPENDING ON WHAT THE ACCESSING DEVICE IS ASKING FOR.
					--DISCUSSION OF PORT SIZE AND BYTE SIZING IS ALL IN SECTION 12 OF THE 68030 USER MANUAL
					--WE ALSO INCLUDE BYTE SELECTION FOR DMA.
					
					--UPPER UPPER BYTE ENABLE (D31..24)
					IF 
						(A(1 downto 0) = "00") --OR
						--(nBGACK = '0' AND nUDS = '0' AND A(1) = '1')
					THEN			
						datamask(3) <= '0'; 
					ELSE 
						datamask(3) <= '1';
					END IF;

					--UPPER MIDDLE BYTE (D23..16)
					IF 
						(A(1 downto 0) = "01") OR
						(A(1) = '0' AND SIZ(0) = '0') OR
						(A(1) = '0' AND SIZ(1) = '1') --OR
						--(nBGACK = '0' AND nLDS = '0' AND A(1) = '1') 
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
						(A(0) = '1' AND A(1) = '0' AND SIZ(0) = '0') --OR
						--(nBGACK = '0' AND nUDS = '0' AND A(1) = '0')
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
						(A(1) = '1' AND SIZ(1) ='1') --OR
						--(nBGACK = '0' AND nLDS = '0' AND A(1) = '0')
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
	
	--SDRAM COMMANDS ARE SAMPLED ON THE RISING EDGE. WE ARE SETTING COMMANDS ON THE 
	--FALLING EDGE SO THE COMMANDS ARE STABLE AT THE MOMENT THE SDRAM LATCHES THE COMMAND.
	--SDRAM COMMANDS ALL SIMULATE OK
	
	--SOMETHING OF NOTE...THE 68000 AND 68030 LATCH READ DATA ON THE FALLING EDGE,
	--WHILE THE DATA FROM THE SDRAM IS ONLY GUARANTEED TO BE VALID ON A SINGLE RISING EDGE.
	--THIS MEANS WE NEED TO DO "TRICKS" TO GET THE DATA INTO THE 680x0. 
	--INVERTING THE SDRAM CLOCK WOULD PROBABLY SIMPLIFY ALL OF THIS AND ALLOW US 
	--TO NOT USE "TRICKS".
	
	nZCS <= sdramcom(3);
	nZRAS <= sdramcom(2);
	nZCAS <= sdramcom(1);	
	nZWE <= sdramcom(0);	
	
	PROCESS ( CPUCLK, nRESET ) BEGIN
	
		IF (nRESET = '0') THEN 
		
				--THE AMIGA HAS BEEN RESET OR JUST POWERED UP
				CURRENT_STATE <= PRESTART;				
				sdramcom <= ramstate_NOP;				
				SDRAM_START_REFRESH_COUNT <= '0';					
				CLKE <= '0';
				COUNT <= 0;
				nDTACK <= 'Z';
				dsacken <= '0';
				
				ZMA(10 DOWNTO 0) <= (OTHERS => '0');
				ZBANK0 <= '0';
				ZBANK1 <= '0';
		
		ELSIF ( FALLING_EDGE (CPUCLK) ) THEN
			
			--WE CANNOT USE BURST MODE WITH Z2 RAM, WHICH ONLY WORKS WITH STERM TERMINATED ACTIONS.
			--ZORRO 2 RAM ACCESSES ARE ALL ASYNCHRONOUS.
			
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
					--200 microsecond is needed to stabilize. We are going to rely on the 
					--the system reset to give us the needed time, although it might be inadequate.

					CURRENT_STATE <= POWERUP_PRECHARGE;
					ZMA <= ("0010000000000"); --PRECHARGE ALL			
					sdramcom <= ramstate_PRECHARGE;
					CLKE <= '1';
					
				WHEN POWERUP_PRECHARGE =>
				
					CURRENT_STATE <= MODE_REGISTER;
					ZMA <= "0001000100000"; --PROGRAM THE SDRAM...NO READ OR WRITE BURST, CAS LATENCY=2
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
					
				WHEN AUTO_REFRESH_PRECHARGE =>
				
					--THE TIME BETWEEN PRECHARGE AND AUTOREFRESH WILL BE TIGHT AT 50MHz.
					--IT NEEDS 21ns BETWEEN THE TWO COMMANDS.
					CURRENT_STATE <= AUTO_REFRESH;
					sdramcom <= ramstate_AUTOREFRESH;
					
				WHEN AUTO_REFRESH =>
					--REFRESH the SDRAM
					--MUST BE FOLLOWED BY NOPs UNTIL REFRESH COMPLETE
					--Refresh minimum time is 60ns. We must NOP enough clock cycles to meet this requirement.
					--50MHz IS 20ns PER CYCLE, 40MHz IS 24ns, 33 IS 30ns, 25MHz IS 40ns.
					--SO, 3 CLOCK CYCLES FOR 50 AND 40 MHz AND 2 CLOCK CYCLES FOR 33 AND 25 MHz.					
					
					--ADD A CLOCK CYCLE TO ACHEIVE THE MINIMIM REFRESH TIME OF 60ns
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
				
					--MEMORY MAP 
					--3210987654321098765432 10 ADDRESS BITS
					
					--0010000000000000000000 00 $200000-$3FFFFF
					--0011111111111111111111 11

					--0100000000000000000000 00 $400000-$5FFFFF
					--0101111111111111111111 11

					--0110000000000000000000 00 $600000-$7FFFFF
					--0110111111111111111111 11

					--1000000000000000000000 00 $800000-$9FFFFF
					--1001111111111111111111 11
				
					IF (refresh = '1') THEN
				
						--TIME TO REFRESH THE SDRAM, WHICH TAKES PRIORITY.	
						CURRENT_STATE <= AUTO_REFRESH_PRECHARGE;					
						ZMA <= ("0010000000000"); --PRECHARGE ALL
						sdramcom <= ramstate_PRECHARGE;							
					
					ELSIF nMEMZ2 = '0' AND nDS = '0' THEN 
					
						--WE ARE IN THE Z2 MEMORY SPACE WITH THE ADDRESS AND DATA STROBES ASSERTED.
						--SEND THE BANK ACTIVATE COMMAND W/RAS
						
						CURRENT_STATE <= RAS_STATE;
						--ZMA(10 downto 0) <= A(12 downto 2);
						--ZBANK0 <= A(13);
						--ZBANK1 <= A(14);
						
						ZMA(10 downto 0) <= A(20 downto 10);
						ZBANK0 <= A(21);
						ZBANK1 <= A(22);
						
						sdramcom <= ramstate_BANKACTIVATE;
						
						--IF THIS IS A WRITE ACTION, WE CAN IMMEDIATELY ASSERT _DSACKx.
						--IF (RnW = '0') THEN
						
							--dsacken <= '1';
							
						--END IF;
						
					END IF;
					
				WHEN RAS_STATE =>	
					
					--BANK ACTIVATE
					--SET CAS STATE VALUES SO THEY LATCH ON THE NEXT CLOCK EDGE
					CURRENT_STATE <= CAS_STATE;
					
					--A7 IS THE MAX ADDRESS BIT FOR THE COLUMN SELECTION.
					ZMA(7 downto 0) <= A(9 downto 2);
					ZMA(8) <= '0';
					ZMA(9) <= '0';
					ZMA(10) <= '1'; --AUTO PRECHARGE
					
					IF RnW = '0' THEN
						--WRITE STATE
						sdramcom <= ramstate_WRITE;
						dsacken <= '1';
					ELSE
						--READ STATE
						sdramcom <= ramstate_READ;
					END IF;	
					
					--dsacken <= '1';
					--dsacken <= '0';
					COUNT <= 0;
					
				WHEN CAS_STATE =>
					
					--IF THIS IS A READ ACTION, THE CAS LATENCY IS 2 CLOCK CYCLES.
					
					--WE NOP FOR THE REMAINING CYCLES.
					sdramcom <= ramstate_NOP;
					
					--dsacken <= '0';	
					
					IF nMEMZ2 = '0' THEN
					
						IF RnW = '1' THEN
						
							--68030 CAN COMMIT ON THE NEXT FALLING CLOCK EDGE.
							--ASSERTING BOTH DSACKs TELLS THE 68030 THAT THIS IS A 32 BIT PORT.
							
							IF	COUNT = 0 THEN
							
								--SIGNAL _DSACKn BE ASSERTED THE FIRST TIME.
								dsacken <= '1';
								COUNT <= 1;
								
							ELSE
							
								--AFTERWARDS, ALLOW THE _DSACKn PROCEDURE TO DO IT'S THING.
								dsacken <= '0';
								CLKE <= '0';
								
							END IF;							
							
						ELSE
						
							dsacken <= '0';
							
						END IF;
							
					
					ELSE
					
						--THE ADDRESS STROBE HAS NEGATED INDICATING THE END OF THE MEMORY ACCESS.						
						CURRENT_STATE <= RUN_STATE;
						CLKE <= '1';
						
					END IF;	
				
			END CASE;
				
		END IF;
	END PROCESS;
	
	---------------------------
	-- A2630 ROM CHIP SELECT --
	---------------------------
	
	--THE ROM IS PLACED IN THE RESET VECTOR ($000000) WHEN THE SYSTEM FIRST STARTS/RESTARTS.
	--AT THAT TIME, THE ROM RESPONDS IN THE SPACE AT $000000 - $00FFFF.
	--THE ROM WILL STOP RESPONDING ONCE phantomlo IS SET = 1 AFTER CONFIGURATION.
	
	lorom <= '1' WHEN A(23 DOWNTO 16) = x"00" AND phantomlo = '0' AND RnW = '1' ELSE '0';
	
	--AFTERWARD, THE ROM IS THEN MOVED TO THE ADDRESS SPACE AT $F80000 - $F8FFFF.
	--THIS IS THE "NORMAL" PLACE FOR SYSTEM ROMS.
	--THE ROM WILL STOP RESPONDING ONCE phantomhi IS SET = 1 AFTER CONFIGURATION.
	
	--11111000
	hirom <= '1' WHEN A(23 DOWNTO 16) = x"F8" AND phantomhi = '0' AND RnW = '1' ELSE '0';
	
	--THE FINAL ROM CHIP SELECT SIGNAL
	nCSROM <= '0' WHEN (lorom = '1' OR hirom = '1') AND nAS = '0' ELSE '1';	
	
	---------------------------
	-- ROM DATA TRANSFER ACK --
	---------------------------
	
	--THIS IS FOR 16 BIT ROM ACCESS ASYNC CYCLES.
	
	PROCESS (CPUCLK) BEGIN
	
		IF RISING_EDGE (CPUCLK) THEN
			
			IF nCSROM = '0' THEN
				
				--WE ARE IN THE ONBOARD ROM ADDRESS SPACE.
				--THE 27C256 EPROM NEEDS 40-75ns TO STABILIZE DATA.
				--THIS DELAYS DSACK BY THE NUMBER OF CLOCKS DEFINED BY DELAYVALUE.
				--THE NUMBER OF CLOCK CYCLES TO ACHIEVE THE NEEDED WAIT TIME IS DETERMINED
				--BY THE CLOCK SPEED. WHEN DELAYVALUE = 1, THIS RESULTS IN A DELAY OF 
				--3 CLOCK CYCLES. THIS SHOULD BE GOOD FOR ANY SPEED, BUT IS A COMPROMISE.
				--SINCE THE ROM IS ONLY READ DURING INITIAL STARTUP, THIS SHOULD BE OK.
			
				IF dsackdelay(DELAYVALUE) = '1' THEN				
					
					--nDSACK0 <= '1';
					nDSACK1 <= '0';
				
				ELSIF dsackdelay(DELAYVALUE) = '0' THEN				
					
					--nDSACK0 <= '1';
					nDSACK1 <= '1';
					
					dsackdelay(0) <= '1';
					dsackdelay(DELAYVALUE DOWNTO 1) <= dsackdelay(DELAYVALUE-1 DOWNTO 0);
				
				END IF;	

			ELSIF autoconfigspace = '1' THEN
			
				--WE ARE IN THE AUTOCONFIG ADDRESS SPACE
				IF nAS = '0' THEN
				
					--nDSACK0 <= '1';
					nDSACK1 <= '0';
					
				ELSE
				
					--nDSACK0 <= '1';
					nDSACK1 <= '1';
					
				END IF;
				
			ELSIF cpuaccess = '1' THEN
			
				--WE ARE IN THE SDRAM ADDRESS SPACE	
				IF nAS = '0' AND (dsacken = '1' OR nDSACK0 = '0') THEN
			
					--ASSERT!
					nDSACK0 <= '0';
					nDSACK1 <= '0';
					
				ELSE
				
					--DON'T ASSERT AT THIS TIME.
					nDSACK0 <= '1';
					nDSACK1 <= '1';
					
				END IF;
				
			ELSE
			
				nDSACK0 <= 'Z';
				nDSACK1 <= 'Z';
				
				dsackdelay <= (OTHERS => '0');
				
			END IF;
		
		END IF;
		
	END PROCESS;
	
	---------------------------
	-- STATE MACHINE DISABLE --
	---------------------------
	
	--ASSERT SMDIS (STATE MACHINE DISABLE) WHENEVER WE ARE ACCESSING A RESOURCE
	--ON THE 2630 CARD. THIS INCLUDES ROM, AUTOCONFIG, IDE, ZORRO 2, OR ZORRO 3 
	--MEMORY SPACES. THIS PREVENTS THE 68000 STATE MACHINE FROM STARTING
	--DURING THOSE ACCESS PERIODS.
	
	onboard <= '1' WHEN hirom = '1' OR lorom = '1' OR autoconfigspace = '1' ELSE '0';
	memaccess <= '1' WHEN nIDEACCESS = '0' OR nMEMZ2 = '0' OR nMEMZ3 = '0' ELSE '0';	
	
	SMDIS <= '1' WHEN onboard = '1' OR memaccess = '1' ELSE '0';
	
	-------------------
	-- JOHANN'S MODE --
	-------------------

	--This is a special reset used to reset the ROM configuration registers.  If
   --JMODE (Johann's special mode) is active, we can reset the registers
   --with the CPU.  Otherwise, the registers can only be reset with a cold
   --reset asserted.
	
	PROCESS (CPUCLK) BEGIN
	
		IF RISING_EDGE(CPUCLK) THEN
			IF (jmode = '0' AND nHALT = '0' AND nRESET = '0') OR (jmode = '1' AND nRESET = '0') THEN
				regreset <= '1';
			ELSE
				regreset <= '0';
			END IF;
		END IF;
		
	END PROCESS;
	
	---------------------------------
	-- SPECIAL AUTOCONFIG REGISTER --
	---------------------------------
	
	--THE SPECIAL REGISTER FOR THE A2630 RESIDES AT $E80040, LOWER BYTE.
	--THIS IS USED FOR THE ROM AUTOCONFIG IN PLACE OF THE REGULAR AUTOCONFIG
	--WRITE REGISTER FOUND AT $E80048. THIS REGISTER MAY APPEAR MULTIPLE TIMES,
	--UNTIL ROMCONFIGED IS WRITTEN HIGH. OTHERWISE, THE AUTOCONFIG PROCESS
	--IS IDENTICAL TO ANY OTHER.
	
	--EVEN THOUGH THIS ISN'T WITH THE AUTOCONFIG STUFF, IT STILL
	--RESPONDS IN THE AUTOCONFIG SPACE, WITH _DSACK1 HANDLED THERE.
	
	PROCESS (CPUCLK, regreset) BEGIN
	
		IF (regreset = '1') THEN
		
			phantomlo <= '0';
			phantomhi <= '0';
			romconfiged <= '0';
			jmode <= '0';
			MODE68K <= '0';
	
		ELSIF FALLING_EDGE (CPUCLK) THEN
		
			IF (autoconfigspace = '1' AND A(6 downto 1) = "100000" AND RnW = '0' AND nDS = '0' AND nCPURESET = '1' AND romconfiged = '0') THEN
				phantomlo <= DROM(16);
				phantomhi <= DROM(17);
				romconfiged <= DROM(18);
				jmode <= DROM(19);
				MODE68K <= DROM(20);
			END IF;
			
		END IF;
		
	END PROCESS;
	
	----------------
	-- AUTOCONFIG --
	----------------
	
	--IS EVERYTHING WE WANT CONFIGURED?
	--THIS IS PASSED TO THE _COPCFG SIGNAL 
	--U602 WILL ASSERT Z3CONFIGED WHEN Z3 RAM HAS BEEN AUTOCONFIGed OR IF Z3 RAM IS DISABLED.
	CONFIGED <= '1' WHEN Z3CONFIGED = '1' AND boardconfiged = '1' ELSE '0';

	--We have three boards we need to autoconfig, in this order
	--1. The 68030 ROM (SEE ALSO SPECIAL REGISTER, ABOVE)
	--2. The base memory (8MB) in the Zorro 2 space
	--3. The expansion memory in the Zorro 3 space. This is done in U602.	

	--A good explaination of the autoconfig process is given in the Amiga Hardware Reference Manual from Commodore
	--https://archive.org/details/amiga-hardware-reference-manual-3rd-edition
			
	--BOARDCONFIGED IS ASSERTED WHEN WE ARE DONE CONFIGING THE ROM AND ZORRO 2 MEMORY
	--WHEN THE ZORRO 2 RAM IS DISABLED BY J303, IT SETS Z2AUTO = 0.
	boardconfiged <= '1' WHEN (romconfiged = '1' AND Z2AUTO = '0') OR (romconfiged = '1' AND ramconfiged = '1') ELSE '0';
	
	--WE ARE IN THE Z2 AUTOCONFIG ADDRESS SPACE ($E80000).
	--THIS IS QUALIFIED BY BOARDCONFIGED SO WE STOP RESPONDING TO THE AUTOCONFIG 
	--SPACE ONCE WE ARE COMPLETELY CONFIGURED.
	--11101000
	autoconfigspace <= '1'
		WHEN 
			A(23 downto 16) = x"E8" AND boardconfiged = '0'
		ELSE
			'0';				

	--THIS CODE ASSERTS THE AUTOCONFIG DATA ON TO D(31..28),
	--DEPENDING ON WHAT WE ARE AUTOCONFIGing.	
	--We AUTOCONFIG the 2630 FIRST, then the Zorro 2 RAM
	--SIMULATES OK
	
	D(31 downto 28) <= 
			D_2630
				WHEN romconfiged = '0' AND autoconfigspace = '1' AND RnW = '1' AND nAS = '0'
		ELSE
			D_ZORRO2RAM 
				WHEN autoconfigspace ='1' AND RnW = '1' AND nAS = '0'
		ELSE
			"ZZZZ";		
			
	--Here it is in all its glory...the AUTOCONFIG sequence
	PROCESS ( CPUCLK, nRESET ) BEGIN
	
		IF nRESET = '0' THEN
			
			--rambaseaddress0 <= "000";
			--rambaseaddress1 <= "000";
			ramconfiged <= '0';	
			
		ELSIF ( RISING_EDGE (CPUCLK)) THEN
		
			IF autoconfigspace = '1' THEN
			
				IF RnW = '1' AND nAS = '0' THEN
					--The 680x0 is reading from us
				
					CASE A(6 downto 1) IS

						--offset $00
						WHEN "000000" => 
							D_2630 <= "1110"; 
							D_ZORRO2RAM <= "1110"; --er_type: Zorro 2 card without BOOT ROM, LINK TO MEM POOL

						--offset $02
						WHEN "000001" => 
							D_2630 <= "0000"; --8MB
							D_ZORRO2RAM <= "0000"; --er_type: NEXT BOARD NOT RELATED, 8MB

						--offset $04 INVERTED
						WHEN "000010" => 
							D_2630 <= "1010";
							D_ZORRO2RAM <= "1010"; --Product Number Hi Nibble, we are stealing the A2630 product number

						--offset $06 INVERTED
						WHEN "000011" => 
							D_2630 <= "1110";
							D_ZORRO2RAM <= "1111"; --Product Number Lo Nibble
							
						--offset $08 INVERTED
						WHEN "000100" =>
							D_2630 <= "1111"; 
							D_ZORRO2RAM <= "1011"; --PREFER 8 MEG SPACE, CAN'T BE SHUT UP

						--offset $0C INVERTED						
						WHEN "000110" => 
							D_2630 <= OSMODE & "111"; --THE A2630 CONFIGURES THIS NIBBLE AS "0111" WHEN UNIX, "1111" WHEN AMIGA OS
							D_ZORRO2RAM <= "1111"; --Reserved: must be zeroes

						--offset $12 INVERTED
						WHEN "001001" => 
							D_2630 <= "1111";
							D_ZORRO2RAM <= "1101"; --MANUFACTURER Number, high byte, low nibble hi byte. Just for fun, lets put C= in here!

						--offset $16 INVERTED
						WHEN "001011" => 
							D_2630 <= "1111";
							D_ZORRO2RAM <= "1101"; --MANUFACTURER Number, low nibble low byte. Just for fun, lets put C= in here!

						WHEN OTHERS => 
							D_2630 <= "1111";
							D_ZORRO2RAM <= "1111"; --INVERTED...Reserved offsets and unused offset values are all zeroes

					END CASE;					

				ELSIF ( RnW = '0' AND nDS = '0' ) THEN	
				
					--THE TIMING HERE ASSERTS DSACK1 IN 68030 STATE 2, AS REQUIRED FOR NO WAIT STATES.
					--_DS IS ASSERTED IN S3, SO WE LATCH THE INCOMING DATA ON THE RISING EDGE OF S4.
					--ALL SHOULD BE GOOD.
				
					IF ( A(6 downto 1) = "100100" ) THEN
						--WRITE REGISTER AT OFFSET $48. THIS IS WHERE THE BASE ADDRESS IS ASSIGNED.
						
						--THERE MIGHT BE A CASE WHERE WE ARE HAVE JUST CONFIGED THE ROM WHERE
						--WE GET TO THIS ADDRESS AND MISTAKENLY THINK IT'S THE RAM BEING CONFIGURED
						--FOOD FOR THOUGHT. IN THAT CASE WE NEED TO WAIT UNTIL WE GET TO THE NEXT
						--AUTOCONFIG CYCLE TO ENTER THE BELOW CODE.
						
						--IF ( romconfiged = '1' AND ramconfiged = '0' ) THEN
						IF ( romconfiged = '1' ) THEN
							
							--THIS IS THE ZORRO 2 RAM BASE ADDRESS FOR OUR 8 MEGABYTES.
							--THERE ARE TWO POSSIBLE SLOTS FOR THIS SPACE...01 AND 10.
							
							
								
								--rambaseaddress0 <= "001";
								--rambaseaddress1 <= "010";
						
					
								
							ramconfiged <= '1'; 
							
						END IF;								
						
					END IF;	
						
				END IF;					
				
			END IF;
			
		END IF;
		
	END PROCESS;
	
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
		
	--userdata	<= '1' WHEN FC( 2 downto 0 ) = "001" ELSE '0'; --(cpustate:1)
	--superdata <= '1' WHEN FC( 2 downto 0 ) = "101" ELSE '0'; --(cpustate:5)
	
	nCIIN <= '1' 
		WHEN			
			--(chipram = '1' AND ( userdata = '1' OR superdata = '1' ) AND EXTSEL = '0') OR
			--!CACHE = chipram & (userdata # superdata) & !EXTSEL
			--(ciaspace = '1'  AND EXTSEL = '0') OR
			--ciaspace & !EXTSEL
			--(chipregs = '1'  AND EXTSEL = '0') OR
			--chipregs & !EXTSEL
			--(iospace = '1'  AND EXTSEL = '0')
			--iospace & !EXTSEL
			
			--nMEMZ2 = '0' OR
			nMEMZ3 = '0'
			--( A(23 DOWNTO 16) >= x"F8" AND A(23 DOWNTO 16) <= x"FF" )
		ELSE
			'0';		

	-----------------------
	-- 6888x CHIP SELECT --
	-----------------------
	
	--This selects the 68881 or 68882 math chip (FPU chip select), as long as there's no DMA 
	--going on.  If the chip isn't there, we want a bus error generated to 
	--force an F-line emulation exception.  Add in AS as a qualifier here
	--if the PAL ever turns out too slow to make FPUCS before AS. U306
	
	--field spacetype	= [A19..16] ;
	--coppercom	= (spacetype:20000) ; 00100000000000000000
	coppercom <= '1' WHEN A( 19 downto 16 ) = "0010" ELSE '0';
	--field copperid	= [A15..13] ;	
	--mc68881	= (copperid:2000) ; 0010000000000000
	mc68881 <= '1' WHEN A( 15 downto 13 ) = "001" ELSE '0';

	--FPUCS = cpuspace & coppercom & mc68881 & !BGACK;
	nFPUCS <= '0' WHEN ( FC(2 downto 0) = "111" AND coppercom = '1' AND mc68881 = '1' AND nBGACK = '1' ) ELSE '1';

	--BERR		= cpuspace & coppercom & mc68881 & !SENSE & !BGACK;
	--BERR.OE	= cpuspace & coppercom & mc68881 & !SENSE & !BGACK;
	nBERR <= '0' WHEN ( FC(2 downto 0) = "111" AND coppercom = '1' AND mc68881 = '1' AND nBGACK = '1' AND nSENSE = '1' ) ELSE 'Z';
	
	--------------------
	-- AUTO VECTORING --
	--------------------
	
	--This forces all interrupts to be serviced by autovectoring.  None
	--of the built-in devices supply their own vectors, and the system is
	--generally incompatible with supplied vectors, so this shouldn't be
	--a problem working all the time.  During DMA we don't want any AVEC
	--generation, in case the DMA device is like a Boyer HD and doesn't
	--drive the function codes properly. U306	
			
	--SOME TRIVIA...JEFF BOYER HAD A HAND IN DESIGNING SOME OF THE FIRST ZORRO 2
	--PERIPHERALS AT COMMODORE. SUCH CARDS INCLUDE THE A2052 RAM EXPANSION AND THE A2090 AND A2091
	--HARD DRIVE CARDS. AT MIMINUM, HE HAD A HAND IN DEVELOPING THE ORIGINAL DMAC CHIP FOUND ON THE 
	--A2090/A2091. THUS, IT SEEMS THE "BOYER HD" REFERENCED ABOVE IS, IN FACT, ANY HARD DRIVE
	--CONTROLLER WITH HIS ORIGINAL DMAC. THAT DESIGN WAS REPLACED BY THE SDMAC IN THE A3000.
	--AGAIN, DESIGNED BY JEFF BOYER.
		
	--field spacetype	= [A19..16] ;
	--interruptack	= (spacetype:f0000) ;
	--11110000000000000000
	--interruptack <= '1' WHEN A( 19 downto 16 ) = "1111" ELSE '0';

	--AVEC		= cpuspace & interruptack & !BGACK;
	nAVEC <= '0' WHEN (FC(2 downto 0) = "111" AND A( 19 downto 16 ) = "1111" AND nBGACK = '1') ELSE '1';

end Behavioral;