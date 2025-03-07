#!/bin/bash

set -o errexit

# --- Global Variables ---
sudo_cmd=""
package_manager=""
desired_os=0
os=""
arch=""
arch_official=""
CWD=""
docker_installed="false"
PROJECT_INFO="/tmp/.project_info"


# Regular Colors
Black='\033[0;30m'        # Black
Red='\[\e[0;31m\]'        # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White
NC='\033[0m' # No Color

# Function to handle errors
handle_error() {
    echo "Error occurred during $1."
    exit 1
}

is_command_present() {
    type "$1" >/dev/null 2>&1
}

# Check whether the given command exists.

has_cmd() {
    command -v "$1" > /dev/null 2>&1
}

# Check whether 'wget' command exists.
has_wget() {
    has_cmd wget
}

has_sed() {
    has_cmd sed
}

# Check whether 'curl' command exists.
has_curl() {
    has_cmd curl
}

has_nvm() {
    [ -s "$HOME/.nvm/nvm.sh" ]
}

has_node() {
    has_cmd node
}

has_pnpm() {
    has_cmd pnpm
}

is_mac() {
    [[ $OSTYPE == darwin* ]]
}

is_arm64(){
    [[ `uname -m` == 'arm64' || `uname -m` == 'aarch64' ]]
}

check_os() {
    if is_mac; then
        package_manager="brew"
        desired_os=1
        os="Mac"
        return
    fi

    if is_arm64; then
        arch="arm64"
        arch_official="aarch64"
    else
        arch="amd64"
        arch_official="x86_64"
    fi

    platform=$(uname -s | tr '[:upper:]' '[:lower:]')

    os_name="$(cat /etc/*-release | awk -F= '$1 == "NAME" { gsub(/"/, ""); print $2; exit }')"

    case "$os_name" in
        Ubuntu*|Pop!_OS)
            desired_os=1
            os="ubuntu"
            package_manager="apt-get"
            ;;
        Amazon\ Linux*)
            desired_os=1
            os="amazon linux"
            package_manager="yum"
            ;;
        Debian*)
            desired_os=1
            os="debian"
            package_manager="apt-get"
            ;;
        Linux\ Mint*)
            desired_os=1
            os="linux mint"
            package_manager="apt-get"
            ;;
        Red\ Hat*)
            desired_os=1
            os="red hat"
            package_manager="dnf"
            ;;
        CentOS*)
            desired_os=1
            os="centos"
            package_manager="dnf"
            ;;
        Rocky*)
            desired_os=1
            os="centos"
            package_manager="dnf"
            ;;
        SLES*)
            desired_os=1
            os="sles"
            package_manager="zypper"
            ;;
        openSUSE*)
            desired_os=1
            os="opensuse"
            package_manager="zypper"
            ;;
        *)
            desired_os=0
            os="Not Found: $os_name"
    esac
}

check_ports_occupied() {
    echo ""
    echo "-------------------------"
    echo "-------------------------"
    echo "-------------------------"
    local port_check_output
    local ports_pattern="3000|3333"

    if is_mac; then
        port_check_output="$(netstat -anp tcp | awk '$6 == "LISTEN" && $4 ~ /^.*\.('"$ports_pattern"')$/')"
    elif is_command_present ss; then
        port_check_output="$(ss --all --numeric --tcp | awk '$1 == "LISTEN" && $4 ~ /^.*:('"$ports_pattern"')$/')"
    elif is_command_present netstat; then
        port_check_output="$(netstat --all --numeric --tcp | awk '$6 == "LISTEN" && $4 ~ /^.*:('"$ports_pattern"')$/')"
    fi

    if [[ -n $port_check_output ]]; then
        send_event "port_not_available"

        echo "+++++++++++ ERROR ++++++++++++++++++++++"
        echo "Rahat requires ports 3000 & 3333 to be open. Please shut down any other service(s) that may be running on these ports."
        echo "++++++++++++++++++++++++++++++++++++++++"
        echo ""
        exit 1
    fi
}


