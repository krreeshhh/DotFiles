CC ?= gcc
CFLAGS ?= -O2 -fPIC
TARGET = libnautilus-theme-reloader.so
INSTALL_DIR = /usr/lib/nautilus/extensions-4

all: $(TARGET)

$(TARGET): nautilus-theme-reloader.c
	$(CC) -shared $(CFLAGS) $$(pkg-config --cflags --libs libnautilus-extension-4 gtk4) $< -o $@

install: $(TARGET)
	install -Dm755 $(TARGET) $(INSTALL_DIR)/$(TARGET)

clean:
	rm -f $(TARGET)
