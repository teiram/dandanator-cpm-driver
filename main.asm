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

detect_keypress: 	; Detect L is pressed (A14=0, Data bit 1)
	ld 	a, $bf 	; A14=0
	in 	a, (ulaport)
	bit 	1, a
	jp 	z, kempston_loader


        ld      hl, relocated_area_start
        ld      de, relocation_area
        ld      bc, relocated_area_end - relocated_area_start
        ldir
        jp      relocation_area

relocated_area_start:
include cpm_loader.asm
include dandanator_reloc.asm
relocated_area_end:

kempston_loader:
	ld 	de, $4000 		;Uncompress Screen
	ld 	hl, (kloader_scr_addr)
	call 	dzx7
	ld 	hl, writer_code 	;Copy writer code to ram
	ld 	de, kloader_entry_point
	ld 	bc, writer_code_end-writer_code
	ldir
	jp 	kloader_entry_point	; jump to writer code

dzx7:
	include dzx7_turbo.asm 		; ZX7 decompression - Turbo version 
writer_code:
	incbin eewriter_romset.bin 	; Include binary for eewriter_romset 
					; with $f000 org
writer_code_end:
