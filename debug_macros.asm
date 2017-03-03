MACRO	debug_border_colour, colour
IF DEBUG EQ 1
	push 	af
        ld      a, colour
        out     (0xfe), a
	pop	af
ENDIF
ENDM

MACRO	debug_restore_border
	debug_border_colour 1
ENDM
