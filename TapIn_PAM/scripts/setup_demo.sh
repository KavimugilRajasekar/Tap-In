#!/bin/bash

# TapIn PAM Demo Setup Script
# This script demonstrates how to set up and test the TapIn PAM system

set -e  # Exit on any error

echo "TapIn PAM Module Demo Setup"
echo "============================"

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" 
        exit 1
    fi
}

# Function to generate a shared secret
generate_shared_secret() {
    echo "Generating shared secret..."
    SECRET=$(openssl rand -hex 32)
    echo "$SECRET" > /etc/tapin/shared_secret
    chmod 600 /etc/tapin/shared_secret
    echo "Shared secret generated and saved to /etc/tapin/shared_secret"
}

# Function to create a test token (for demonstration purposes)
create_test_token() {
    echo "Creating a test authentication token..."
    USERNAME="${1:-$(whoami)}"
    TOKEN=$(openssl rand -hex 16)
    EXPIRY=$(($(date +%s) + 120))  # 2 minutes from now
    
    echo "$USERNAME:$TOKEN:$EXPIRY" > /var/run/tapin_auth.token
    chmod 600 /var/run/tapin_auth.token
    echo "Test token created for user: $USERNAME"
    echo "Token will expire at: $(date -d @$EXPIRY)"
}

# Function to test PAM module (basic test)
test_pam_module() {
    echo "Testing PAM module installation..."
    if [ -f "/lib/security/libtapin_pam.so" ]; then
        echo "✓ PAM module found at /lib/security/libtapin_pam.so"
    else
        echo "✗ PAM module not found!"
        return 1
    fi
}

# Function to show system status
show_status() {
    echo
    echo "System Status:"
    echo "- PAM module: $(if [ -f /lib/security/libtapin_pam.so ]; then echo "INSTALLED"; else echo "NOT INSTALLED"; fi)"
    echo "- Shared secret: $(if [ -f /etc/tapin/shared_secret ]; then echo "CONFIGURED"; else echo "NOT CONFIGURED"; fi)"
    echo "- Test token: $(if [ -f /var/run/tapin_auth.token ]; then echo "PRESENT"; else echo "NOT PRESENT"; fi)"
    echo "- Bluetooth service: $(if systemctl is-active --quiet bluetooth; then echo "RUNNING"; else echo "NOT RUNNING"; fi)"
}

# Main menu
show_menu() {
    echo
    echo "Choose an option:"
    echo "1) Install TapIn PAM components"
    echo "2) Generate shared secret"
    echo "3) Create test token"
    echo "4) Test PAM module"
    echo "5) Show system status"
    echo "6) Clean up test files"
    echo "7) Exit"
    echo
}

# Main loop
while true; do
    show_menu
    read -p "Enter your choice (1-7): " choice
    
    case $choice in
        1)
            echo "Installing TapIn PAM components..."
            make install
            echo "Installation completed!"
            ;;
        2)
            check_root
            generate_shared_secret
            ;;
        3)
            check_root
            read -p "Enter username for test token (default: current user): " USERNAME
            create_test_token "$USERNAME"
            ;;
        4)
            test_pam_module
            ;;
        5)
            show_status
            ;;
        6)
            check_root
            echo "Cleaning up test files..."
            rm -f /var/run/tapin_auth.token
            echo "Test files cleaned up."
            ;;
        7)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done