#!/usr/bin/env bash

source config
source helpers.sh

function mount_nfs() {
    # local directory
    local user_input
    user_input=$(prompt_user_input "Enter local directory")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling mount"
        return 3
    fi
    local local_dir="$user_input"

    # remote directory
    user_input=$(prompt_user_input "Enter remote directory")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling mount"
        return 3
    fi
    local remote_dir="$user_input"

    # server ip
    local user_choice
    user_choice=$(prompt_user_choice "Select server: " true "${servers[@]}")
    local prompt_rc=$?
    if [[ $prompt_rc -eq 1 ]]; then
        user_input=$(prompt_user_input "Enter server ip")
        if [[ $? -eq 3 ]]; then
            echo_red_newline "Canceling mount"
            return 3
        else
            local server_ip="$user_input"
        fi
    elif [[ prompt_rc -eq 3 ]]; then
        echo_red_newline "Canceling unmount"
        return 3
    else
        local server="${user_choice}_ip"
        local server_ip="${!server}"
    fi

    # Check if ip is valid
    if [[ ! "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid ip"
        return 4
    fi

    if [ ! -d "$local_dir" ]; then
        mkdir "$local_dir"
    fi

    if mount -t nfs "$server_ip":"$remote_dir" "$local_dir"; then
        echo_green_newline "Mounted $server_ip:$remote_dir to $local_dir"
    else
        echo_red_newline "Failed to mount $server_ip:$remote_dir to $local_dir"
        echo_yellow_newline "Are you root or sudo?"
    fi

    mounted_dirs+=("$local_dir")
}

function unmount_nfs() {
    mounted_dirs=("y")
    local user_choice
    user_choice=$(prompt_user_choice "Select directory: " false "${mounted_dirs[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling unmount"
        return 3
    fi

    if umount "$user_choice"; then
        echo_green "Unmounted $user_choice"
    else
        echo_red_newline "Failed to unmount $user_choice"
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
            return 4
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
    local user_choice
    user_choice=$(prompt_user_choice "Select source profile: " false "${profiles[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    fi

    if [[ " ${profiles[*]} " =~ ${user_choice} ]]; then
        profile_dir="${profiles_dir}/${user_choice}"
    else
        echo_red_newline "No source profile found"
        return 4
    fi

    local user_input
    user_input=$(prompt_user_input "Enter username")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    else
        local username="$user_input"
    fi

    local user_choice
    user_choice=$(prompt_user_choice "Select user id: " true "Default '${default_user_id}'")

    if [ "$user_choice" == "Default '${default_user_id}'" ]; then
        user_id="$default_user_id"
    else
        user_id="$user_choice"
    fi

    user_choice=$(prompt_user_choice "Select group id: " true "Default '${default_group_id}'")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    else
        if [ "$user_choice" == "Default '${default_group_id}'" ]; then
            group_id="$default_group_id"
        else
            group_id="$user_choice"
        fi
    fi

    user_choice=$(prompt_user_choice "Select group name: " true "Default '${default_group_name}'")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    else
        if [ "$user_choice" == "Default '${default_group_name}'" ]; then
            local group_name="$default_group_name"
        else
            local group_name="$user_choice"
        fi
    fi

    user_input=$(prompt_user_input "User information")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    else
        local user_input_info="$user_input"
    fi

    user_input=$(prompt_user_input "Enter password")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    else
        local password="$user_input"
    fi

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
    local user_choice
    user_choice=$(prompt_user_choice "Select source profile: " false "${profiles[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    fi

    if [[ " ${profiles[*]} " =~ ${user_choice} ]]; then
        profile_source="${profiles_dir}/${user_choice}"
    else
        echo_red_newline "No source profile found"
        return 4
    fi

    echo_yellow_newline "Creating iso..."

    if [ ! -d "$iso_dir" ]; then
        if ! mkdir --parents "$iso_dir"; then
            echo_red_newline "Failed to create ${iso_dir}"
            return 4
        fi
    fi

    local iso_dest
    iso_dest="${iso_dir}/ArchLinux-${user_choice}-$(date +%Y.%m.%d)-x86_64"

    if ! mkarchiso -w "/tmp/archiso-tmp" -o "$iso_dest" "$profile_source"; then
        echo_red_newline "Failed to create iso"
        return 4
    fi

    echo_green_newline "Created iso '${iso_dest}'"
}

function create_profile() {
    local user_choice
    user_choice=$(prompt_user_choice "Select source profile: " false "${profiles[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    fi

    if [[ " ${profiles[*]} " =~ ${user_choice} ]]; then
        profile_source="${profiles_dir}/${user_choice}"
    else
        echo_red_newline "No source profile found"
        return 4
    fi

    local profile_name
    profile_name=$(prompt_user_input "Enter profile name")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    fi

    local profiles_dest="$profiles_out/$profile_name"

    if [ ! -d "$profiles_dest" ]; then
        if ! mkdir --parents "$profiles_dest"; then
            echo_red_newline "Failed to create ${profiles_dest}"
            return 4
        fi
    fi

    if cp --recursive --preserve "$profile_source/." "$profiles_dest/"; then
        echo_green_newline "Created profile '${profile_name}'"
    else
        echo_red_newline "Failed to create profile '${profile_name}'"
        return 4
    fi

    if ! grep -q "$profile_name" config; then
        sed -i "s/profiles=(/profiles=(\"${profile_name}\" /" config
    fi
}
