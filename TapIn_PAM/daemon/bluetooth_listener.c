/*
 * TapIn Bluetooth Listener Daemon
 * Listens for authentication requests from the mobile app via Bluetooth
 * 
 * This daemon listens on a Bluetooth RFCOMM socket for authentication requests
 * from the TapIn mobile application and forwards them to the helper daemon.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <bluetooth/bluetooth.h>
#include <bluetooth/rfcomm.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <sys/un.h>
#include <json-c/json.h>
#include <sys/wait.h>

#define MAX_BUFFER_SIZE 1024
#define SERVICE_NAME "TapIn Authentication Service"
#define SERVICE_UUID "00001101-0000-1000-8000-00805f9b34fb"  // Standard Serial Port Profile UUID
#define SOCKET_PATH "/tmp/tapin_helper.sock"

// Function to check if a Bluetooth device is paired/trusted
int is_device_paired(const char* device_address) {
    char command[256];
    int result;
    
    // Command to check if the device is paired using bluetoothctl
    snprintf(command, sizeof(command), 
            "timeout 5 bluetoothctl info %s 2>/dev/null | grep -q 'Paired: yes' && echo 1 || echo 0");
    
    // For security, we replace the device address in the command template
    char actual_command[256];
    snprintf(actual_command, sizeof(actual_command), 
            "timeout 5 bluetoothctl info %s 2>/dev/null | grep -q 'Paired: yes' && echo 1 || echo 0", 
            device_address);
    
    // Execute the command and capture output
    FILE* pipe = popen(actual_command, "r");
    if (!pipe) {
        syslog(LOG_ERR, "Failed to execute bluetoothctl command");
        return 0;
    }
    
    char result_str[10];
    if (fgets(result_str, sizeof(result_str), pipe) != NULL) {
        result = atoi(result_str);
    } else {
        result = 0;
    }
    
    pclose(pipe);
    
    return result;
}

// Global flag for signal handling
static volatile sig_atomic_t running = 1;

// Signal handler to gracefully stop the daemon
void signal_handler(int sig) {
    running = 0;
}

/*
 * Function to validate authentication request JSON format
 */
int validate_auth_request_format(const char* data) {
    json_object *json_obj;
    struct json_object *username_obj, *timestamp_obj, *nonce_obj, *hmac_obj;
    
    // Parse the JSON data
    json_obj = json_tokener_parse(data);
    if (!json_obj) {
        syslog(LOG_ERR, "Invalid JSON format in authentication request");
        return 0;
    }
    
    // Check for required fields
    if (!json_object_object_get_ex(json_obj, "username", &username_obj) ||
        !json_object_object_get_ex(json_obj, "timestamp", &timestamp_obj) ||
        !json_object_object_get_ex(json_obj, "nonce", &nonce_obj) ||
        !json_object_object_get_ex(json_obj, "hmac", &hmac_obj)) {
        syslog(LOG_ERR, "Missing required fields in authentication request");
        json_object_put(json_obj);
        return 0;
    }
    
    // Validate field types
    if (!json_object_is_type(username_obj, json_type_string) ||
        !json_object_is_type(timestamp_obj, json_type_string) ||
        !json_object_is_type(nonce_obj, json_type_string) ||
        !json_object_is_type(hmac_obj, json_type_string)) {
        syslog(LOG_ERR, "Invalid field types in authentication request");
        json_object_put(json_obj);
        return 0;
    }
    
    // Validate field lengths to prevent buffer overflows
    const char *username = json_object_get_string(username_obj);
    const char *timestamp_str = json_object_get_string(timestamp_obj);
    const char *nonce = json_object_get_string(nonce_obj);
    const char *hmac = json_object_get_string(hmac_obj);
    
    if (strlen(username) > 64 || strlen(timestamp_str) > 20 || 
        strlen(nonce) > 64 || strlen(hmac) > 128) {
        syslog(LOG_ERR, "Authentication request fields too long");
        json_object_put(json_obj);
        return 0;
    }
    
    // Clean up
    json_object_put(json_obj);
    
    syslog(LOG_INFO, "Authentication request format validation passed");
    return 1;
}

/*
 * Function to send data to the helper daemon via Unix socket
 */
int send_to_helper_daemon(const char* data) {
    int sock;
    struct sockaddr_un addr;
    int result;
    char response[32];
    ssize_t bytes_received;
    
    // Create socket
    sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        syslog(LOG_ERR, "Failed to create Unix socket for helper daemon communication: %s", strerror(errno));
        return 0;
    }
    
    // Setup address structure
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);
    
    // Connect to the helper daemon
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        syslog(LOG_ERR, "Failed to connect to helper daemon socket: %s", strerror(errno));
        close(sock);
        return 0;
    }
    
    // Send the data
    if (write(sock, data, strlen(data)) < 0) {
        syslog(LOG_ERR, "Failed to send data to helper daemon: %s", strerror(errno));
        close(sock);
        return 0;
    }
    
    // Receive response
    bytes_received = read(sock, response, sizeof(response) - 1);
    if (bytes_received < 0) {
        syslog(LOG_ERR, "Failed to read response from helper daemon: %s", strerror(errno));
        close(sock);
        return 0;
    }
    
    response[bytes_received] = '\0';
    
    // Close socket
    close(sock);
    
    // Check response
    if (strncmp(response, "OK", 2) == 0) {
        syslog(LOG_INFO, "Helper daemon processed authentication request successfully");
        return 1; // Success
    } else {
        syslog(LOG_ERR, "Helper daemon failed to process authentication request: %s", response);
        return 0; // Failure
    }
}