show_checklist() {
    echo ""
    echo "---------------------------------------"
    echo "🔍 Pre-installation Checklist:"
    echo "---------------------------------------"
    
    # Align columns for a more tabular output
    printf "%-40s %s\n" "Checking if 'curl' is available..." "$(has_curl && echo "✅ Found" || echo "❌ Missing")"
    printf "%-40s %s\n" "Checking if 'wget' is available..." "$(has_wget && echo "✅ Found" || echo "❌ Missing")"
    printf "%-40s %s\n" "Checking if 'sed' is available..." "$(has_sed && echo "✅ Found" || echo "❌ Missing")"
    printf "%-40s %s\n" "Checking if 'docker' is available..." "$(is_command_present docker && echo "✅ Found" || echo "❌ Missing")"

    if [ "$1" == "dev" ]; then
        echo ""
        echo "🛠️ Dev mode enabled! Additional checks:"
        printf "%-40s %s\n" "Checking if 'nvm' is available..." "$(has_nvm && echo "✅ Found" || echo "❌ Missing")"
        printf "%-40s %s\n" "Checking if 'node' is available..." "$(has_node && echo "✅ Found" || echo "❌ Missing")"
        printf "%-40s %s\n" "Checking if 'pnpm' is available..." "$(has_pnpm && echo "✅ Found" || echo "❌ Missing")"
    fi
}

setup_node() {
    echo ""
    echo "---------------------------------------"
    echo "🔍 Setup Node:"
    echo "---------------------------------------"
    export NVM_DIR="$HOME/.nvm"

    if has_nvm; then
        echo "✅ NVM is already installed. Loading NVM..."
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "loading nvm.sh"
    else
        echo "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash || handle_error "installing NVM"
        echo "Loading NVM..."
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "loading nvm.sh"
    fi

    if has_node; then
        echo "✅ Node.js is already installed."
    else
        echo "Installing Node.js v20..."
        nvm install v20 || handle_error "installing Node.js v20"
    fi

    if has_pnpm; then
        echo "✅ PNPM is already installed globally."
    else
        echo "Installing PNPM globally..."
        npm install -g pnpm || handle_error "installing pnpm"
    fi

    echo "✅ Node.js and pnpm setup complete!"
}



request_sudo() {
    if hash sudo 2>/dev/null; then
        echo -e "\n\n🙇 We will need sudo access to complete the installation."
        if (( $EUID != 0 )); then
            sudo_cmd="sudo"
            echo -e "Please enter your sudo password, if prompted."
            if ! $sudo_cmd -l | grep -e "NOPASSWD: ALL" > /dev/null && ! $sudo_cmd -v; then
                echo "Need sudo privileges to proceed with the installation."
                exit 1;
            fi

            echo -e "Got it! Thanks!! 🙏\n"
            echo -e "Okay! We will bring up the Rahat cluster from here 🚀\n"
        fi
	fi
}

# Function to install Docker
install_docker() {
    echo ""
    echo "---------------------------------------"
    echo "Installing Docker..."
    echo "---------------------------------------"
    
    if [[ $package_manager == "apt-get" ]]; then
        # Install Docker on Ubuntu/Debian-based systems
        $sudo_cmd apt-get update -y || handle_error "updating package list"
        $sudo_cmd apt-get install -y apt-transport-https ca-certificates curl software-properties-common || handle_error "installing dependencies"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $sudo_cmd tee /etc/apt/keyrings/docker.asc > /dev/null || handle_error "adding Docker GPG key"
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
        $sudo_cmd tee /etc/apt/sources.list.d/docker.list > /dev/null || handle_error "adding Docker repository"
        $sudo_cmd apt-get update -y || handle_error "updating package list"
        $sudo_cmd apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || handle_error "installing Docker"
        $sudo_cmd usermod -aG docker "${USER}" || handle_error "adding user to docker group"

        echo "✅ Docker installed successfully."
        echo "⚠️  You must log out and log back in to use Docker without sudo."
        echo "⚠️  For this session, Docker commands will need 'sudo'."
    elif [[ $package_manager == "yum" || $package_manager == "dnf" ]]; then
        # Install Docker on Red Hat/CentOS/Fedora-based systems
        $sudo_cmd yum install -y yum-utils || handle_error "installing yum-utils"
        $sudo_cmd yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || handle_error "adding Docker repo"
        $sudo_cmd yum install -y docker-ce docker-ce-cli containerd.io || handle_error "installing Docker"
    elif [[ $package_manager == "zypper" ]]; then
        # Install Docker on openSUSE/SLES systems
        $sudo_cmd zypper refresh || handle_error "refreshing zypper repositories"
        $sudo_cmd zypper install -y docker || handle_error "installing Docker"
    elif is_mac; then
        # On macOS, Docker Desktop must be installed manually
        echo "Docker Desktop must be installed manually on macOS. You can download it from: https://www.docker.com/products/docker-desktop"
        echo "After installing Docker Desktop, rerun this script to continue the setup."
        exit 1
    else
        echo "Docker installation is not supported for this OS. Please install Docker manually."
        exit 1
    fi
}

start_docker() {
    echo ""
    echo "---------------------------------------"
    echo "🐳 Starting Docker ..."
    echo "---------------------------------------"
    if [[ $os == "Mac" ]]; then
        open --background -a Docker && while ! docker system info > /dev/null 2>&1; do sleep 1; done
    else 
        if ! $sudo_cmd systemctl is-active docker.service > /dev/null; then
            echo "Starting docker service"
            $sudo_cmd systemctl start docker.service
        fi
        if [[ -z $sudo_cmd ]]; then
            if ! docker ps > /dev/null && true; then
                request_sudo
            fi
        fi
    fi
}

clone_repository() {
    echo ""
    echo "---------------------------------------"
    echo "Cloning Repository ..."
    echo "---------------------------------------"
    echo ""
    echo "Cloning Rahat-Setup repository..."
    git clone https://github.com/rahataid/Rahat-Setup.git || handle_error "cloning Rahat-Setup repository"
    cd Rahat-Setup || handle_error "changing to Rahat-Setup directory"
    CWD=$(pwd)  # Store current working directory (Rahat-Setup)
    echo "$CWD" >> "$PROJECT_INFO"
}

clone_sub_repositories() {
    echo ""
    echo "Cloning rahat-platform repository..."
    git clone https://github.com/rahataid/rahat-platform.git || handle_error "cloning rahat-platform repository"
    cd rahat-platform && git checkout dev || handle_error "checking out dev branch in rahat-platform"
    pnpm install || handle_error "installing pnpm dependencies in rahat-platform"
    pnpx prisma generate || handle_error "generating Prisma client for rahat-platform"
    cd $CWD
    
    echo ""
    echo "Cloning rahat-ui repository..."
    git clone https://github.com/rahataid/rahat-ui.git || handle_error "cloning rahat-ui repository"
    cd rahat-ui && git checkout dev || handle_error "checking out dev branch in rahat-ui"
    pnpm install || handle_error "installing pnpm dependencies in rahat-ui"
    cd $CWD
}

# Setup environment variables
setup_environment() {
    echo ""
    echo "---------------------------------------"
    echo "Setting up environment files..."
    echo "---------------------------------------"
    cd $CWD/docker || handle_error "changing to docker directory"
    cp $CWD/docker/.env.platform.example $CWD/docker/.env.platform || handle_error "copying .env.platform.example"

    if [ "$1" == "dev" ]; then
        cp $CWD/docker/.env.rahat-ui.example $CWD/docker/.env.rahat-ui || handle_error "copying .env.rahat-ui.example"
        cp $CWD/docker/.env.platform $CWD/rahat-platform/.env || handle_error "copying .env.platform to rahat-platform"
    fi
    
}

# Function to comment out the command line in the docker-compose.yml
comment_out_command_line() {
    echo ""
    echo "---------------------------------------"
    echo "Commenting Out Command Line..."
    echo "---------------------------------------"
    cd $CWD || handle_error "changing to Rahat-Setup directory"
    if [ "$1" == "dev" ]; then
        echo "Nothing"
    else
        echo "Commenting out the 'command: sleep 500' line in the docker-compose.yml..."
        sed -i 's/command: sleep 500/#command: sleep 500/' docker/docker-compose.yaml || handle_error "commenting out the 'command: sleep 500' line in docker-compose.yml"
    fi
}


# Start application with Docker Compose
start_docker_compose() {
    echo ""
    echo "---------------------------------------"
    echo "Starting application with Docker Compose..."
    echo "---------------------------------------"
    cd $CWD/docker || handle_error "changing to docker directory"
    if [ "$1" == "dev" ]; then
        echo "Running docker-compose-local.yaml for development..."
        $sudo_cmd docker compose -f docker-compose-local.yaml up -d --build || handle_error "starting Docker containers with docker-compose-local"
    else
        echo "Running docker-compose.yaml for production..."
        $sudo_cmd docker compose -f docker-compose.yaml up -d || handle_error "starting Docker containers with docker-compose"
    fi
}

# Run Prisma migrations
run_prisma_migrations() {
    echo ""
    echo "---------------------------------------"
    echo "Running Prisma migration..."
    echo "---------------------------------------"
    sleep 10  # Wait for Docker containers to start
    # Check if 'dev' argument is passed
    if [[ "$1" == "dev" ]]; then
        # If 'dev' is passed, run the migration locally
        cd $CWD/rahat-platform || handle_error "changing to rahat-platform directory"
        npx prisma migrate dev --skip-seed || handle_error "running Prisma migration"
        cd $CWD
    else
        # If 'dev' is not passed, run the migration inside the Docker container
        echo "No 'dev' argument passed. Running Prisma migration inside Docker container..."
        $sudo_cmd docker exec rahat_platform npx prisma migrate dev --skip-seed || handle_error "running Prisma migration inside Docker container"
    fi
}

# Restart Docker Compose
restart_docker_compose() {
    echo ""
    echo "---------------------------------------"
    echo "Restarting Docker Compose..."
    echo "---------------------------------------"
    cd $CWD/docker || handle_error "changing to docker directory"
    # Check if 'dev' argument is passed
    if [[ "$1" == "dev" ]]; then
        # If 'dev' is passed, run the migration locally
        $sudo_cmd docker compose -f docker-compose-local.yaml restart || handle_error "restarting Docker containers with docker-compose"
    else
        $sudo_cmd docker rm rahat_platform -f || handle_error "removing rahat-platform container"
        $sudo_cmd docker compose -f docker-compose.yaml up -d || handle_error "restarting Docker containers with docker-compose"
    fi
    cd $CWD
}


check_services_status() {
    echo ""
    echo "------------------------------------------------------------"
    echo "🔍 Checking if Docker containers are running properly..."
    echo "------------------------------------------------------------"

    # Check if Rahat UI container is running
    if docker ps --filter "name=rahat_ui" --format '{{.Names}}' > /dev/null; then
        echo "✅ Rahat UI container is running."
    else
        echo "❌ Rahat UI container is not running."
    fi

    # Check if Rahat Platform container is running
    if docker ps --filter "name=rahat_platform" --format '{{.Names}}' > /dev/null; then
        echo "✅ Rahat Platform container is running."
    else
        echo "❌ Rahat Platform container is not running."
    fi
    
    echo ""
    echo "🔍 Checking if Rahat UI and Rahat Platform are accessible..."

    # Check if Rahat UI is accessible on localhost:3000
    if curl --silent --head --fail http://localhost:3000 > /dev/null; then
        echo "✅ Rahat UI is accessible at http://localhost:3000"
    else
        echo "❌ Rahat UI is not accessible at http://localhost:3000"
    fi

    # Check if Rahat Platform is accessible on localhost:3333
    if curl --silent --head --fail http://localhost:3333 > /dev/null; then
        echo "✅ Rahat Platform is accessible at http://localhost:3333"
    else
        echo "❌ Rahat Platform is not accessible at http://localhost:3333"
    fi

    echo ""
}


# Cleanup function
cleanup() {
    echo ""
    echo "-------------------------------------"
    echo "🔍 Stopping Docker containers..."
    echo "-------------------------------------"

    # Read docker_installed and CWD from the .project_info file
    docker_installed=$(sed -n '1p' "$PROJECT_INFO")  # First line is docker_installed
    CWD=$(sed -n '2p' "$PROJECT_INFO")  # Second line is CWD

    # Check if we successfully read the information
    if [ -z "$docker_installed" ] || [ -z "$CWD" ]; then
        echo "Error: .project_info is missing required data."
        exit 1
    fi

    # Change directory to where the docker-compose file is located
    cd "$CWD/docker" || handle_error "changing to docker directory"

    # Stop and remove containers using docker-compose.yaml or docker-compose-local.yaml
    echo "Stopping containers using docker-compose..."
    $sudo_cmd docker compose -f docker-compose.yaml down || handle_error "stopping Docker containers from docker-compose.yaml"
    $sudo_cmd docker compose -f docker-compose-local.yaml down || handle_error "stopping Docker containers from docker-compose-local.yaml"

    echo "Docker containers stopped and removed."

    # Check if Docker was installed by the script and remove it
    if [ "$docker_installed" == "true" ]; then
        echo "Docker was installed by the script. Removing Docker..."
        if [[ $package_manager == "apt-get" ]]; then
            $sudo_cmd apt-get remove --purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y || handle_error "removing Docker"
            $sudo_cmd apt-get autoremove -y || handle_error "removing unused packages"
            $sudo_cmd apt-get clean || handle_error "cleaning up apt cache"
        elif [[ $package_manager == "yum" ]]; then
            $sudo_cmd yum remove docker-ce docker-ce-cli containerd.io -y || handle_error "removing Docker"
        elif [[ $package_manager == "dnf" ]]; then
            $sudo_cmd dnf remove docker-ce docker-ce-cli containerd.io -y || handle_error "removing Docker"
        fi
        # Remove the marker file after Docker is removed
        rm $PROEJECT_INFO
        echo "Docker removed successfully."
    else
        echo "Docker was already installed, skipping removal."
    fi
}

# Main Script Execution
main() {
    if [ "$1" == "cleanup" ]; then
        cleanup
        exit 0
    fi

    show_checklist "$1"

    echo ""
    echo -e "👋 Thank you for trying out Rahat! "
    echo ""

    sudo_cmd=""

    # Check sudo permissions
    if (( $EUID != 0 )); then
        echo "🟡 Running installer with non-sudo permissions."
        echo "   In case of any failure or prompt, please consider running the script with sudo privileges."
        echo ""
    else
        sudo_cmd="sudo"
    fi

    # Checking OS and assigning package manager
    desired_os=0
    os=""
    email=""
    echo -e "🌏 Detecting your OS ...\n"
    check_os

    # Check if Docker daemon is installed and available
    if ! is_command_present docker; then
        docker_installed=true
        if [[ $package_manager == "apt-get" || $package_manager == "zypper" || $package_manager == "yum" ]]; then
            request_sudo
            install_docker
            # Mark Docker as installed by the script
            PROJECT_INFO="/tmp/.project_info"
            echo "true" > "$PROJECT_INFO"

        elif is_mac; then
            echo ""
            echo "+++++++++++ IMPORTANT READ ++++++++++++++++++++++"
            echo "Docker Desktop must be installed manually on Mac OS to proceed. Docker can only be installed automatically on Ubuntu / openSUSE / SLES / Redhat / Cent OS"
            echo "https://docs.docker.com/docker-for-mac/install/"
            echo "++++++++++++++++++++++++++++++++++++++++++++++++"
            send_event "docker_not_installed"
            exit 1
        else
            echo ""
            echo "+++++++++++ IMPORTANT READ ++++++++++++++++++++++"
            echo "Docker must be installed manually on your machine to proceed. Docker can only be installed automatically on Ubuntu / openSUSE / SLES / Redhat / Cent OS"
            echo "https://docs.docker.com/get-docker/"
            echo "++++++++++++++++++++++++++++++++++++++++++++++++"
            send_event "docker_not_installed"
            exit 1
        fi
    fi

    start_docker

    # Check if 'dev' argument is passed
    if [ "$1" == "dev" ]; then
        setup_node "$1"
        # Clone Rahat-Setup repository (always)
        clone_repository

        # Clone sub-repositories (rahat-platform, rahat-ui)
        clone_sub_repositories

        # Setup environment variables
        setup_environment
    else
        # If 'dev' argument is not passed, just clone the Rahat-Setup repository
        clone_repository
    fi

    # Start application with the appropriate Docker Compose file
    start_docker_compose "$1"

    # Run Prisma migrations
    run_prisma_migrations "$1"

    # Comment out the 'command' line
    comment_out_command_line "$1"

    # Restart Docker Compose
    restart_docker_compose "$1"
    check_services_status
    newgrp docker
    echo ""
    echo "-------------------------------------"
    echo "Setup completed successfully. Now you can use docker without sudo"
    echo "-------------------------------------"
}

# Call the main function to execute the setup
main "$1"
