DEBUG			EQU 	0
include 		debug_macros.asm
SVC_BANK_05             EQU     $ + 0FE00h      ; Last value written to $7ffd
SVC_BANK_68             EQU     $ + 0FE01h      ; Last value written to $1ffd
SVC_SCB                 EQU     $ + 0FE03H      ; SCB Address
SVC_D_HOOK              EQU     $ + 0FE05H      ; Hook in a disk device
SVC_ALLOCATE            EQU     $ + 0FE07H      ; Allocate memory area
SVC_DEALLOCATE          EQU     $ + 0FE09H      ; Return allocated memory
SCB_BIOS_DRV            equ     $F9DA           ; Current BIOS drive
SCB_CCP_DRV             equ     $F9AF           ; Current CCP drive
VERSION                 EQU     0001H           ; Version number (BCD encoded)
sector_size             EQU     $1000           ; Block to save/load from eeprom
;
; FID Header
;
jp      FID_EMS
db      'SPECTRUM'              ;Name
db      'FID'                   ;Type
dw      VERSION                 ;Version number
dw      0000H                   ;checksum
db      40h                     ;Start boundary
db      80h                     ;End boundary
db      0,0,0,0,0,0,0,0,0,0,0,0 ;Reserved

;===================
; Variables
;===================
; Data buffer
buffer_addr:
        dw      0
buffer_state:
	db	0		; Dirty status of the buffer
cached_block:
	db	$ff		; EEPROM has 128 4K blocks
				; 8 bits are enough to hold this value
;=============================================
; FID_EMS: Driver Entry Point 
;=============================================
;Early morning start.
;Entry conditions:
;       DE = FID environment version
;       C = country code
;Exit conditions:
;       If carry true then OK
;               HL = address of sign on message terminated by #FF
;       If carry false then error
;               HL = address of error message terminated by #FF
;       Always
;               Other flags A BC DE IX IY corrupt
;               All other registers preserved
FID_EMS:

;        So far I don't think we need this
;	 since we will be allocating our driver always
;        ld      a, (SCB_BIOS_DRV)
;        and     0xff
;        jr      z, fid_ems_allocate
;        ld      hl, dup_error_msg
;        or      a
;        ret
fid_ems_allocate:
        ld      de, sector_size
        call    SVC_ALLOCATE
        jr      c, fid_ems_init
        ld      hl, nomem_error_msg
        ret
fid_ems_init:
        ld      (buffer_addr), hl       ; Memory allocated by SVC_ALLOCATE

        ld      de, FID_JUMP_BLOCK 
        ld      hl, (dpblk + 5)
        inc     hl                      ; Block count
        ; 4 times block count (two maps * 512 byte blocks) divided by 8
        ; Bytes for a double bit allocation table
        srl     h
        rr      l       		; Divide by 2
        ld      ix, $0000
        ld      iy, $0000 
        ld      b, $ff    		; First available drive unit
        call    SVC_D_HOOK
        jr      nc, fdl_errors
        ld      hl, ok_ems_msg
        scf
        ret
fdl_errors:
        and     $01
        ld      hl, nomem_error_msg
        ret     nz
        ld      hl, noletter_error_msg
        ret

FID_JUMP_BLOCK:
        jp      FID_D_LOGON
        jp      FID_D_READ
        jp      FID_D_WRITE
        jp      FID_D_FLUSH
        jp      FID_D_MESS

;=============================================
; FID_D_LOGON: Initialize logical device
;=============================================
;Logon a drive and initialise the DPB as required. 
;The required sizes of allocation vector, checksum vector and hash table must not exceed those allocated by SVC_D_HOOK.
;Entry conditions:
;       B = drive
;       IX = address of DPB
;Exit conditions
;       If carry true then OK
;               A = return code
;               #00 => OK
;               B corrupt
;       If carry false and zero true then error but no retry
;               A = CP/M return code
;               #01 => non-recoverable error condition
;               #FF => media changed
;               B corrupt
;       If carry false and zero false then error; ask user, retry if requested
;               A = CP/M return code
;               #01 => non-recoverable error condition
;               #FF => media changed
;               B = message number
;       Always
;               C DE HL IX IY corrupt
;               All other registers preserved
FID_D_LOGON:

        push    ix
        pop     de
        ld      hl, dpblk
        ld      bc, dpblk_end - dpblk
        ldir


        xor a
        scf
        ret

