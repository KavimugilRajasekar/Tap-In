/*
 * TapIn Helper Daemon
 * Processes authentication requests and generates temporary tokens
 * 
 * This daemon receives authentication data from the Bluetooth listener,
 * validates it, and creates a temporary authentication token file
 * that the PAM module can use for authentication.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <json-c/json.h>
#include <openssl/hmac.h>
#include <openssl/sha.h>
#include <sys/select.h>
#include <sys/un.h>
#include <sys/socket.h>

#define TOKEN_FILE "/var/run/tapin_auth.token"
#define SHARED_SECRET_FILE "/etc/tapin/shared_secret"
#define MAX_USERNAME_LENGTH 64
#define MAX_TOKEN_LENGTH 64
#define MAX_JSON_LENGTH 512
#define TOKEN_EXPIRY_SECONDS 20
#define SOCKET_PATH "/tmp/tapin_helper.sock"

// Global flag for signal handling
static volatile sig_atomic_t running = 1;

// Signal handler to gracefully stop the daemon
void signal_handler(int sig) {
    running = 0;
}

/*
 * Function to read the shared secret for HMAC verification
 */
char* read_shared_secret() {
    FILE *file;
    static char secret[256];
    size_t len;
    
    file = fopen(SHARED_SECRET_FILE, "r");
    if (!file) {
        syslog(LOG_ERR, "Could not open shared secret file: %s", strerror(errno));
        return NULL;
    }
    
    if (fgets(secret, sizeof(secret), file) == NULL) {
        fclose(file);
        syslog(LOG_ERR, "Could not read shared secret from file");
        return NULL;
    }
    
    fclose(file);
    
    // Remove trailing newline if present
    len = strlen(secret);
    if (len > 0 && secret[len-1] == '\n') {
        secret[len-1] = '\0';
    }
    
    return secret;
}

/*
 * Function to validate the HMAC signature
 */
int validate_hmac(const char* data, const char* received_hmac, const char* secret) {
    unsigned char* result;
    unsigned int len = EVP_MAX_MD_SIZE;
    char hex_result[EVP_MAX_MD_SIZE * 2 + 1];
    int i;
    
    result = HMAC(EVP_sha256(), secret, strlen(secret), (unsigned char*)data, strlen(data), NULL, &len);
    
    // Convert to hex string
    for (i = 0; i < len; i++) {
        sprintf(hex_result + (i * 2), "%02x", result[i]);
    }
    hex_result[len * 2] = '\0';
    
    // Use constant-time comparison to prevent timing attacks
    size_t hmac_len = strlen(received_hmac);
    if (strlen(hex_result) != hmac_len) {
        return 0; // Different lengths, not equal
    }
    
    // Perform constant-time comparison
    unsigned char result = 0;
    for (i = 0; i < hmac_len; i++) {
        result |= hex_result[i] ^ received_hmac[i];
    }
    return result == 0;
}

/*
 * Function to validate the authentication request
 */
