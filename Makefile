
#$  make INSTALL_BIN=/my/different/path
INSTALL_BIN = /usr/bin
INSTALL_ETC = /etc/trip
INSTALL_MNT = /mnt/trip
LOCAL_ETC = ./etc-trip

CC     = gcc
DFLAGS = -D_POSIX_C_SOURCE=200112L -DTRIP_PATH=\"$(INSTALL_BIN)/trip.sh\"

CFLAGS = -g -Wextra -ansi -pedantic

OBJS = trip.o

EXEC  = trip

.PHONY: install-bin install uninstall-bin uninstall clean tgz

$(EXEC): $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o $(@)

trip.o: trip.c
	$(CC) -c $(CFLAGS) $(DFLAGS) trip.c -o $(@)

install-bin: $(EXEC)
	install -t $(INSTALL_BIN) $(EXEC) tripskel trip.sh

install: install-bin
	# Configs.
	install -d $(INSTALL_ETC)
	install -t $(INSTALL_ETC) $(LOCAL_ETC)/post_install.sh $(LOCAL_ETC)/post_uninstall.sh
	install -m u=rw,go=r -t $(INSTALL_ETC) $(LOCAL_ETC)/conf $(LOCAL_ETC)/exclude
	# Mount points.
	install -d $(INSTALL_MNT)/lfs $(INSTALL_MNT)/union $(INSTALL_MNT)/pkg

uninstall-bin:
	rm -f $(INSTALL_BIN)/$(EXEC) \
		$(INSTALL_BIN)/tripskel \
		$(INSTALL_BIN)/trip.sh

uninstall: uninstall-bin
	rm -f -d $(INSTALL_MNT)/lfs $(INSTALL_MNT)/union $(INSTALL_MNT)/pkg
	rm -f -d $(INSTALL_MNT)
	# You must manually remove the following:
	#   /etc/trip/       - Configs.
	#   /var/lib/trip/   - Metadata about installed packages.
	#   ???              - Any installed packages.

clean:
	rm -f $(OBJS) $(EXEC)

tgz:
	git archive --prefix=trip/ master | gzip > ../trip.tgz

