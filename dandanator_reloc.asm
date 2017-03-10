ddntraddrconf           equ     0
ddntraddrcmd            equ     1
ddntraddrdat1           equ     2
ddntraddrdat2           equ     3
pauseloopsn             equ     20

ddntr_command   equ $ - relocated_area_start
;Send special command with long confirmation
sendspcmdlc: 
        ld      hl, ddntraddrcmd        ; HL=0 Command (ZESARUX)
        ld      b, a
nrcmdloop0:
	nop                     ; 5 nops = 11,2 us 48k 3 nops = 8,9us 48k, 
                                ; 2 nops = 7,75us 48k/7,625us 128k 
                                ; (1 nop not working)
        nop	
        nop
        ld      (hl), a         ; Send Pulse			
        djnz    nrcmdloop0

        ld      b,pauseloopsn           ; Drift more than 32us (timeout) and 
                                        ; allow extra time before next command 
                                        ; (20=~72us)
drift0:		
        djnz    drift0                  ; Drift will allow for variances in PIC 
                                        ; clock Speed and Spectrum Type.

        inc     hl                      ; HL=1 Data1 (ZESARUX)
        ld      a, d                    ; Data 1
        ld      b, a
nrcmdloop1:
	nop                     ; 5 nops = 11,2 us 48k 3 nops = 8,9us 48k, 
                                ; 2 nops = 7,75us 48k/7,625us 128k 
                                ; (1 nop not working)
        nop	
        nop
        ld      (hl), a         ; Send Pulse			
        djnz    nrcmdloop1
		
        ld      b, pauseloopsn	        ; Drift more than 32us (timeout) and 
                                        ; allow extra time before next command 
                                        ; (20=~72us)
drift1:
        djnz    drift1                  ; Drift will allow for variances in PIC 
                                        ; clock Speed and Spectrum Type.
        inc     hl                      ; HL=2 Data2 (ZESARUX)
        ld      a, e                    ; Data 2
        ld      b, a
nrcmdloop2:
	nop                     ; 5 nops = 11,2 us 48k 3 nops = 8,9us 48k, 
                                ; 2 nops = 7,75us 48k/7,625us 128k 
                                ; (1 nop not working)
        nop	
        nop
        ld      (hl), a         ; Send Pulse			
        djnz    nrcmdloop2

                                ; Will still take some time to perform actual 
        ld      b, pauseloopsn          ; Drift more than 32us (timeout) and 
                                        ; allow extra time before next command 
                                        ;(20=~72us)
drift2:
        djnz drift2                     ; Drift will allow for variances in PIC 
                                        ; clock Speed and Spectrum Type.

                                        ; Now about 4,8ms to confirm command 
                                        ; with a pulse to ddntraddrconf

        ld      (ddntraddrconf), a      ;Signal Dandanator the command 
                                        ;confirmation (any A value for ZESARUX)
        ld      b, 64					;Wait for command to perform			
pauselconf:
        djnz    pauselconf
        ret

; normal command
ddntr_normal_command   equ $ - relocated_area_start
dan_normal_cmd:      
	ld 	b, a
normal_cmd_loop:      
	nop			; 5 nops = 11,2 us 48k 3 nops = 8,9us 48k, 
				; 2 nops = 7,75us 48k/7,625us 128k 
				;(1 nop not working)
	nop
	nop
	ld 	(hl), a		; Send Pulse                    
	djnz normal_cmd_loop
        ld 	b, 64 
normal_exit_loop:
	djnz normal_exit_loop                           
	ret
	
	     
; initeepvars - Init PIC Eeprom Vars for boot options and Button Behaviour	

initeepvars:
        ld      hl, commands	; Point to commands table
loopcmds:
	ld      a, (hl)         ; Load Command code
        inc     hl              ; Move to Data 1
        ld      d,(hl)          ; Load Data 1
        inc     hl              ; Move to Data 2
        ld      e, (hl)         ; Load Data 2
        inc     hl              ; Move to next command
        cp      255             ; Check if no more commands
        jr      z, endcmds		
        push    hl
        call    sendspcmdlc     ; Send Special Command with Long comfirmation
        pop     hl              ; Restore HL
        jr      loopcmds        ; Next Init command in table
endcmds:
	ret

commands:	
DEFB 41,1,0     ; Special Command - Store Boot Bank
                ; Bank 1 - Dandanator
                ; On normal Boot (no buttons)
			
DEFB 41,32,1    ; Special Command - Store Boot Bank
                ; Bank 32 - Extra Rom
                ; On switch 1 pressed
                
DEFB 41,33,2    ; Special Command - Store Boot Bank
                ; Bank 33 - Internal Rom
                ; On switch 2 pressed	

DEFB 49,1,1     ; Special Command - Command Allow on Extra Bank
                ; Bank 1 - Dandanator ROM - Effectively disabling extra 
                ;   rom 1 commands
                ; Position 1 (2 positions are checked)	

DEFB 49,1,2     ; Special Command - Command Allow on Extra Bank
                ; Bank 1 - Dandanator ROM - Effectively disabling extra 
                ;  rom 2 commands
                ; Position 2 (2 positions are checked)	

DEFB 42,1,3     ; Select Button 1 short press as Reset
                ; Bank 1 Unused for this action
                ; 3 is Reset and short

DEFB 42,33,9    ; Select Button 1 long press as Return to internal ROM
                ; Bank 33 - Internal
                ; 9 is Reset Selecting Bank & Long
			
DEFB 42,1,17    ; Select Button 1 Double press as Dandanator Menu
                ; Bank 1 - Extra Rom
                ; 17 is Reset Selecting Bank & Double
			
DEFB 42,0,31    ; Select Button 1 Double press Window to 350ns
                ; Dont add any more steps to postscaler
                ; 7 step postscaler

DEFB 43,1,1     ; Select Button 2 short press as Dandanator Menu
                ; Bank 1 is Dandanator Menu
                ; 1 is select rom and reset (could also enable commands, 
                ;   but first bank always has commands enabled)

DEFB 255        ; End of Commands										
; ----------------------------------------------------------------------------------------
