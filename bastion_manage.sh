#!/usr/bin/env bash
#
# Copyright (c) 2025. All rights reserved.
#
# Name: bastion_manage.sh
# Version: 1.2.4
# Author: Mstaaravin
# Contributors: Developed with assistance from Claude AI
# Description: Comprehensive OCI Cloud bastion management script
#              Creates, lists and manages OCI bastions and sessions
#              Compatible with OCI CLI
#              Now with SSH config integration for easy access
#
# =================================================================
# OCI Bastion Script Management Tool
# =================================================================
#
# DESCRIPTION:
#   This script provides a unified interface to manage Oracle Cloud Infrastructure (OCI)
#   bastion services. It combines creation, listing, and management of bastions
#   and sessions in a single tool with hierarchical commands.
#
#   Features include:
#   - Creating new bastion services with customizable parameters
#   - Creating new bastion sessions (SSH and Port Forwarding)
#   - Listing bastions in a compartment
#   - Listing active sessions for a bastion
#   - Showing detailed information about bastions and sessions
#   - Automatic SSH config generation for easy access to targets
#
#   NOTE: This script uses the OCI CLI authentication configuration
#   located at ~/.oci/config for authentication with OCI services.
#   Make sure this file is properly configured before using the script.
#
#   For a complete documentation of the OCI Bastion service, refer to:
#   https://docs.oracle.com/en-us/iaas/tools/oci-cli/3.54.4/oci_cli_docs/cmdref/bastion/bastion/create.html or
#   https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/bastion/bastion/create.html
#
# USAGE:
#   ./bastion_manage.sh <verb> <object> [options]
#
# VERBS:
#   create    Create a new resource (bastion or session)
#   list      List resources (bastions or sessions)
#   show      Show detailed information about a resource
#   help      Show help information
#
# OBJECTS:
#   bastion   OCI bastion service
#   session   OCI bastion session
#
# OPTIONS:
#   For detailed options for each command, run:
#   ./bastion_manage.sh help <verb> <object>
#   Example: ./bastion_manage.sh help create bastion
#
# COMMON PARAMETERS:
#   -r, --region REGION        Specify OCI Region (default: configured region)
#   -p, --profile PROFILE      Specify OCI Profile to use (default: DEFAULT)
#   --debug                    Enable debug mode for detailed information
#   -h, --help                 Show help for the specific command
#
# CREATE BASTION OPTIONS:
#   -c, --compartment-id OCID  Compartment OCID (required)
#   -n, --name NAME            Bastion name (required)
#   -s, --target-subnet-id OCID Target subnet OCID (required)
#   -v, --vcn-id OCID          VCN OCID (recommended for validation)
#   --client-cidr CIDR         Client CIDR blocks allowed (default: 0.0.0.0/0)
#   --max-session-ttl SECONDS  Maximum session TTL in seconds (default: 10800)
#
# CREATE SESSION OPTIONS:
#   -b, --bastion-id OCID      Bastion OCID (required)
#   -n, --name NAME            Session name (required)
#   -t, --target-ip IP         Target private IP address (required)
#   -p, --port PORT            Target port (default: 22)
#   --type TYPE                Session type (SSH or PORT_FORWARDING, default: SSH)
#   --ttl SECONDS              Session TTL in seconds (default: 3600)
#   --key-type TYPE            Key type (PUB or PEM, default: PUB)
#   --key-file PATH            Public key file (default: ~/.ssh/id_rsa.pub)
#
# SSH CONFIG OPTIONS:
#   --ssh-config-dir DIR       Directory for SSH config files (default: ~/.ssh/config.d)
#   --ssh-identity-file FILE   SSH identity file (default: ~/.ssh/id_rsa)
#   --ssh-config-enabled       Enable SSH config generation (default)
#   --ssh-config-disabled      Disable SSH config generation
#
# EXAMPLES:
#   # Create a new bastion: (requires compartment OCID, subnet OCID)
#   ./bastion_manage.sh create bastion -c ocid1.compartment.oc1..example -n my-bastion -s ocid1.subnet.oc1.example
#
#   # Create a new SSH session: (requires VM OCID, target IP and OS user)
#   ./bastion_manage.sh create session -b ocid1.bastion.oc1..example -n my-session -t 10.0.0.25
#
#   # Create a port forwarding session: (requires target IP and port)
#   ./bastion_manage.sh create session -b ocid1.bastion.oc1..example -n db-session -t 10.0.0.30 \
#     -p 1521 --type PORT_FORWARDING --ttl 7200
#
#   # Create an SSH session with custom key file: (requires bastion OCID, target IP, OS user, key file and name session)
#   ./bastion_manage.sh create session -b ocid1.bastion.oc1..example -n secure-session \
#     -t 10.0.0.25 --key-file ~/.ssh/custom_key.pub
#
#   # List all bastions in a compartment:
#   ./bastion_manage.sh list bastion -c ocid1.compartment.oc1..example
#
#   # List all bastions across all accessible compartments:
#   ./bastion_manage.sh list bastion --all
#
#   # List all sessions for a bastion: (you need to know previously created bastion OCID)
#   ./bastion_manage.sh list session -b ocid1.bastion.oc1.region.xxxx
#
#   # Show detailed information for a bastion:
#   ./bastion_manage.sh show bastion -b ocid1.bastion.oc1.region.xxxx
#
#   # Show detailed information for a session by name:
#   ./bastion_manage.sh show session -b ocid1.bastion.oc1.region.xxxx -s "my-session-name"
#
#   # Show detailed information for a session by ID:
#   ./bastion_manage.sh show session -b ocid1.bastion.oc1.region.xxxx -i ocid1.bastionsession.oc1.region.xxxx
#
#   # Get help for a specific command:
#   ./bastion_manage.sh help create bastion
#   ./bastion_manage.sh help list session
#


# Global variables as specified
OCI_REGION="sa-santiago-1"
COMPARTMENT_OCID="ocid1.compartment.oc1..aaaaaaaajzeqkclqbyj7pwwl5wjqefwmwttctrmzzrzfadci7anrwwqtgcvq"
TARGET_SUBNET_OCID="ocid1.subnet.oc1.sa-santiago-1.aaaaaaaaxgdlro2hsj5h3t6ikzo7fs7behz63jhwxpvvejhhle5qcpfjrb2a"
BASTION_NAME="bastion01"
CLIENT_CIDR="0.0.0.0/0"
MAX_SESSION_TTL=10800
OCI_PROFILE="DEFAULT"
BASTION_OCID=""
SHOW_SESSION=""

# Additional variables for session management
SESSION_NAME="session04"
TARGET_RESOURCE_OCID="ocid1.instance.oc1.sa-santiago-1.anzwgljrb4w7ojacpcovxr7zm7llulu5464z3twive5bept7bn3w7fc6swaq"
TARGET_OS_USER="opc"
PUBLIC_KEY_FILE="~/.ssh/carlmira.pub"
TARGET_IP="10.0.1.243"
TARGET_PORT=22
SESSION_TYPE="SSH"
SESSION_TTL=1800
SESSION_OCID=""
KEY_TYPE="PUB"

# SSH config variables
SSH_CONFIG_DIR="$HOME/.ssh/config.d"
SSH_IDENTITY_FILE="$HOME/.ssh/carlmira"
SSH_CONFIG_DOMAIN="host.bastion.%REGION%.oci.oraclecloud.com"  # %REGION% will be replaced automatically
SSH_CONFIG_PREFIX="oci_bastion"                                # Prefix for configuration files
SSH_CONFIG_ENABLED=true                                        # Flag to enable/disable this feature

# Additional required variables
DEBUG_MODE=false
VERB=""
OBJECT=""


# Check if OCI config exists
if [ ! -f ~/.oci/config ]; then
    echo "Error: OCI configuration file not found at ~/.oci/config"
    echo "Please make sure the OCI CLI is installed and configured properly."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this script. Please install it."
    exit 1
fi

# Check if oci CLI is installed
if ! command -v oci &> /dev/null; then
    echo "Error: OCI CLI is required for this script. Please install it."
    exit 1
fi

# Function to show main script usage
show_main_usage() {
    echo "Usage: $0 <verb> <object> [options]"
    echo ""
    echo "Verbs:"
    echo "  create    Create a new resource (bastion or session)"
    echo "  list      List resources (bastions or sessions)"
    echo "  show      Show detailed information about a resource"
    echo "  help      Show help information"
    echo ""
    echo "Objects:"
    echo "  bastion   OCI bastion service"
    echo "  session   OCI bastion session"
    echo ""
    echo "For detailed help on a specific command:"
    echo "  $0 help <verb> <object>"
    echo "  Example: $0 help create bastion"
}

# Debug function
debug() {
    if [ "$DEBUG_MODE" = true ]; then
        echo "[DEBUG] $1"
    fi
}

# Debug the exact command that will be executed
debug_command() {
    if [ "$DEBUG_MODE" = true ]; then
        echo "[DEBUG] Executing command: $1"
    fi
}

