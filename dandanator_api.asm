; ------------------------------------------------------------------------------
; ZX Dandanator! mini API for hw v1.1 
; Including eeprom write sst39sf040 functionality
; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------
; erase sst39sf040 sector 
;     a  = sector number (39sf040 has 128 4k sectors)
;
; * Must be run from ram, di, and with external eeprom paged in
; ------------------------------------------------------------------------------
dan_sst_sector_erase:
	push 	af		; save sector number
	and 	3		; get sector within page
	sla 	a		; move to a13,a12 in hl
	sla 	a
	sla 	a
	sla 	a
	ld 	h, a		
	ld 	l, 0
	pop 	af		; get sector number back
	push 	hl		; save address of sector

	ld 	e, a		; put pic in sector erase sector mode
	ld 	a, 48		; special command 48, external eeprom operations			
	ld 	d, 16		; 16, sector erase (sectorn contained in e)
	call 	dan_special_command
	call 	dan_confirmation_pulse
	
	pop 	hl		; get sector address back (pushed from hl)
	
se_step1:	
	ld 	bc, j5555	; five step command to allow sector erase
	ld 	a, $aa
	ld 	(bc),a			
se_step2:	
	ld 	bc, j2aaa				
	ld 	a, $55
	ld 	(bc), a	
se_step3:	
	ld 	bc, j5555				
	ld 	a, $80
	ld 	(bc), a
se_step4:	
	ld 	bc, j5555				
	ld 	a, $aa
	ld 	(bc), a
se_step5:	
	ld	bc, j2aaa				
	ld 	a, $55
	ld 	(bc), a
se_step6:	
	ld 	a, $30		; actual sector erase		
	ld 	(hl), a
	
	ld 	bc, 1400	; wait over 25 ms for sector erase to complete 
				; (datasheet pag 13) -> 1400*18us= 25,2 ms
waitsec:			; loop ts = 64ts -> aprox 18us on 128k machines
	ex 	(sp),hl		; 19ts
	ex 	(sp),hl		; 19ts
	dec 	bc		; 6ts
	ld 	a, b		; 4ts
	or 	c		; 4ts
	jr 	nz, waitsec	; 12ts / 7ts

	ret			; 10ts
; ------------------------------------------------------------------------------



; ------------------------------------------------------------------------------
; Program 39sf040 sector
; 	a  = sector number (39sf040 has 128 4k sectors)
; 	hl = ram address of sector to program : source of data
;
; * Must be run from ram, di, and with external eeprom paged in 
; * Sector must be erased first
; ------------------------------------------------------------------------------
dan_sst_sector_program:
	push 	hl		; save ram address
	push 	af		; save sector number
	ld 	e, a		; put pic in sector program mode
	ld 	a, 48		; special command 48, external eeprom operations
	ld 	d, 32		; 32, sector program
	call 	dan_special_command
	call 	dan_confirmation_pulse
	pop 	af		; get sector number back in a
	pop 	hl		; get ramaddress back					
	and 	3		; get 2 least significant bits of sector number
	sla 	a		; move these bits to a13-a12
	sla 	a
	sla 	a
	sla 	a
	ld 	d, a		; de is the beginning of the write area 
				; (4k sector aligned) within slot.
	ld 	e, 0
sectlp:				; sector loop 4096 bytes
			
pb_step1:	
	ld 	bc, j5555	; 3 step command to allow byte-write
	ld 	a, $aa
	ld 	(bc), a
pb_step2: 	
	ld 	bc, j2aaa
	ld 	a, $55
	ld 	(bc),a
pb_step3: 	
	ld 	bc, j5555
	ld 	a, $a0
	ld 	(bc), a	
pb_step4:	
	ld 	a, (hl)		; write actual byte
	ld 	(de), a
				; datasheet asks for 14us write time, but loop 
				; takes longer between actual writes
	inc 	hl		; next data byte
	inc 	de		; next byte in sector
	ld 	a,d		; check for 4096 iterations (d=0x_0, e=0x00)
	and 	15		; get 4 lower bits
	or 	e		; now also check for a 0x00 in e
	jr 	nz, sectlp
	ret
