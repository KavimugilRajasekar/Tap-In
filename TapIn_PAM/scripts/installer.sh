#!/bin/bash

# TapIn PAM Module and Daemons - Comprehensive Installer
# This script safely installs the TapIn authentication system with all dependencies
# and provides rollback capability in case of issues.

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="/tmp/tapin_backup_$(date +%s)"
LOG_FILE="/tmp/tapin_install.log"
CURRENT_USER="$(whoami)"
IS_ROOT=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        IS_ROOT=true
        print_status "Running as root user"
    else
        print_status "Running as regular user: $CURRENT_USER"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$NAME
        DISTRO_VERSION=$VERSION_ID
        DISTRO_ID=$ID
        print_status "Detected distribution: $DISTRO $DISTRO_VERSION ($DISTRO_ID)"
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
}

# Function to install dependencies based on distribution
install_dependencies() {
    print_status "Installing required dependencies..."
    
    case $DISTRO_ID in
        ubuntu|debian|linuxmint|pop|zorin)
            if [ "$IS_ROOT" = false ]; then
                print_status "Requesting sudo access for package installation..."
                sudo -v || exit 1
            fi
            
            print_status "Updating package lists..."
            if [ "$IS_ROOT" = true ]; then
                apt-get update
            else
                sudo apt-get update
            fi
            
            print_status "Installing dependencies..."
            DEPS="build-essential libpam0g-dev libjson-c-dev libssl-dev libbluetooth-dev pkg-config bluetooth"
            
            if [ "$IS_ROOT" = true ]; then
                apt-get install -y $DEPS
            else
                sudo apt-get install -y $DEPS
            fi
            ;;
        fedora|rhel|centos|rocky|almalinux)
            if [ "$IS_ROOT" = false ]; then
                print_status "Requesting sudo access for package installation..."
                sudo -v || exit 1
            fi
            
            print_status "Installing dependencies..."
            DEPS="gcc make pam-devel json-c-devel openssl-devel bluez-devel bluez"
            
            if [ "$IS_ROOT" = true ]; then
                dnf install -y $DEPS
            else
                sudo dnf install -y $DEPS
            fi
            ;;
        opensuse|sles)
            if [ "$IS_ROOT" = false ]; then
                print_status "Requesting sudo access for package installation..."
                sudo -v || exit 1
            fi
            
            print_status "Installing dependencies..."
            DEPS="gcc make pam-devel libjson-c-devel libopenssl-devel bluez-devel"
            
            if [ "$IS_ROOT" = true ]; then
                zypper install -y $DEPS
            else
                sudo zypper install -y $DEPS
            fi
            ;;
        arch|manjaro)
            if [ "$IS_ROOT" = false ]; then
                print_status "Requesting sudo access for package installation..."
                sudo -v || exit 1
            fi
            
            print_status "Installing dependencies..."
            DEPS="base-devel pam json-c openssl bluez bluez-utils"
            
            if [ "$IS_ROOT" = true ]; then
                pacman -S --noconfirm $DEPS
            else
                sudo pacman -S --noconfirm $DEPS
            fi
            ;;
        *)
            print_error "Unsupported distribution: $DISTRO_ID"
            print_warning "Please manually install the following dependencies:"
            print_warning "- build-essential (or gcc, make)"
            print_warning "- libpam0g-dev (or pam-devel)"
            print_warning "- libjson-c-dev (or json-c-devel)"
            print_warning "- libssl-dev (or openssl-devel)"
            print_warning "- libbluetooth-dev (or bluez-devel)"
            print_warning "- pkg-config"
            print_warning "- bluetooth service"
            exit 1
            ;;
    esac
    
    print_success "Dependencies installed successfully"
}

# Function to backup existing installation
backup_existing() {
    print_status "Creating backup of existing installation (if any)..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup PAM module
    if [ -f "/lib/security/libtapin_pam.so" ]; then
        cp "/lib/security/libtapin_pam.so" "$BACKUP_DIR/" 2>/dev/null || true
        print_status "Backed up existing PAM module"
    fi
    
    # Backup daemons
    if [ -f "/usr/local/bin/tapin_helper" ]; then
        cp "/usr/local/bin/tapin_helper" "$BACKUP_DIR/" 2>/dev/null || true
        print_status "Backed up existing helper daemon"
    fi
    
    if [ -f "/usr/local/bin/bluetooth_listener" ]; then
        cp "/usr/local/bin/bluetooth_listener" "$BACKUP_DIR/" 2>/dev/null || true
        print_status "Backed up existing Bluetooth daemon"
    fi
    
    # Backup config files
    if [ -d "/etc/tapin" ]; then
        cp -r "/etc/tapin" "$BACKUP_DIR/etc_tapin" 2>/dev/null || true
        print_status "Backed up existing TapIn config directory"
    fi
    
    # Backup PAM config
    if [ -f "/etc/pam.d/tapin" ]; then
        cp "/etc/pam.d/tapin" "$BACKUP_DIR/" 2>/dev/null || true
        print_status "Backed up existing PAM configuration"
    fi
    
    # Backup systemd services
    if [ -f "/etc/systemd/system/tapin-helper.service" ]; then
        cp "/etc/systemd/system/tapin-helper.service" "$BACKUP_DIR/" 2>/dev/null || true
        print_status "Backed up existing helper service"
    fi
    
    if [ -f "/etc/systemd/system/tapin-bluetooth.service" ]; then
        cp "/etc/systemd/system/tapin-bluetooth.service" "$BACKUP_DIR/" 2>/dev/null || true
        print_status "Backed up existing Bluetooth service"
    fi
    
    print_success "Backup completed successfully"
}

# Function to build the project
build_project() {
    print_status "Building TapIn PAM module and daemons..."
    
    cd "$PROJECT_ROOT"
    
    # Clean previous builds
    make clean 2>/dev/null || true
    
    # Build the project
    if make; then
        print_success "Build completed successfully"
        return 0
    else
        print_error "Build failed"
        return 1
    fi
}

# Function to install the binaries
install_binaries() {
    print_status "Installing TapIn binaries..."
    
    # Ensure target directories exist
    if [ "$IS_ROOT" = true ]; then
        mkdir -p /lib/security /usr/local/bin /etc/pam.d /etc/systemd/system
    else
        sudo mkdir -p /lib/security /usr/local/bin /etc/pam.d /etc/systemd/system
    fi
    
    # Install PAM module
    if [ "$IS_ROOT" = true ]; then
        cp "$PROJECT_ROOT/libtapin_pam.so" /lib/security/
        chmod 644 /lib/security/libtapin_pam.so
    else
        sudo cp "$PROJECT_ROOT/libtapin_pam.so" /lib/security/
        sudo chmod 644 /lib/security/libtapin_pam.so
    fi
    
    # Install daemons
    if [ "$IS_ROOT" = true ]; then
        cp "$PROJECT_ROOT/tapin_helper" /usr/local/bin/
        cp "$PROJECT_ROOT/bluetooth_listener" /usr/local/bin/
        chmod 755 /usr/local/bin/tapin_helper
        chmod 755 /usr/local/bin/bluetooth_listener
    else
        sudo cp "$PROJECT_ROOT/tapin_helper" /usr/local/bin/
        sudo cp "$PROJECT_ROOT/bluetooth_listener" /usr/local/bin/
        sudo chmod 755 /usr/local/bin/tapin_helper
        sudo chmod 755 /usr/local/bin/bluetooth_listener
    fi
    
    print_success "Binaries installed successfully"
}

# Function to install configuration files
install_config() {
    print_status "Installing configuration files..."
    
    # Create TapIn config directory
    if [ "$IS_ROOT" = true ]; then
        mkdir -p /etc/tapin
        touch /etc/tapin/shared_secret
        chmod 600 /etc/tapin/shared_secret
    else
        sudo mkdir -p /etc/tapin
        sudo touch /etc/tapin/shared_secret
        sudo chmod 600 /etc/tapin/shared_secret
    fi
    
    # Install PAM configuration
    if [ "$IS_ROOT" = true ]; then
        cp "$PROJECT_ROOT/config/tapin" /etc/pam.d/
        chmod 644 /etc/pam.d/tapin
    else
        sudo cp "$PROJECT_ROOT/config/tapin" /etc/pam.d/
        sudo chmod 644 /etc/pam.d/tapin
    fi
    
    # Install systemd services
    if [ "$IS_ROOT" = true ]; then
        cp "$PROJECT_ROOT/config/tapin-helper.service" /etc/systemd/system/
        cp "$PROJECT_ROOT/config/tapin-bluetooth.service" /etc/systemd/system/
        chmod 644 /etc/systemd/system/tapin-helper.service
        chmod 644 /etc/systemd/system/tapin-bluetooth.service
        systemctl daemon-reload
    else
        sudo cp "$PROJECT_ROOT/config/tapin-helper.service" /etc/systemd/system/
        sudo cp "$PROJECT_ROOT/config/tapin-bluetooth.service" /etc/systemd/system/
        sudo chmod 644 /etc/systemd/system/tapin-helper.service
        sudo chmod 644 /etc/systemd/system/tapin-bluetooth.service
        sudo systemctl daemon-reload
    fi
    
    print_success "Configuration files installed successfully"
}

