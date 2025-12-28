#!/bin/bash

# TapIn PAM Deployment Script
# This script automates the deployment of the TapIn PAM system

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}TapIn PAM Module Deployment Script${NC}"
echo "=================================="

# Function to print status
print_status() {
    echo -e "${YELLOW}[*] $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}[!] $1${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    if command_exists apt-get; then
        # Ubuntu/Debian
        apt-get update
        apt-get install -y build-essential libpam0g-dev libjson-c-dev libssl-dev libbluetooth-dev
    elif command_exists dnf; then
        # Fedora/RHEL
        dnf install -y gcc make pam-devel json-c-devel openssl-devel bluez-devel
    elif command_exists yum; then
        # Older RHEL/CentOS
        yum install -y gcc make pam-devel json-c-devel openssl-devel bluez-devel
    else
        print_error "Unsupported package manager. Please install dependencies manually."
        print_error "Required: build-essential, libpam0g-dev, libjson-c-dev, libssl-dev, libbluetooth-dev"
        exit 1
    fi
    
    print_success "Dependencies installed"
}

# Function to build TapIn components
build_tapin() {
    print_status "Building TapIn components..."
    
    if [ ! -f "Makefile" ]; then
        print_error "Makefile not found. Please run this script from the TapIn_PAM directory."
        exit 1
    fi
    
    make clean
    make
    
    print_success "TapIn components built successfully"
}

# Function to install TapIn components
install_tapin() {
    print_status "Installing TapIn components..."
    make install
    print_success "TapIn components installed successfully"
}

# Function to generate shared secret
generate_shared_secret() {
    print_status "Generating shared secret..."
    
    if [ ! -f "/etc/tapin/shared_secret" ]; then
        mkdir -p /etc/tapin
        openssl rand -hex 32 > /etc/tapin/shared_secret
        chmod 600 /etc/tapin/shared_secret
        print_success "Shared secret generated and saved to /etc/tapin/shared_secret"
        print_status "IMPORTANT: Save this secret in your Flutter app configuration!"
    else
        print_status "Shared secret already exists at /etc/tapin/shared_secret"
    fi
}

# Function to start services
start_services() {
    print_status "Starting TapIn services..."
    systemctl daemon-reload
    systemctl enable tapin-helper.service tapin-bluetooth.service
    systemctl start tapin-helper.service tapin-bluetooth.service
    print_success "TapIn services started and enabled"
}

# Function to backup existing PAM config
backup_pam_config() {
    print_status "Checking existing PAM configurations..."
    
    # Backup existing configurations if they exist
    for config in gdm lightdm sddm login; do
        if [ -f "/etc/pam.d/$config" ]; then
            if [ ! -f "/etc/pam.d/$config.tapin.backup" ]; then
                cp "/etc/pam.d/$config" "/etc/pam.d/$config.tapin.backup"
                print_status "Backed up /etc/pam.d/$config to /etc/pam.d/$config.tapin.backup"
            fi
        fi
    done
}

# Function to configure PAM
configure_pam() {
    print_status "Configuring PAM for common login managers..."
    
    # Configure common PAM files
    for config in gdm lightdm sddm login; do
        if [ -f "/etc/pam.d/$config" ]; then
            # Check if TapIn PAM is already configured
            if ! grep -q "pam_tapin.so" "/etc/pam.d/$config"; then
                # Backup the original file
                cp "/etc/pam.d/$config" "/etc/pam.d/$config.tapin.backup"
                
                # Add TapIn PAM configuration (insert after auth section start or at the beginning of auth section)
                temp_file=$(mktemp)
                sed '/^auth/{
                    N
                    /auth.*sufficient/!{
                        i\
auth    sufficient    pam_tapin.so
                        s/$//
                    }
                    b end
                }
                /^auth/!b
                /^auth/{
                    /pam_tapin.so/!{
                        i\
auth    sufficient    pam_tapin.so
                    }
                }
                :end' "/etc/pam.d/$config" > "$temp_file"
                
                # If no auth line was found, just add at the beginning
                if ! grep -q "pam_tapin.so" "$temp_file"; then
                    sed '1i\
auth    sufficient    pam_tapin.so' "/etc/pam.d/$config" > "$temp_file"
                fi
                
                mv "$temp_file" "/etc/pam.d/$config"
                print_status "Configured /etc/pam.d/$config for TapIn"
            else
                print_status "/etc/pam.d/$config already configured for TapIn"
            fi
        else
            print_status "/etc/pam.d/$config not found, skipping"
        fi
    done
}

# Function to check service status
check_services() {
    print_status "Checking service status..."
    
    if systemctl is-active --quiet tapin-helper; then
        print_success "tapin-helper service is running"
    else
        print_error "tapin-helper service is not running"
    fi
    
    if systemctl is-active --quiet tapin-bluetooth; then
        print_success "tapin-bluetooth service is running"
    else
        print_error "tapin-bluetooth service is not running"
    fi
    
    if systemctl is-active --quiet bluetooth; then
        print_success "bluetooth service is running"
    else
        print_error "bluetooth service is not running - please start it: sudo systemctl start bluetooth"
    fi
}

# Function to display setup summary
display_summary() {
    echo
    echo -e "${GREEN}Deployment Summary${NC}"
    echo "=================="
    echo "✓ TapIn PAM module and daemons installed"
    echo "✓ Shared secret generated (saved to /etc/tapin/shared_secret)"
    echo "✓ Services enabled and started"
    echo "✓ PAM configuration updated for common login managers"
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Ensure your Bluetooth adapter is working: sudo systemctl status bluetooth"
    echo "2. Pair your mobile device with this Linux system"
    echo "3. Configure the same shared secret in your Flutter app"
    echo "4. Test the authentication flow"
    echo
    echo -e "${YELLOW}Configuration Files:${NC}"
    echo "- PAM module: /lib/security/libtapin_pam.so"
    echo "- Shared secret: /etc/tapin/shared_secret"
    echo "- Services: tapin-helper.service, tapin-bluetooth.service"
    echo "- PAM configs: /etc/pam.d/gdm, /etc/pam.d/lightdm, etc."
    echo
    echo -e "${YELLOW}To Test:${NC}"
    echo "Monitor logs: sudo journalctl -u tapin-bluetooth.service -f"
    echo "Check status: sudo make status-services"
}

# Main execution
main() {
    echo "This script will deploy the TapIn PAM system."
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Starting TapIn PAM deployment..."
        
        # Run deployment steps
        install_dependencies
        build_tapin
        install_tapin
        generate_shared_secret
        backup_pam_config
        configure_pam
        start_services
        check_services
        display_summary
        
        print_success "TapIn PAM deployment completed!"
    else
        print_status "Deployment cancelled."
        exit 0
    fi
}

# Run main function
main "$@"