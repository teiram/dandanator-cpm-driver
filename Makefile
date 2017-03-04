all:    ddntr_eeprom.bin    ddntr.rom

DDNTR_SOURCES = main.asm dandanator_reloc.asm cpm_loader.asm constants.asm
ddntr_eeprom.bin :  eeprom_fid_driver.bin $(DDNTR_SOURCES)
	pasmo main.asm $@

ddntr.rom : ddntr_eeprom.bin disk.raw slot31.raw
	@cat ddntr_eeprom.bin disk.raw /dev/zero | dd bs=16384 count=31 | cat - slot31.raw > ddntr.rom

eeprom_fid_driver.bin : eeprom_fid_driver.asm dandanator_api.asm debug_macros.asm
	pasmo --prl eeprom_fid_driver.asm $@

.PHONY : clean all zip
clean: 
	@rm -f *.bin *.zip ddntr.rom

zip:
	@zip -9 "ddntr.rom.`date "+%Y%m%d%H%M%S"`.zip" ddntr.rom  

