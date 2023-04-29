#!/usr/bin/env bash

function echo_red() {
    printf "\033[0;31m%s\033[0m" "$1"
}
function echo_green() {
    printf "\033[0;32m%s\033[0m" "$1"
}
function echo_yellow() {
    printf "\033[0;33m%s\033[0m" "$1"
}

function echo_red_newline() {
    printf "\033[0;31m%s\033[0m\\n" "$1"
}
function echo_green_newline() {
    printf "\033[0;32m%s\033[0m\\n" "$1"
}
function echo_yellow_newline() {
    printf "\033[0;33m%s\033[0m\\n" "$1"
}

function restore_cursor_position() {
    printf "\033[u"
}
function save_cursor_position() {
    printf "\033[s"
}

function clean_terminal() {
    printf "\033[2J"
    printf "\033[0;0H"
}

function prompt_user_choice() {
    # clean_terminal

    local PS3="$1"
    local manual="$2"
    local options=("${@:3}")
    local REPLY

    if [ "$manual" = true ]; then
        options+=("Manual input")
    fi

    select REPLY in "${options[@]}" "Cancel"; do
        if [ "$REPLY" == "Manual input" ]; then
            prompt_user_input "Enter value"
            return 1
        elif [ "$REPLY" == "Cancel" ]; then
            return 3
        elif [[ -n "$REPLY" ]]; then
            echo "$REPLY"
            break
        else
            echo_red_newline "Invalid choice"
        fi
    done
}

function prompt_user_input {
    # clean_terminal

    local message="$1"
    local REPLY

    message+=" or 'c' to cancel: "

    read -p "$message" -r REPLY

    if [ "$REPLY" == "c" ]; then
        return 3
    else
        echo "$REPLY"
    fi
}

function check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo_red_newline "Please run as root"
        exit
    fi
}