# Function to generate shared secret
generate_shared_secret() {
    print_status "Generating shared secret for HMAC validation..."
    
    # Generate a random 32-byte hex string
    SHARED_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "$(tr -dc 'a-f0-9' < /dev/urandom | head -c 64)")
    
    if [ "$IS_ROOT" = true ]; then
        echo "$SHARED_SECRET" > /etc/tapin/shared_secret
        chmod 600 /etc/tapin/shared_secret
    else
        echo "$SHARED_SECRET" | sudo tee /etc/tapin/shared_secret >/dev/null
        sudo chmod 600 /etc/tapin/shared_secret
    fi
    
    print_success "Shared secret generated and saved to /etc/tapin/shared_secret"
    print_warning "IMPORTANT: Save this secret in your Flutter app for authentication to work:"
    echo "$SHARED_SECRET"
}

# Function to start and enable services
start_services() {
    print_status "Starting and enabling TapIn services..."
    
    if [ "$IS_ROOT" = true ]; then
        systemctl enable tapin-helper.service tapin-bluetooth.service
        systemctl start tapin-helper.service tapin-bluetooth.service
    else
        sudo systemctl enable tapin-helper.service tapin-bluetooth.service
        sudo systemctl start tapin-helper.service tapin-bluetooth.service
    fi
    
    # Wait a moment for services to start
    sleep 2
    
    # Check service status
    if [ "$IS_ROOT" = true ]; then
        if systemctl is-active --quiet tapin-helper.service && systemctl is-active --quiet tapin-bluetooth.service; then
            print_success "Services started successfully"
        else
            print_error "Services failed to start properly"
            systemctl status tapin-helper.service tapin-bluetooth.service
            return 1
        fi
    else
        if sudo systemctl is-active --quiet tapin-helper.service && sudo systemctl is-active --quiet tapin-bluetooth.service; then
            print_success "Services started successfully"
        else
            print_error "Services failed to start properly"
            sudo systemctl status tapin-helper.service tapin-bluetooth.service
            return 1
        fi
    fi
}

# Function to verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Check if binaries exist
    if [ ! -f "/lib/security/libtapin_pam.so" ]; then
        print_error "PAM module not found at /lib/security/libtapin_pam.so"
        return 1
    fi
    
    if [ ! -f "/usr/local/bin/tapin_helper" ]; then
        print_error "Helper daemon not found at /usr/local/bin/tapin_helper"
        return 1
    fi
    
    if [ ! -f "/usr/local/bin/bluetooth_listener" ]; then
        print_error "Bluetooth daemon not found at /usr/local/bin/bluetooth_listener"
        return 1
    fi
    
    # Check if config files exist
    if [ ! -f "/etc/pam.d/tapin" ]; then
        print_error "PAM configuration not found at /etc/pam.d/tapin"
        return 1
    fi
    
    if [ ! -f "/etc/tapin/shared_secret" ]; then
        print_error "Shared secret not found at /etc/tapin/shared_secret"
        return 1
    fi
    
    # Check if services are running
    if [ "$IS_ROOT" = true ]; then
        if ! systemctl is-active --quiet tapin-helper.service; then
            print_error "tapin-helper service is not running"
            return 1
        fi
        
        if ! systemctl is-active --quiet tapin-bluetooth.service; then
            print_error "tapin-bluetooth service is not running"
            return 1
        fi
    else
        if ! sudo systemctl is-active --quiet tapin-helper.service; then
            print_error "tapin-helper service is not running"
            return 1
        fi
        
        if ! sudo systemctl is-active --quiet tapin-bluetooth.service; then
            print_error "tapin-bluetooth service is not running"
            return 1
        fi
    fi
    
    print_success "Installation verified successfully"
}

