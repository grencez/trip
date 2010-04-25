
#$  make INSTALL_BIN=/my/different/path
INSTALL_BIN = /usr/bin

CC     = gcc
DFLAGS = -D_POSIX_C_SOURCE=200112L -DTRIP_PATH=\"$(INSTALL_BIN)/trip.sh\"

CFLAGS = -g -Wall -ansi -pedantic

OBJS = trip.o

EXEC  = trip

$(EXEC): $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o $(@)
	chmod u=rx,g=rx,o=rx $(@)

trip.o:
	$(CC) -c $(CFLAGS) $(DFLAGS) trip.c -o $(@)

.PHONY: install
install: $(EXEC)
	cp --preserve=mode $(EXEC) trip-skel.sh trip.sh $(INSTALL_BIN)


.PHONY: uninstall
uninstall:
	rm -f $(INSTALL_BIN)/$(EXEC) \
		$(INSTALL_BIN)/trip-skel.sh \
		$(INSTALL_BIN)/trip.sh

.PHONY: clean
clean:
	rm -f $(OBJS) $(EXEC)

.PHONY: tgz
tgz:
	git archive --prefix=trip/ master | gzip > ../trip.tgz

