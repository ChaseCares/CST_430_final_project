#!/usr/bin/env bash

source config
source helpers.sh

mounted_dirs=()

function mount_nfs() {
    prompt_user_input "Enter local directory: "
    local local_dir="$user_input"
    mounted_dirs+=("$local_dir")
    echo "${mounted_dirs[@]}"

    prompt_user_input "Enter remote directory: "
    local remote_dir="$user_input"

    prompt_user_choice "Select server: " "Select server to mount from" "${servers[@]}" "Manual input" "Cancel"

    if [ "$user_choice" == "Cancel" ]; then
        echo "Canceled"
        return
    elif [ "$user_choice" == "Manual input" ]; then
        prompt_user_input "Enter ip: "
        server_ip="$user_input"
    else
        server="${user_choice}_ip"
        server_ip="${!server}"
    fi

    # Check if ip is valid
    if [[ "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Valid ip"
    else
        echo "Invalid ip"
        return
    fi

    if [ ! -d "$local_dir" ]; then
        mkdir local_dir
    fi

    if mount -t nfs "$server_ip":"$remote_dir" "$local_dir"; then
        echo_green_newline "Mounted $server_ip:$remote_dir to $local_dir"
    else
        echo_red_newline "Failed to mount $server_ip:$remote_dir to $local_dir"
        echo_yellow_newline "Are you root or sudo?"
    fi
}

function unmount_nfs() {
    prompt_user_choice "Select directory: " "Select directory to unmount" "${mounted_dirs[@]}" "Cancel"
    local dir="$user_choice"

    if umount "$dir"; then
        echo_green "Unmounted $dir"
    else
        echo_red_newline "Failed to unmount $dir"
    fi
}

function main() {
    # check_root
    while true; do
        prompt_user_choice "Select action: " "Select action to perform" "Mount" "Unmount" "Cancel"

        if [ "$user_choice" == "Cancel" ]; then
            echo "Canceled"
            exit
        elif [ "$user_choice" == "Mount" ]; then
            mount_nfs
        elif [ "$user_choice" == "Unmount" ]; then
            unmount_nfs
        fi
    done
}

main
