SVC_SCB                 EQU     $ + 0FE03H      ; SCB Address
SVC_D_HOOK              EQU     $ + 0FE05H      ; Hook in a disk device
SVC_ALLOCATE            EQU     $ + 0FE07H      ; Allocate memory area
SVC_DEALLOCATE          EQU     $ + 0FE09H      ; Return allocated memory
SCB_BIOS_DRV            equ     $F9DA           ; unidad actual de la BIOS
SCB_CCP_DRV             equ     $F9AF           ; Unidad actual del CPP
VERSION                 EQU     0001H           ; VERSION NUMBER IN BCD
sector_size             EQU     $1000           ; Block to save/load from eeprom
;
; FID Header
;
jp      FID_EMS
db      'SPECTRUM'              ;Name
db      'FID'                   ;Type
db      VERSION                 ;Version number
db      0000H                   ;checksum
db      0                       ;Start boundary
db      0                       ;End boundary
db      0,0,0,0,0,0,0,0,0,0,0,0 ;Reserved

buffer_addr:
        dw      0
dpblk:     ;DISK PARAMETER BLOCK
        DW      26              ;SECTORS PER TRACK      +0
        DB      3               ;BLOCK SHIFT FACTOR     +2
        DB      7               ;BLOCK MASK             +3
        DB      0               ;NULL MASK              +4
        DW      242             ;DISK SIZE-1            +5
        DW      63              ;DIRECTORY MAX          +7
        DB      192             ;ALLOC 0                +9
        DB      0               ;ALLOC 1                +10
        DW      16              ;CHECK SIZE             +11
        DW      2               ;TRACK OFFSET           +13


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

        ld      a, 1
        ccf
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
        or a
        ret

nomem_error_msg:
        db      "No enough free memory", $0d, $0a, $ff
dup_error_msg:
        db      "Driver already installed", $0d, $0a, $ff
noletter_error_msg:
        db      "Drive in use", $0d, $0a, $ff
ok_ems_msg:
        db      "Dandanator Disk Driver 0.1 succesfully registered", $0d, $0a, $ff