;====================
;DISK PARAMETER BLOCK
dpblk:
        dw      36      ;spt. 128byte records per track                 +0
        db      4       ;bsh. Block shift. 3 = 1k, 4 = 2k, 5 = 4k...    +2
        db      $f      ;blm. Block mask. 7 = 1k, F = 2k, 1F = 4k...    +3
        db      0       ;exm. Extent mask                               +4
        dw      223     ;dsm. Number of blocks on the disk - 1          +5
        dw      127      ;drm. Number of directory entries - 1           +7
        db      $f0     ;al0. Directory allocation bitmap (1st byte)    +9
        db      0       ;al1. Directory allocation bitmap (2nd byte)    +10
        dw      $8000   ;Checksum vector size, 0 for a fixed disc
                        ; No. directory entries/4, rounded up.          +11
        dw      0       ;off. Number of reserved tracks                 +13
        db      2       ;psh. Physical sector shift, 0 = 128-byte sectors
                        ;1 = 256-byte sectors,  2 = 512-byte sectors... +15
        db      3       ;phm. Physical sector mask,  0 = 128-byte sectors
                        ;1 = 256-byte sectors, 3 = 512-byte sectors...  +16
dpblk_end:

; The directory allocation bitmap is interpreted as:

;       al0                     al1
;       b7b6b5b4b3b2b1b0        b7b6b5b4b3b2b1b0
;        1 1 1 1 0 0 0 0         0 0 0 0 0 0 0 0
;               - ie, in this example, the first 4 blocks of the disc 
;               contain the directory.

;=============================================
; FID_D_READ: Read logical sector
;=============================================
;Read a 512 byte sector.
;Entry conditions:
;       B = drive
;       DE = logical sector
;       HL = logical track
;       IX = address of DPB
;       IY = address of destination
;Exit conditions:
;       If carry true then OK
;               A = return code
;               $00 => OK
;               B corrupt
;       If carry false and zero true then error but no retry
;               A = CP/M return code
;               $01 => non-recoverable error condition
;               $FF => media changed
;               B corrupt
;       If carry false and zero false then error; ask user, retry if requested
;               A = CP/M return code
;               $01 => non-recoverable error condition
;               $FF => media changed
;               B = message number
;       Always
;               C DE HL IX IY corrupt
;               All other registers preserved
FID_D_READ:
	di
	call	fetch_block
	jr	nc, error_fetch

        ; Calculate block offset in buffer_addr
        ld      hl, (buffer_addr)
        ld      a, d
        and     $0f     ; Offset in the 4K buffer
        ld      d, a
        add     hl, de

        push    iy      ; IY holds the transfer buffer address
        pop     de
        ld      bc, 512
        ldir

        ld      a, 0
        scf             ; Set carry (success)
error_fetch:
	ei
	ret 

;=============================================
; FID_D_WRITE: Write logical sector
;=============================================
;Write a 512 byte sector.
;Entry conditions:
;       B = drive
;       C = deblocking code
;               0 => deferred write
;               1 => non-deferred write
;               2 => deferred write to first sector in block
;       DE = logical sector
;       HL = logical track
;       IX = address of DPB
;       IY = address of source
;Exit conditions:
;       If carry true then OK
;               A = return code
;               $00 => OK
;               B corrupt
;       If carry false and zero true then error but no retry
;               A = CP/M return code
;               $01 => non-recoverable error condition
;               $02 => disc is read-only
;               $FF => media changed
;               B corrupt
;       If carry false and zero false then error; ask user, retry if requested
;               A = CP/M return code
;               $01 => non-recoverable error condition
;               $02 => disc is read-only
;               $FF => media changed
;               B = message number
;       Always
;               C DE HL IX IY corrupt
;               All other registers preserved
FID_D_WRITE:
	di
	push	bc
	call	fetch_block	; Get the block to modify

        ; Calculate block offset in buffer_addr
	ld	hl, (buffer_addr)
	ld	a, d
	and	$0f		; Offset in the 4K buffer
	ld	d, a
	add	hl, de
	push	iy
	pop	de
	ex	de, hl
	ld	bc, 512
	ldir
	ld	a, 1
	ld	(buffer_state), a	; Mark the buffer as dirty

	pop	bc
	ld	a, c
	cp	$1
	jr	nz, deferred_write
	call	save_current_block
deferred_write:
	xor	a
        scf
	ei
        ret

;=============================================
; FID_D_FLUSH: Flush buffers
;=============================================
;Entry conditions:
;       B = drive
;       IX = address of DPB
;Exit conditions:
;       If carry true then OK
;               A = return code
;               $00 => OK
;               B corrupt
FID_D_FLUSH:
	di
	call	save_current_block
        scf
        xor a
        ei
        ret

;=============================================
; FID_D_MESS: Driver messages
;=============================================
;Return a message string in the language of the country specified to FID_EMS.
;
;Entry conditions:
;
;       B = message number (as returned by the other FID_D_ routines)
;       IX = address of DPB
;Exit conditions:
;       If carry true then message text is available
;               HL = address of message terminated by #FF
;       If carry false then error, no message
;               HL corrupt
;       Always
;               Other flags A BC DE corrupt
FID_D_MESS:

        ld      hl, generic_error_msg
        scf
        ret

;===============================================================================
; Fetches a block from the EEPROM
; Useful for either read or write routines
; Entry conditions:
;   B = drive
;   DE = logical sector
;   HL = logical track
;   IX = address of DPB
;   IY = address of destination
; Output status:
;   DE = block offset
;   Carry OK to denote success
;   No errors are possible so far
;   All registers corrupted (but alternate ones)
; * Shall be entered with interrupts disabled
;===============================================================================
fetch_block:
	; Calculate track offset, assuming
	; that each track has 9 sectors
	; 512 bytes each
        push    hl
        pop     bc              ; BC holds now the track number
        and     a               ; Clear Carry

                                ; Multiply track number by 9
                                ; Multiplying by 8 and self adding on HL
        sla     c
        rl      b               ; By 2
        and     a
        sla     c               
        rl      b               ; By 4
        and     a
        sla     c               
        rl      b               ; By 8
        add     hl, bc          ; hl contains track + track * 8 = track * 9
        add     hl, de          ; hl contains track * 9 + sector
	push	hl
	pop	de

	ld	d, 0
	ld	a, e
	and	$1f
	ld	e, a		; 5 lower bits for sector offset

        ld      b, 9		; Calculate requested block offset
shift_pos:
        sla     e
        rl      d
        djnz    shift_pos       ; de holds now the slot offset in bytes

        push    de              ; We need it later to calculate the offset in 
                                ; buffer area

	ld	a, (cached_block)
	ld	b, 3		; Shift 3 positions to go from 512b to 4K
shift_to_block:
	srl	h
	rr	l
	djnz	shift_to_block		; l holds now the eeprom 4k block
	cp	l
	jp	z, cached

	call	save_current_block	; Save the current block if dirty
	ld	a, l
	ld	(cached_block), a	; Mark as cached, since there's no
					; chance of controlled failure from 
					; now on

	debug_border_colour 4

        ld      b, 2			; Shift 2 more positions to get the
					; slot (16K)
shift_to_slot:        
        srl     h
        rr      l
        djnz    shift_to_slot      	; l holds the slot offset
					; 8 bits are enough (h must be zero)
        ;di

        ; We need page 3 in $C000 to have access to CP/M variables
        ;    and also where the stack resides
        ld      a, (SVC_BANK_05)
        and     $f8
        or      3
        ld      bc, $7ffd
        out     (c), a

        ; Switch to normal mapping mode (We assume running in bank 5 
        ;       from $4000 onwards, as stated in our FID header)
        ld      a, (SVC_BANK_68)
        and     $fe            ; Clear special mode banking
        ld      bc, $1ffd
        out     (c), a

	; Pause for PIC
	ld	b, 32
pause_pic_enter_load:
	djnz	pause_pic_enter_load

        ; Unlock dandanator commands
        push    hl

        ld      a, 46
        ld      d, 16
        ld      e, 16
        call    dan_special_command_with_confirmation

        pop     hl

        ; Ask dandanator to map needed slot
        ld      a, l
        add     a, 3 + 1        ; Add disk slot offset (plus command shift)
	ld	hl, 1
        call    dan_normal_command

        pop     hl		; block offset (512 bytes)
	push	hl
        ld      a, h
        and     $f0             
        ld      h, a            ; 4K boundaries
	ld	l, 0

        ld      de, (buffer_addr)
        ld      bc, 4096
        ldir                    ; Copy 4K from mapped EEPROM to buffer_addr

	xor 	a
	ld	(buffer_state), a 	; Set the buffer as clean

        ; Switch to internal ROM and block commands afterwards
        ld      a, 40           ; Command 40
        ld      d, 33           ; Slot 33 (Internal rom)
        ld      e, 4            ; Block commands afterwards
        call    dan_special_command_with_confirmation

        ; Switch back to allram mode
        ld      a, (SVC_BANK_68)
	ld	bc, $1ffd
        out     (c), a

cached:
	pop 	de	; Return in DE the block offset
        ld      a, 0
	debug_restore_border
        scf             ; Set carry (success)
        ret

;===============================================================================
; Saves the currently buffered block to eeprom in case its state is dirty
; Entry conditions:
;  None
; Output status:
;   Carry OK to denote success
;   AF, DE, BC, HL preserved
; * Shall be entered with interrupts disabled
;===============================================================================
save_current_block:

	push	af
	push 	bc
	push	de
	push 	hl

	ld	a, (buffer_state)	; Check buffer status
	cp	$1			; 1 means dirty
	jr	nz, nosave_required

	ld	a, (cached_block)	; Check if we have something cached
	cp	$ff
	jr	z, nosave_required

        ; We need page 3 in $C000 where the stack resides
        ld      a, (SVC_BANK_05)
        and     $f8
        or      3
        ld      bc, $7ffd
        out     (c), a

        ; Switch to normal mapping mode (needed by sst routines)
        ld      a, (SVC_BANK_68)
        and     $fe            		; Clear special mode banking
        ld      bc, $1ffd
        out     (c), a

	; Pause for PIC
	ld	b, 32
pause_pic_enter_save:
	djnz	pause_pic_enter_save

        ld      a, 46
        ld      d, 16
        ld      e, 16
        call    dan_special_command_with_confirmation

        ; Ask dandanator to map first disk slot
        ld      a, 3 + 1
	ld	hl, 1
        call    dan_normal_command

	ld	a, (cached_block)
	add	a, 12			; Offset of reserved SST blocks (4 * 3)
	call	dan_sst_sector_erase

	ld	a, (cached_block)
	add	a, 12
	ld	hl, (buffer_addr)
	call	dan_sst_sector_program

        ; Switch to internal ROM and block commands afterwards
        ld      a, 40           ; Command 40
        ld      d, 33           ; Slot 33 (Internal rom)
        ld      e, 4            ; Block commands afterwards
        call    dan_special_command_with_confirmation

        ; Switch back to allram mode
        ld      a, (SVC_BANK_68)
	ld	bc, $1ffd
        out     (c), a

	ld	a, 0
	ld	(buffer_state), a
nosave_required:
	pop	hl
	pop	de
	pop	bc
	pop 	af
	scf
	ret

include dandanator_api.asm

nomem_error_msg:
        db      "No enough free memory", $0d, $0a, $ff
dup_error_msg:
        db      "Driver already installed", $0d, $0a, $ff
noletter_error_msg:
        db      "Drive in use", $0d, $0a, $ff
ok_ems_msg:
        db      "Dandanator Disk Driver 0.1 succesfully registered", $0d, $0a, $ff
generic_error_msg:
        db      "Generic message error", $0d, $0a, $ff