; ------------------------------------------------------------------------------



; ------------------------------------------------------------------------------
; Unlock dandanator commands - 
; * Must be run at the beginning of the code, needs sp set
; * Also pages in slot 2
; ------------------------------------------------------------------------------
dan_unlock_command:
	ld 	e, 16			; unlock commands
	ld 	d, 16
	ld 	a, 46
	call 	dan_special_command
	jp 	dan_confirmation_pulse
;	ret				; one less push (jp instead of call/ret)
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; reset dandanator to slot 0
; 
; ----------------------------------------------------------------------------------------
dan_reset_command: 
	ld 	a,1			; command 1 -> slot 0
	ld 	hl,1
	call 	dan_normal_command
reset:		
	rst 	0
; ------------------------------------------------------------------------------



; ------------------------------------------------------------------------------
; Send special command to dandanator - 
; Sends command (a), data 1 (d) and data 2 (e)- prepare for pulse
; Destroys hl, b.
; Uses extra 2 bytes on stack
;
; * Must be run from ram if changing slots 
; ------------------------------------------------------------------------------
dan_special_command:	
	ld 	hl, ddntraddrcmd	; hl=0 command (zesarux)
	call 	dan_normal_command	; send command 	
;	ld 	b,pauseloopsn		; drift more than 128us (timeout) and 
					; allow extra time before next command 
					; (50=~180us)
;drift0:		
;	djnz 	drift0			; drift will allow for variances in pic
					; clock speed and spectrum type.
			
	inc 	hl			; hl=1 data1 (zesarux)
	ld 	a, d			; data 1
	call 	dan_normal_command	; send data 1
;	ld 	b, pauseloopsn		; drift more than 128us (timeout) and 
					; allow extra time before next command 
					; (50=~180us)
;drift1:		
;	djnz 	drift1			; drift will allow for variances in pic
					; clock speed and spectrum type.
			
	inc 	hl			; hl=2 data2 (zesarux)
	ld 	a, e			; data 2
	jp 	dan_normal_command	; send data 2
;	ld 	b, pauseloopsn		; drift more than 128us (timeout) and 
					; allow extra time before next command 
					; (50=~180us)
;drift2:		
;	djnz 	drift2			; drift will allow for variances in pic
					; clock speed and spectrum type.
	;ret				; now about 4,8ms to confirm command 
					; with a pulse to ddntraddrconf
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Send normal command to dandanator - sends command/data
; a  = cmd/data, 
; hl = port number:  1 for cmd, 2 for data1, 3 for data2, 
; (0 for confirmation) (zesarux) 
;
; destroys b
; * 0 is signaled by 256 pulses.
; * Must be run from RAM 
; ------------------------------------------------------------------------------
dan_normal_command:	
	ld 	b, a	
nrcmdloop:	
	nop
	nop
	nop
	nop
	ld 	(hl), a			; send pulse			
	djnz 	nrcmdloop
	ld 	b, 128			; uncomment for full normalcommand 
					; execution (must be run from ram)
waitxcmd:	
	djnz 	waitxcmd				
	ret							
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Sends confirmation pulse to dandanator and wait a bit - also pause routine
; ------------------------------------------------------------------------------
dan_confirmation_pulse:	
	ld 	(0),a
pause: 		
	push 	bc
	ld 	b, pauseloopsn
waitpause:	
	djnz 	waitpause
	pop 	bc
	ret			
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; send command to dandanator with confirmation pulse
; *see dan_special_command
; *see dan_confirmation_pulse
; ------------------------------------------------------------------------------
dan_special_command_with_confirmation:
	call	dan_special_command
	jp	dan_confirmation_pulse
	;ret

pauseloopsn 	equ 64
ddntraddrcmd 	equ 1
j5555		equ $1555	; jedec $5555 with a15,a14=0 to force rom write
				; (pic will set page 1 so final address will be
				; $5555)
j2aaa		equ $2aaa	; jedec $2aaa, pic will select page 0

