# Makefile for TapIn PAM Module and Daemons

CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2 -D_GNU_SOURCE -I/usr/include/bluetooth
PAM_CFLAGS = -fPIC -DPAM_STATIC
LDFLAGS = -shared
PAM_LIBS = -lpam
DAEMON_LIBS = -lpam -ljson-c -lssl -lcrypto -lbluetooth

# Directories
SRCDIR = src
DAEMONDIR = daemon
CONFIGDIR = config
SCRIPTSDIR = scripts
BINDIR = bin

# Targets
PAM_MODULE = libtapin_pam.so
HELPER_DAEMON = tapin_helper
BLUETOOTH_DAEMON = bluetooth_listener

all: $(PAM_MODULE) $(HELPER_DAEMON) $(BLUETOOTH_DAEMON)

# Build the PAM module
$(PAM_MODULE): $(SRCDIR)/tapin_pam.c
	$(CC) $(CFLAGS) $(PAM_CFLAGS) $(LDFLAGS) -o $@ $< $(PAM_LIBS)

# Build the helper daemon
$(HELPER_DAEMON): $(DAEMONDIR)/tapin_helper.c
	$(CC) $(CFLAGS) -o $@ $< $(DAEMON_LIBS)

# Build the Bluetooth listener daemon
$(BLUETOOTH_DAEMON): $(DAEMONDIR)/bluetooth_listener.c
	$(CC) $(CFLAGS) -o $@ $< $(DAEMON_LIBS)

# Create necessary directories
directories:
	mkdir -p $(BINDIR)

# Install the PAM module to the system
install-pam: $(PAM_MODULE)
	sudo cp $(PAM_MODULE) /lib/security/
	sudo chmod 644 /lib/security/$(PAM_MODULE)

# Install the daemons
install-daemons: $(HELPER_DAEMON) $(BLUETOOTH_DAEMON)
	sudo cp $(HELPER_DAEMON) /usr/local/bin/
	sudo cp $(BLUETOOTH_DAEMON) /usr/local/bin/
	sudo chmod 755 /usr/local/bin/$(HELPER_DAEMON)
	sudo chmod 755 /usr/local/bin/$(BLUETOOTH_DAEMON)

# Install configuration files
install-config:
	sudo mkdir -p /etc/tapin
	sudo touch /etc/tapin/shared_secret
	sudo chmod 600 /etc/tapin/shared_secret
	sudo mkdir -p /etc/pam.d/
	sudo cp config/tapin /etc/pam.d/
	sudo chmod 644 /etc/pam.d/tapin
	sudo cp config/tapin-helper.service /etc/systemd/system/
	sudo cp config/tapin-bluetooth.service /etc/systemd/system/
	sudo chmod 644 /etc/systemd/system/tapin-helper.service
	sudo chmod 644 /etc/systemd/system/tapin-bluetooth.service
	sudo systemctl daemon-reload

# Install all components
install: all install-pam install-daemons install-config
	@echo "TapIn PAM module and daemons installed successfully!"
	@echo "Remember to configure PAM in your login manager."

# Create configuration files
config:
	mkdir -p $(CONFIGDIR)
	echo "# TapIn PAM Configuration" > $(CONFIGDIR)/tapin
	echo "auth    sufficient    pam_tapin.so" >> $(CONFIGDIR)/tapin
	echo "account required      pam_tapin.so" >> $(CONFIGDIR)/tapin

# Clean build artifacts
clean:
	rm -f $(PAM_MODULE) $(HELPER_DAEMON) $(BLUETOOTH_DAEMON)

# Uninstall (safely remove the installed files)
uninstall:
	-sudo systemctl stop tapin-helper.service tapin-bluetooth.service
	-sudo systemctl disable tapin-helper.service tapin-bluetooth.service
	-sudo rm -f /lib/security/$(PAM_MODULE)
	-sudo rm -f /usr/local/bin/$(HELPER_DAEMON)
	-sudo rm -f /usr/local/bin/$(BLUETOOTH_DAEMON)
	-sudo rm -f /etc/systemd/system/tapin-helper.service /etc/systemd/system/tapin-bluetooth.service
	-sudo rm -rf /etc/tapin
	-sudo rm -f /etc/pam.d/tapin
	-sudo systemctl daemon-reload
	@echo "TapIn PAM module and daemons uninstalled."

# Service management targets
start-services:
	sudo systemctl start tapin-helper.service tapin-bluetooth.service

stop-services:
	sudo systemctl stop tapin-helper.service tapin-bluetooth.service

restart-services:
	sudo systemctl restart tapin-helper.service tapin-bluetooth.service

enable-services:
	sudo systemctl enable tapin-helper.service tapin-bluetooth.service
	sudo systemctl start tapin-helper.service tapin-bluetooth.service

status-services:
	sudo systemctl status tapin-helper.service tapin-bluetooth.service

# Create a test target
test: all
	@echo "Build completed successfully!"
	@echo "PAM Module: $(PAM_MODULE)"
	@echo "Helper Daemon: $(HELPER_DAEMON)"
	@echo "Bluetooth Daemon: $(BLUETOOTH_DAEMON)"

.PHONY: all clean install install-pam install-daemons install-config install-config uninstall config test directories