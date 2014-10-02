#
# if you want the ram-disk device, define this to be the
# size in blocks.
#
RAMDISK =  #-DRAMDISK=512
FDEBUG	= -g
AS	=as
LD	=ld
LDFLAGS	=-melf_i386 -Ttext=0x00 -e startup_32
CC	=gcc -m32 -march=i386 $(RAMDISK)
CFLAGS	=-Wall -O2 -fomit-frame-pointer $(FDEBUG)

CPP	=cpp -nostdinc -Iinclude

#
# ROOT_DEV specifies the default root-device when making the image.
# This can be either FLOPPY, /dev/xxxx or empty, in which case the
# default of /dev/hd6 is used by 'build'.
#
ROOT_DEV= #FLOPPY 

ARCHIVES=kernel/kernel.o mm/mm.o fs/fs.o
DRIVERS =kernel/blk_drv/blk_drv.a kernel/chr_drv/chr_drv.a
MATH	=kernel/math/math.a
LIBS	=lib/lib.a

.c.s:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -S -o $*.s $<
.s.o:
	$(AS) -march=i386 -o $*.o $<
.c.o:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -c -o $*.o $<

all:	Image

Image: boot/boot boot/setup tools/system
	objcopy -O binary tools/system tools/kernel
	objcopy -O binary boot/boot tools/boot
	objcopy -O binary boot/setup tools/setup
	dd conv=notrunc seek=0 count=1 if=tools/boot of=$@
	dd conv=notrunc seek=1 count=4 if=tools/setup of=$@
	dd conv=notrunc seek=5 if=tools/kernel of=$@
	ls -lh $@

disk: Image
	dd bs=8192 if=Image of=/dev/fd0


boot/head.o: boot/head.s
	$(AS) $(FDEBUG) --32 -march=i386+387 $< -o $@

tools/system:	boot/head.o init/main.o \
		$(ARCHIVES) $(DRIVERS) $(MATH) $(LIBS)
	$(LD) $(LDFLAGS) boot/head.o init/main.o \
	$(ARCHIVES) \
	$(DRIVERS) \
	$(MATH) \
	$(LIBS) \
	-o tools/system 
	nm tools/system | grep -v '\(compiled\)\|\(\.o$$\)\|\( [aU] \)\|\(\.\.ng$$\)\|\(LASH[RL]DI\)'| sort > System.map 

kernel/math/math.a:
	(cd kernel/math; make)

kernel/blk_drv/blk_drv.a:
	(cd kernel/blk_drv; make)

kernel/chr_drv/chr_drv.a:
	(cd kernel/chr_drv; make)

kernel/kernel.o:
	(cd kernel; make)

mm/mm.o:
	(cd mm; make)

fs/fs.o:
	(cd fs; make)

lib/lib.a:
	(cd lib; make)

boot/setup: boot/setup.s
	$(AS) --32 -o boot/setup.o boot/setup.s
	$(LD) -m elf_i386  -oformat=binary -Ttext=0x00 -o boot/setup boot/setup.o

boot/boot:	boot/boot.s
	$(AS) --32 -o boot/boot.o boot/boot.s
	$(LD) -m elf_i386  -oformat=binary -Ttext=0x00 -o boot/boot boot/boot.o

tmp.s:	boot/boot.s tools/system
	(echo -n "SYSSIZE = (";ls -l tools/system | grep system \
		| cut -c25-31 | tr '\012' ' '; echo "+ 15 ) / 16") > tmp.s
	cat boot/boot.s >> tmp.s

clean:
	rm -f System.map tmp_make core boot/boot boot/setup
	rm -f init/*.o tools/system tools/build boot/*.o
	rm -f tools/kernel tools/boot tools/setup
	(cd mm;make clean)
	(cd fs;make clean)
	(cd kernel;make clean)
	(cd lib;make clean)

backup: clean
	(cd .. ; tar cf - linux | compress16 - > backup.Z)
	sync

dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in init/*.c;do echo -n "init/";$(CPP) -M $$i;done) >> tmp_make
	cp tmp_make Makefile
	(cd fs; make dep)
	(cd kernel; make dep)
	(cd mm; make dep)

### Dependencies:
init/main.o: init/main.c include/unistd.h include/sys/stat.h \
  include/sys/types.h include/sys/times.h include/sys/utsname.h \
  include/utime.h include/time.h include/linux/tty.h include/termios.h \
  include/linux/sched.h include/linux/head.h include/linux/fs.h \
  include/linux/mm.h include/signal.h include/asm/system.h \
  include/asm/io.h include/stddef.h include/stdarg.h include/fcntl.h
