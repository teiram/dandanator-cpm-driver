all:    ddntr_eeprom.bin    ddntr.rom

DDNTR_SOURCES = main.asm dandanator.asm cpm_loader.asm constants.asm
ddntr_eeprom.bin :  eeprom_fid_driver.bin $(DDNTR_SOURCES)
	pasmo main.asm $@

ddntr.rom : ddntr_eeprom.bin padding.bin
	@cat ddntr_eeprom.bin padding.bin > ddntr.rom

padding.bin : 
	@dd if=/dev/zero of=padding.bin bs=16384 count=28

eeprom_fid_driver.bin : eeprom_fid_driver.asm
	pasmo --prl $^ $@

.PHONY : clean all
clean: 
	@rm -f *.bin ddntr.rom

	

