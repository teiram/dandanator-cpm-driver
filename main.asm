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
include dandanator.asm
relocated_area_end:

org 0x1000
fid_driver:
incbin eeprom_fid_driver.bin
fid_driver_end:

org 0x4000
incbin S10CPM3.EMS

org 0xc000
dpblk:     ;DISK PARAMETER BLOCK
DW      26              ;SECTORS PER TRACK
DB      3               ;BLOCK SHIFT FACTOR
DB      7               ;BLOCK MASK
DB      0               ;NULL MASK
DW      242             ;DISK SIZE-1
DW      63              ;DIRECTORY MAX
DB      192             ;ALLOC 0
DB      0               ;ALLOC 1
DW      16              ;CHECK SIZE
DW      2               ;TRACK OFFSET

ds 0x10000 - $

