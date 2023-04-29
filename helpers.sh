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

function prompt_user_choice {
    # clean_terminal

    local PS3="$1"
    local message="$2"
    local options=("${@:3}")

    echo "$message"
    user_choice=""

    select user_choice in "${options[@]}" "Manual input" "Cancel"; do
        if [[ -n "$user_choice" ]]; then
            break
        else
            echo_red_newline "Invalid choice"
        fi
    done

    if [ "$user_choice" == "Cancel" ]; then
        user_choice=""
        echo "Canceled"
        return
    elif [ "$user_choice" == "Manual input" ]; then
        prompt_user_input "Enter value: "
    fi

}

function prompt_user_input {
    # clean_terminal

    local message="$1"
    message+=" or 'c' to cancel: "
    user_input=""

    echo -n "$message"
    read -r user_input

    if [ "$user_choice" == "c" ]; then
        user_choice=""
        echo "Canceled"
        return
    fi
}

function check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo_red_newline "Please run as root"
        exit
    fi
}
