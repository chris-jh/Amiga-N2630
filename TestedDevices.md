The purpose of this list is to catalog devices that have been tested with the N2630. This allows users to understand what is known to work and what may not work, as well as alert developers of potential issues. In the event a plug in card or peripheral does not work, it is recommended to add this as a new issue to the repository. Everyone is encouraged to create a pull request to update this list.

Device|Working|Hardware Revision*|ROM Revision*|Notes**|Date Reported
-|-|-|-|-|-
Supra WordSync SCSI|Yes|Unknown|AMAB6||March 2023
GottaGoFastRAM2000|Yes|Unknown|Unknown||March 2023
A2091 SCSI|Yes|Rev 4.0 Modified|7.0|U600 Rev 2.0.4|October 2023
Oktagon 2008|No|Rev 5|6.10|RETEST WITH NEWEST FIRMWARE. It is necessary to disable autoboot on the Oktagon or disable IDE on the N2630. You cannot have two autoboot devices enabled.|September 2023
AT Emulator (Bridgeboard)|No|Rev 6|Unknown||September 2023
X-Surf 100 Network Card|No|Unknown||Autconfigures and then fails during initial register activity.|September 2023
Plipbox|Yes|Unknown (Purchased from Sordan)|0.6|Roadshow,<br>plipbox.device 020,<br>U600 Rev 2.0.4|October 2023
Ariadne|Yes|1.2B|Unknown|U600 Rev 2.0.5<br>U602 Rev 1.1.0|October 2023

*If the hardware or ROM revision cannot be determined, mark as "Unknown"  
**Include interesting observations or hardware/software settings that optimize the device.
