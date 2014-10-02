.att_syntax
.arch i386
.code16

/*
 * the number of clicks(16 bytes) to be loaded.
 * 0x3000<<4 = 196kB, more than enough for current version of linux.
 */
.equ SYSSIZE,	0x3000

.equ SETUPLEN,	4
.equ BOOTSEG,	0x07c0
.equ INITSEG,	0x9000
.equ SETUPSEG,	0x9020
.equ SYSSEG,	0x1000
.equ ENDSEG,	SYSSEG + SYSSIZE

.equ ROOT_DEV,	0x301


.text

.type printrm, @function

.globl _start

_start:
	movw $BOOTSEG, %ax
	movw %ax, %ds
	movw $INITSEG, %ax
	movw %ax, %es

	movw $256, %cx
	subw %si, %si
	subw %di, %di
	rep movsw

	ljmp $INITSEG, $go

go:
	movw %cs, %ax
	movw %ax, %ds
	movw %ax, %es

	movw %ax, %ss
	movw $0xFF00, %sp

/*
 * load the setup-sectors directly after the bootblock
 * Note that 'es' is already set up
 */
	
load_setup:
	/*
	 * Read some sectors from a block storage device(CHS).
	 * DL: driver number
	 * DH: begin header
	 * CH: begin track
	 * CL: begin sector
	 * AH: Operation(0x02=read, 0x03=write, 0x00=reset ...)
	 * AL: sections to operate
	 * BX: buffer address
	 */
	movw $0x0000, %dx
	movw $0x0002, %cx
	movw $0x0200, %bx
	movw $(0x0200+SETUPLEN), %ax
	int $0x13
	jnc ok_load_setup

	/*
	 * reset the diskette, then reload the setup-sectors
	 */
	movw $0x0000, %dx
	movw $0x0000, %ax
	int $0x13
	jmp load_setup


ok_load_setup:
	
	/*
	 * Get disk drive parameters, specifically nr of sectors/track
	 * BIOS rounte return it in CX register, It's 0x12(18 s/t) for 1.44 floppy
	 */
	movb $0x00, %dl
	movw $0x0800, %ax
	int $0x13
	movb $0x00, %ch
	movw %cx, sectors 

	movw $INITSEG, %ax
	movw %ax, %es

	/*
	 * print some inane messages
	 * now we want to load system sections(at 0x10000)
	 */
	pushw $21
	pushw $msg1
	call printrm
	addw $4, %sp
	
	movw $SYSSEG, %ax
	movw %ax, %es

	call read_system
	call shutdown_motor
	
	/* get root device */

	mov %cs:root_dev, %ax
	cmpw $0, %ax
	jne root_defined

	movw %cs:sectors, %bx

	movw $0x0208, %ax	/*/dev/ps0 - 1.2 Mb*/
	cmpw $15, %bx
	je root_defined

	movw $0x021c, %ax	/*/dev/PS0 - 1.44Mb*/
	cmpw $18, %bx
	je root_defined

/*die if root not defined or boot device is not ps0 or PS0*/
undef_root:
	jmp undef_root

root_defined:
	movw %ax, %cs:root_dev

	/*Debug*/
	pushw $4
	pushw $msg1+21
	call printrm
	addw $4, %sp

	ljmp $SETUPSEG, $0

die:
	jmp die

/*
 * We use the following rounte to load system sections at 0x10000
 * We also get the (18) sectors per track of device driver. 
 */

sread:	.word 1+SETUPLEN /* have read sectors in the track*/
head:	.word 0
track:	.word 0

read_system:
	movw %es, %ax
	test $0x0fff, %ax

	/* ensure es located at 64KB boundary */
	jne die

	/* We load system segment at es:bx */
	xorw %bx, %bx

/*
 * input is sread, head, track
 * output at es:bx, then offset head or track or sread
 */
rp_read:
	movw %es, %ax
	cmpw $ENDSEG, %ax
	jb ok1_read

	/* complete 196k read from boot device, return */

	ret

ok1_read:
	movw %cs:sectors, %ax
	subw sread, %ax
	movw %ax, %cx
	shl $9, %cx
	add %bx, %cx

	/*(%bx) <= 64kB*/
	jnc ok2_read
	je ok2_read

	/*(%bx) > 64kB*/
	xorw %ax, %ax
	subw %bx, %ax
	shr $9, %ax
	
	/*
	 * (ax) = sectors to read <= sectors per track
	 * (cx) = bytes to read (ax)* 512
	 */
ok2_read:
	call read_track

	movw %ax, %cx
	addw sread, %ax
	cmpw %cs:sectors, %ax
	jne ok3_read
	
	/* 
	 * here, all header's sectors in one track been loaded.
	 * if it's head=0, set (ax)=1
	 * jmp to ok4_read, set head=1, read another header 1(ax).
	 *
	 * if it's head=1, ax was substracted to been 0.
	 * then aet the track++ and head=0. 
	 */
	movw $1, %ax
	subw head, %ax
	jne ok4_read
	incw track
ok4_read:
	movw %ax, head
	xorw %ax, %ax
	
/* head or track maybe offseted */
ok3_read:

	/* 
	 * Ok, we have set the next read at (sread, head, track)
	 * then, compute the next es:bx loaded address
	 */
	movw %ax, sread
	shl $9, %cx
	addw %cx, %bx
	jnc rp_read
	
	/* es += 0x1000 bx = 0, */
	movw %es, %ax
	addw $0x1000, %ax
	movw %ax, %es

	xorw %bx, %bx
	jmp rp_read

/*
 * input ax
 */
read_track:
	pushw %ax
	pushw %bx
	pushw %cx
	pushw %dx

read_t:

	/* CL = begin sectors, CH = begin track */
	movw track, %dx
	movw sread, %cx
	incw %cx
	movb %dl, %ch

	/* DL = driver number, DH = begin header */
	movw head, %dx
	movb %dl, %dh
	movb $0, %dl
	andw $0x0100, %dx

	movb $2, %ah
	int $0x13
	jc bad_rt

	popw %dx
	popw %cx
	popw %bx
	popw %ax
	ret

bad_rt:
	/* reset the floppy, then read the track again */
	movw $0, %ax
	movw $0, %dx
	int $0x13
	jmp read_t

/*===================================================================*/

/*
 * This function just to shut down the floppy driver motor.
 * So we know that's state when enter the kernel.
 */ 

shutdown_motor:
	pushw %dx
	movw $0x3f2, %dx
	movb $0x00, %al
	outb %al, %dx
	popw %dx
	ret

/*
 * This is a function run in real mode.
 * I use it to print some debug message when booting system.
 */

printrm:
	pushw %bp
	movw %sp, %bp

	pushw %ax
	pushw %bx
	pushw %cx
	pushw %dx
	pushw %es

	movw $INITSEG, %ax
	movw %ax, %es
	movb $0x03, %ah
	xorb %bh, %bh
	int $0x10

	movw 6(%bp), %cx	/*string length*/
	movw $0x0007, %bx
	movw 4(%bp), %ax	/*string address*/
	pushw %bp
	movw %ax, %bp
	movw $0x1301, %ax
	int $0x10
	popw %bp

	popw %es
	popw %dx
	popw %cx
	popw %bx
	popw %ax
	popw %bp
	ret

sectors:
	.word 0
msg1:
	.ascii "\r\nLoading system ... OK\r\n"

.org 508
root_dev:
	.word ROOT_DEV
boot_flag:
	.word 0xAA55

