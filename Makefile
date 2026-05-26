ifndef KERNEL
KERNEL = /lib/modules/$(shell uname -r)/build
endif

CFLAGS_amibios_smi.o += -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0

obj-m += amibios_dmi.o
amibios_dmi-objs := amibios_smi.o amibios_sysfs.o

all: modules

modules clean:
	make -C $(KERNEL) M=$(shell pwd) $@