# Validate OCIDs (basic format checking)
validate_ocid() {
    local ocid="$1"
    local name="$2"
    
    if [[ ! "$ocid" =~ ^ocid1\.[a-z-]+\.[a-z0-9-]+\.[a-z0-9-]+\..+ ]]; then
        echo "Warning: $name OCID format may be incorrect."
        echo "Expected format: ocid1.resource-type.region.id"
        echo "Provided: $ocid"
        read -p "Continue anyway? (y/n): " confirm_ocid
        if [[ $confirm_ocid != [yY] && $confirm_ocid != [yY][eE][sS] ]]; then
            echo "Operation cancelled."
            exit 0
        fi
    fi
}

# Function to verify OCI CLI authentication
verify_oci_auth() {
    echo "Verifying OCI CLI authentication..."
    OCI_TEST=$(oci iam region list --profile "$OCI_PROFILE" --all 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error: OCI CLI authentication failed:"
        echo "$OCI_TEST"
        echo "Please check your OCI configuration and credentials."
        exit 1
    fi
}

#
# SSH CONFIG FUNCTIONS
#

# Function to ensure SSH config directories exist
ensure_ssh_config_dirs() {
    # Ensure ~/.ssh exists
    if [ ! -d "$HOME/.ssh" ]; then
        debug "Creating ~/.ssh directory"
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
    fi
    
    # Ensure ~/.ssh/config exists
    if [ ! -f "$HOME/.ssh/config" ]; then
        debug "Creating empty ~/.ssh/config file"
        touch "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
    fi
    
    # Ensure ~/.ssh/config.d directory exists
    if [ ! -d "$SSH_CONFIG_DIR" ]; then
        debug "Creating $SSH_CONFIG_DIR directory"
        mkdir -p "$SSH_CONFIG_DIR"
        chmod 700 "$SSH_CONFIG_DIR"
    fi
}

# Function to ensure Include directive exists at the beginning of the main config file
update_main_ssh_config() {
    local config_file_name="${SSH_CONFIG_PREFIX}_$1"
    local include_line="Include $SSH_CONFIG_DIR/${config_file_name}"
    
    # Convert to a form usable in grep (escape dots and other special chars)
    local grep_pattern=$(echo "${config_file_name}" | sed 's/\./\\./g')
    
    # Check if the Include directive already exists
    if grep -q "${grep_pattern}" "$HOME/.ssh/config"; then
        debug "Include directive already exists in ~/.ssh/config"
        
        # Check if it's at the end of the file
        if [ "$(tail -1 "$HOME/.ssh/config")" = "$include_line" ]; then
            debug "Include directive found at the end of the file. Moving it to the beginning..."
            
            # Remove the line from the end
            sed -i "/${grep_pattern}/d" "$HOME/.ssh/config"
            
            # Now continue with adding it to the beginning
        else
            # It exists but not at the end, so just return
            return 0
        fi
    fi
    
    debug "Adding Include directive to the beginning of ~/.ssh/config"
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # First line: OCI Bastion header if it doesn't exist
    echo "# OCI Bastion Sessions" > "$temp_file"
    
    # Second line: The Include directive
    echo "$include_line" >> "$temp_file"
    
    # Third line: blank line
    echo "" >> "$temp_file"
    
    # Now append the rest of the SSH config file
    # But first, check if the first line is already the OCI Bastion header
    local first_line=$(head -1 "$HOME/.ssh/config")
    if [ "$first_line" = "# OCI Bastion Sessions" ]; then
        # Skip the first line when appending
        tail -n +2 "$HOME/.ssh/config" >> "$temp_file"
    else
        cat "$HOME/.ssh/config" >> "$temp_file"
    fi
    
    # Replace the original file with our temp file
    cp "$temp_file" "$HOME/.ssh/config"
    rm "$temp_file"
    
    # Fix permissions
    chmod 600 "$HOME/.ssh/config"
    
    debug "Added include directive at the beginning of ~/.ssh/config: $include_line"
    
    return 0
}

# Function to create SSH config file for a bastion session
create_ssh_config_file() {
    local session_name="$1"
    local session_id="$2"
    local target_ip="$3"
    local target_port="${4:-22}"
    local bastion_host="$5"
    local identity_file="${6:-$SSH_IDENTITY_FILE}"
    local target_user="${7:-opc}"
    
    # Create unique config file name based on session ID (last 8 chars)
    local short_id="${session_id: -8}"
    local config_file_name="${SSH_CONFIG_PREFIX}_${short_id}"
    local config_file_path="$SSH_CONFIG_DIR/$config_file_name"
    

    # Validate that we have a proper bastion_host
    if [ -z "$bastion_host" ]; then
        echo "Error: Cannot create SSH config without bastion host."
        return 1
    fi

    # Remove any trailing quotes or special characters
    bastion_host=$(echo "$bastion_host" | tr -d '"' | tr -d "'" | tr -d ';')

    # For security, basic validation of parameters
    if [[ ! "$session_id" =~ ^ocid1\.[a-z]+\.[a-z0-9\.-]+\.[a-z0-9\.-]+\..+ ]]; then
        echo "Warning: Session ID doesn't appear to be a valid OCID format."
    fi
    
    if [[ ! "$target_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Warning: Target IP doesn't appear to be in valid format. Using anyway."
    fi
    
    debug "Creating SSH config file: $config_file_path"
    
    # Create the config file with all necessary options
    cat > "$config_file_path" << EOF
# OCI Bastion SSH Config for Session: $session_name (ID: $short_id)
# Created: $(date)
# Target: $target_ip:$target_port

Host bastion-$short_id
    HostName $bastion_host
    User $session_id
    IdentityFile $identity_file
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    LogLevel ERROR

Host target-$short_id
    HostName $target_ip
    User $target_user
    Port $target_port
    ProxyJump bastion-$short_id
    IdentityFile $identity_file
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    LogLevel ERROR
EOF

    # Set proper permissions
    chmod 600 "$config_file_path"
    
    # Update the main SSH config to include this file
    update_main_ssh_config "$short_id"
    
    echo "SSH config created: $config_file_path"
    echo "You can connect directly using: ssh target-$short_id"
    
    return 0
}


# Function to extract bastion host from SSH command
extract_bastion_host() {
    local ssh_command="$1"
    
    # For commands with ProxyCommand, extract the host from inside it
    if [[ "$ssh_command" == *"ProxyCommand"* ]]; then
        # Extract the full hostname after the @ symbol and before any space, quote or other char
        local host=$(echo "$ssh_command" | grep -o -E "@[^[:space:]\"]+[[:space:]]+" | sed 's/^@//g' | sed 's/[[:space:]]*$//g' | head -1)
        
        # If we found a host, return it
        if [ -n "$host" ]; then
            echo "$host"
            return 0
        fi
    fi
    
    # If we get here, try a more general approach
    # Look for a pattern that resembles a bastion hostname
    local host=$(echo "$ssh_command" | grep -o -E "host\.bastion\.[a-z0-9\.-]+\.oci\.oraclecloud\.com" | head -1)
    
    # If found, return it
    if [ -n "$host" ]; then
        echo "$host"
        return 0
    fi
    
    # Last resort fallback - try to get anything that might be a hostname
    local host=$(echo "$ssh_command" | grep -o -E "[a-zA-Z0-9][a-zA-Z0-9\.-]+\.[a-zA-Z]{2,}" | grep -v "ssh-" | head -1)
    
    echo "$host"
}


# Function to extract user ID from SSH command
extract_user_id() {
    local ssh_command="$1"
    
    # Try to extract user from an SSH command
    local user=$(echo "$ssh_command" | grep -o -E "[^[:space:]]+@" | sed 's/@$//')
    
    echo "$user"
}


# Function to setup SSH config for a session
setup_ssh_config() {
    local session_name="$1"
    local session_id="$2"
    local ssh_command="$3"
    local target_ip="$4"
    local target_port="${5:-22}"
    local target_user="${6:-opc}"
    
    # Only proceed if SSH config is enabled
    if [ "$SSH_CONFIG_ENABLED" != "true" ]; then
        debug "SSH config generation is disabled."
        return 0
    fi
    
    # Ensure directories exist
    ensure_ssh_config_dirs
    
    # Extract bastion host from SSH command
    local bastion_host=$(extract_bastion_host "$ssh_command")
    
    # If we couldn't extract the host, we can't continue
    if [ -z "$bastion_host" ]; then
        echo "Warning: Could not extract bastion host from SSH command."
        echo "SSH config file was not created."
        return 1
    fi
    
    # Debug the extracted host
    debug "Extracted bastion host: $bastion_host"
    
    # Extract user ID if not provided (for completeness)
    if [ -z "$session_id" ]; then
        session_id=$(extract_user_id "$ssh_command")
        if [ -z "$session_id" ]; then
            echo "Warning: Could not extract session ID from SSH command."
            echo "SSH config file was not created."
            return 1
        fi
    fi
    
    # Debug the extracted user ID
    debug "Using session ID: $session_id"
    
    # Create the SSH config file
    create_ssh_config_file "$session_name" "$session_id" "$target_ip" "$target_port" "$bastion_host" "$SSH_IDENTITY_FILE" "$target_user"
    
    return $?
}



# Function to show SSH config options in help
show_ssh_config_options() {
    echo "SSH Config Options:"
    echo "  --ssh-config-dir DIR        SSH config directory (default: $SSH_CONFIG_DIR)"
    echo "  --ssh-identity-file FILE    SSH identity file (default: $SSH_IDENTITY_FILE)"
    echo "  --ssh-config-domain DOMAIN  SSH config domain (default: $SSH_CONFIG_DOMAIN)"
    echo "  --ssh-config-prefix PREFIX  SSH config file prefix (default: $SSH_CONFIG_PREFIX)"
    echo "  --ssh-config-enabled        Enable SSH config generation (default: $SSH_CONFIG_ENABLED)"
    echo "  --ssh-config-disabled       Disable SSH config generation"
}

#
# CREATE BASTION FUNCTIONS
#

# Function to show create bastion usage
show_create_bastion_usage() {
    echo "Usage: $0 create bastion [options]"
    echo "Options:"
    echo "  -c, --compartment-id OCID  Compartment OCID where bastion will be created (required)"
    echo "  -n, --name NAME            Name for the bastion (required)"
    echo "  -v, --vcn-id OCID          VCN OCID for validation and information (optional, but recommended)"
    echo "  -s, --target-subnet-id OCID Subnet OCID where bastion will be created (required)"
    echo "  --client-cidr CIDR         Client CIDR blocks allowed (default: $CLIENT_CIDR)"
    echo "  --max-session-ttl SECONDS  Maximum session TTL in seconds (default: $MAX_SESSION_TTL)"
    echo "  -r, --region REGION        OCI Region (default: configured region)"
    echo "  -p, --profile PROFILE      OCI Profile to use (default: $OCI_PROFILE)"
    echo "  --debug                    Enable debug mode to show detailed information"
    echo "  -h, --help                 Show this help message"
}

# Function to create a bastion
create_bastion() {
    # Process arguments for create bastion command
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -c|--compartment-id)
                COMPARTMENT_OCID="$2"
                shift 2
                ;;
            -n|--name)
                BASTION_NAME="$2"
                shift 2
                ;;
            -v|--vcn-id)
                VCN_ID="$2"
                shift 2
                ;;
            -s|--target-subnet-id)
                TARGET_SUBNET_OCID="$2"
                shift 2
                ;;
            --client-cidr)
                CLIENT_CIDR="$2"
                shift 2
                ;;
            --max-session-ttl)
                MAX_SESSION_TTL="$2"
                shift 2
                ;;
            -r|--region)
                OCI_REGION="$2"
                shift 2
                ;;
            -p|--profile)
                OCI_PROFILE="$2"
                shift 2
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_create_bastion_usage
                exit 0
                ;;
            *)
                echo "Unknown option for create bastion command: $1"
                show_create_bastion_usage
                exit 1
                ;;
        esac
    done
    
    # Check required parameters
    if [ -z "$COMPARTMENT_OCID" ]; then
        echo "Error: Compartment ID (-c, --compartment-id) is required."
        show_create_bastion_usage
        exit 1
    fi

    if [ -z "$BASTION_NAME" ]; then
        echo "Error: Bastion name (-n, --name) is required."
        show_create_bastion_usage
        exit 1
    fi

    if [ -z "$VCN_ID" ]; then
        echo "Warning: VCN ID (-v, --vcn-id) is not provided."
        echo "While not required by the OCI CLI, it is recommended for validation."
        echo "The VCN will be inferred from the subnet."
        read -p "Continue without VCN validation? (y/n): " confirm_vcn
        if [[ $confirm_vcn != [yY] && $confirm_vcn != [yY][eE][sS] ]]; then
            echo "Bastion creation cancelled."
            exit 0
        fi
    fi

    if [ -z "$TARGET_SUBNET_OCID" ]; then
        echo "Error: Target subnet ID (-s, --target-subnet-id) is required."
        show_create_bastion_usage
        exit 1
    fi
    
    # Verify OCI CLI and authentication
    verify_oci_auth
    
    # Check if client CIDR format is correct
    if [[ ! "$CLIENT_CIDR" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "Warning: Client CIDR '$CLIENT_CIDR' might not be in the correct format."
        echo "Expected format: x.x.x.x/x (e.g., 0.0.0.0/0 or 10.0.0.0/16)"
        read -p "Continue anyway? (y/n): " confirm_cidr
        if [[ $confirm_cidr != [yY] && $confirm_cidr != [yY][eE][sS] ]]; then
            echo "Bastion creation cancelled."
            exit 0
        fi
    fi

    # If multiple CIDR blocks are provided, format them properly for the API
    if [[ "$CLIENT_CIDR" == *","* ]]; then
        # Create a proper JSON array with quoted elements
        IFS=',' read -ra CIDR_BLOCKS <<< "$CLIENT_CIDR"
        client_cidr_json='['
        for i in "${!CIDR_BLOCKS[@]}"; do
            # Add comma if not the first element
            if [ "$i" -gt 0 ]; then
                client_cidr_json+=','
            fi
            # Trim whitespace and add quotes
            client_cidr_json+='"'$(echo "${CIDR_BLOCKS[$i]}" | xargs)'"'
        done
        client_cidr_json+=']'
    else
        # Single CIDR block
        client_cidr_json='["'"$CLIENT_CIDR"'"]'
    fi
    
    # Validate OCIDs
    validate_ocid "$COMPARTMENT_OCID" "Compartment"
    if [ -n "$VCN_ID" ]; then
        validate_ocid "$VCN_ID" "VCN"
    fi
    validate_ocid "$TARGET_SUBNET_OCID" "Target Subnet"
    
    # Prepare region parameter
    region_param=""
    if [ -n "$OCI_REGION" ]; then
        region_param="--region $OCI_REGION"
    fi
    
    # Show summary of bastion to be created
    echo "Creating bastion with the following configuration:"
    echo "  Name: $BASTION_NAME"
    echo "  Compartment ID: $COMPARTMENT_OCID"
    if [ -n "$VCN_ID" ]; then
        echo "  VCN ID: $VCN_ID (for information only, not used by CLI)"
    fi
    echo "  Target Subnet: $TARGET_SUBNET_OCID"
    echo "  Client CIDR: $(echo "$client_cidr_json" | sed 's/^\[//' | sed 's/\]$//' | sed 's/"//g')"
    echo "  Max Session TTL: $MAX_SESSION_TTL seconds"
    echo "  OCI Profile: $OCI_PROFILE"
    if [ -n "$OCI_REGION" ]; then
        echo "  Region: $OCI_REGION"
    else
        echo "  Region: [default from profile]"
    fi
    
    # Confirm creation
    read -p "Continue with bastion creation? (y/n): " confirm
    if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
        echo "Bastion creation cancelled."
        exit 0
    fi
    
    # Debug command
    debug "Formatted CIDR JSON: $client_cidr_json"
    debug_command "oci bastion bastion create --compartment-id \"$COMPARTMENT_OCID\" --bastion-type \"STANDARD\" --target-subnet-id \"$TARGET_SUBNET_OCID\" --client-cidr-list '$client_cidr_json' --max-session-ttl \"$MAX_SESSION_TTL\" --name \"$BASTION_NAME\" --profile \"$OCI_PROFILE\" $region_param"
    
    # Create the bastion with parameters
    echo "Creating bastion..."
    BASTION_OUTPUT=$(oci bastion bastion create \
        --compartment-id "$COMPARTMENT_OCID" \
        --bastion-type "STANDARD" \
        --target-subnet-id "$TARGET_SUBNET_OCID" \
        --client-cidr-list "$client_cidr_json" \
        --max-session-ttl "$MAX_SESSION_TTL" \
        --name "$BASTION_NAME" \
        --profile "$OCI_PROFILE" \
        $region_param 2>&1)
    
    # Check for errors
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo "Error creating bastion."
        echo "Error details:"
        echo "$BASTION_OUTPUT"
        exit 1
    fi
    
    # Extract and print the bastion OCID
    BASTION_OCID=$(echo "$BASTION_OUTPUT" | jq -r '.data.id' 2>/dev/null)
    if [ -z "$BASTION_OCID" ] || [ "$BASTION_OCID" == "null" ]; then
        echo "Warning: Could not extract bastion OCID from the response."
        echo "Full response:"
        echo "$BASTION_OUTPUT"
        exit 1
    fi
    
    echo "Bastion creation initiated."
    echo "Bastion OCID: $BASTION_OCID"
    
    # Wait for the bastion to become active (optional)
    echo "Waiting for bastion to become active..."
    MAX_WAIT_SECONDS=300
    WAITED_SECONDS=0
    INTERVAL=10
    
    while [ $WAITED_SECONDS -lt $MAX_WAIT_SECONDS ]; do
        BASTION_INFO=$(oci bastion bastion get \
            --bastion-id "$BASTION_OCID" \
            --profile "$OCI_PROFILE" \
            $region_param 2>&1)
            
        if [ $? -ne 0 ]; then
            echo "Error getting bastion status:"
            echo "$BASTION_INFO"
            exit 1
        fi
        
        BASTION_STATE=$(echo "$BASTION_INFO" | jq -r '.data."lifecycle-state"' 2>/dev/null)
        
        if [ "$BASTION_STATE" == "ACTIVE" ]; then
            echo "Bastion is now ACTIVE."
            break
        elif [ "$BASTION_STATE" == "FAILED" ]; then
            echo "Bastion creation failed."
            echo "Full status:"
            echo "$BASTION_INFO" | jq '.data'
            exit 1
        fi
        
        echo "Current state: $BASTION_STATE. Waiting $INTERVAL more seconds..."
        sleep $INTERVAL
        WAITED_SECONDS=$((WAITED_SECONDS + INTERVAL))
    done
    
    if [ $WAITED_SECONDS -ge $MAX_WAIT_SECONDS ]; then
        echo "Warning: Timed out waiting for bastion to become active."
        echo "Please check the bastion status manually."
    fi
    
    # Display final bastion information
    echo "========================================"
    echo "Bastion created successfully!"
    echo "========================================"
    echo "Name: $BASTION_NAME"
    echo "OCID: $BASTION_OCID"
    echo "State: $BASTION_STATE"
    echo "========================================"
    echo "Use these commands to manage this bastion:"
    echo "$0 list session -b $BASTION_OCID"
    echo "$0 show bastion -b $BASTION_OCID"
    echo "========================================"
}


#
# CREATE SESSION FUNCTIONS
#

# Function to show create session usage
show_create_session_usage() {
    echo "Usage: $0 create session [options]"
    echo "Options:"
    echo "  -b, --bastion-id OCID      Bastion OCID (required)"
    echo "  -n, --name NAME            Session display name (required)"
    echo "  -t, --target-ip IP         Target private IP address (required for PORT_FORWARDING)"
    echo "  -p, --port PORT            Target port (default: $TARGET_PORT)"
    echo "  --type TYPE                Session type (SSH or PORT_FORWARDING, default: $SESSION_TYPE)"
    echo "  --ttl SECONDS              Session time-to-live in seconds (minimum: 1800, default: $SESSION_TTL)"
    echo "  --key-type TYPE            Key type (PUB or PEM, default: $KEY_TYPE)"
    echo "  --key-file PATH            Public key file (default: $PUBLIC_KEY_FILE)"
    echo "  --target-id OCID           Target compute instance OCID (required for SSH sessions)"
    echo "  --target-user USER         Target OS username (default: $TARGET_OS_USER, required for SSH sessions)"
    echo "  -r, --region REGION        OCI Region (default: configured region)"
    echo "  --profile PROFILE          OCI Profile to use (default: $OCI_PROFILE)"
    echo "  --debug                    Enable debug mode to show detailed information"
    echo "  -h, --help                 Show this help message"
    echo ""
    show_ssh_config_options
}


# Function to create a session
create_session() {
    # Process arguments for create session command
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -b|--bastion-id)
                BASTION_OCID="$2"
                shift 2
                ;;
            -n|--name)
                SESSION_NAME="$2"
                shift 2
                ;;
            -t|--target-ip)
                TARGET_IP="$2"
                shift 2
                ;;
            -p|--port)
                TARGET_PORT="$2"
                shift 2
                ;;
            --type)
                SESSION_TYPE="$2"
                shift 2
                ;;
            --ttl)
                SESSION_TTL="$2"
                shift 2
                ;;
            --key-type)
                KEY_TYPE="$2"
                shift 2
                ;;
            --key-file)
                PUBLIC_KEY_FILE="$2"
                shift 2
                ;;
            --target-id)
                TARGET_RESOURCE_OCID="$2"
                shift 2
                ;;
            --target-user)
                TARGET_OS_USER="$2"
                shift 2
                ;;
            -r|--region)
                OCI_REGION="$2"
                shift 2
                ;;
            --profile)
                OCI_PROFILE="$2"
                shift 2
                ;;
            --ssh-config-dir)
                SSH_CONFIG_DIR="$2"
                shift 2
                ;;
            --ssh-identity-file)
                SSH_IDENTITY_FILE="$2"
                shift 2
                ;;
            --ssh-config-domain)
                SSH_CONFIG_DOMAIN="$2"
                shift 2
                ;;
            --ssh-config-prefix)
                SSH_CONFIG_PREFIX="$2"
                shift 2
                ;;
            --ssh-config-enabled)
                SSH_CONFIG_ENABLED=true
                shift
