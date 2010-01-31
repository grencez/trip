
INSTALL_BIN = /usr/bin
TRIP_SH = $(INSTALL_BIN)/trip.sh

CC     = gcc
DFLAGS = -D_POSIX_C_SOURCE=200112L -DTRIP_PATH=\"$(TRIP_SH)\"

CFLAGS = -g -Wall -ansi -pedantic
LFLAGS = 

EXEC  = trip

UNIV_OBJS =
OBJS = 

default: $(EXEC)
	# SUCCESS?

%.o: %.c %.h $(HDRS)
	$(CC) -c $(CFLAGS) $(DFLAGS) $(*).c -o $(*).o

%: $(UNIV_OBJS) %.c
	$(CC) $(CFLAGS) $(LFLAGS) $(DFLAGS) \
		$(UNIV_OBJS) $(@).c -o $(@)

.PHONY: install
install: $(EXEC)
	chmod u=rx,g=rx,o=rx $(EXEC)
	cp --preserve=mode $(EXEC) trip-skel.sh trip.sh $(INSTALL_BIN)


.PHONY: uninstall
uninstall:
	rm -f $(INSTALL_BIN)/$(EXEC) \
		$(INSTALL_BIN)/trip-skel.sh \
		$(TRIP_SH)

.PHONY: testpkg
testpkg:
	make clean
	\
		mdir=`pwd` \
		; pkname=testpkg-1.0 \
		; tmpdir=`mktemp -d` \
		; pkdir=$$tmpdir/$$pkname \
		\
		; mkdir $$pkdir \
		; cp Makefile trip.c trip.sh $$pkdir \
		; cd $$tmpdir \
		; tar c $$pkname | gzip > $${mdir}/$${pkname}.tar.gz \
		; cd $$mdir \
		; rm -r $$tmpdir
	tar c testpkg-1.0 | gzip > testpkg-1.0.trip.tar.gz

.PHONY: clean
clean:
	rm -f $(OBJS) $(EXEC) *.tar.gz



