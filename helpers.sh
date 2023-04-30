#!/usr/bin/env bash

# Created for CST-430 Final Project
# Date: 2021-04-30
# Created by ChaseC

# The following functions will echo whatever is passed to them in the specified color
function echo_red_newline() {
    printf "\033[0;31m%s\033[0m\\n" "$1"
}
function echo_green_newline() {
    printf "\033[0;32m%s\033[0m\\n" "$1"
}
function echo_yellow_newline() {
    printf "\033[0;33m%s\033[0m\\n" "$1"
}

# This function will provide a menu for the user to select from
function prompt_user_choice() {
    # Save the provided arguments to local variables
    local PS3="$1"
    local manual="$2"
    local options=("${@:3}")
    local REPLY

    # If manual is true, add the manual input option to the array
    if [ "$manual" = true ]; then
        options+=("Manual input")
    fi

    # Loop until the user selects a valid option
    select REPLY in "${options[@]}" "Cancel"; do
        # If the user selects the manual input option, prompt for input and return
        if [ "$REPLY" == "Manual input" ]; then
            prompt_user_input "Enter value"
            return 1
        # If the user selects the cancel option, return
        elif [ "$REPLY" == "Cancel" ]; then
            return 3
        # If the user selects a valid option, return
        elif [[ -n "$REPLY" ]]; then
            echo "$REPLY"
            break
        else
            echo_red_newline "Invalid choice"
        fi
    done
}

# This function will prompt the user for input
function prompt_user_input {
    # Save the provided arguments to local variables
    local message="$1"
    local REPLY

    # Append the cancel option to the message
    message+=" or 'c' to cancel: "

    # Prompt the user for input and record there response
    read -p "$message" -r REPLY

    # If the user selects the cancel option, return 3
    if [ "$REPLY" == "c" ]; then
        return 3
    # If the user enters a value, return it
    else
        echo "$REPLY"
    fi
}

# This function will check if the user is running as route, as most functions require it
function check_root() {
    # If the user is not root, exit
    if [ "$EUID" -ne 0 ]; then
        echo_red_newline "Please run as root"
        exit
    fi
}
