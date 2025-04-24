#!/usr/bin/env bash
#
# Copyright (c) 2025. All rights reserved.
#
# Name: list_bastions.sh
# Version: 1.0.2
# Author: Mstaaravin
# Contributors: Developed with assistance from Claude AI
# Description: Lists and manages OCI Cloud bastion sessions
#              Provides detailed information about active sessions
#              Compatible with OCI CLI
#
# =================================================================
# OCI Bastion Sessions Manager
# =================================================================
#
# DESCRIPTION:
#   This script lists and provides details about bastion sessions in
#   Oracle Cloud Infrastructure (OCI). It allows viewing all active
#   sessions for a specific bastion, with options to show detailed
#   information for individual sessions.
#
#   NOTE: This script uses the OCI CLI authentication configuration
#   located at ~/.oci/config for authentication with OCI services.
#   Make sure this file is properly configured before using the script.
#
# USAGE:
#   ./list_bastions.sh [options]
#
# OPTIONS:
#   -b, --bastion OCID    Bastion OCID (default: configured OCID)
#   -r, --region REGION   OCI Region (default: configured region)
#   -p, --profile PROFILE OCI Profile to use (default: DEFAULT)
#   -s, --show NAME       Show detailed information for a specific session
#   -h, --help            Show this help message
#
# EXAMPLES:
#   # Interactive mode with default values:
#   ./list_bastions.sh
#
#   # List sessions for a specific bastion:
#   ./list_bastions.sh -b ocid1.bastion.oc1.region.xxxx
#
#   # List sessions for a specific region:
#   ./list_bastions.sh -r us-ashburn-1
#
#   # Show detailed information for a specific session:
#   ./list_bastions.sh -s "my-session-name"
#
#   # Use a specific OCI profile:
#   ./list_bastions.sh -p PRODUCTION
#

# Global variables
BASTION_OCID="ocid1.bastion.oc1.sa-bogota-1.amaaaaaac5t2n5aacn4iortj4uytzn647ejislwwhttvuc3lhnc3wwjq7zrq"
OCI_REGION="sa-bogota-1"
OCI_PROFILE="DEFAULT"
SHOW_SESSION=""

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

# Check if oci CLI is installed
if ! command -v oci &> /dev/null; then
    echo "Error: OCI CLI is required for this script. Please install it."
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
echo "$0 --show SESSION_NAME"
