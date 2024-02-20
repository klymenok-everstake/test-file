#!/bin/bash
# Script to switch CentOS 7 to Oracle Linux 8 yum repository.

set -e
unset CDPATH

yum_url="https://yum.oracle.com"
github_url="https://github.com/oracle/centos2ol/"
arch=$(uname -m)

usage() {
    echo "Usage: ${0##*/} [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "-h        Display this help and exit"
    echo "-k        Do not install the UEK kernel and disable UEK repos"
    echo "-r        Reinstall all CentOS RPMs with Oracle Linux RPMs"
    echo "          Note: This is not necessary for support"
    echo "-V        Verify RPM information before and after the switch"
    exit 1
} >&2

have_program() {
    hash "$1" >/dev/null 2>&1
}

dep_check() {
    if ! have_program "$1"; then
        echo "'${1}' command not found. Please install or add it to your PATH and try again."
        exit 1
    fi
}

exit_message() {
    echo "$1"
    echo "For assistance, please open an issue via GitHub: ${github_url}."
    exit 1
} >&2

if [ "$(id -u)" -ne 0 ]; then
    exit_message "You must run this script as root. Try running 'sudo ${0}'."
fi

echo "Checking for required packages..."
for pkg in rpm yum curl; do
    dep_check "${pkg}"
done

echo "Checking your distribution..."
if ! old_release=$(rpm -q --whatprovides redhat-release); then
    exit_message "You appear to be running an unsupported distribution."
fi

echo "Downloading Oracle Linux 8 yum repository file..."
repo_file="oracle-linux-ol8.repo"
curl -o "/etc/yum.repos.d/${repo_file}" "${yum_url}/repo/OracleLinux/OL8/baseos/latest/x86_64/getPackage/${repo_file}"

echo "Switching old release package with Oracle Linux..."
rpm --import "${yum_url}/RPM-GPG-KEY-oracle-ol8"

yum remove -y "${old_release}"
yum install -y oraclelinux-release-el8

echo "Switching to Oracle Linux 8 repositories..."
yum-config-manager --enable ol8_baseos_latest ol8_appstream

install_uek_kernel=true
while getopts "hrkV" option; do
    case "$option" in
        h) usage ;;
        r) ;; # Placeholder for reinstall option
        k) install_uek_kernel=false ;;
        V) ;; # Placeholder for verify option
        *) usage ;;
    esac
done

if [ "${install_uek_kernel}" = true ]; then
    echo "Installing UEK (Unbreakable Enterprise Kernel)..."
    yum-config-manager --enable ol8_UEKR6
    yum install -y kernel-uek
fi

echo "Cleaning up..."
yum clean all

echo "Rebuilding RPM database..."
rpm --rebuilddb

echo "Performing distro-sync..."
yum -y distro-sync

echo "Update completed successfully. Please reboot your system."
