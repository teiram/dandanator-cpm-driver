all:    ddntr_eeprom.bin    ddntr.rom

DDNTR_SOURCES = main.asm dandanator.asm cpm_loader.asm constants.asm
ddntr_eeprom.bin :  eeprom_fid_driver.bin $(DDNTR_SOURCES)
	pasmo main.asm $@

ddntr.rom : ddntr_eeprom.bin disk.raw
	@cat ddntr_eeprom.bin disk.raw /dev/zero | dd of=ddntr.rom bs=16384 count=32

eeprom_fid_driver.bin : eeprom_fid_driver.asm
	pasmo --prl $^ $@

.PHONY : clean all
clean: 
	@rm -f *.bin ddntr.rom

	

