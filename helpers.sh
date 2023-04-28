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