int validate_auth_request(struct json_object* json_obj) {
    struct json_object *username_obj, *timestamp_obj, *nonce_obj, *hmac_obj;
    const char *username, *timestamp_str, *nonce, *hmac, *secret;
    long timestamp, current_time;
    char data_to_verify[256];
    
    // Extract fields from JSON
    if (!json_object_object_get_ex(json_obj, "username", &username_obj) ||
        !json_object_object_get_ex(json_obj, "timestamp", &timestamp_obj) ||
        !json_object_object_get_ex(json_obj, "nonce", &nonce_obj) ||
        !json_object_object_get_ex(json_obj, "hmac", &hmac_obj)) {
        syslog(LOG_ERR, "Missing required fields in authentication request");
        return 0;
    }
    
    username = json_object_get_string(username_obj);
    timestamp_str = json_object_get_string(timestamp_obj);
    nonce = json_object_get_string(nonce_obj);
    hmac = json_object_get_string(hmac_obj);
    
    if (!username || !timestamp_str || !nonce || !hmac) {
        syslog(LOG_ERR, "Invalid field types in authentication request");
        return 0;
    }
    
    // Convert timestamp to long
    timestamp = atol(timestamp_str);
    
    // Check timestamp validity (within 30 seconds)
    time(&current_time);
    if (abs(current_time - timestamp) > 30) {
        syslog(LOG_ERR, "Authentication request timestamp is too old or in the future");
        return 0;
    }
    
    // Read shared secret
    secret = read_shared_secret();
    if (!secret) {
        syslog(LOG_ERR, "Could not read shared secret for HMAC validation");
        return 0;
    }
    
    // Prepare data for HMAC verification (username:timestamp:nonce)
    snprintf(data_to_verify, sizeof(data_to_verify), "%s:%s:%s", username, timestamp_str, nonce);
    
    // Validate HMAC
    if (!validate_hmac(data_to_verify, hmac, secret)) {
        syslog(LOG_ERR, "HMAC validation failed for authentication request");
        return 0;
    }
    
    syslog(LOG_INFO, "Authentication request validated successfully for user: %s", username);
    return 1;
}

/*
 * Function to generate a random authentication token using /dev/urandom
 */
void generate_auth_token(char* token, size_t size) {
    const char charset[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    FILE *urandom;
    int i;
    int random_byte;
    
    // Open /dev/urandom for cryptographically secure random data
    urandom = fopen("/dev/urandom", "r");
    if (!urandom) {
        // Fallback to less secure method if /dev/urandom is not available
        syslog(LOG_WARNING, "Could not open /dev/urandom, using less secure random");
        time_t t;
        srand((unsigned) time(&t));
        
        for (i = 0; i < size - 1; i++) {
            int key = rand() % (int)(sizeof charset - 1);
            token[i] = charset[key];
        }
        token[size - 1] = '\0';
        return;
    }
    
    for (i = 0; i < size - 1; i++) {
        // Read a random byte and use it as an index
        if (fread(&random_byte, sizeof(random_byte), 1, urandom) == 1) {
            // Use the random byte to select a character from the charset
            int key = (unsigned char)random_byte % (int)(sizeof charset - 1);
            token[i] = charset[key];
        } else {
            // Fallback to a predictable character if random read fails
            token[i] = 'x';
        }
    }
    
    fclose(urandom);
    token[size - 1] = '\0';
}

/*
 * Function to create the authentication token file
 */
int create_auth_token_file(const char* username) {
    FILE *file;
    char token[MAX_TOKEN_LENGTH];
    time_t expiry_time;
    
    // Generate random token
    generate_auth_token(token, sizeof(token));
    
    // Calculate expiry time
    time(&expiry_time);
    expiry_time += TOKEN_EXPIRY_SECONDS;
    
    // Create token file
    file = fopen(TOKEN_FILE, "w");
    if (!file) {
        syslog(LOG_ERR, "Could not create token file: %s", strerror(errno));
        return 0;
    }
    
    fprintf(file, "%s:%s:%ld\n", username, token, expiry_time);
    fclose(file);
    
    // Set appropriate permissions (only root can read)
    chmod(TOKEN_FILE, 0600);
    
    syslog(LOG_INFO, "Authentication token created for user: %s, expires at: %ld", username, expiry_time);
    return 1;
}

/*
 * Main processing function
 */
int process_auth_request(const char* json_data) {
    struct json_object *json_obj;
    struct json_object *username_obj;
    const char *username;
    
    // Parse JSON
    json_obj = json_tokener_parse(json_data);
    if (!json_obj) {
        syslog(LOG_ERR, "Invalid JSON data received");
        return 0;
    }
    
    // Validate the request
    if (!validate_auth_request(json_obj)) {
        json_object_put(json_obj);
        return 0;
    }
    
    // Extract username for token creation
    json_object_object_get_ex(json_obj, "username", &username_obj);
    username = json_object_get_string(username_obj);
    
    // Create authentication token file
    int result = create_auth_token_file(username);
    
    // Clean up
    json_object_put(json_obj);
    
    return result;
}

/*
 * Function to create and listen on a Unix domain socket
 */
int setup_unix_socket() {
    int sock;
    struct sockaddr_un addr;
    
    // Remove existing socket if it exists
    unlink(SOCKET_PATH);
    
    // Create socket
    sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        syslog(LOG_ERR, "Failed to create Unix socket: %s", strerror(errno));
        return -1;
    }
    
    // Setup address structure
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);
    
    // Bind socket
    if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        syslog(LOG_ERR, "Failed to bind Unix socket: %s", strerror(errno));
        close(sock);
        return -1;
    }
    
    // Listen for connections
    if (listen(sock, 5) < 0) {
        syslog(LOG_ERR, "Failed to listen on Unix socket: %s", strerror(errno));
        close(sock);
        unlink(SOCKET_PATH);
        return -1;
    }
    
    // Set secure permissions for socket - only root and the daemon user can access
    chmod(SOCKET_PATH, 0600);
    
    return sock;
}

/*
 * Main function for the helper daemon
 * Listens for requests from the Bluetooth daemon via Unix socket
 */
int main(int argc, char *argv[]) {
    // Check if we're running in process mode (for direct execution from Bluetooth daemon)
    if (argc > 1 && strcmp(argv[1], "--process-auth-request") == 0) {
        // Read JSON from stdin
        char buffer[MAX_JSON_LENGTH];
        if (fgets(buffer, sizeof(buffer), stdin) != NULL) {
            if (process_auth_request(buffer)) {
                printf("Authentication processed successfully\n");
                return 0;
            } else {
                printf("Authentication failed\n");
                return 1;
            }
        }
        return 1;
    }
    
    // Open syslog
    openlog("tapin_helper", LOG_PID, LOG_DAEMON);
    
    syslog(LOG_INFO, "TapIn Helper Daemon starting");
    
    // Set up signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Setup Unix socket for communication with Bluetooth daemon
    int unix_sock = setup_unix_socket();
    if (unix_sock < 0) {
        syslog(LOG_ERR, "Failed to setup Unix socket");
        closelog();
        return 1;
    }
    
    syslog(LOG_INFO, "TapIn Helper Daemon listening on Unix socket: %s", SOCKET_PATH);
    
    fd_set readfds;
    
    // Main daemon loop
    while (running) {
        FD_ZERO(&readfds);
        FD_SET(unix_sock, &readfds);
        
        struct timeval timeout;
        timeout.tv_sec = 1;
        timeout.tv_usec = 0;
        
        int activity = select(unix_sock + 1, &readfds, NULL, NULL, &timeout);
        
        if (activity < 0) {
            if (errno != EINTR) {  // EINTR is expected during signal handling
                syslog(LOG_ERR, "Select error: %s", strerror(errno));
            }
            continue;
        }
        
        if (FD_ISSET(unix_sock, &readfds)) {
            // Accept connection
            int client_sock = accept(unix_sock, NULL, NULL);
            if (client_sock < 0) {
                syslog(LOG_ERR, "Accept error: %s", strerror(errno));
                continue;
            }
            
            // Read data from client
            char buffer[MAX_JSON_LENGTH];
            int bytes_read = read(client_sock, buffer, sizeof(buffer) - 1);
            if (bytes_read > 0) {
                buffer[bytes_read] = '\0';
                
                // Process the authentication request
                if (process_auth_request(buffer)) {
                    // Send success response
                    write(client_sock, "OK", 2);
                } else {
                    // Send error response
                    write(client_sock, "ERR", 3);
                }
            }
            
            close(client_sock);
        }
    }
    
    // Cleanup
    close(unix_sock);
    unlink(SOCKET_PATH);
    
    syslog(LOG_INFO, "TapIn Helper Daemon stopping");
    closelog();
    
    return 0;
}