;;
            --ssh-config-disabled)
                SSH_CONFIG_ENABLED=false
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_create_session_usage
                exit 0
                ;;
            *)
                echo "Unknown option for create session command: $1"
                show_create_session_usage
                exit 1
                ;;
        esac
    done
    
    # Check required parameters
    if [ -z "$BASTION_OCID" ]; then
        echo "Error: Bastion OCID (-b, --bastion-id) is required."
        show_create_session_usage
        exit 1
    fi
    
    if [ -z "$SESSION_NAME" ]; then
        echo "Error: Session name (-n, --name) is required."
        show_create_session_usage
        exit 1
    fi
    
    # Validate session type
    if [[ ! "$SESSION_TYPE" =~ ^(SSH|PORT_FORWARDING)$ ]]; then
        echo "Error: Invalid session type '$SESSION_TYPE'. Must be SSH or PORT_FORWARDING."
        show_create_session_usage
        exit 1
    fi
    
    # Check SSH-specific parameters
    if [ "$SESSION_TYPE" = "SSH" ]; then
        if [ -z "$TARGET_RESOURCE_OCID" ]; then
            echo "Error: Target resource OCID (--target-id) is required for SSH sessions."
            show_create_session_usage
            exit 1
        fi
        validate_ocid "$TARGET_RESOURCE_OCID" "Target Resource"
    else
        # PORT_FORWARDING requires target IP
        if [ -z "$TARGET_IP" ]; then
            echo "Error: Target IP (-t, --target-ip) is required for PORT_FORWARDING sessions."
            show_create_session_usage
            exit 1
        fi
        
        # Validate target IP
        if [[ ! "$TARGET_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Warning: Target IP '$TARGET_IP' might not be in the correct format."
            echo "Expected format: x.x.x.x (e.g., 10.0.0.25)"
            read -p "Continue anyway? (y/n): " confirm_ip
            if [[ $confirm_ip != [yY] && $confirm_ip != [yY][eE][sS] ]]; then
                echo "Session creation cancelled."
                exit 0
            fi
        fi
    fi
    
    # Validate key type if provided
    if [[ ! "$KEY_TYPE" =~ ^(PUB|PEM)$ ]]; then
        echo "Error: Invalid key type '$KEY_TYPE'. Must be PUB or PEM."
        show_create_session_usage
        exit 1
    fi
    
    # Verify session TTL is at least 1800 seconds (30 minutes)
    if [ "$SESSION_TTL" -lt 1800 ]; then
        echo "Warning: Requested TTL ($SESSION_TTL seconds) is less than the minimum required (1800 seconds)."
        echo "Setting TTL to the minimum allowed: 1800 seconds."
        SESSION_TTL=1800
    fi
    
    # Validate public key file exists for SSH sessions
    if [ "$SESSION_TYPE" = "SSH" ]; then
        # Expand the tilde in the path
        expanded_key_file="${PUBLIC_KEY_FILE/#\~/$HOME}"
        
        if [ ! -f "$expanded_key_file" ]; then
            echo "Error: Public key file '$PUBLIC_KEY_FILE' not found."
            echo "Please provide a valid public key file path."
            exit 1
        fi
        
        # Read the key file
        public_key=$(cat "$expanded_key_file")
        
        # Basic validation of the key format
        if [[ "$KEY_TYPE" = "PUB" && ! "$public_key" =~ ^ssh-[a-z]+ ]]; then
            echo "Warning: The public key file doesn't appear to be in OpenSSH format."
            read -p "Continue anyway? (y/n): " confirm_key
            if [[ $confirm_key != [yY] && $confirm_key != [yY][eE][sS] ]]; then
                echo "Session creation cancelled."
                exit 0
            fi
        fi
    fi
    
    # Validate bastion OCID
    validate_ocid "$BASTION_OCID" "Bastion"
    
    # Verify OCI CLI and authentication
    verify_oci_auth
    
    # Prepare region parameter
    region_param=""
    if [ -n "$OCI_REGION" ]; then
        region_param="--region $OCI_REGION"
    fi
    
    # Verify the bastion exists and is active
    echo "Verifying bastion status..."
    BASTION_INFO=$(oci bastion bastion get \
        --bastion-id "$BASTION_OCID" \
        --profile "$OCI_PROFILE" \
        $region_param 2>&1)
        
    if [ $? -ne 0 ]; then
        echo "Error getting bastion status:"
        echo "$BASTION_INFO"
        exit 1
    fi
    
    BASTION_STATE=$(echo "$BASTION_INFO" | jq -r '.data."lifecycle-state"' 2>/dev/null)
    
    if [ "$BASTION_STATE" != "ACTIVE" ]; then
        echo "Error: Bastion is not in ACTIVE state. Current state: $BASTION_STATE"
        echo "The bastion must be in ACTIVE state to create a session."
        exit 1
    fi
    
    # Get max session TTL from bastion
    MAX_BASTION_TTL=$(echo "$BASTION_INFO" | jq -r '.data."max-session-ttl-in-seconds"' 2>/dev/null)
    
    # Check if requested TTL exceeds the bastion's maximum
    if [ "$SESSION_TTL" -gt "$MAX_BASTION_TTL" ]; then
        echo "Warning: Requested TTL ($SESSION_TTL seconds) exceeds the bastion's maximum TTL ($MAX_BASTION_TTL seconds)."
        echo "Setting TTL to the maximum allowed: $MAX_BASTION_TTL seconds."
        SESSION_TTL="$MAX_BASTION_TTL"
    fi

    # Show summary of session to be created
    echo "Creating session with the following configuration:"
    echo "  Name: $SESSION_NAME"
    echo "  Bastion OCID: $BASTION_OCID"
    echo "  Session Type: $SESSION_TYPE"
    echo "  Session TTL: $SESSION_TTL seconds"
    
    if [ "$SESSION_TYPE" = "SSH" ]; then
        echo "  Target Resource OCID: $TARGET_RESOURCE_OCID"
        echo "  Target OS Username: $TARGET_OS_USER"
        echo "  Key Type: $KEY_TYPE"
        echo "  Public Key File: $PUBLIC_KEY_FILE"
    else
        echo "  Target IP: $TARGET_IP"
        echo "  Target Port: $TARGET_PORT"
    fi
    
    echo "  OCI Profile: $OCI_PROFILE"
    if [ -n "$OCI_REGION" ]; then
        echo "  Region: $OCI_REGION"
    else
        echo "  Region: [default from profile]"
    fi
    
    # Confirm creation
    read -p "Continue with session creation? (y/n): " confirm
    if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
        echo "Session creation cancelled."
        exit 0
    fi
    
    # Create the session based on type
    if [ "$SESSION_TYPE" = "SSH" ]; then
        # Create SSH session
        echo "Creating SSH session..."
        
        # Build the command with corrected parameters
        create_cmd="oci bastion session create-managed-ssh \
            --bastion-id \"$BASTION_OCID\" \
            --display-name \"$SESSION_NAME\" \
            --session-ttl $SESSION_TTL \
            --target-resource-id \"$TARGET_RESOURCE_OCID\" \
            --target-os-username \"$TARGET_OS_USER\" \
            --profile \"$OCI_PROFILE\" \
            $region_param"
        
        # Add public key
        if [ "$KEY_TYPE" = "PUB" ]; then
            create_cmd="$create_cmd --ssh-public-key-file \"$expanded_key_file\""
        else
            create_cmd="$create_cmd --ssh-public-key-content \"$public_key\""
        fi
        
        # Debug the command
        debug_command "$create_cmd"
        
        # Create the session
        SESSION_OUTPUT=$(eval "$create_cmd" 2>&1)
        
    else
        # Create Port Forwarding session
        echo "Creating Port Forwarding session..."
        
        create_cmd="oci bastion session create-port-forwarding \
            --bastion-id \"$BASTION_OCID\" \
            --display-name \"$SESSION_NAME\" \
            --session-ttl $SESSION_TTL \
            --target-private-ip \"$TARGET_IP\" \
            --target-port $TARGET_PORT \
            --profile \"$OCI_PROFILE\" \
            $region_param"
            
        # Debug the command
        debug_command "$create_cmd"
        
        # Create the session
        SESSION_OUTPUT=$(eval "$create_cmd" 2>&1)
    fi
    
    # Check for errors
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo "Error creating session."
        echo "Error details:"
        echo "$SESSION_OUTPUT"
        exit 1
    fi
    
    # Extract and print the session OCID
    SESSION_OCID=$(echo "$SESSION_OUTPUT" | jq -r '.data.id' 2>/dev/null)
    if [ -z "$SESSION_OCID" ] || [ "$SESSION_OCID" == "null" ]; then
        echo "Warning: Could not extract session OCID from the response."
        echo "Full response:"
        echo "$SESSION_OUTPUT"
        exit 1
    fi
    
    echo "Session creation initiated."
    echo "Session OCID: $SESSION_OCID"
    
    # Wait for the session to become active
    echo "Waiting for session to become active..."
    MAX_WAIT_SECONDS=180
    WAITED_SECONDS=0
    INTERVAL=10
    
    while [ $WAITED_SECONDS -lt $MAX_WAIT_SECONDS ]; do
        SESSION_INFO=$(oci bastion session get \
            --session-id "$SESSION_OCID" \
            --profile "$OCI_PROFILE" \
            $region_param 2>&1)
            
        if [ $? -ne 0 ]; then
            echo "Error getting session status:"
            echo "$SESSION_INFO"
            exit 1
        fi
        
        SESSION_STATE=$(echo "$SESSION_INFO" | jq -r '.data."lifecycle-state"' 2>/dev/null)
        
        if [ "$SESSION_STATE" == "ACTIVE" ]; then
            echo "Session is now ACTIVE."
            break
        elif [ "$SESSION_STATE" == "FAILED" ]; then
            echo "Session creation failed."
            echo "Full status:"
            echo "$SESSION_INFO" | jq '.data'
            exit 1
        fi
        
        echo "Current state: $SESSION_STATE. Waiting $INTERVAL more seconds..."
        sleep $INTERVAL
        WAITED_SECONDS=$((WAITED_SECONDS + INTERVAL))
    done
    
    SESSION_ACTIVATED=false
      if [ $WAITED_SECONDS -ge $MAX_WAIT_SECONDS ]; then
        echo "Warning: Timed out waiting for session to become active."
        echo "The session was created but has not reached ACTIVE state yet."
        echo ""
        # Intentar obtener el estado actual
        SESSION_INFO=$(oci bastion session get \
            --session-id "$SESSION_OCID" \
            --profile "$OCI_PROFILE" \
            $region_param 2>/dev/null)
            
        if [ $? -eq 0 ]; then
            SESSION_STATE=$(echo "$SESSION_INFO" | jq -r '.data."lifecycle-state"' 2>/dev/null)
            echo "Current state: $SESSION_STATE"
        else
            echo "Could not retrieve current session state."
        fi
    else
        SESSION_ACTIVATED=true
    fi

    # Display session information and connection details
    echo ""
    echo "========================================"
    echo "Session created successfully!"
    echo "========================================"
    echo "Name: $SESSION_NAME"
    echo "OCID: $SESSION_OCID"
    echo "State: $SESSION_STATE"
    echo "TTL: $SESSION_TTL seconds (expires in ~$(($SESSION_TTL / 60)) minutes)"
    echo "========================================"

    if [ "$SESSION_ACTIVATED" = false ]; then
        echo "To check session status later, use:"
        echo "$0 show session -b $BASTION_OCID -s \"$SESSION_NAME\""
        echo ""
    fi

    # Show connection information based on session type
    if [ "$SESSION_TYPE" = "SSH" ]; then
        SSH_COMMAND=$(echo "$SESSION_INFO" | jq -r '.data["ssh-metadata"]["command"] // "N/A"')
        if [ "$SSH_COMMAND" != "N/A" ] && [ "$SSH_COMMAND" != "null" ]; then
            echo "SSH Command:"
            echo "$SSH_COMMAND"
            
            # Setup SSH config if enabled
            if [ "$SSH_CONFIG_ENABLED" = "true" ]; then
                # Extract session ID from the SSH command or metadata
                local extracted_session_id=$(echo "$SESSION_INFO" | jq -r '.data.id // ""')
                
                echo ""
                echo "Setting up SSH config..."
                setup_ssh_config "$SESSION_NAME" "$extracted_session_id" "$SSH_COMMAND" "$TARGET_IP" "$TARGET_PORT" "$TARGET_OS_USER"
                
                # Get the short ID for user reference
                local short_id="${extracted_session_id: -8}"
                if [ -n "$short_id" ]; then
                    echo ""
                    echo "================ SSH CONFIG CREATED ================"
                    echo "You can now connect directly using: ssh target-$short_id"
                    echo "====================================================="
                fi
            fi
        else
            echo "Connection information is not available yet."
            echo "Please run the following command to get connection details:"
            echo "$0 show session -b $BASTION_OCID -s \"$SESSION_NAME\""
        fi
    else
        echo "Port Forwarding Session created."
        
        # For Port Forwarding, we should extract additional connection details if available
        local local_port=$(echo "$SESSION_INFO" | jq -r '.data["port-forwarding-metadata"]["local-port"] // "N/A"')
        if [ "$local_port" != "N/A" ] && [ "$local_port" != "null" ]; then
            echo ""
            echo "============ PORT FORWARDING DETAILS ============"
            echo "Local Port: $local_port"
            echo "Target: $TARGET_IP:$TARGET_PORT"
            echo "To connect, use: localhost:$local_port"
            echo "================================================="
        else
            echo "Please run the following command to get connection details:"
            echo "$0 show session -b $BASTION_OCID -s \"$SESSION_NAME\""
        fi
    fi
    
    echo "========================================"
}


################################################################################
# LIST BASTION FUNCTIONS
################################################################################


# Function to list bastions
list_bastion() {
    local all_compartments=false
    local include_children=false
    local child_compartments=()
    
    # Process arguments for list bastion command
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -c|--compartment-id)
                COMPARTMENT_OCID="$2"
                shift 2
                ;;
            -r|--region)
                OCI_REGION="$2"
                shift 2
                ;;
            -p|--profile)
                OCI_PROFILE="$2"
                shift 2
                ;;
            --all)
                include_children=true
                shift
                ;;
            --include-children)
                include_children=true
                shift
                ;;
            -h|--help)
                show_list_bastion_usage
                exit 0
                ;;
            *)
                echo "Unknown option for list bastion command: $1"
                show_list_bastion_usage
                exit 1
                ;;
        esac
    done
    
    # Check required parameters
    if [ -z "$COMPARTMENT_OCID" ]; then
        echo "Error: Compartment ID (-c, --compartment-id) is required."
        show_list_bastion_usage
        exit 1
    fi
    
    # Prepare region parameter
    region_param=""
    if [ -n "$OCI_REGION" ]; then
        region_param="--region $OCI_REGION"
    fi
    
    # Validate OCID
    validate_ocid "$COMPARTMENT_OCID" "Compartment"
    
    # Initialize results object
    local all_bastions=$(echo '{"data": []}')
    
    # First, get bastions in the specified compartment
    echo "Listing bastions..."
    echo "Querying bastions in compartment: $COMPARTMENT_OCID"
    
    BASTIONS=$(oci bastion bastion list \
        --compartment-id "$COMPARTMENT_OCID" \
        --all \
        --profile "$OCI_PROFILE" \
        $region_param)
        
    # Check for errors
    if [ $? -ne 0 ]; then
        echo "Error listing bastions in compartment $COMPARTMENT_OCID."
        exit 1
    fi
    
    # Add these bastions to our results
    all_bastions=$(echo "$BASTIONS")
    
    # If --all or --include-children is specified, get direct child compartments
    if [ "$include_children" = true ]; then
        echo "Retrieving direct child compartments for: $COMPARTMENT_OCID"
        
        CHILD_COMPARTMENTS=$(oci iam compartment list \
            --compartment-id "$COMPARTMENT_OCID" \
            --lifecycle-state ACTIVE \
            --all \
            --profile "$OCI_PROFILE" \
            $region_param 2>/dev/null)
            
        if [ $? -ne 0 ]; then
            echo "Warning: Failed to retrieve child compartments. Showing bastions from specified compartment only."
        else
            # Get the number of child compartments
            local child_count=$(echo "$CHILD_COMPARTMENTS" | jq '.data | length')
            
            if [ -n "$child_count" ] && [ "$child_count" -gt 0 ]; then
                echo "Found $child_count direct child compartments"
                
                # Initialize combined results with parent compartment bastions
                local combined_results=$(echo "$BASTIONS")
                
                # For each child compartment, get bastions
                echo "$CHILD_COMPARTMENTS" | jq -c '.data[]' | while read -r compartment; do
                    local child_id=$(echo "$compartment" | jq -r '.id')
                    local child_name=$(echo "$compartment" | jq -r '.name')
                    
                    echo "Querying bastions in child compartment: $child_name ($child_id)"
                    
                    CHILD_BASTIONS=$(oci bastion bastion list \
                        --compartment-id "$child_id" \
                        --all \
                        --profile "$OCI_PROFILE" \
                        $region_param 2>/dev/null)
                        
                    if [ $? -ne 0 ]; then
                        echo "Warning: Error querying bastions in child compartment $child_name. Skipping."
                        continue
                    fi
                    
                    # Add compartment info to bastions and combine results
                    local child_bastion_count=$(echo "$CHILD_BASTIONS" | jq '.data | length')
                    if [ -n "$child_bastion_count" ] && [ "$child_bastion_count" -gt 0 ]; then
                        echo "Found $child_bastion_count bastions in child compartment $child_name"
                        
                        # Add compartment ID and name to each bastion for better tracking
                        CHILD_BASTIONS=$(echo "$CHILD_BASTIONS" | jq --arg comp_id "$child_id" --arg comp_name "$child_name" \
                            '.data = [.data[] | . + {"compartment-id": $comp_id, "compartment-name": $comp_name}]')
                        
                        # Combine with existing results
                        combined_results=$(echo "$combined_results" | jq --argjson new_data "$(echo "$CHILD_BASTIONS" | jq '.data')" \
                            '.data += $new_data')
                    else
                        echo "No bastions found in child compartment $child_name"
                    fi
                done
                
                # Use the combined results
                all_bastions=$combined_results
            else
                echo "No child compartments found for $COMPARTMENT_OCID"
            fi
        fi
    fi
    
    # Count the number of bastions in the final result
    BASTION_COUNT=$(echo "$all_bastions" | jq '.data | length')
    
    if [ "$BASTION_COUNT" -eq 0 ]; then
        echo "No bastions found."
        exit 0
    fi
    
    # Print table header
    echo "=== Bastions ==="
    printf "%-30s %-15s %-50s %-15s %-30s\n" \
           "Name" "State" "OCID" "Region" "Compartment"
    echo "---------------------------------------------------------------------------------------------------------------"
    
    # Extract and display information for each bastion
    echo "$all_bastions" | jq -c '.data[]' | while read -r bastion; do
        name=$(echo "$bastion" | jq -r '.name // "Unnamed"')
        state=$(echo "$bastion" | jq -r '."lifecycle-state" // "Unknown"')
        ocid=$(echo "$bastion" | jq -r '.id')
        region=$(echo "$bastion" | jq -r '."region" // "Unknown"')
        
        # Try to get compartment name first, fall back to compartment ID
        comp_name=$(echo "$bastion" | jq -r '."compartment-name" // "N/A"')
        if [ "$comp_name" = "N/A" ]; then
            comp_id=$(echo "$bastion" | jq -r '."compartment-id" // "Unknown"')
            compartment=$(echo "$comp_id" | awk -F. '{print $2"."$3}')
        else
            compartment="$comp_name"
        fi
        
        # Print the table row
        printf "%-30s %-15s %-50s %-15s %-30s\n" \
               "${name:0:30}" "$state" "$ocid" "$region" "${compartment:0:30}"
    done
    
    echo ""
    echo "Total bastions: $BASTION_COUNT"
    echo ""
    echo "To view detailed information for a specific bastion:"
    echo "$0 show bastion -b BASTION_OCID"
    echo ""
    echo "To list sessions for a specific bastion:"
    echo "$0 list session -b BASTION_OCID"
}

