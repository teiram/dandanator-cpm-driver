include constants.asm

org 	0
	
        di
        ld sp, stack_ptr

        ; Set splash screen
        ld      hl, screen
        ld      de, 0x4000
        ld      bc, screen_end - screen
        ldir
        
        ei
        halt
        halt
        di

        ld      a, 0
        out     (ulaport), a


	ld	bc, $0
pause_splash:
	djnz	pause_splash
	dec	c
	jr	nz, pause_splash


        ld      hl, relocated_area_start
        ld      de, relocation_area
        ld      bc, relocated_area_end - relocated_area_start
        ldir

        jp      relocation_area

org 	0x38

	ei
	ret
		
		
relocated_area_start:
include cpm_loader.asm
include dandanator_reloc.asm
relocated_area_end:

org 	0x1000
fid_driver:
incbin 	eeprom_fid_driver.bin
fid_driver_end:

screen:
incbin	splash.scr
screen_end:

org 	0x4000
incbin 	S10CPM3.EMS

ds 	0xc000 - $
