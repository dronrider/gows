#!/usr/bin/env bash

Version="0.0.0"

# Set the folder for the projects
work_folder="./"
work_project=""

CO='\033[0m' # color off
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

unset -v url
unset -v env
unset -v dest

function show_help() {
  echo "Usage: $(basename $0) [h|v|u|e|d]"
  echo "Options:"
  echo "  -h, --help     Display this help message"
  echo "  -v, --version  Display version information"
  echo "  -u, --url      SSH URL to git progect"
  echo "  -e, --env      Path to file - bash script"
  echo "  -d, --dest     Path to destination dir"

  exit 1
}

# Function to clone a project repository
function clone_project() {
    local host=$1 group=$2 project=$3
    if [[ -n "$host" && -n "$group" && -n "$project" ]]; then
        local dir="$projects_folder/$group/$project"
        if [[ ! -d "$dir" || -z "$(ls -A "$dir")" ]]; then
            mkdir -p "$dir"
            git clone "git@${host}:${group}/${project}.git" "$dir"
        fi
    fi
}

# Function to process the Git path and clone the project
function process_git_path() {
    IFS='@:/' read -ra parts <<< "$url"
    local host="${parts[1]}" group="${parts[2]}" project="${parts[3]%%.*}"
    clone_project "$host" "$group" "$project"
    echo "$group/$project"
}

# Function to process a line from go.mod file
function process_go_mod_line() {
    local path=$(echo "$1" | sed -E 's| v[0-9]+(\.[0-9]+)*.*||' | sed -E 's|/v[0-9]+||' | xargs)
    echo -e "path: ${path}"
    if [[ -z "${processed_paths["$path"]}" ]]; then
        IFS='/' read -ra parts <<< "$path"
        local host="${parts[0]}" group="${parts[1]}" project="${parts[2]}" submodule="${parts[3]}"
        clone_project "$host" "$group" "$project"

        if [[ -z "$submodule" ]]; then
            echo "replace $path => $projects_folder/$group/$project" >> $work_folder/go.work
        else
            echo "replace $path => $projects_folder/$group/$project/$submodule" >> $work_folder/go.work
        fi

        processed_paths[$path]=1
        # Add the project to the YAML file
        echo "  - $path" >> "$work_project.yaml"
    fi
}

while getopts ":hv:u:e:d:" opt; do
  case $opt in
    h) show_help ;;
    v) 
        echo $Version 
        exit ;;
    u) url=$OPTARG ;;
    e) env=$OPTARG ;;
    d) dest=$OPTARG ;;
    \?) show_help ;;
  esac
done

# Check if the requiRED arguments are provided
if [[ -z "$url" ]]; then echo -e "${RED}git project url requiRED${CO}"; exit 1; fi

if [ -f "$env" ]; then
    echo -e "${GREEN}Found additional env file, executing...${CO}"
    sh $env
fi

if [ ! -z "$dest" ]; then
    work_folder=$dest
fi

projects_folder="${work_folder}projects"
internal_host=$(echo $url | sed 's/.*@\(.*\):.*/\1/')

echo -e "\n${YELLOW}Folders: ${CO}"
echo -e "${YELLOW}work dir: $work_folder ${CO}"
echo -e "${YELLOW}projects dir: $projects_folder ${CO}"
echo -e "${YELLOW}host for internal packages: $internal_host  ${CO}"
echo -e "${YELLOW}git URL: $url  ${CO}\n"

# Associative array to keep track of processed paths
declare -A processed_paths

# Initialize Go workspace to the work directory
echo -e "${GREEN}Step 1/5: Goint to the work directory, init go work... ${CO}"
cd $work_folder
go work init

# Process the Git path and extract the work project
echo -e "${GREEN}Step 2/5: Parsing getting project URL, cloning to the projects folder... ${CO}"
path_part=$(process_git_path "$1")
echo -e "generated project tree: $path_part"

echo -e "${GREEN}Step 3/5: Create project's deps file... ${CO}"
IFS='/' read -ra parts <<< "$path_part"
mkdir -p "$work_folder/deps"
work_project="${work_folder}/deps/${parts[0]}-${parts[1]}"
# Create the YAML file for the service dependencies
echo "dependencies:" > "$work_project.yaml"
echo -e "created dependencies file: "$work_project.yaml""

echo -e "${GREEN}Step 4/5: Walking to project's go.mod file and download internal deps... ${CO}"
# Set the go.mod path based on the provided argument or default to the project path
go_mod_path=$projects_folder/$path_part
echo -e "path to go.mod: $go_mod_path"
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
        [[ $line != *"$internal_host"* ]] && continue
        process_go_mod_line "$line"
    fi

    [[ $start -eq 2 || $start -eq 3 ]] && start=1
done < "$go_mod_path/go.mod"

# Use the Go workspace and sync dependencies
echo -e "${GREEN}Step 5/5: Executing go work... ${CO}"
go work use "$go_mod_path"
go work sync
