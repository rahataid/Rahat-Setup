#!/bin/bash

set -o errexit

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

# Check whether 'wget' command exists.
has_wget() {
    has_cmd wget
}

# Check whether 'curl' command exists.
has_curl() {
    has_cmd curl
}

# Check whether the given command exists.
has_cmd() {
    command -v "$1" > /dev/null 2>&1
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


# Function to install Docker
install_docker() {
    echo "Installing Docker..."
    
    if [[ $package_manager == "apt-get" ]]; then
        # Install Docker on Ubuntu/Debian-based systems
        $sudo_cmd apt-get update -y || handle_error "updating package list"
        $sudo_cmd apt-get install -y apt-transport-https ca-certificates curl software-properties-common || handle_error "installing dependencies"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $sudo_cmd apt-key add - || handle_error "adding Docker GPG key"
        $sudo_cmd add-apt-repository "deb [arch=$arch] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || handle_error "adding Docker repository"
        $sudo_cmd apt-get update -y || handle_error "updating package list"
        $sudo_cmd apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || handle_error "installing Docker"
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
    echo -e "🐳 Starting Docker ...\n"
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
    echo "Cloning Rahat-Setup repository..."
    git clone https://github.com/rahataid/Rahat-Setup.git || handle_error "cloning Rahat-Setup repository"
    cd Rahat-Setup || handle_error "changing to Rahat-Setup directory"
    CWD=$(pwd)  # Store current working directory (Rahat-Setup)
}

clone_sub_repositories() {
    echo "Cloning rahat-platform repository..."
    git clone https://github.com/rahataid/rahat-platform.git || handle_error "cloning rahat-platform repository"
    cd rahat-platform && git checkout dev || handle_error "checking out dev branch in rahat-platform"
    pnpm install || handle_error "installing pnpm dependencies in rahat-platform"
    pnpx prisma generate || handle_error "generating Prisma client for rahat-platform"
    cd $CWD

    echo "Cloning rahat-ui repository..."
    git clone https://github.com/rahataid/rahat-ui.git || handle_error "cloning rahat-ui repository"
    cd rahat-ui && git checkout dev || handle_error "checking out dev branch in rahat-ui"
    pnpm install || handle_error "installing pnpm dependencies in rahat-ui"
    cd $CWD
}

# Setup environment variables
setup_environment() {
    echo "Setting up environment files..."
    cd docker || handle_error "changing to docker directory"
    cp .env.platform.example .env.platform || handle_error "copying .env.platform.example"
    cp .env.rahat-ui.example .env.rahat-ui || handle_error "copying .env.rahat-ui.example"
    cd $CWD

    echo "Copying .env.platform into rahat-platform..."
    cp docker/.env.platform rahat-platform/.env || handle_error "copying .env.platform to rahat-platform"
}

# Start application with Docker Compose
start_docker_compose() {
    echo "Starting application with Docker Compose..."
    if [ "$1" == "dev" ]; then
        echo "Running docker-compose-local.yaml for development..."
        cd docker || handle_error "changing to docker directory"
        docker compose -f docker-compose-local.yaml up -d --build || handle_error "starting Docker containers with docker-compose-local"
    else
        echo "Running docker-compose.yaml for production..."
        cd docker || handle_error "changing to docker directory"
        docker compose -f docker-compose.yaml up -d || handle_error "starting Docker containers with docker-compose"
    fi
}

# Run Prisma migrations
run_prisma_migrations() {
    echo "Running Prisma migration..."
    
    # Check if 'dev' argument is passed
    if [[ "$1" == "dev" ]]; then
        # If 'dev' is passed, run the migration locally
        cd $CWD
        cd rahat-platform || handle_error "changing to rahat-platform directory"
        pnpx prisma migrate dev --skip-seed || handle_error "running Prisma migration"
        cd $CWD
    else
        # If 'dev' is not passed, run the migration inside the Docker container
        echo "No 'dev' argument passed. Running Prisma migration inside Docker container..."
        docker exec rahat_platform pnpx prisma migrate dev --skip-seed || handle_error "running Prisma migration inside Docker container"
    fi
}


# Restart Docker Compose
restart_docker_compose() {
    echo "Restarting Docker Compose..."
    cd docker || handle_error "changing to docker directory"
    docker compose -f docker-compose-local.yaml restart || handle_error "restarting Docker containers with docker-compose"
}

# Cleanup function
cleanup() {
    echo "Stopping Docker containers..."
    cd docker || handle_error "changing to docker directory"
    docker compose down || handle_error "stopping Docker containers"

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
            sudo usermod -aG docker "${USER}"
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
        # Clone Rahat-Setup repository (always)
        clone_repositories

        # Clone sub-repositories (rahat-platform, rahat-ui)
        clone_sub_repositories

        # Setup environment variables
        setup_environment
    else
        # If 'dev' argument is not passed, just clone the Rahat-Setup repository
        clone_repositories
    fi

    # Start application with the appropriate Docker Compose file
    start_docker_compose "$1"

    # Run Prisma migrations
    run_prisma_migrations

    # Restart Docker Compose
    restart_docker_compose

    echo "Setup completed successfully."
}

# Call the main function to execute the setup
main "$1"
