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

function prompt_user_choice {
    local PS3="$1"
    local message="$2"
    local options=("${@:3}") # all arguments after
    user_choice=""

    printf "\\n%s\\n" "$message"

    select user_choice in "${options[@]}"; do
        if [[ -n "$user_choice" ]]; then
            break
        else
            echo_red_newline "Invalid choice"
        fi
    done
}

function prompt_user_input {
    local message="$1"
    user_input=""

    echo -n "$message"
    read -r user_input
}

function check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo_red_newline "Please run as root"
        exit
    fi
}
