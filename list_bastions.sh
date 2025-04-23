#!/bin/bash

# Global variables
BASTION_OCID="ocid1.bastion.oc1.sa-bogota-1.amaaaaaac5t2n5aacn4iortj4uytzn647ejislwwhttvuc3lhnc3wwjq7zrq"
OCI_REGION="sa-bogota-1"
OCI_PROFILE="DEFAULT"
SHOW_SESSION=""

# Function to show script usage
show_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -b, --bastion OCID    Bastion OCID (default: $BASTION_OCID)"
    echo "  -r, --region REGION   OCI Region (default: $OCI_REGION)"
    echo "  -p, --profile PROFILE OCI Profile to use (default: $OCI_PROFILE)"
    echo "  -s, --show NAME       Show detailed information for a specific session"
    echo "  -h, --help            Show this help message"
}

# Process arguments
if [ $# -eq 0 ]; then
    # No arguments provided, show options and prompt for confirmation
    echo "No parameters provided. Using default values:"
    show_usage
    echo ""
    read -p "Press Enter to continue with these values, or Ctrl+C to cancel..." </dev/tty
    echo ""
else
    # Process provided arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -b|--bastion)
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
            -s|--show)
                SHOW_SESSION="$2"
                shift 2
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
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this script. Please install it."
    exit 1
fi

# List bastion sessions
echo "Querying sessions for bastion: $BASTION_OCID"
echo "Using OCI profile: $OCI_PROFILE"

# Retrieve sessions using OCI CLI
SESSIONS=$(oci bastion session list \
    --bastion-id "$BASTION_OCID" \
    --region "$OCI_REGION" \
    --all \
    --profile "$OCI_PROFILE")

# Check for errors
if [ $? -ne 0 ]; then
    echo "Error querying bastion sessions."
    exit 1
fi

# If --show is specified, show details for a specific session
if [ -n "$SHOW_SESSION" ]; then
    # Search for the session by name
    SESSION_DETAILS=$(echo "$SESSIONS" | jq -c --arg name "$SHOW_SESSION" '.data[] | select(."display-name" == $name)')
    
    if [ -z "$SESSION_DETAILS" ]; then
        echo "No session found with name: $SHOW_SESSION"
        exit 1
    fi
    
    # Show complete details
    echo "Complete details for session: $SHOW_SESSION"
    echo "$SESSION_DETAILS" | jq '.'
    exit 0
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
    
    # Convert TTL from seconds to hours
    ttl_hours=$(echo "scale=2; $ttl/3600" | bc 2>/dev/null || echo "N/A")
    
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
echo "$0 --show SESSION_NAME"
