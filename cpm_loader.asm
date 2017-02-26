        ;;DEBUG
        ld      a, 2
        out     (ulaport), a

        ; Initialize 1ffd/7ffd saved values
        ld      ix, variable_zone
        ld      (ix + value_7ffd_offset), default_7ffd_value 
        ld      (ix + value_1ffd_offset), default_1ffd_value 

        ; Copy FID loader to upper RAM (Bank 0: 0x1000)
        ld      hl, fid_loader
        ld      de, 0xd000
        ld      bc, fid_loader_end - fid_loader
        ldir

        ; Copy FID to upper RAM (Bank 0: 0x0100)
        ld      hl, fid_driver
        ld      de, 0xc100
        ld      bc, fid_driver_end - fid_driver
        ldir

        ; Page bank 4 in
        ld      b, 4
        call    relocation_area + page_upper_bank_offset
        ; Ask dandanator to map slot 1 (Start of S10CPM3.EMS)
        ld      a, 40           ; Command 40
        ld      d, 1 + 1        ; Slot 1
        ld      e, 0            ; Do nothing afterwards
        call    relocation_area + ddntr_command

        ; Copy to RAM (bank 4: 0x0000)
        ld      hl, 0x0000
        ld      de, 0xc000
        ld      bc, 0x4000
        ldir

        ; Patch CP/M to avoid disk controller initialization
        ld      bc, 0x2ffd
        in      a, (c)
        cp      $ff             ; Port 2ffd always returns FF on a Plus2A
        jr      nz, plus3

        ld      hl, relocation_area + plus2a_patch_offset
        ld      de, 0xc202
        ld      bc, plus2a_patch_end - plus2a_patch
        ldir
        
plus3:
        ; Page bank 3 in
        ld      b, 3
        call relocation_area + page_upper_bank_offset
        ; Ask dandanator to map slot 2 (End of S10CPM3.EMS)
        ld      a, 40           ; Command 40
        ld      d, 2 + 1        ; Slot 2
        ld      e, 0            
        call relocation_area + ddntr_command
        ; Copy to RAM (bank 3: 0x0000)
        ld      hl, 0x0000
        ld      de, 0xc000
        ld      bc, 0x4000
        ldir

        ; Switch to internal ROM and block commands afterwards
        ld      a, 40           ; Command 40
        ld      d, 33           ; Slot 33 (Internal rom)
        ld      e, 4            ; Block commands afterwards
        call relocation_area + ddntr_command

        ;; DEBUG
        ld      a, 3
        out     (ulaport), a

        ; Select shadow screen
        ld      a, (variable_zone + value_7ffd_offset)
        or      8
        ld      bc, 0x7ffd
        out     (c), a

        ;; DEBUG
        ld      a, 4
        out     (ulaport), a

        ; Select All RAM Mode 2 (4, 5, 6, 3) 
        ld      a, (variable_zone + value_1ffd_offset)
        or      1
        ld      bc, 0x1ffd
        out     (c), a
        
        ;; DEBUG
        ld      a, 5
        out     (ulaport), a

        ld      hl, relocation_area + cpm_patcher_offset
        ld      de, 0x9c40
        ld      bc, cpm_patcher_end - cpm_patcher
        ldir

        ld      a, 6
        out     (ulaport), a

        jp      0x9c40
        
; Maps the bank in B to high memory
; Modifies: ix, bc, a
page_upper_bank_offset equ      $ - relocated_area_start
page_upper_bank:
        ld      ix, variable_zone
        ld      a, (ix + value_7ffd_offset)
        and     0xf8
        or      b
        ld      bc, 0x7ffd
        ld      (ix + value_7ffd_offset), a
        out     (c), a
        ret

cpm_patcher_offset equ     $ - relocated_area_start
cpm_patcher:
        ld      hl, 0xc000
        ld      de, 0x4000
        ld      bc, 0x3f80
        ldir
        ld      hl, fid_setup
        ld      (ems_patch), hl

        ;; DEBUG
        ld      a, 7
        out     (ulaport), a

        im      1
        di
        jp      0
cpm_patcher_end:

dir_ram_3       equ fid_name - fid_loader + $1000

fid_loader:
        ;;DEBUG
        ld      a, 0
        out     (ulaport), a

;        ld      iy, dir_ram_3
;        ld      a, (iy+12)
;        cp      $ff
;        jr      nz, fid_loader2
fid_loader1:
        ld      a, (iy + 11)
        ld      (scb_bios_drv), a    ; Default BIOS drive
        ld      (scb_ccp_drv), a     ; Default CCP drive
;        jr      fid_loader3
fid_loader2:
        ld      hl, dir_ram_3
        ld      de, $0203
        ld      bc, 11
        ldir
        call    fid_install
fid_loader3:
        ld      a, 3                 ; Search for FID in C
        ld      (fid_mask),a
        jp      fid_search

fid_name                db 'DDNTR   FID'
fid_default_drive       db 2                 ;0 = A, 1 = B, 2 = C
fid_no_driver           db 0   

fid_loader_end:

plus2a_patch_offset equ $ - relocated_area_start
plus2a_patch:
        ld a, $60
        nop
        nop
        nop
        nop
plus2a_patch_end:

