SVC_BANK_05             EQU     $ + 0FE00h      ;Last value written to $7ffd
SVC_BANK_68             EQU     $ + 0FE01h      ;Last value written to $1ffd
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

; Data buffer
buffer_addr:
        dw      0

;DISK PARAMETER BLOCK
dpblk:
        dw      36      ;spt. 128byte records per track                 +0
        db      3       ;bsh. Block shift. 3 = 1k, 4 = 2k, 5 = 4k...    +2
        db      7       ;blm. Block mask. 7 = 1k, F = 2k, 1F = 4k...    +3
        db      0       ;exm. Extent mask                               +4
        dw      174     ;dsm. Number of blocks on the disk - 1          +5
        dw      63      ;drm. Number of directory entries - 1           +7
        db      $c0     ;al0. Directory allocation bitmap (1st byte)    +9
        db      0       ;al1. Directory allocation bitmap (2nd byte)    +10
        dw      16      ;Checksum vector size, 0 for a fixed disc
                        ; No. directory entries/4, rounded up.          +11
        dw      0       ;off. Number of reserved tracks                 +13
        db      2       ;psh. Physical sector shift, 0 = 128-byte sectors
                        ;1 = 256-byte sectors,  2 = 512-byte sectors... +15
        db      3       ;phm. Physical sector mask,  0 = 128-byte sectors
                        ;1 = 256-byte sectors, 3 = 512-byte sectors...  +16

; The directory allocation bitmap is interpreted as:

;       al0                     al1
;       b7b6b5b4b3b2b1b0        b7b6b5b4b3b2b1b0
;        1 1 1 1 0 0 0 0         0 0 0 0 0 0 0 0
;               - ie, in this example, the first 4 blocks of the disc 
;               contain the directory.


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
        ld      a, 2
        out     (0xfe), a

        ld      a, (SCB_BIOS_DRV)
        and     0xff
        jr      z, fid_ems_allocate
        ld      hl, dup_error_msg
        or      a
        ret
fid_ems_allocate:
        ld      de, sector_size
        call    SVC_ALLOCATE
        jr      c, fid_ems_init
        ld      hl, nomem_error_msg
        ret
fid_ems_init:
        ld      (buffer_addr), hl
        scf

        ld      b, 2
        call    FID_D_LOGON
        jr      nc, error_fid_d_logon

        ld      hl, ok_ems_msg
        scf

error_fid_d_logon:
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
        ld      a, 1
        out     (0xfe), a

        ld      de, FID_JUMP_BLOCK 
        ld      hl, (dpblk + 5)
        inc     hl                      ; Block count
        ld      ix, $0000               ; Not sure about this
        ld      iy, $0000               ; Not sure about this
        call    SVC_D_HOOK
        jr      nc, fdl_errors
        push    ix                      ; Storage for DPB
        pop     de
        ld      hl, dpblk
        ld      bc, 17
        ldir                            ; Copy DPB

        xor a
        scf
        ret
fdl_errors:
        and     $01
        ld      hl, nomem_error_msg
        ret     nz
        ld      hl, noletter_error_msg
        ret

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
        ld      a, 4
        out     (0xfe), a

                                ; Calculate track offset, assuming
                                ; that each track has 9 sectors
                                ; 512 bytes each
        push    hl
        pop     bc
        and     a               ; Clear Carry

        sla     c
        sla     c
        sla     c               
        add     hl, bc          ; hl contains track * 9
        add     hl, de          ; hl contains track * 9 + sector


        push    hl              ; hl will hold the byte offset (aligned to 4k)
        pop     de              ; de will hold the slot offset 


        ld      b, 5
shift_slot:        
        srl     d
        rr      e
        djnz    shift_slot      ; e holds the slot offset (>> 5)

        ld      b, 9
shift_pos:
        sla     l
        rl      h
        djnz    shift_pos       ; hl holds the byte offset

        push    hl              ; We need it later to calculate the offset in 
                                ; buffer area

        ld      l, 0
        ld      a, h
        and     $f0
        ld      h, a            ; Aligned to 4K boundaries

        di
        ; Switch to normal mapping mode (We assume we are running in
        ;       bank 5 from $4000 onwards, as stated in our FID header)
        ld      a, (SVC_BANK_68)
        and     $fe            ; Clear special mode banking
        ld      bc, $1ffd
        out     (c), a

        ; We need page 3 in $C000 to have access to CP/M variables
        ld      a, (SVC_BANK_05)
        and     $f8
        or      3
        ld      bc, $7ffd
        out     (c), a

        push    hl              ; Save source address in slot 0

        ; Unlock dandanator commands
        push    de
        ld      a, 46
        ld      d, 16
        ld      e, 16
        call    sendspcmdlc
        pop     de

        ; Ask dandanator to map needed slot
        ld      a, e
        add     a, 3 + 1        ; Add disk slot offset (plus command shift)
        ld      d, a            ; Slot 
        ld      a, 40           ; Command 40
        ld      e, 0            ; No further actions
        call    sendspcmdlc   

        pop     hl
        ld      de, (buffer_addr)
        ld      bc, 4096
        ldir                    ; Copy 4K from mapped EEPROM to buffer_addr

        ; Switch to internal ROM and block commands afterwards
        ld      a, 40           ; Command 40
        ld      d, 33           ; Slot 33 (Internal rom)
        ld      e, 4            ; Block commands afterwards
        call    sendspcmdlc

        ; Restore $7ffd value
        ld      a, (SVC_BANK_05)
        out     ($7ffd), a

        ; Switch back to allram mode
        ld      a, (SVC_BANK_68)
        out     ($1ffd), a

        ei

        ; Calculate block offset in buffer_addr
        ld      hl, (buffer_addr)
        pop     de
        ld      a, d
        and     $0f     ; Offset in the 4K buffer
        ld      d, a
        add     hl, de

        push    iy      ; IY holds the transfer buffer address
        pop     de

        ld      bc, 512
        ldir

        ;DEBUG
        ld      a, 0
        out     (0xfe), a

        ld      a, 0
        scf             ; Set carry (success)
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
        ld      a, 5
        out     (0xfe), a
        sub     a
        scf
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
        ld      a, 6
        out     (0xfe), a
        scf
        xor a
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
        ld      a, 6
        out     (0xfe), a

        ld      hl, generic_error_msg
        scf
        ret

include dandanator.asm

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
