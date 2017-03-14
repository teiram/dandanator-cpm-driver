all:    loader.bin dandanator_fid_driver.bin

DDNTR_SOURCES = main.asm dandanator_reloc.asm cpm_loader.asm constants.asm
loader.bin :  $(DDNTR_SOURCES)
	pasmo main.asm $@

dandanator_fid_driver.bin : eeprom_fid_driver.asm dandanator_api.asm debug_macros.asm
	pasmo --prl eeprom_fid_driver.asm $@

.PHONY : clean all zip
clean: 
	@rm -f *.bin
