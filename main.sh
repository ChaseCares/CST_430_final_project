#!/usr/bin/env bash

# Created for CST-430 Final Project
# Date: 2021-04-30
# Created by ChaseC

# Importing helper functions and config file
source config
source helpers.sh

# This function will mtount an nfs share to a local directory
function mount_nfs() {
    # Prompt user for the local directory mount point
    local user_input
    # Run prompt_user_input in a subshell to capture the return code
    user_input=$(prompt_user_input "Enter local directory")
    # Return code 3 is cancel, return code 0 is success
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling mount"
        # If the user cancels propagate the return code
        return 3
    fi
    # Capture the user input, to a new local variable
    local local_dir="$user_input"

    # Prompt user for the remote directory mount point
    user_input=$(prompt_user_input "Enter remote directory")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling mount"
        return 3
    fi
    local remote_dir="$user_input"

    # Prompt user for the server ip
    local user_choice
    # Run prompt_user_choice in a subshell to capture the return code
    user_choice=$(prompt_user_choice "Select server: " true "${servers[@]}")
    # Save the return code to a local variable, as it's accessed multiple times
    local prompt_rc=$?
    # Return codes: 3 is cancel, 1 is manual input, 0 is success (Meaning the user chose one of the available options provided)
    if [[ $prompt_rc -eq 1 ]]; then
        # If the user opted to enter a manual ip, prompt for it
        user_input=$(prompt_user_input "Enter server ip")
        # Check to make sure that the user did not cancel during the step
        if [[ $? -eq 3 ]]; then
            echo_red_newline "Canceling mount"
            return 3
        else
            # If the user did not cancel, save the input to a new local variable
            local server_ip="$user_input"
        fi
    # If the user canceled, propagate the return code
    elif [[ prompt_rc -eq 3 ]]; then
        echo_red_newline "Canceling unmount"
        return 3
    else
        # If the user chose one of the available options, save the ip to a new local variable
        local server="${user_choice}_ip"
        local server_ip="${!server}"
    fi

    # Check to make sure that the ip is valid
    if [[ ! "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid ip"
        # Return code 4 is an error occurred
        return 4
    fi

    # Check to make sure that the local directory exists, if not create it
    if [ ! -d "$local_dir" ]; then
        mkdir --parents "$local_dir"
    fi

    # Mount the remote directory to the local directory, and provide feedback to the user
    if mount -t nfs "$server_ip":"$remote_dir" "$local_dir"; then
        echo_green_newline "Mounted $server_ip:$remote_dir to $local_dir"
    else
        echo_red_newline "Failed to mount $server_ip:$remote_dir to $local_dir"
        echo_yellow_newline "Are you root or sudo?"
    fi

    # Add the local directory to the mounted directories array
    mounted_dirs+=("$local_dir")
}

# This function will unmount an nfs share
function unmount_nfs() {
    # Prompt the user to select the directory to unmount from the provided list
    local user_choice
    user_choice=$(prompt_user_choice "Select directory: " false "${mounted_dirs[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling unmount"
        return 3
    fi

    # Unmount the selected directory, and provide feedback to the user
    if umount "$user_choice"; then
        echo_green "Unmounted $user_choice"
    else
        echo_red_newline "Failed to unmount $user_choice"
    fi
}

# This function will edit an existing file, or create it if it does not exist
function edit_file() {
    # Save the provided arguments to local variables
    local file="$1"
    local data="$2"

    # Check to make sure that the file exists, if not create it and provide feedback to the user
    if [ ! -f "$file" ]; then
        if touch "$file"; then
            echo_green_newline "Created ${file}"
        else
            echo_red_newline "Failed to create ${file}"
            return 4
        fi
    fi

    # Check to see if the data already exists in the file, if not append it and provide feedback to the user
    if grep -q "$data" "$file"; then
        echo_yellow_newline "Found ${data} in ${file}"
    else
        echo_green_newline "Did not find ${data} in ${file}, appending..."
        echo "$data" >>"$file"
    fi
}

# This function will create the requisite files needed to create a new user and they're permissions
function add_user() {
    # Prompt the user to select the profile to use
    local user_choice
    user_choice=$(prompt_user_choice "Select source profile: " false "${profiles[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling add user"
        return 3
    fi

    # Make sure that the users choice is in the available profiles array
    if [[ " ${profiles[*]} " =~ ${user_choice} ]]; then
        profile_dir="${profiles_dir}/${user_choice}"
    else
        echo_red_newline "No source profile found"
        return 4
    fi

    # Prompt the user for the username, and save it to a local variable
    local user_input
    user_input=$(prompt_user_input "Enter username")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    else
        local username="$user_input"
    fi

    # Prompt the user for the user id, and save it to a local variable
    local user_choice
    user_choice=$(prompt_user_choice "Select user id: " true "Default '${default_user_id}'")
    if [ "$user_choice" == "Default '${default_user_id}'" ]; then
        user_id="$default_user_id"
    else
        user_id="$user_choice"
    fi

    # Prompt the user for the group id, and save it to a local variable
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

    # Prompt the user for the group name, and save it to a local variable
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

    # Prompt the user for the user information, and save it to a local variable
    user_input=$(prompt_user_input "User information")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    else
        local user_input_info="$user_input"
    fi

    # Prompt the user for a password, and save it to a local variable
    user_input=$(prompt_user_input "Enter password")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    else
        local password="$user_input"
    fi

    # Communicate to the user what action is happening
    echo_yellow_newline "Adding user '${username}' to passwd..."
    # Edit/create the passwd file with the provided information
    edit_file "${profile_dir}/airootfs/etc/passwd" "${username}:x:${user_id}:${group_id}:${user_input_info}:/home/${username}:/usr/bin/bash"

    # Communicate to the user what action is happening
    echo_yellow_newline "Adding user '${username}' to shadow..."
    # Generate the password hash and save it to a local variable
    local pass_hash
    pass_hash=$(openssl passwd -6 "$password")
    # Edit/create the shadow file with the provided information and the generated password hash
    edit_file "${profile_dir}/airootfs/etc/shadow" "${username}:${pass_hash}:${days_since_Jan_1}:${min_pw_age}:${max_pw_age}:${pw_warning_period}:${pw_inactivity_period}:${account_expi_date}:::"

    # Communicate to the user what action is happening
    echo_yellow_newline "Adding user '${username}' to group..."
    # Edit/create the group file with the provided information
    edit_file "${profile_dir}/airootfs/etc/group" "${group_name}:x:${group_id}:${username}"

    # Communicate to the user what action is happening
    echo_yellow_newline "Adding user '${username}' to gshadow..."
    # Edit/create the gshadow file with the provided information
    edit_file "${profile_dir}/airootfs/etc/gshadow" "${group_name}:!::${username}"
}

# This function will create an iso from a profile
function create_iso() {
    # Prompt the user to select the profile to use
    local user_choice
    user_choice=$(prompt_user_choice "Select source profile: " false "${profiles[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    fi

    # Make sure that the users choice is in the available profiles array
    if [[ " ${profiles[*]} " =~ ${user_choice} ]]; then
        # If the user chose one of the available options, save the profile to a local variable
        profile_source="${profiles_dir}/${user_choice}"
    else
        echo_red_newline "No source profile found"
        return 4
    fi

    echo_yellow_newline "Creating iso..."

    # Check to make sure that the iso directory exists, if not create it
    if [ ! -d "$iso_dir" ]; then
        if ! mkdir --parents "$iso_dir"; then
            echo_red_newline "Failed to create ${iso_dir}"
            return 4
        fi
    fi

    # Create the iso from the profile, and provide feedback to the user
    if ! mkarchiso -v -w "/tmp/archiso-tmp" -o "$iso_dir" "$profile_source"; then
        echo_red_newline "Failed to create iso"
        return 4
    fi
    echo_green_newline "Created iso '${iso_dir}'"
}

# This function will create a new profile from an existing profile
function create_profile() {
    # Prompt the user to select the profile to use
    local user_choice
    user_choice=$(prompt_user_choice "Select source profile: " false "${profiles[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    fi

    # Make sure that the users choice is in the available profiles array
    if [[ " ${profiles[*]} " =~ ${user_choice} ]]; then
        profile_source="${profiles_dir}/${user_choice}"
    else
        echo_red_newline "No source profile found"
        return 4
    fi

    # Prompt the user for the profile name, and save it to a local variable
    local profile_name
    profile_name=$(prompt_user_input "Enter profile name")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    fi

    # Check to make sure that the profiles directory exists, if not create it
    local profiles_dest="$profiles_out/$profile_name"
    if [ ! -d "$profiles_dest" ]; then
        if ! mkdir --parents "$profiles_dest"; then
            echo_red_newline "Failed to create ${profiles_dest}"
            return 4
        fi
    fi

    # Copy the profile to the profiles directory, and provide feedback to the user
    if cp --recursive --preserve "$profile_source/." "$profiles_dest/"; then
        echo_green_newline "Created profile '${profile_name}'"
    else
        echo_red_newline "Failed to create profile '${profile_name}'"
        return 4
    fi

    # Check to see if the profile name is already in the config file, if not add it
    if ! grep -q "$profile_name" config; then
        sed -i "s/profiles=(/profiles=(\"${profile_name}\" /" config
    fi

    # If the remote directory exists, copy the Welcome.html file to the profile
    if [[ -d "remote" ]]; then
        if cp "remote/Welcome.html" "$profiles_dest/airootfs/root/"; then
            echo_green_newline "Copied Welcome.html to '${profiles_dest}/airootfs/root/'"
        else
            echo_red_newline "Failed to copy Welcome.html to '${profiles_dest}/airootfs/root/'"
            return 4
        fi
    fi
}

# This function will create a command for a user to create a vm from an iso
function create_mv() {
    # Find all available isos and save them to a local variable
    local isos
    isos=$(find iso -name "*.iso" -printf "%f ")
    # shellcheck disable=SC2206
    isos=($isos)

    # Prompt the user to select the iso to use for the vm, and save it to a local variable
    local user_choice
    user_choice=$(prompt_user_choice "Select iso: " false "${isos[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling mv creation"
        return 3
    fi

    # Prompt the user for the mv name, and save it to a local variable
    local mv_name
    mv_name=$(prompt_user_input "Enter mv name")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling mv creation"
        return 3
    fi

    # Create the command for the user to run to create the vm
    echo -e "\nvirt-install \\
        --name ${mv_name} \\
        --memory 1024 \\
        --vcpus=2,maxvcpus=4 \\
        --cpu host \\
        --cdrom iso/${user_choice} \\
        --disk size=2,format=qcow2 \\
        --network user \\
        --virt-type kvm\n"
}

# This function will create a new ssh key
function create_ssh_keys() {
    # Check if the ssh directory exists, if not create it
    if [ ! -d "$ssh_dir" ]; then
        mkdir --parents "$ssh_dir"
    fi

    # Prompt the user for the ssh key name, and save it to a local variable
    local user_input
    user_input=$(prompt_user_input "Enter ssh name")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling ssh key creation"
        return 3
    else
        local ssh_name="$user_input"
    fi

    # Prompt the user for ssh key comments, and save it to a local variable
    user_input=$(prompt_user_input "Enter ssh key comments")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling ssh key creation"
        return 3
    else
        local comments="$user_input"
    fi

    # Create the ssh key with the information provided by the user, and provide feedback to the user
    if [[ ! $(ssh-keygen -t $ssh_type -C "$comments" -N "" -f "$ssh_dir/$ssh_name.$ssh_type") ]]; then
        echo_red_newline "Failed to create ssh key"
        return 4
    else
        echo_green_newline "Created ssh key '${ssh_name}'"
    fi
}

# This function will add an ssh key to a profile
function add_ssh_key() {
    # Prompt the user to select the profile to use
    local user_choice
    user_choice=$(prompt_user_choice "Select source profile: " false "${profiles[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling profile creation"
        return 3
    else
        local profile="${profiles_dir}/${user_choice}"
    fi

    # Find all available ssh keys and save them to a local variable
    local ssh_keys
    ssh_keys=$(find "$ssh_dir" -name "*.$ssh_type" -printf "%f ")
    # shellcheck disable=SC2206
    ssh_keys=($ssh_keys)

    # Find the comment for each ssh key and save them to a local variable
    local key_comment
    for key in "${ssh_keys[@]}"; do
        key_comment+=("$(ssh-keygen -l -f "$ssh_dir/$key" | awk '{print $3} ')")
    done

    # Add the comment to the ssh key name, for it easier selection
    for i in "${!ssh_keys[@]}"; do
        ssh_keys[i]="${ssh_keys[i]} (Comment: ${key_comment[i]})"
    done

    # Prompt the user to select the ssh key to add to the profile, and save it to a local variable
    user_choice=$(prompt_user_choice "Select key: " false "${ssh_keys[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling mv creation"
        return 3
    else
        local key
        key=$(echo "$user_choice" | awk '{print $1}')
    fi

    # Check if the ssh directory exists, if not create it
    if [[ ! -d "$profile/airootfs/root/.ssh/" ]]; then
        mkdir --parents "$profile/airootfs/root/.ssh/"
    fi

    # Copy the ssh key to the profile, and provide feedback to the user
    if cp -r "$ssh_dir/$key" "$profile/airootfs/root/.ssh/"; then
        echo_green_newline "Added ssh key '${key}'"
    else
        echo_red_newline "Failed to add ssh key '${key}'"
        return 4
    fi
}

# This function will set the hostname for a profile
function set_hostname() {
    # Prompt the user to select the profile to use
    local user_choice
    user_choice=$(prompt_user_choice "Select profile: " false "${profiles[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling set hostname"
        return 3
    fi

    # Make sure that the users choice is in the available profiles array
    if [[ " ${profiles[*]} " =~ ${user_choice} ]]; then
        profile_source="${profiles_dir}/${user_choice}"
    else
        echo_red_newline "No profile found"
        return 4
    fi

    # Prompt the user for the hostname, and save it to a local variable
    local hostname
    hostname=$(prompt_user_input "Enter hostname")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling set hostname"
        return 3
    fi

    # Define the name of the file that will contain the hostname
    local hostname_file="${profile_source}/airootfs/etc/hostname"

    # Check if the hostname file exists, if not create it
    if [ -f "$hostname_file" ]; then
        # Replace whatever is in hostname_file with hostname
        if ! sed -i "s/.*/${hostname}/" "$hostname_file"; then
            echo_red_newline "Failed to set hostname"
            return 4
        fi
    else
        # Create the hostname file and add the hostname to it
        if touch "$hostname_file"; then
            if ! echo "$hostname" >"$hostname_file"; then
                echo_red_newline "Failed to set hostname"
                return 4
            fi
        else
            echo_red_newline "Failed to create ${hostname_file}"
            return 4
        fi
    fi
    # Provide feedback to the user
    echo_green_newline "Set hostname to '${hostname}'"
}

# This function will set the locale for a profile
function set_locale() {
    # Prompt the user to select the profile to use
    local user_choice
    user_choice=$(prompt_user_choice "Select profile: " false "${profiles[@]}")
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling set locale"
        return 3
    fi
    # Make sure that the users choice is in the available profiles array
    if [[ " ${profiles[*]} " =~ ${user_choice} ]]; then
        profile_source="${profiles_dir}/${user_choice}"
    else
        echo_red_newline "No profile found"
        return 4
    fi

    # Print the user to enter the locale and provide the default as an option, and save it to a local variable
    user_choice=$(prompt_user_choice "Select locale: " true "Default locale: ${default_locale}")
    # Save the return code as it's used more than once
    local prompt_rc=$?
    if [[ $prompt_rc -eq 3 ]]; then
        # If the user cancels, provide feedback and return
        echo_red_newline "Canceling set locale"
        return 3
    elif [[ $prompt_rc -eq 1 ]]; then
        # If the user manually inputs a locale, set the locale to the user input
        local locale="$user_choice"
    else
        # If the user selects the default locale, set the locale to the default
        local locale="$default_locale"
    fi

    # Define the name of the file that will contain the locale
    local locale_file="${profile_source}/airootfs/etc/locale.conf"

    # Check if the locale file exists, if not create it
    if [ -f "$locale_file" ]; then
        # Replace whatever is in locale_file with LANG=$locale
        if ! sed -i "s/.*/LANG=${locale}/" "$locale_file"; then
            echo_red_newline "Failed to set hostname"
            return 4
        fi
    # If the locale file exists, but is empty, add LANG=$locale to it
    else
        if touch "$locale_file"; then
            if ! echo "$hostname" >"$locale_file"; then
                echo_red_newline "Failed to set locale"
                return 4
            fi
        else
            echo_red_newline "Failed to create ${locale_file}"
            return 4
        fi
    fi

    # Provide feedback to the user
    echo_green_newline "Set locale to '${locale}'"
}

# This function creates a menu for the user to select an action
function menu() {
    local user_choice
    # Define the actions that the user can select from
    actions=("Mount NFS" "Unmount NFS" "Add User" "Create ISO" "Create Profile" "Set Hostname" "Create VM" "Create SSH Keys" "Add SSH Key" "Exit")
    # Prompt the user to select an action, and save it to a local variable
    user_choice=$(prompt_user_choice "Select action: " false "${actions[@]}")
    # If the return code is 3, the user canceled, so exit
    if [[ $? -eq 3 ]]; then
        echo_red_newline "Canceling"
        exit
    fi

    # Run the function that corresponds to the users choice
    case $user_choice in
    "Mount NFS")
        mount_nfs
        ;;
    "Unmount NFS")
        unmount_nfs
        ;;
    "Add User")
        add_user
        ;;
    "Create ISO")
        create_iso
        ;;
    "Create Profile")
        create_profile
        ;;
    "Set Hostname")
        set_hostname
        ;;
    "Create VM")
        create_mv
        ;;
    "Create SSH Keys")
        create_ssh_keys
        ;;
    "Add SSH Key")
        add_ssh_key
        ;;
    "Exit")
        exit 0
        ;;
    esac
}

# This function is the main function that Runs the menu in a loop so the user can run multiple actions
function main() {
    # Verify that the user is running as root, if not exit
    check_root

    # Run the menu in a loop
    while true; do
        menu
    done
}

main
