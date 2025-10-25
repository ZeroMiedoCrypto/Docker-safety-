PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

install:
	mkdir -p $(DESTDIR)$(BINDIR)
	install -m755 scripts/safeopen.sh $(DESTDIR)$(BINDIR)/safeopen

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/safeopen

.PHONY: install uninstall
