include constants.asm

org 0
        di
        ld sp, stack_ptr

        ;; DEBUG
        ld      a, 1
        out     (ulaport), a

        ld      hl, relocated_area_start
        ld      de, relocation_area
        ld      bc, relocated_area_end - relocated_area_start
        ldir

        jp      relocation_area

relocated_area_start:
include cpm_loader.asm
; Assumed that dandanator.asm starts with the command entry point
ddntr_command   equ $ - relocated_area_start
include dandanator.asm
relocated_area_end:

org 0x1000
fid_driver:
incbin eeprom_fid_driver.bin
fid_driver_end:

org 0x4000
incbin S10CPM3.EMS

ds 0xc000 - $
