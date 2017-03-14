include constants.asm

org 	0
        di
	jp	bootstrap
        
org 	0x38
	ei
	ret

org	0x66
	retn
	
org	bootstrap
        ld 	sp, stack_ptr
set_splash: 
	; Set splash screen on normal screen
	ld      hl, (screen_addr)
	ld      de, $4000
	ld      bc, (screen_size)
	ldir
        
        ; Set splash screen on shadow screen, page 7
        ld 	bc, $7ffd	; Select Page 7 in upper ram
        ld	a, 7
        out 	(c),a

        ld 	hl, (screen_addr)
        ld	de, $c000
        ld	bc, (screen_size)
        ldir

        ld 	bc, $7ffd 	; Go back to boot memory configuration
        xor	a
	out	(c), a
		
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

relocated_area_start:
include cpm_loader.asm
include dandanator_reloc.asm
relocated_area_end:
