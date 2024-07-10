#!/bin/bash

# Function to prompt user for input with a default value
prompt_with_default() {
	local prompt="$1"
	local default="$2"
	read -p "$prompt [$default]: " value
	value=${value:-$default}
}

# Installation wizard
echo "Welcome to the installation wizard!"

# Step 1: Select projects directory
prompt_with_default "Enter the directory for storing projects" "$HOME/projects"
projects_dir="$value"

# Step 2: Enter URL for private repositories
prompt_with_default "Enter the URL for your private repositories" "gitlab.mydomain.com"
private_repo_url="$value"

# Check if the selected directory exists, if not, create it
if [ ! -d "$projects_dir" ]; then
	read -p "The directory '$projects_dir' does not exist. Do you want to create it? [y/N]: " create_dir
	if [[ $create_dir =~ ^[Yy]$ ]]; then
		mkdir -p "$projects_dir"
		echo "Directory '$projects_dir' created."
	else
		echo "Installation aborted. Please select a valid directory."
		exit 1
	fi
fi

# Check if Golang is installed, if not, install it
if ! command -v go &>/dev/null; then
	echo "Golang is not installed. Installing Golang..."

	# Detect the operating system
	case "$(uname -s)" in
	Linux*)
		# Ubuntu
		if command -v apt-get &>/dev/null; then
			sudo apt-get update
			sudo apt-get install -y golang
		else
			echo "Unsupported Linux distribution. Please install Golang manually."
			exit 1
		fi
		;;
	Darwin*)
		# macOS with Homebrew
		if command -v brew &>/dev/null; then
			brew update
			brew install golang
		else
			echo "Homebrew is not installed. Please install Golang manually."
			exit 1
		fi
		;;
	CYGWIN* | MINGW* | MSYS*)
		# Windows with Chocolatey
		if command -v choco &>/dev/null; then
			choco install golang
		else
			echo "Chocolatey is not installed. Please install Golang manually."
			exit 1
		fi
		;;
	*)
		echo "Unsupported operating system. Please install Golang manually."
		exit 1
		;;
	esac

	echo "Golang installed successfully."
fi

# Set GOPRIVATE environment variable
export GOPRIVATE="$private_repo_url"
echo "GOPRIVATE environment variable set to '$private_repo_url'."

# Prompt user to add a project to the workspace
while true; do
	read -p "Enter the repository URL to add a project to the workspace (or press Enter to skip): " repo_url
	if [ -z "$repo_url" ]; then
		break
	fi
	./ws.sh "$repo_url"
done

echo "Installation completed successfully!"
