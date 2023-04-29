#!/usr/bin/env bash

source config
source helpers.sh

mounted_dirs=()

function mount_nfs() {
    prompt_user_input "Enter local directory"
    local local_dir="$user_input"
    mounted_dirs+=("$local_dir")
    echo "${mounted_dirs[@]}"

    prompt_user_input "Enter remote directory"
    local remote_dir="$user_input"

    prompt_user_choice "Select server: " "Select server to mount from" "${servers[@]}"

    if [ "$user_choice" == "Manual input" ]; then
        prompt_user_input "Enter ip"
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
    prompt_user_choice "Select directory: " "Select directory to unmount" "${mounted_dirs[@]}"
    local dir="$user_choice"

    if umount "$dir"; then
        echo_green "Unmounted $dir"
    else
        echo_red_newline "Failed to unmount $dir"
    fi
}

function edit_file() {
    local file="$1"
    local data="$2"

    if [ ! -f "$file" ]; then
        if touch "$file"; then
            echo_green_newline "Created ${file}"
        else
            echo_red_newline "Failed to create ${file}"
            return
        fi
    fi

    if grep -q "$data" "$file"; then
        echo_yellow_newline "Found ${data} in ${file}"
    else
        echo_green_newline "Did not find ${data} in ${file}, appending..."
        echo "$data" >>"$file"
    fi
}

function add_user() {
    local profile_dir="$1"

    prompt_user_input "Enter username"
    local username="$user_input"

    prompt_user_choice "Select user id: " "Select user id" "Default '${default_user_id}'"

    if [ "$user_choice" == "Default '${default_user_id}'" ]; then
        user_id="$default_user_id"
    else
        user_id="$user_choice"
    fi

    prompt_user_choice "Select group id: " "Select group id" "Default '${default_group_id}'"

    if [ "$user_choice" == "Default '${default_group_id}'" ]; then
        group_id="$default_group_id"
    else
        group_id="$user_choice"
    fi

    prompt_user_choice "Select group name: " "Select group name" "Default '${default_group_name}'"

    if [ "$user_choice" == "Default '${default_group_name}'" ]; then
        local group_name="$default_group_name"
    else
        local group_name="$user_choice"
    fi

    prompt_user_input "User information"
    local user_input_info="$user_input"

    prompt_user_input "Enter password"
    local password="$user_input"

    #passwd
    echo_yellow_newline "Adding user '${username}' to passwd..."
    edit_file "${profile_dir}/airootfs/etc/passwd" "${username}:x:${user_id}:${group_id}:${user_input_info}:/home/${username}:/usr/bin/bash"

    #shadow
    echo_yellow_newline "Adding user '${username}' to shadow..."
    # Generate password hash
    local pass_hash
    pass_hash=$(openssl passwd -6 "$password")
    edit_file "${profile_dir}/airootfs/etc/shadow" "${username}:${pass_hash}:${days_since_Jan_1}:${min_pw_age}:${max_pw_age}:${pw_warning_period}:${pw_inactivity_period}:${account_expi_date}:::"

    #group
    echo_yellow_newline "Adding user '${username}' to group..."
    edit_file "${profile_dir}/airootfs/etc/group" "${group_name}:x:${group_id}:${username}"

    #gshadow
    echo_yellow_newline "Adding user '${username}' to gshadow..."
    edit_file "${profile_dir}/airootfs/etc/gshadow" "${group_name}:!::${username}"
}

function create_iso() {
    prompt_user_choice "Profile: " "Select source profile" "${profiles[@]}"
    local profile="$user_choice"

    if [[ " ${profiles[*]} " =~ ${profile} ]]; then
        profile_source="${profiles_dir}/${profile}"
    else
        echo_red_newline "No source profile found"
        return
    fi

    echo_yellow_newline "Creating iso..."

    if [ ! -d "$iso_out" ]; then
        if ! mkdir --parents "$iso_out"; then
            echo_red_newline "Failed to create ${iso_out}"
            return
        fi
    fi

    local iso_dest
    iso_dest="${iso_out}/ArchLinux-${profile}-$(date +%Y.%m.%d)-x86_64"

    if ! mkarchiso -w "/tmp/archiso-tmp" -o "$iso_dest" "$profile_source"; then
        echo_red_newline "Failed to create iso"
        return
    fi

}

function create_profile() {
    prompt_user_choice "Profile: " "Select source profile" "${profiles[@]}"
    local profile="$user_choice"

    if [[ " ${profiles[*]} " =~ ${profile} ]]; then
        profile_source="${profiles_dir}/${profile}"
    else
        echo_red_newline "No source profile found"
        return
    fi

    prompt_user_input "Enter profile name"
    local profile_name="$user_input"

    local profiles_dest="$profiles_out/$profile_name"

    if [ ! -d "$profiles_dest" ]; then
        if ! mkdir --parents "$profiles_dest"; then
            echo_red_newline "Failed to create ${profiles_dest}"
            return
        fi
    fi

    if cp --recursive --preserve "$profile_source/." "$profiles_dest/"; then
        echo_green_newline "Created profile ${profile_name}"
    else
        echo_red_newline "Failed to create profile ${profile_name}"
    fi

    # Update config to add profile to the list
    if ! grep -q "$profile_name" config; then
        sed -i "s/profiles=(/profiles=(${profile_name} /" config
    fi

}

create_iso
