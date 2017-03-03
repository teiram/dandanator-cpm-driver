all:    ddntr_eeprom.bin    ddntr.rom

DDNTR_SOURCES = main.asm dandanator_reloc.asm cpm_loader.asm constants.asm
ddntr_eeprom.bin :  eeprom_fid_driver.bin $(DDNTR_SOURCES)
	pasmo main.asm $@

ddntr.rom : ddntr_eeprom.bin disk.raw
	@cat ddntr_eeprom.bin disk.raw /dev/zero | dd of=ddntr.rom bs=16384 count=32

eeprom_fid_driver.bin : eeprom_fid_driver.asm dandanator_api.asm
	pasmo --prl eeprom_fid_driver.asm $@

.PHONY : clean all
clean: 
	@rm -f *.bin ddntr.rom

	

