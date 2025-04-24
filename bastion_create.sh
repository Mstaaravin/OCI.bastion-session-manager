#!/usr/bin/env bash
#
# Copyright (c) 2025. All rights reserved.
#
# Name: create_bastion.sh
# Version: 1.0.5
# Author: Mstaaravin
# Contributors: Developed with assistance from Claude AI
# Description: Creates an OCI Cloud bastion service
#              Configures bastion with specified parameters
#              Compatible with OCI CLI
#
# =================================================================
# OCI Bastion Service Creator
# =================================================================
#
# DESCRIPTION:
#   This script creates a bastion service in Oracle Cloud Infrastructure (OCI).
#   It allows specifying various parameters such as compartment ID, bastion name,
#   target subnet, client CIDR blocks, and session TTL settings.
#
#   NOTE: This script is based on the official OCI CLI documentation for creating
#   bastions. While VCN ID is required in the OCI Console when creating a bastion,
#   the OCI CLI does not use this parameter directly as it is inferred from the subnet.
#   This script keeps the VCN ID for information and validation purposes only.
#
#   This script uses the OCI CLI authentication configuration
#   located at ~/.oci/config for authentication with OCI services.
#   Make sure this file is properly configured before using the script.
#
# USAGE:
#   ./create_bastion.sh [options]
#
# OPTIONS:
#   -c, --compartment-id OCID  Compartment OCID where bastion will be created (required)
#   -n, --name NAME            Name for the bastion (required)
#   -v, --vcn-id OCID          VCN OCID for validation and information (optional, but recommended)
#   -s, --target-subnet-id OCID Subnet OCID where bastion will be created (required)
#   --client-cidr CIDR         Client CIDR blocks allowed (default: 0.0.0.0/0)
#   --max-session-ttl SECONDS  Maximum session TTL in seconds (default: 10800 - 3 hours)
#   -r, --region REGION        OCI Region (default: configured region)
#   -p, --profile PROFILE      OCI Profile to use (default: DEFAULT)
#   --debug                    Enable debug mode to show detailed information
#   -h, --help                 Show this help message
#
# EXAMPLES:
#   # Create a bastion with required parameters:
#   ./create_bastion.sh -c ocid1.compartment.oc1..example -n my-bastion -s ocid1.subnet.oc1.example
#
#   # Create a bastion with VCN information (for validation only):
#   ./create_bastion.sh -c ocid1.compartment.oc1..example -n my-bastion -v ocid1.vcn.oc1.example -s ocid1.subnet.oc1.example
#
#   # Create a bastion with custom CIDR and session TTL:
#   ./create_bastion.sh \
#     -c ocid1.compartment.oc1..example \
#     -n secure-bastion \
#     -s ocid1.subnet.oc1.example \
#     --client-cidr "10.0.0.0/16" \
#     --max-session-ttl 7200
#
#   # Use a specific OCI profile and region:
#   ./create_bastion.sh \
#     -c ocid1.compartment.oc1..example \
#     -n dev-bastion \
#     -s ocid1.subnet.oc1.example \
#     -r us-ashburn-1 \
#     -p DEVELOPMENT
#

# Global variables
COMPARTMENT_ID=""
BASTION_NAME=""
VCN_ID=""
TARGET_SUBNET_ID=""
CLIENT_CIDR="0.0.0.0/0"
MAX_SESSION_TTL=10800  # 3 hours in seconds
OCI_REGION=""          # Will use default from config if not specified
OCI_PROFILE="DEFAULT"
DEBUG_MODE=false       # Set to true to enable debug output

# Check if OCI config exists
if [ ! -f ~/.oci/config ]; then
    echo "Error: OCI configuration file not found at ~/.oci/config"
    echo "Please make sure the OCI CLI is installed and configured properly."
    exit 1
fi