# Function to show list bastion usage
show_list_bastion_usage() {
    echo "Usage: $0 list bastion [options]"
    echo "Options:"
    echo "  -c, --compartment-id OCID  Compartment OCID to list bastions from (required)"
    echo "  -r, --region REGION        OCI Region (default: configured region)"
    echo "  -p, --profile PROFILE      OCI Profile to use (default: $OCI_PROFILE)"
    echo "  --all                      Include bastions in direct child compartments"
    echo "  --include-children         Same as --all"
    echo "  -h, --help                 Show this help message"
}




################################################################################
# LIST SESSION FUNCTIONS
################################################################################

# Function to show list session usage
show_list_session_usage() {
    echo "Usage: $0 list session [options]"
    echo "Options:"
    echo "  -b, --bastion-id OCID    Bastion OCID (required)"
    echo "  -r, --region REGION      OCI Region (default: configured region)"
    echo "  -p, --profile PROFILE    OCI Profile to use (default: $OCI_PROFILE)"
    echo "  -h, --help               Show this help message"
}

# Function to list sessions
list_session() {
    # Process arguments for list session command
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -b|--bastion-id)
                BASTION_OCID="$2"
                shift 2
                ;;
            -r|--region)
                OCI_REGION="$2"
                shift 2
                ;;
            -p|--profile)
                OCI_PROFILE="$2"
                shift 2
                ;;
            -h|--help)
                show_list_session_usage
                exit 0
                ;;
            *)
                echo "Unknown option for list session command: $1"
                show_list_session_usage
                exit 1
                ;;
        esac
    done
    
    # Check required parameters
    if [ -z "$BASTION_OCID" ]; then
        echo "Error: Bastion OCID (-b, --bastion-id) is required."
        show_list_session_usage
        exit 1
    fi
    
    # Validate bastion OCID
    validate_ocid "$BASTION_OCID" "Bastion"
    
    # Prepare region parameter
    region_param=""
    if [ -n "$OCI_REGION" ]; then
        region_param="--region $OCI_REGION"
    fi
    
    # List bastion sessions
    echo "Querying sessions for bastion: $BASTION_OCID"
    echo "Using OCI profile: $OCI_PROFILE"
    if [ -n "$OCI_REGION" ]; then
        echo "Region: $OCI_REGION"
    else
        echo "Region: [default from profile]"
    fi
    
    # Retrieve sessions using OCI CLI
    SESSIONS=$(oci bastion session list \
        --bastion-id "$BASTION_OCID" \
        $region_param \
        --all \
        --profile "$OCI_PROFILE")
    
    # Check for errors
    if [ $? -ne 0 ]; then
        echo "Error querying bastion sessions."
        exit 1
    fi

