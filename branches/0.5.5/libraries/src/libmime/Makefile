# Needs to be linked with GLib2.

CPPFLAGS = `pkg-config glib-2.0 --cflags` `getconf LFS_CFLAGS` # -g3

OS_TARGET = linux

ifndef CPU_TARGET
  CPU_TARGET = $(shell uname -i)
  ifeq ($(CPU_TARGET),unknown)
    CPU_TARGET = $(shell uname -m)
  endif
endif

ifeq ($(CPU_TARGET),x86_64)
  CPPFLAGS += -m64
else ifeq ($(CPU_TARGET),i386)
  CPPFLAGS += -m32
else ifeq ($(CPU_TARGET),armv7l)
  CPU_TARGET = arm
else
  $(error Invalid target CPU)
endif

all: clean libmime

clean:
	rm -f *.o *.a *.so.*

libmime: mime-action.o mime-cache.o mime-type.o mime-util.o
	$(AR) rc libmime.a *.o
	mkdir -p ../../$(CPU_TARGET)-$(OS_TARGET)
	cp libmime.a ../../$(CPU_TARGET)-$(OS_TARGET)
# shared library:
#	$(CC) -shared -Wl,-soname,libmime.so.1 -o libmime.so.1.0.1 libmime.a
#	ln -s libmime.so.1 libmime.so