# Function to show script usage
show_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -c, --compartment-id OCID  Compartment OCID where bastion will be created (required)"
    echo "  -n, --name NAME            Name for the bastion (required)"
    echo "  -v, --vcn-id OCID          VCN OCID for validation and information (optional)" 
    echo "  -s, --target-subnet-id OCID Subnet OCID where bastion will be created (required)"
    echo "  --client-cidr CIDR         Client CIDR blocks allowed (default: $CLIENT_CIDR)"
    echo "  --max-session-ttl SECONDS  Maximum session TTL in seconds (default: $MAX_SESSION_TTL)"
    echo "  -r, --region REGION        OCI Region (default: configured region)"
    echo "  -p, --profile PROFILE      OCI Profile to use (default: $OCI_PROFILE)"
    echo "  --debug                    Enable debug mode to show detailed information"
    echo "  -h, --help                 Show this help message"
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
        echo "[DEBUG] Executing command:"
        echo "oci bastion bastion create \\"
        echo "    --compartment-id \"$COMPARTMENT_ID\" \\"
        echo "    --bastion-type \"STANDARD\" \\"
        echo "    --target-subnet-id \"$TARGET_SUBNET_ID\" \\"
        echo "    --client-cidr-list '$CLIENT_CIDR_JSON' \\"
        echo "    --max-session-ttl \"$MAX_SESSION_TTL\" \\"
        echo "    --name \"$BASTION_NAME\" \\"
        echo "    --profile \"$OCI_PROFILE\" \\"
        echo "    $REGION_PARAM"
    fi
}

# Process arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -c|--compartment-id)
            COMPARTMENT_ID="$2"
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
            TARGET_SUBNET_ID="$2"
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
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check required parameters
if [ -z "$COMPARTMENT_ID" ]; then
    echo "Error: Compartment ID (-c, --compartment-id) is required."
    show_usage
    exit 1
fi

if [ -z "$BASTION_NAME" ]; then
    echo "Error: Bastion name (-n, --name) is required."
    show_usage
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

if [ -z "$TARGET_SUBNET_ID" ]; then
    echo "Error: Target subnet ID (-s, --target-subnet-id) is required."
    show_usage
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

# Verify OCI CLI and authentication
echo "Verifying OCI CLI authentication..."
OCI_TEST=$(oci iam region list --profile "$OCI_PROFILE" --all 2>&1)
if [ $? -ne 0 ]; then
    echo "Error: OCI CLI authentication failed:"
    echo "$OCI_TEST"
    echo "Please check your OCI configuration and credentials."
    exit 1
fi

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
    CLIENT_CIDR_JSON='['
    for i in "${!CIDR_BLOCKS[@]}"; do
        # Add comma if not the first element
        if [ "$i" -gt 0 ]; then
            CLIENT_CIDR_JSON+=','
        fi
        # Trim whitespace and add quotes
        CLIENT_CIDR_JSON+='"'$(echo "${CIDR_BLOCKS[$i]}" | xargs)'"'
    done
    CLIENT_CIDR_JSON+=']'
else
    # Single CIDR block
    CLIENT_CIDR_JSON='["'"$CLIENT_CIDR"'"]'
fi

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
            echo "Bastion creation cancelled."
            exit 0
        fi
    fi
}

validate_ocid "$COMPARTMENT_ID" "Compartment"
if [ -n "$VCN_ID" ]; then
    validate_ocid "$VCN_ID" "VCN"
fi
validate_ocid "$TARGET_SUBNET_ID" "Target Subnet"

# Prepare region parameter
REGION_PARAM=""
if [ -n "$OCI_REGION" ]; then
    REGION_PARAM="--region $OCI_REGION"
fi

# Show summary of bastion to be created
echo "Creating bastion with the following configuration:"
echo "  Name: $BASTION_NAME"
echo "  Compartment ID: $COMPARTMENT_ID"
if [ -n "$VCN_ID" ]; then
    echo "  VCN ID: $VCN_ID (for information only, not used by CLI)"
fi
echo "  Target Subnet: $TARGET_SUBNET_ID"
echo "  Client CIDR: $(echo "$CLIENT_CIDR_JSON" | sed 's/^\[//' | sed 's/\]$//' | sed 's/"//g')"
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

# Create the bastion with parameters according to the documentation
# See create.rst.txt for official parameter documentation
echo "Creating bastion..."
debug "Formatted CIDR JSON: $CLIENT_CIDR_JSON"
debug_command

BASTION_OUTPUT=$(oci bastion bastion create \
    --compartment-id "$COMPARTMENT_ID" \
    --bastion-type "STANDARD" \
    --target-subnet-id "$TARGET_SUBNET_ID" \
    --client-cidr-list "$CLIENT_CIDR_JSON" \
    --max-session-ttl "$MAX_SESSION_TTL" \
    --name "$BASTION_NAME" \
    --profile "$OCI_PROFILE" \
    $REGION_PARAM 2>&1)

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
        $REGION_PARAM 2>&1)
        
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
echo "Use this OCID with list_bastions.sh to manage sessions:"
echo "./list_bastions.sh -b $BASTION_OCID"
echo "========================================"
