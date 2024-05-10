#!/bin/bash

# Set the folder for the projects
work_folder="./projects"
work_project=""

# Check if the required arguments are provided
if [[ -z "$1" ]]; then echo "git project url required"; exit 1; fi
if [[ -z "$2" ]]; then echo "url pattern required"; exit 1; fi

# Set Go environment variables
go env -w GOPRIVATE=$2
go env -w CGO_ENABLED=1

# Install libmagic on Mac OS X if not already installed
if [[ ! -f ./install.lock ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then # Mac OS X
        brew install libmagic
        brew link libmagic
        go env -w CGO_CFLAGS=-I/opt/homebrew/include
        go env -w CGO_LDFLAGS=-L/opt/homebrew/lib
    fi
    date '+%d/%m/%Y %H:%M:%S' > install.lock
else
    echo "skip install, install.lock created $(cat install.lock)"
fi

# Initialize Go workspace
go work init

# Function to clone a project repository
function clone_project() {
    local host=$1 group=$2 project=$3
    if [[ -n "$host" && -n "$group" && -n "$project" ]]; then
        local dir="$work_folder/$group/$project"
        if [[ ! -d "$dir" || -z "$(ls -A "$dir")" ]]; then
            mkdir -p "$dir"
            git clone "git@${host}:${group}/${project}.git" "$dir"
        fi
    fi
}

# Function to process the Git path and clone the project
function process_git_path() {
    IFS='@:/' read -ra parts <<< "$1"
    local host="${parts[1]}" group="${parts[2]}" project="${parts[3]%%.*}"
    clone_project "$host" "$group" "$project"
    echo "$work_folder/$group/$project"
}

# Associative array to keep track of processed paths
declare -A processed_paths

# Function to process a line from go.mod file
function process_go_mod_line() {
    local path=$(echo "$1" | sed -E 's| v[0-9]+(\.[0-9]+)*.*||' | sed -E 's|/v[0-9]+||' | xargs)
    if [[ -z "${processed_paths[$path]}" ]]; then
        IFS='/' read -ra parts <<< "$path"
        local host="${parts[0]}" group="${parts[1]}" project="${parts[2]}" submodule="${parts[3]}"

        clone_project "$host" "$group" "$project"

        if [[ -z "$submodule" ]]; then
            echo "replace $path => $work_folder/$group/$project" >> go.work
        else
            echo "replace $path => $work_folder/$group/$project/$submodule" >> go.work
        fi

        processed_paths[$path]=1
        # Add the project to the YAML file
        echo "  - $path" >> "$work_project.yaml"
    fi
}

# Process the Git path and extract the work project
path_part=$(process_git_path "$1")
IFS='/' read -ra parts <<< "$path_part"
mkdir -p "$work_folder/deps"
work_project="${work_folder}/deps/${parts[2]}-${parts[3]}"

# Set the go.mod path based on the provided argument or default to the project path
go_mod_path=${3:-$path_part}

# Create the YAML file for the service dependencies
echo "dependencies:" > "$work_project.yaml"

# Process the go.mod file and clone the required projects
start=0
while IFS= read -r line; do
    case $line in
        "require ("*) start=2 ;;
        "replace ("*) start=3 ;;
        ")") start=0; continue ;;
        *) [[ $start -eq 0 ]] && continue ;;
    esac

    if [[ $start -eq 1 ]]; then
        [[ $line != *"$2"* ]] && continue
        process_go_mod_line "$line"
    fi

    [[ $start -eq 2 || $start -eq 3 ]] && start=1
done < "$go_mod_path/go.mod"

# Use the Go workspace and sync dependencies
go work use "$go_mod_path"
go work sync