/*
 * Function to process received authentication data
 * Forwards the data to the helper daemon via Unix socket
 */
int process_auth_data(const char* data) {
    // Log the received data
    syslog(LOG_INFO, "Received authentication data: %s", data);
    
    // Validate the authentication request format
    if (!validate_auth_request_format(data)) {
        syslog(LOG_ERR, "Authentication request format validation failed");
        return 0;
    }
    
    // Forward to helper daemon via Unix socket
    return send_to_helper_daemon(data);
}

/*
 * Main function for the Bluetooth listener daemon
 */
int main(int argc, char *argv[]) {
    int sock, client_sock;
    struct sockaddr_rc addr = {0}, client_addr = {0};
    socklen_t opt = sizeof(client_addr);
    char buffer[MAX_BUFFER_SIZE];
    int bytes_read;
    
    // Open syslog
    openlog("tapin_bluetooth", LOG_PID, LOG_DAEMON);
    
    syslog(LOG_INFO, "TapIn Bluetooth Listener Daemon starting");
    
    // Set up signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Create socket
    sock = socket(AF_BLUETOOTH, SOCK_STREAM, BTPROTO_RFCOMM);
    if (sock < 0) {
        syslog(LOG_ERR, "Failed to create Bluetooth socket: %s", strerror(errno));
        closelog();
        return 1;
    }
    
    // Bind socket to port 1
    addr.rc_family = AF_BLUETOOTH;
    addr.rc_bdaddr = *BDADDR_ANY;
    addr.rc_channel = 1;
    
    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        syslog(LOG_ERR, "Failed to bind Bluetooth socket: %s", strerror(errno));
        close(sock);
        closelog();
        return 1;
    }
    
    // Start listening
    if (listen(sock, 1) < 0) {
        syslog(LOG_ERR, "Failed to listen on Bluetooth socket: %s", strerror(errno));
        close(sock);
        closelog();
        return 1;
    }
    
    syslog(LOG_INFO, "TapIn Bluetooth Listener listening on channel 1");
    
    // Main daemon loop
    while (running) {
        // Accept a connection
        client_sock = accept(sock, (struct sockaddr *)&client_addr, &opt);
        
        if (client_sock < 0) {
            if (running) {  // Only log error if not shutting down
                syslog(LOG_ERR, "Failed to accept Bluetooth connection: %s", strerror(errno));
            }
            continue;
        }
        
        // Get the client's Bluetooth address
        char client_address[18];
        ba2str(&client_addr.rc_bdaddr, client_address);
        syslog(LOG_INFO, "Connection accepted from: %s", client_address);
        
        // Verify that the connecting device is paired/trusted
        if (!is_device_paired(client_address)) {
            syslog(LOG_WARNING, "Unpaired device attempted connection: %s", client_address);
            close(client_sock);
            continue;  // Skip processing for unpaired devices
        }
        
        syslog(LOG_INFO, "Paired device verified: %s", client_address);
        
        // Read data from the client
        memset(buffer, 0, sizeof(buffer));
        bytes_read = read(client_sock, buffer, sizeof(buffer) - 1);
        
        if (bytes_read > 0) {
            buffer[bytes_read] = '\0';
            syslog(LOG_INFO, "Received %d bytes from %s", bytes_read, client_address);
            
            // Process the received authentication data
            if (process_auth_data(buffer)) {
                syslog(LOG_INFO, "Authentication data processed successfully");
                
                // Send acknowledgment back to client
                const char* ack_msg = "ACK";
                write(client_sock, ack_msg, strlen(ack_msg));
            } else {
                syslog(LOG_ERR, "Failed to process authentication data");
                
                // Send error message back to client
                const char* error_msg = "ERR";
                write(client_sock, error_msg, strlen(error_msg));
            }
        } else if (bytes_read == 0) {
            syslog(LOG_INFO, "Client disconnected: %s", client_address);
        } else {
            syslog(LOG_ERR, "Error reading from client %s: %s", client_address, strerror(errno));
        }
        
        // Close client socket
        close(client_sock);
    }
    
    // Close server socket
    close(sock);
    
    syslog(LOG_INFO, "TapIn Bluetooth Listener Daemon stopping");
    closelog();
    
    return 0;
}