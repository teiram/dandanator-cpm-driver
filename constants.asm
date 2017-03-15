relocation_area         equ     0x7000
variable_zone           equ     0x7600
stack_ptr               equ     0x7ffe

value_7ffd_offset       equ     0
value_1ffd_offset       equ     1

default_7ffd_value      equ     0x10
default_1ffd_value      equ     0x04

fid_setup               equ     0x1000
ems_patch               equ     0x30b4

scb_bios_drv            equ     0xf9da
scb_ccp_drv             equ     0xf9af
fid_search              equ     0xeb2f
fid_install             equ     0xebe9
fid_mask                equ     0xeb7c

ulaport                 equ     0xfe
screen_location		equ	$4000
kloader_entry_point	equ	$f000

version_addr		equ	$0004
fid_addr		equ	$0006
fid_size		equ	$0008
screen_addr		equ	$000a
screen_size		equ	$000c
kloader_scr_addr	equ	$000e
bootstrap		equ	$0100