# Count the number of sessions
    SESSION_COUNT=$(echo "$SESSIONS" | jq '.data | length')
    
    if [ "$SESSION_COUNT" -eq 0 ]; then
        echo "No active sessions found for this bastion."
        exit 0
    fi
    
    # Print table header
    echo "=== Bastion Sessions ==="
    printf "%-25s %-30s %-10s %-15s %-15s %-25s\n" \
           "Name" "Target Resource" "Port" "State" "TTL (hours)" "Session ID (short)"
    echo "--------------------------------------------------------------------------------------------------------"
    
    # Extract and display information for each session
    echo "$SESSIONS" | jq -c '.data[]' | while read -r session; do
        name=$(echo "$session" | jq -r '."display-name" // "Unnamed"')
        target=$(echo "$session" | jq -r '."target-resource-details"."target-resource-display-name" // "N/A"')
        port=$(echo "$session" | jq -r '."target-resource-details"."target-resource-port" // "N/A"')
        state=$(echo "$session" | jq -r '."lifecycle-state" // "Unknown"')
        ttl=$(echo "$session" | jq -r '."session-ttl-in-seconds" // "0"')
        id=$(echo "$session" | jq -r '.id')
        
        # Convert TTL from seconds to hours - more reliable method
        if [ "$ttl" != "null" ] && [ "$ttl" != "0" ]; then
            # Use basic bash arithmetic instead of bc
            ttl_hours=$(printf "%.2f" $(echo "$ttl / 3600" | awk '{print $1}'))
        else
            ttl_hours="N/A"
        fi
        
        # Get the last 8 characters of the ID for display
        short_id="${id: -8}"
        
        # Print the table row
        printf "%-25s %-30s %-10s %-15s %-15s %-25s\n" \
               "${name:0:25}" "${target:0:30}" "$port" "$state" "$ttl_hours" "$short_id"
    done
    
    echo ""
    echo "Total sessions: $SESSION_COUNT"
    echo ""
    echo "To view complete details for a specific session:"
    echo "$0 show session -b $BASTION_OCID -s SESSION_NAME"
}

#
# SHOW BASTION FUNCTIONS
#

# Function to show show bastion usage
show_show_bastion_usage() {
    echo "Usage: $0 show bastion [options]"
    echo "Options:"
    echo "  -b, --bastion-id OCID    Bastion OCID (required)"
    echo "  -r, --region REGION      OCI Region (default: configured region)"
    echo "  -p, --profile PROFILE    OCI Profile to use (default: $OCI_PROFILE)"
    echo "  -h, --help               Show this help message"
}

# Function to show bastion details
show_bastion() {
    # Process arguments for show bastion command
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -b|--bastion-id)
                BASTION_OCID="$2"
                shift 2
                ;;
            -r|--region)
                OCI_REGION="$2"
                shift 2
                ;;
            -p|--profile)
                OCI_PROFILE="$2"
                shift 2
                ;;
            -h|--help)
                show_show_bastion_usage
                exit 0
                ;;
            *)
                echo "Unknown option for show bastion command: $1"
                show_show_bastion_usage
                exit 1
                ;;
        esac
    done
    
    # Check required parameters
    if [ -z "$BASTION_OCID" ]; then
        echo "Error: Bastion OCID (-b, --bastion-id) is required."
        show_show_bastion_usage
        exit 1
    fi
# Validate bastion OCID
    validate_ocid "$BASTION_OCID" "Bastion"
    
    # Prepare region parameter
    region_param=""
    if [ -n "$OCI_REGION" ]; then
        region_param="--region $OCI_REGION"
    fi
    
    # Get bastion details
    echo "Retrieving details for bastion: $BASTION_OCID"
    BASTION_INFO=$(oci bastion bastion get \
        --bastion-id "$BASTION_OCID" \
        --profile "$OCI_PROFILE" \
        $region_param)
    
    # Check for errors
    if [ $? -ne 0 ]; then
        echo "Error retrieving bastion details."
        exit 1
    fi

# Display bastion details
    echo "========================================"
    echo "Bastion Details"
    echo "========================================"
    
    # Extract and format basic information
    name=$(echo "$BASTION_INFO" | jq -r '.data.name')
    state=$(echo "$BASTION_INFO" | jq -r '.data."lifecycle-state"')
    compartment=$(echo "$BASTION_INFO" | jq -r '.data."compartment-id"')
    time_created=$(echo "$BASTION_INFO" | jq -r '.data."time-created"')
    subnet=$(echo "$BASTION_INFO" | jq -r '.data."target-subnet-id"')
    bastion_type=$(echo "$BASTION_INFO" | jq -r '.data."bastion-type"')
    max_ttl=$(echo "$BASTION_INFO" | jq -r '.data."max-session-ttl-in-seconds"')
    dns_proxy=$(echo "$BASTION_INFO" | jq -r '.data."dns-proxy-status"')
    
    # Convert TTL from seconds to hours
    max_ttl_hours=$(printf "%.2f" $(echo "$max_ttl / 3600" | awk '{print $1}'))
    
    # Display formatted information
    echo "Name: $name"
    echo "State: $state"
    echo "OCID: $BASTION_OCID"
    echo "Compartment: $compartment"
    echo "Created: $time_created"
    echo "Target Subnet: $subnet"
    echo "Type: $bastion_type"
    echo "Max Session TTL: $max_ttl seconds ($max_ttl_hours hours)"
    echo "DNS Proxy Status: $dns_proxy"
    
    # Extract and display client CIDR list
    echo ""
    echo "Client CIDR Blocks:"
    echo "$BASTION_INFO" | jq -r '.data."client-cidr-block-allow-list"[]' | while read -r cidr; do
        echo "  - $cidr"
    done
    
    # Show additional info if available
    if [ "$(echo "$BASTION_INFO" | jq 'has("defined-tags")')" == "true" ]; then
        echo ""
        echo "Defined Tags:"
        echo "$BASTION_INFO" | jq -r '.data."defined-tags"'
    fi
    
    if [ "$(echo "$BASTION_INFO" | jq 'has("freeform-tags")')" == "true" ]; then
        echo ""
        echo "Freeform Tags:"
        echo "$BASTION_INFO" | jq -r '.data."freeform-tags"'
    fi
    
    echo ""
    echo "========================================"
    echo "For session management, use:"
    echo "$0 list session -b $BASTION_OCID"
    echo "$0 create session -b $BASTION_OCID -n SESSION_NAME -t TARGET_IP"
    echo "========================================"
}

#
# SHOW SESSION FUNCTIONS
#

# Function to show show session usage
show_show_session_usage() {
    echo "Usage: $0 show session [options]"
    echo "Options:"
    echo "  -b, --bastion-id OCID    Bastion OCID (required)"
    echo "  -s, --session NAME       Session name (required)"
    echo "  -i, --session-id OCID    Session OCID (alternative to -s)"
    echo "  -r, --region REGION      OCI Region (default: configured region)"
    echo "  -p, --profile PROFILE    OCI Profile to use (default: $OCI_PROFILE)"
    echo "  -h, --help               Show this help message"
    echo ""
    show_ssh_config_options
}

# Function to show session details
show_session() {
    # Process arguments for show session command
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -b|--bastion-id)
                BASTION_OCID="$2"
                shift 2
                ;;
            -s|--session)
                SHOW_SESSION="$2"
                shift 2
                ;;
            -i|--session-id)
                SESSION_OCID="$2"
                shift 2
                ;;
            -r|--region)
                OCI_REGION="$2"
                shift 2
                ;;
            -p|--profile)
                OCI_PROFILE="$2"
                shift 2
                ;;
            --ssh-config-dir)
                SSH_CONFIG_DIR="$2"
                shift 2
                ;;
            --ssh-identity-file)
                SSH_IDENTITY_FILE="$2"
                shift 2
                ;;
            --ssh-config-domain)
                SSH_CONFIG_DOMAIN="$2"
                shift 2
                ;;
            --ssh-config-prefix)
                SSH_CONFIG_PREFIX="$2"
                shift 2
                ;;
            --ssh-config-enabled)
                SSH_CONFIG_ENABLED=true
                shift
                ;;
            --ssh-config-disabled)
                SSH_CONFIG_ENABLED=false
                shift
                ;;
            -h|--help)
                show_show_session_usage
                exit 0
                ;;
            *)
                echo "Unknown option for show session command: $1"
                show_show_session_usage
                exit 1
                ;;
        esac
    done
    
    # Check required parameters
    if [ -z "$BASTION_OCID" ]; then
        echo "Error: Bastion OCID (-b, --bastion-id) is required."
        show_show_session_usage
        exit 1
    fi
    
    if [ -z "$SHOW_SESSION" ] && [ -z "$SESSION_OCID" ]; then
        echo "Error: Either session name (-s, --session) or session OCID (-i, --session-id) is required."
        show_show_session_usage
        exit 1
    fi
    
    # Validate bastion OCID
    validate_ocid "$BASTION_OCID" "Bastion"
    if [ -n "$SESSION_OCID" ]; then
        validate_ocid "$SESSION_OCID" "Session"
    fi
    
    # Prepare region parameter
    region_param=""
    if [ -n "$OCI_REGION" ]; then
        region_param="--region $OCI_REGION"
    fi
    
    # Get session information
    if [ -n "$SESSION_OCID" ]; then
        # Get session directly by OCID
        echo "Retrieving session with OCID: $SESSION_OCID"
        SESSION_INFO=$(oci bastion session get \
            --session-id "$SESSION_OCID" \
            --profile "$OCI_PROFILE" \
            $region_param)
        
        if [ $? -ne 0 ]; then
            echo "Error retrieving session details."
            exit 1
        fi
        
        # Display the session details
        echo "$SESSION_INFO" | jq '.'
        exit 0
    else
        # First list all sessions and find the one by name
        echo "Retrieving session '$SHOW_SESSION' from bastion: $BASTION_OCID"
        
        # Get all sessions
        SESSIONS=$(oci bastion session list \
            --bastion-id "$BASTION_OCID" \
            $region_param \
            --all \
            --profile "$OCI_PROFILE")
        
        if [ $? -ne 0 ]; then
            echo "Error retrieving sessions."
            exit 1
        fi
        
        # Find the session by name
        SESSION_DETAILS=$(echo "$SESSIONS" | jq -c --arg name "$SHOW_SESSION" '.data[] | select(."display-name" == $name)')
        
        if [ -z "$SESSION_DETAILS" ]; then
            echo "No session found with name: $SHOW_SESSION"
            exit 1
        fi
        
        # Display detailed information in a formatted way
        session_id=$(echo "$SESSION_DETAILS" | jq -r '.id')
        display_name=$(echo "$SESSION_DETAILS" | jq -r '."display-name"')
        state=$(echo "$SESSION_DETAILS" | jq -r '."lifecycle-state"')
        time_created=$(echo "$SESSION_DETAILS" | jq -r '."time-created"')
        ttl=$(echo "$SESSION_DETAILS" | jq -r '."session-ttl-in-seconds"')
        target_resource=$(echo "$SESSION_DETAILS" | jq -r '."target-resource-details"."target-resource-display-name" // "N/A"')
        target_ip=$(echo "$SESSION_DETAILS" | jq -r '."target-resource-details"."target-resource-private-ip-address" // "N/A"')
        target_port=$(echo "$SESSION_DETAILS" | jq -r '."target-resource-details"."target-resource-port" // "N/A"')
        session_type=$(echo "$SESSION_DETAILS" | jq -r '.type // "Unknown"')
        
        # Convert TTL from seconds to hours
        ttl_hours=$(printf "%.2f" $(echo "$ttl / 3600" | awk '{print $1}'))
        
        echo "========================================"
        echo "Session Details"
        echo "========================================"
        echo "Name: $display_name"
        echo "ID: $session_id"
        echo "State: $state"
        echo "Created: $time_created"
        echo "Type: $session_type"
        echo "TTL: $ttl seconds ($ttl_hours hours)"
        echo ""
        echo "Target Resource: $target_resource"
        echo "Target IP: $target_ip"
        echo "Target Port: $target_port"
        echo "========================================"
        
        # Show SSH command for SSH sessions if active
        if [ "$session_type" == "MANAGED_SSH" ] && [ "$state" == "ACTIVE" ]; then
            ssh_command=$(echo "$SESSION_DETAILS" | jq -r '.["ssh-metadata"]["command"] // "N/A"')
            if [ "$ssh_command" != "N/A" ] && [ "$ssh_command" != "null" ]; then
                echo ""
                echo "SSH Command:"
                echo "$ssh_command"
                echo ""
                
                # Ask if user wants to setup SSH config
                if [ "$SSH_CONFIG_ENABLED" = "true" ]; then
                    read -p "Would you like to setup SSH config for easy access? (y/n): " setup_config
                    if [[ $setup_config == [yY] || $setup_config == [yY][eE][sS] ]]; then
                        # Extract target IP from session details
                        local target_ip_from_session=$(echo "$SESSION_DETAILS" | jq -r '."target-resource-details"."target-resource-private-ip-address" // "N/A"')
                        
                        if [ "$target_ip_from_session" = "N/A" ] || [ "$target_ip_from_session" = "null" ]; then
                            # If we can't extract from session details, try to extract from SSH command
                            # This is a simplified approach and might need enhancement
                            target_ip_from_session=$(echo "$ssh_command" | grep -o -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -1)
                        fi
                        
                        if [ -z "$target_ip_from_session" ]; then
                            read -p "Enter target IP address: " target_ip_from_session
                        fi
                        
                        # Setup SSH config
                        setup_ssh_config "$display_name" "$session_id" "$ssh_command" "$target_ip_from_session" "$target_port" "opc"
                        
                        # Get the short ID for user reference
                        local short_id="${session_id: -8}"
                        if [ -n "$short_id" ]; then
                            echo ""
                            echo "================ SSH CONFIG CREATED ================"
                            echo "You can now connect directly using: ssh target-$short_id"
                            echo "====================================================="
                        fi
                    fi
                fi
            fi
        elif [ "$session_type" == "PORT_FORWARDING" ] && [ "$state" == "ACTIVE" ]; then
            # Handle port forwarding details
            port_forwarding_details=$(echo "$SESSION_DETAILS" | jq -r '.["port-forwarding-metadata"] // "N/A"')
            if [ "$port_forwarding_details" != "N/A" ] && [ "$port_forwarding_details" != "null" ]; then
                local_port=$(echo "$SESSION_DETAILS" | jq -r '.["port-forwarding-metadata"]["local-port"] // "N/A"')
                if [ "$local_port" != "N/A" ] && [ "$local_port" != "null" ]; then
                    echo ""
                    echo "============ PORT FORWARDING DETAILS ============"
                    echo "Local Port: $local_port"
                    echo "Target: $target_ip:$target_port"
                    echo "To connect, use: localhost:$local_port"
                    echo "================================================="
                fi
            fi
        fi
    fi
}


# Function to show help for a specific command
show_help() {
    if [ $# -eq 0 ]; then
        show_main_usage
        exit 0
    fi
    
    help_verb="$1"
    shift
    
    if [ $# -eq 0 ]; then
        case "$help_verb" in
            create)
                echo "Available create commands:"
                echo "  $0 create bastion    - Create a new bastion"
                echo "  $0 create session    - Create a new session on a bastion"
                echo ""
                echo "For more details, use: $0 help create <object>"
                ;;
            list)
                echo "Available list commands:"
                echo "  $0 list bastion    - List all bastions in a compartment"
                echo "  $0 list session    - List all sessions for a bastion"
                echo ""
                echo "For more details, use: $0 help list <object>"
                ;;
            show)
                echo "Available show commands:"
                echo "  $0 show bastion    - Show detailed information for a bastion"
                echo "  $0 show session    - Show detailed information for a session"
                echo ""
                echo "For more details, use: $0 help show <object>"
                ;;
            *)
                echo "Unknown verb: $help_verb"
                show_main_usage
                exit 1
                ;;
        esac
        exit 0
    fi
    
    help_object="$1"
    
    case "$help_verb $help_object" in
        "create bastion")
            show_create_bastion_usage
            ;;
        "create session")
            show_create_session_usage
            ;;
        "list bastion")
            show_list_bastion_usage
            ;;
        "list session")
            show_list_session_usage
            ;;
        "show bastion")
            show_show_bastion_usage
            ;;
        "show session")
            show_show_session_usage
            ;;
        *)
            echo "Unknown command: $help_verb $help_object"
            show_main_usage
            exit 1
            ;;
    esac
}


# Main script execution

# Check if at least one command is provided
if [ $# -eq 0 ]; then
    echo "Error: No command specified."
    show_main_usage
    exit 1
fi

# Parse command
VERB="$1"
shift

if [ $# -eq 0 ] && [ "$VERB" != "help" ]; then
    echo "Error: No object specified."
    show_main_usage
    exit 1
fi

# Get the object for most commands
if [ "$VERB" != "help" ]; then
    OBJECT="$1"
    shift
fi

# Execute the appropriate function based on verb and object
case "$VERB" in
    create)
        case "$OBJECT" in
            bastion)
                create_bastion "$@"
                ;;
            session)
                create_session "$@"
                ;;
            *)
                echo "Error: Unknown object '$OBJECT' for verb 'create'"
                echo "Valid objects: bastion, session"
                exit 1
                ;;
        esac
        ;;
    list)
        case "$OBJECT" in
            bastion)
                list_bastion "$@"
                ;;
            session)
                list_session "$@"
                ;;
            *)
                echo "Error: Unknown object '$OBJECT' for verb 'list'"
                echo "Valid objects: bastion, session"
                exit 1
                ;;
        esac
        ;;
    show)
        case "$OBJECT" in
            bastion)
                show_bastion "$@"
                ;;
            session)
                show_session "$@"
                ;;
            *)
                echo "Error: Unknown object '$OBJECT' for verb 'show'"
                echo "Valid objects: bastion, session"
                exit 1
                ;;
        esac
        ;;
    help)
        show_help "$@"
        ;;
    *)
        echo "Error: Unknown verb '$VERB'"
        show_main_usage
        exit 1
        ;;
esac

exit 0