# Function to display setup summary
display_summary() {
    print_success "TapIn PAM installation completed successfully!"
    echo
    print_status "Installation Summary:"
    print_status "  - PAM module: /lib/security/libtapin_pam.so"
    print_status "  - Helper daemon: /usr/local/bin/tapin_helper"
    print_status "  - Bluetooth daemon: /usr/local/bin/bluetooth_listener"
    print_status "  - PAM config: /etc/pam.d/tapin"
    print_status "  - Shared secret: /etc/tapin/shared_secret"
    print_status "  - Services: tapin-helper.service, tapin-bluetooth.service"
    echo
    print_status "Next steps:"
    print_status "  1. Configure your login manager to use the 'tapin' PAM service"
    print_status "  2. Pair your mobile device with this Linux system via Bluetooth"
    print_status "  3. Configure the same shared secret in your Flutter app"
    print_status "  4. Test the authentication flow"
    echo
    print_warning "IMPORTANT: The shared secret for HMAC validation has been generated."
    print_warning "         You must configure the same secret in your Flutter app."
    echo
    print_status "To test the services:"
    print_status "  - Check status: sudo systemctl status tapin-helper.service tapin-bluetooth.service"
    print_status "  - View logs: sudo journalctl -u tapin-helper.service -f"
    print_status "  - View logs: sudo journalctl -u tapin-bluetooth.service -f"
    echo
    print_status "For rollback, run: sudo $0 --uninstall"
}

# Function to uninstall TapIn
uninstall() {
    print_status "Uninstalling TapIn PAM module and daemons..."
    
    # Stop and disable services
    if [ "$IS_ROOT" = true ]; then
        systemctl stop tapin-helper.service tapin-bluetooth.service 2>/dev/null || true
        systemctl disable tapin-helper.service tapin-bluetooth.service 2>/dev/null || true
    else
        sudo systemctl stop tapin-helper.service tapin-bluetooth.service 2>/dev/null || true
        sudo systemctl disable tapin-helper.service tapin-bluetooth.service 2>/dev/null || true
    fi
    
    # Remove files
    if [ "$IS_ROOT" = true ]; then
        rm -f /lib/security/libtapin_pam.so
        rm -f /usr/local/bin/tapin_helper
        rm -f /usr/local/bin/bluetooth_listener
        rm -f /etc/pam.d/tapin
        rm -rf /etc/tapin
        rm -f /etc/systemd/system/tapin-helper.service
        rm -f /etc/systemd/system/tapin-bluetooth.service
        systemctl daemon-reload
    else
        sudo rm -f /lib/security/libtapin_pam.so
        sudo rm -f /usr/local/bin/tapin_helper
        sudo rm -f /usr/local/bin/bluetooth_listener
        sudo rm -f /etc/pam.d/tapin
        sudo rm -rf /etc/tapin
        sudo rm -f /etc/systemd/system/tapin-helper.service
        sudo rm -f /etc/systemd/system/tapin-bluetooth.service
        sudo systemctl daemon-reload
    fi
    
    print_success "TapIn PAM module and daemons uninstalled successfully!"
}

