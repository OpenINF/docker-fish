#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) The OpenINF Authors and Friends. All rights reserved.
# Triply re-licensed under MIT/Apache-2.0/BlueOak-1.0.0. See LICENSE/ at project root for more info.
#-------------------------------------------------------------------------------------------------------------
#
# ** This script is community supported **
# Docs: https://github.com/OpenINF/openinf-docker-fish/blob/HEAD/library-scripts/docs/common.md
# Maintainer: The OpenINF Community
#
# Syntax: ./common-debian.sh [username] [user UID] [user GID] [upgrade packages flag] [Add non-free packages]

set -e

USERNAME=${1:-"automatic"}
USER_UID=${2:-"automatic"}
USER_GID=${3:-"automatic"}
UPGRADE_PACKAGES=${4:-"true"}
ADD_NON_FREE_PACKAGES=${5:-"false"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER_FILE="/usr/local/etc/vscode-dev-containers/common"

if [ "$(id -u)" -ne 0 ]; then
  echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
  exit 1
fi

# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" >/etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

# If in automatic mode, determine if a user already exists, if not use vscode
if [ "$USERNAME" = "auto" ] || [ "$USERNAME" = "automatic" ]; then
  USERNAME=""
  POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
  for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
    if id -u "$CURRENT_USER" >/dev/null 2>&1; then
      USERNAME=$CURRENT_USER
      break
    fi
  done
  if [ "$USERNAME" = "" ]; then
    USERNAME=vscode
  fi
elif [ "$USERNAME" = "none" ]; then
  USERNAME=root
  USER_UID=0
  USER_GID=0
fi

# Load markers to see which steps have already run
if [ -f "$MARKER_FILE" ]; then
  echo "Marker file found:"
  cat "$MARKER_FILE"
  source "$MARKER_FILE"
fi

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Function to call apt-get if needed
apt_get_update_if_needed() {
  if [ ! -d "/var/lib/apt/lists" ] || [ "$(ls /var/lib/apt/lists/ | wc -l)" = "0" ]; then
    echo "Running apt-get update..."
    apt-get update
  else
    echo "Skipping apt-get update."
  fi
}

# Run install apt-utils to avoid debconf warning then verify presence of other common developer tools and dependencies
if [ "$PACKAGES_ALREADY_INSTALLED" != "true" ]; then

  package_list="apt-utils \
        openssh-client \
        gnupg2 \
        dirmngr \
        iproute2 \
        procps \
        lsof \
        htop \
        net-tools \
        psmisc \
        curl \
        wget \
        rsync \
        ca-certificates \
        unzip \
        zip \
        nano \
        vim-tiny \
        less \
        jq \
        lsb-release \
        apt-transport-https \
        dialog \
        libc6 \
        libgcc1 \
        libkrb5-3 \
        libgssapi-krb5-2 \
        libicu[0-9][0-9] \
        liblttng-ust[0-9] \
        libstdc++6 \
        zlib1g \
        locales \
        sudo \
        ncdu \
        man-db \
        strace \
        manpages \
        manpages-dev \
        init-system-helpers"

  # Needed for adding manpages-posix and manpages-posix-dev which are non-free packages in Debian
  if [ "$ADD_NON_FREE_PACKAGES" = "true" ]; then
    # Bring in variables from /etc/os-release like VERSION_CODENAME
    . /etc/os-release
    sed -i -E "s/deb http:\/\/(deb|httpredir)\.debian\.org\/debian $VERSION_CODENAME main/deb http:\/\/\1\.debian\.org\/debian $VERSION_CODENAME main contrib non-free/" /etc/apt/sources.list
    sed -i -E "s/deb-src http:\/\/(deb|httredir)\.debian\.org\/debian $VERSION_CODENAME main/deb http:\/\/\1\.debian\.org\/debian $VERSION_CODENAME main contrib non-free/" /etc/apt/sources.list
    sed -i -E "s/deb http:\/\/(deb|httpredir)\.debian\.org\/debian $VERSION_CODENAME-updates main/deb http:\/\/\1\.debian\.org\/debian $VERSION_CODENAME-updates main contrib non-free/" /etc/apt/sources.list
    sed -i -E "s/deb-src http:\/\/(deb|httpredir)\.debian\.org\/debian $VERSION_CODENAME-updates main/deb http:\/\/\1\.debian\.org\/debian $VERSION_CODENAME-updates main contrib non-free/" /etc/apt/sources.list
    sed -i "s/deb http:\/\/security\.debian\.org\/debian-security $VERSION_CODENAME\/updates main/deb http:\/\/security\.debian\.org\/debian-security $VERSION_CODENAME\/updates main contrib non-free/" /etc/apt/sources.list
    sed -i "s/deb-src http:\/\/security\.debian\.org\/debian-security $VERSION_CODENAME\/updates main/deb http:\/\/security\.debian\.org\/debian-security $VERSION_CODENAME\/updates main contrib non-free/" /etc/apt/sources.list
    sed -i "s/deb http:\/\/deb\.debian\.org\/debian $VERSION_CODENAME-backports main/deb http:\/\/deb\.debian\.org\/debian $VERSION_CODENAME-backports main contrib non-free/" /etc/apt/sources.list
    sed -i "s/deb-src http:\/\/deb\.debian\.org\/debian $VERSION_CODENAME-backports main/deb http:\/\/deb\.debian\.org\/debian $VERSION_CODENAME-backports main contrib non-free/" /etc/apt/sources.list
    # Handle bullseye location for security https://www.debian.org/releases/bullseye/amd64/release-notes/ch-information.en.html
    sed -i "s/deb http:\/\/security\.debian\.org\/debian-security $VERSION_CODENAME-security main/deb http:\/\/security\.debian\.org\/debian-security $VERSION_CODENAME-security main contrib non-free/" /etc/apt/sources.list
    sed -i "s/deb-src http:\/\/security\.debian\.org\/debian-security $VERSION_CODENAME-security main/deb http:\/\/security\.debian\.org\/debian-security $VERSION_CODENAME-security main contrib non-free/" /etc/apt/sources.list
    echo "Running apt-get update..."
    apt-get -y update
    package_list="$package_list manpages-posix manpages-posix-dev"
  else
    apt_get_update_if_needed
  fi

  # Download libssl1.1 to apt archives cache.
  curl -sL -o/var/cache/apt/archives/libssl1.1_1.1.1f-1ubuntu2_amd64.deb http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb

  # Install libssl1.1 if available.
  if [[ ! -z $(apt-cache --names-only search ^libssl1.1$) ]]; then
    package_list="$package_list       libssl1.1"
  fi

  echo "Packages to verify are installed: $package_list"
  apt-get -y install --no-install-recommends "$package_list" 2> >(grep -v 'debconf: delaying package configuration, since apt-utils is not installed' >&2)

  # Install git if not already installed (may be more recent than distro version)
  if ! type git >/dev/null 2>&1; then
    apt-get -y install --no-install-recommends git
  fi

  PACKAGES_ALREADY_INSTALLED="true"
fi

# Get to latest versions of all packages
if [ "$UPGRADE_PACKAGES" = "true" ]; then
  apt_get_update_if_needed
  apt-get -y upgrade --no-install-recommends
  apt-get autoremove -y
fi

# Ensure at least the en_US.UTF-8 UTF-8 locale is available.
if [ "$LOCALE_ALREADY_SET" != "true" ] && ! grep -o -E '^\s*en_US.UTF-8\s+UTF-8' /etc/locale.gen >/dev/null; then
  echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
  locale-gen
  LOCALE_ALREADY_SET="true"
fi

# Create or update a non-root user to match UID/GID.
group_name="$USERNAME"
if id -u "$USERNAME" >/dev/null 2>&1; then
  # User exists, update if needed
  if [ "$USER_GID" != "automatic" ] && [ "$USER_GID" != "$(id -g "$USERNAME")" ]; then
    group_name="$(id -gn "$USERNAME")"
    groupmod --gid "$USER_GID" "$group_name"
    usermod --gid "$USER_GID" "$USERNAME"
  fi
  if [ "$USER_UID" != "automatic" ] && [ "$USER_UID" != "$(id -u "$USERNAME")" ]; then
    usermod --uid "$USER_UID" "$USERNAME"
  fi
else
  # Create user
  if [ "$USER_GID" = "automatic" ]; then
    groupadd "$USERNAME"
  else
    groupadd --gid "$USER_GID" "$USERNAME"
  fi
  if [ "$USER_UID" = "automatic" ]; then
    useradd -s /bin/bash --gid "$USERNAME" -m "$USERNAME"
  else
    useradd -s /bin/bash --uid "$USER_UID" --gid "$USERNAME" -m "$USERNAME"
  fi
fi

# Add sudo support for non-root user
if [ "$USERNAME" != "root" ] && [ "$EXISTING_NON_ROOT_USER" != "$USERNAME" ]; then
  echo "$USERNAME" ALL=\(root\) NOPASSWD:ALL >/etc/sudoers.d/"$USERNAME"
  chmod 0440 /etc/sudoers.d/"$USERNAME"
  EXISTING_NON_ROOT_USER="$USERNAME"
fi

# code shim, it fallbacks to code-insiders if code is not available
cat <<'EOF' >/usr/local/bin/code
#!/bin/sh
get_in_path_except_current() {
    which -a "$1" | grep -A1 "$0" | grep -v "$0"
}
code="$(get_in_path_except_current code)"
if [ -n "$code" ]; then
    exec "$code" "$@"
elif [ "$(command -v code-insiders)" ]; then
    exec code-insiders "$@"
else
    echo "code or code-insiders is not installed" >&2
    exit 127
fi
EOF
chmod +x /usr/local/bin/code

# systemctl shim - tells people to use 'service' if systemd is not running
cat <<'EOF' >/usr/local/bin/systemctl
#!/bin/sh
set -e
if [ -d "/run/systemd/system" ]; then
    exec /bin/systemctl "$@"
else
    echo '\n"systemd" is not running in this container due to its overhead.\nUse the "service" command to start services instead. e.g.: \n\nservice --status-all'
fi
EOF
chmod +x /usr/local/bin/systemctl

# Add RC snippet and custom bash prompt
if [ "$RC_SNIPPET_ALREADY_ADDED" != "true" ]; then
  echo "$rc_snippet" >>/etc/bash.bashrc
  echo "$codespaces_bash" >>"$user_rc_path/.bashrc"
  echo 'export PROMPT_DIRTRIM=4' >>"$user_rc_path/.bashrc"
  if [ "$USERNAME" != "root" ]; then
    echo "$codespaces_bash" >>"/root/.bashrc"
    echo 'export PROMPT_DIRTRIM=4' >>"/root/.bashrc"
  fi
  chown "$USERNAME":"$group_name" "$user_rc_path/.bashrc"
  RC_SNIPPET_ALREADY_ADDED="true"
fi

# Persist image metadata info, script if meta.env found in same directory
meta_info_script="$(
  cat <<'EOF'
#!/bin/sh
. /usr/local/etc/vscode-dev-containers/meta.env
# Minimal output
if [ "$1" = "version" ] || [ "$1" = "image-version" ]; then
    echo "${VERSION}"
    exit 0
elif [ "$1" = "release" ]; then
    echo "${GIT_REPOSITORY_RELEASE}"
    exit 0
elif [ "$1" = "content" ] || [ "$1" = "content-url" ] || [ "$1" = "contents" ] || [ "$1" = "contents-url" ]; then
    echo "${CONTENTS_URL}"
    exit 0
fi
#Full output
echo
echo "Development container image information"
echo
if [ ! -z "${VERSION}" ]; then echo "- Image version: ${VERSION}"; fi
if [ ! -z "${DEFINITION_ID}" ]; then echo "- Definition ID: ${DEFINITION_ID}"; fi
if [ ! -z "${VARIANT}" ]; then echo "- Variant: ${VARIANT}"; fi
if [ ! -z "${GIT_REPOSITORY}" ]; then echo "- Source code repository: ${GIT_REPOSITORY}"; fi
if [ ! -z "${GIT_REPOSITORY_RELEASE}" ]; then echo "- Source code release/branch: ${GIT_REPOSITORY_RELEASE}"; fi
if [ ! -z "${BUILD_TIMESTAMP}" ]; then echo "- Timestamp: ${BUILD_TIMESTAMP}"; fi
if [ ! -z "${CONTENTS_URL}" ]; then echo && echo "More info: ${CONTENTS_URL}"; fi
echo
EOF
)"
if [ -f "$SCRIPT_DIR/meta.env" ]; then
  mkdir -p /usr/local/etc/vscode-dev-containers/
  cp -f "$SCRIPT_DIR/meta.env" /usr/local/etc/vscode-dev-containers/meta.env
  echo "$meta_info_script" >/usr/local/bin/devcontainer-info
  chmod +x /usr/local/bin/devcontainer-info
fi

# Write marker file
mkdir -p "$(dirname "$MARKER_FILE")"
echo -e "\
    PACKAGES_ALREADY_INSTALLED=$PACKAGES_ALREADY_INSTALLED\n\
    LOCALE_ALREADY_SET=$LOCALE_ALREADY_SET\n\
    EXISTING_NON_ROOT_USER=$EXISTING_NON_ROOT_USER\n\
    RC_SNIPPET_ALREADY_ADDED=$RC_SNIPPET_ALREADY_ADDED"

echo "Done!"