# Function to rollback from backup
rollback() {
    print_status "Rolling back installation from backup..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "No backup found at $BACKUP_DIR"
        return 1
    fi
    
    # Restore PAM module
    if [ -f "$BACKUP_DIR/libtapin_pam.so" ]; then
        if [ "$IS_ROOT" = true ]; then
            cp "$BACKUP_DIR/libtapin_pam.so" /lib/security/
        else
            sudo cp "$BACKUP_DIR/libtapin_pam.so" /lib/security/
        fi
        print_status "Restored PAM module"
    fi
    
    # Restore daemons
    if [ -f "$BACKUP_DIR/tapin_helper" ]; then
        if [ "$IS_ROOT" = true ]; then
            cp "$BACKUP_DIR/tapin_helper" /usr/local/bin/
            chmod 755 /usr/local/bin/tapin_helper
        else
            sudo cp "$BACKUP_DIR/tapin_helper" /usr/local/bin/
            sudo chmod 755 /usr/local/bin/tapin_helper
        fi
        print_status "Restored helper daemon"
    fi
    
    if [ -f "$BACKUP_DIR/bluetooth_listener" ]; then
        if [ "$IS_ROOT" = true ]; then
            cp "$BACKUP_DIR/bluetooth_listener" /usr/local/bin/
            chmod 755 /usr/local/bin/bluetooth_listener
        else
            sudo cp "$BACKUP_DIR/bluetooth_listener" /usr/local/bin/
            sudo chmod 755 /usr/local/bin/bluetooth_listener
        fi
        print_status "Restored Bluetooth daemon"
    fi
    
    # Restore config files
    if [ -d "$BACKUP_DIR/etc_tapin" ]; then
        if [ "$IS_ROOT" = true ]; then
            rm -rf /etc/tapin
            cp -r "$BACKUP_DIR/etc_tapin" /etc/tapin
        else
            sudo rm -rf /etc/tapin
            sudo cp -r "$BACKUP_DIR/etc_tapin" /etc/tapin
        fi
        print_status "Restored TapIn config directory"
    fi
    
    # Restore PAM config
    if [ -f "$BACKUP_DIR/tapin" ]; then
        if [ "$IS_ROOT" = true ]; then
            cp "$BACKUP_DIR/tapin" /etc/pam.d/
            chmod 644 /etc/pam.d/tapin
        else
            sudo cp "$BACKUP_DIR/tapin" /etc/pam.d/
            sudo chmod 644 /etc/pam.d/tapin
        fi
        print_status "Restored PAM configuration"
    fi
    
    # Restore systemd services
    if [ -f "$BACKUP_DIR/tapin-helper.service" ]; then
        if [ "$IS_ROOT" = true ]; then
            cp "$BACKUP_DIR/tapin-helper.service" /etc/systemd/system/
            chmod 644 /etc/systemd/system/tapin-helper.service
        else
            sudo cp "$BACKUP_DIR/tapin-helper.service" /etc/systemd/system/
            sudo chmod 644 /etc/systemd/system/tapin-helper.service
        fi
        print_status "Restored helper service"
    fi
    
    if [ -f "$BACKUP_DIR/tapin-bluetooth.service" ]; then
        if [ "$IS_ROOT" = true ]; then
            cp "$BACKUP_DIR/tapin-bluetooth.service" /etc/systemd/system/
            chmod 644 /etc/systemd/system/tapin-bluetooth.service
        else
            sudo cp "$BACKUP_DIR/tapin-bluetooth.service" /etc/systemd/system/
            sudo chmod 644 /etc/systemd/system/tapin-bluetooth.service
        fi
        print_status "Restored Bluetooth service"
    fi
    
    if [ "$IS_ROOT" = true ]; then
        systemctl daemon-reload
    else
        sudo systemctl daemon-reload
    fi
    
    print_success "Rollback completed successfully"
    print_warning "You may need to restart services manually if they were running"
}

# Main installation function
main_install() {
    print_status "Starting TapIn PAM installation..."
    print_status "Project root: $PROJECT_ROOT"
    print_status "Log file: $LOG_FILE"
    echo
    
    check_root
    detect_distro
    install_dependencies
    backup_existing
    build_project
    install_binaries
    install_config
    generate_shared_secret
    start_services
    verify_installation
    display_summary
    
    print_success "Installation completed successfully!"
}

# Parse command line arguments
case "${1:-}" in
    --uninstall)
        if [ "$EUID" -ne 0 ]; then
            print_error "Uninstall requires root privileges"
            print_status "Run: sudo $0 --uninstall"
            exit 1
        fi
        uninstall
        ;;
    --rollback)
        if [ "$EUID" -ne 0 ]; then
            print_error "Rollback requires root privileges"
            print_status "Run: sudo $0 --rollback"
            exit 1
        fi
        rollback
        ;;
    --help|-h)
        echo "TapIn PAM Module and Daemons Installer"
        echo
        echo "Usage:"
        echo "  $0                    Install TapIn PAM module and daemons"
        echo "  $0 --uninstall        Uninstall TapIn PAM module and daemons"
        echo "  $0 --rollback         Rollback to previous installation (if backup exists)"
        echo "  $0 --help             Show this help message"
        echo
        echo "This script will:"
        echo "  1. Install required dependencies"
        echo "  2. Build the TapIn PAM module and daemons"
        echo "  3. Install binaries to system locations"
        echo "  4. Configure PAM and systemd services"
        echo "  5. Generate shared secret for HMAC validation"
        echo "  6. Start and enable services"
        echo
        echo "The installation is safe and includes rollback capability."
        ;;
    "")
        # Check if already running as root for installation
        if [ "$EUID" -eq 0 ]; then
            print_warning "Running installer as root is not recommended for security"
            print_status "It's safer to run as a regular user with sudo access"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Installation cancelled"
                exit 0
            fi
        fi
        
        main_install
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac