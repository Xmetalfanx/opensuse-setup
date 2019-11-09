#!/bin/bash
#
# opensuse-setup.sh
#
# (c) Niki Kovacs 2019 <info@microlinux.fr>
#
# This script turns a vanilla OpenSUSE Leap KDE installation into a full-blown
# Linux desktop with bells and whistles. 

# Operating system
OS=$(hostnamectl | grep "Operating System")

# OpenSUSE Leap version
VERSION="15.1"

# Current directory
CWD=$(pwd)

# Existing users
USERS="$(ls -A /home)"

# Mark these packages for removal
CRUFT=$(egrep -v '(^\#)|(^\s+$)' ${CWD}/${VERSION}/zypper/useless-packages.txt)

# Mark these packages for installation
EXTRA=$(egrep -v '(^\#)|(^\s+$)' ${CWD}/${VERSION}/zypper/extra-packages.txt)

# Download mirrors
MIRROR="http://download.opensuse.org"
NVIDIA="https://download.nvidia.com"
PACKMAN="http://ftp.gwdg.de/pub/linux/misc/packman/suse"
DVDCSS="http://opensuse-guide.org/repo"
KDEXTRA="https://download.opensuse.org/repositories/KDE:/Extra"
RECODE="https://download.opensuse.org/repositories/home:/manfred-h"
VAGRANT="https://download.opensuse.org/repositories/Virtualization:/vagrant"
MICROLINUX="https://www.microlinux.fr/download"

# Logs
LOG="/tmp/$(basename "${0}" .sh).log"
echo > ${LOG}

# Open Source Software
REPONAME[1]="oss"
REPOSITE[1]="${MIRROR}/distribution/leap/${VERSION}/repo/oss"
PRIORITY[1]="99" # standard

# Non Open Source Software
REPONAME[2]="non-oss"
REPOSITE[2]="${MIRROR}/distribution/leap/${VERSION}/repo/non-oss"
PRIORITY[2]="99" # standard

# Open Source Updates
REPONAME[3]="oss-updates"
REPOSITE[3]="${MIRROR}/update/leap/${VERSION}/oss"
PRIORITY[3]="99" # standard

# Non Open Source Updates
REPONAME[4]="non-oss-updates"
REPOSITE[4]="${MIRROR}/update/leap/${VERSION}/non-oss"
PRIORITY[4]="99" # standard

# NVidia drivers
REPONAME[5]="nvidia"
REPOSITE[5]="${NVIDIA}/opensuse/leap/${VERSION}"
PRIORITY[5]="99" # standard

# Enhanced multimedia stuff
REPONAME[6]="packman"
REPOSITE[6]="${PACKMAN}/openSUSE_Leap_${VERSION}"
PRIORITY[6]="90" # replace official packages

# Provides the libdvdcss library
REPONAME[7]="dvdcss"
REPOSITE[7]="${DVDCSS}/openSUSE_Leap_${VERSION}"
PRIORITY[7]="99" # standard

# Extra stuff for KDE
REPONAME[8]="kde"
REPOSITE[8]="${KDEXTRA}/openSUSE_Leap_${VERSION}"
PRIORITY[8]="100" # don't replace official packages

# Provides the recode utility
REPONAME[9]="recode"
REPOSITE[9]="${RECODE}/openSUSE_Leap_${VERSION}"
PRIORITY[9]="99" # standard

# Provides a more recent version of Vagrant
REPONAME[10]="vagrant"
REPOSITE[10]="${VAGRANT}/openSUSE_Leap_${VERSION}"
PRIORITY[10]="90" # replace official packages

# Number of repositories
REPOS=${#REPONAME[*]}

usage() {
  # Display help message
  echo "Usage: ${0} OPTION"
  echo 'OpenSUSE Leap KDE post-install configuration.'
  echo 'Options:'
  echo '  -1, --shell    Configure Bash and Vim.'
  echo '  -2, --repos    Setup official and third-party repositories.'
  echo '  -3, --prune    Remove unneeded applications.'
  echo '  -4, --extra    Install additional applications.'
  echo '  -5, --fonts    Install Microsoft and Apple fonts.'
  echo '  -6, --menus    Configure custom menu entries.'
  echo '  -7, --kderc    Install custom KDE profile.'
  echo '  -8, --users    Apply custom KDE profile for existing users.'
  echo '  -9, --magic    Perform all of the above in one go.'
  echo '  -h, --help     Show this message.'
  echo "Logs are written to ${LOG}."
}

configure_shell() {
  # Install custom command prompts and a handful of nifty aliases.
  echo 'Configuring Bash shell for root.'
  cat ${CWD}/${VERSION}/bash/root-bashrc > /root/.bashrc
  echo 'Configuring Bash shell for users.'
  cat ${CWD}/${VERSION}/bash/user-alias > /etc/skel/.alias
  # Existing users might want to use it.
  if [ ! -z "${USERS}" ]
  then
    for USER in ${USERS}
    do
      cat ${CWD}/${VERSION}/bash/user-alias > /home/${USER}/.alias
      chown ${USER}:users /home/${USER}/.alias
    done
  fi
  # Add a handful of nifty system-wide options for Vim.
  echo 'Configuring Vim.'
  cat ${CWD}/${VERSION}/vim/vimrc > /etc/vimrc
  # Make Xterm look less ugly.
  echo 'Configuring Xterm.'
  cat ${CWD}/${VERSION}/xterm/Xresources > /root/.Xresources
  cat ${CWD}/${VERSION}/xterm/Xresources > /etc/skel/.Xresources
  # Existing users might also want to use it.
  if [ ! -z "${USERS}" ]
  then
    for USER in ${USERS}
    do
      cat ${CWD}/${VERSION}/xterm/Xresources > /home/${USER}/.Xresources
      chown ${USER}:users /home/${USER}/.Xresources
    done
  fi
}

configure_repos() {
  # Configure official and third-party package repositories.
  echo 'Removing existing repositories.'
  rm -f /etc/zypp/repos.d/*.repo
  for (( REPO=1 ; REPO<=${REPOS} ; REPO++ ))
  do
    echo "Configuring repository: ${REPONAME[${REPO}]}"
    zypper addrepo -k --priority ${PRIORITY[${REPO}]} \
      ${REPOSITE[${REPO}]} ${REPONAME[${REPO}]} >> ${LOG} 2>&1
    if [ "${?}" -ne 0 ]
    then
      echo "Could not add repository: ${REPONAME[${REPO}]}" >&2
      exit 1
    fi
  done
  # Refresh metadata and import GPG keys.
  echo 'Refreshing repository information.'
  echo 'This might take a moment...'
  zypper --gpg-auto-import-keys refresh >> ${LOG} 2>&1
  if [ "${?}" -ne 0 ]
  then
    echo "Could not refresh repository information." >&2
    exit 1
  fi
  # Update and replace some vanilla packages with enhanced versions.
  echo 'Updating system with enhanced packages.'
  echo "This might also take a moment..."
  zypper --non-interactive update --allow-vendor-change >> ${LOG} 2>&1
  if [ "${?}" -ne 0 ]
  then
    echo "Could not perform system update." >&2
    exit 1
  fi
  echo 'All repositories configured successfully.'
}

remove_cruft() {
  # Remove unneeded applications listed in zypper/useless-packages.txt.
  echo "Removing useless packages from the system."
  for PACKAGE in ${CRUFT}
  do
    if rpm -q ${PACKAGE} > /dev/null 2>&1 
    then
      echo "Removing package: ${PACKAGE}"
      zypper --non-interactive remove --clean-deps ${PACKAGE} >> ${LOG} 2>&1
      if [ "${?}" -ne 0 ]
        then
        echo "Could not remove package ${PACKAGE}." >&2
        exit 1
      fi
    fi
  done
  echo "All useless packages removed from the system."
}

install_extras() {
  # Install extra packages listed in zypper/extra-packages.txt.
  echo "Installing extra packages."
  for PACKAGE in ${EXTRA}
  do
    if ! rpm -q ${PACKAGE} > /dev/null 2>&1 
    then
      echo "Installing package: ${PACKAGE}"
      zypper --non-interactive install --no-recommends \
        --allow-vendor-change ${PACKAGE} >> ${LOG} 2>&1
      if [ "${?}" -ne 0 ]
        then
        echo "Could not install package ${PACKAGE}." >&2
        exit 1
      fi
    fi
  done
  echo "All extra packages installed on the system."
}

install_fonts() {
  echo "Installing additional TrueType fonts."
  # Download and install Microsoft TrueType fonts.
  if [ ! -d /usr/share/fonts/truetype/microsoft ]
  then
    pushd /tmp >> ${LOG} 2>&1
    rm -rf /usr/share/fonts/truetype/microsoft
    rm -rf /usr/share/fonts/truetype/msttcorefonts
    echo "Installing Microsoft TrueType fonts."
    wget -c --no-check-certificate \
      ${MICROLINUX}/webcore-fonts-3.0.tar.gz >> ${LOG} 2>&1 \
    wget -c --no-check-certificate \
      ${MICROLINUX}/symbol.gz >> ${LOG} 2>&1
    mkdir /usr/share/fonts/truetype/microsoft
    tar xvf webcore-fonts-3.0.tar.gz >> ${LOG} 2>&1
    pushd webcore-fonts >> ${LOG} 2>&1
    if type fontforge > /dev/null 2>&1
    then
      fontforge -lang=ff -c 'Open("vista/CAMBRIA.TTC(Cambria)"); \
        Generate("vista/CAMBRIA.TTF");Close();Open("vista/CAMBRIA.TTC(Cambria Math)"); \
        Generate("vista/CAMBRIA-MATH.TTF");Close();' >> ${LOG} 2>&1
      rm vista/CAMBRIA.TTC
    fi
    cp fonts/* /usr/share/fonts/truetype/microsoft/
    cp vista/* /usr/share/fonts/truetype/microsoft/
    popd >> ${LOG} 2>&1
    fc-cache -f -v >> ${LOG} 2>&1
  fi
  # Download and install Apple TrueType fonts
  if [ ! -d /usr/share/fonts/apple-fonts ]
  then
    cd /tmp
    rm -rf /usr/share/fonts/apple-fonts
    echo "Installing Apple TrueType fonts."
    wget -c --no-check-certificate \
      ${MICROLINUX}/FontApple.tar.xz >> ${LOG} 2>&1
    mkdir /usr/share/fonts/apple-fonts
    tar xvf FontApple.tar.xz >> ${LOG} 2>&1
    mv Lucida*.ttf Monaco.ttf /usr/share/fonts/apple-fonts/
    fc-cache -f -v >> ${LOG} 2>&1
    rm -f FontApple.tar.xz
    cd - >> ${LOG} 2>&1
  fi
  # Download and install Eurostile fonts
  if [ ! -d /usr/share/fonts/eurostile ]
  then
    cd /tmp
    rm -rf /usr/share/fonts/eurostile
    echo "Installing Eurostile TrueType fonts."
    wget -c --no-check-certificate ${MICROLINUX}/Eurostile.zip >> ${LOG} 2>&1
    unzip Eurostile.zip -d /usr/share/fonts/ >> ${LOG} 2>&1
    mv /usr/share/fonts/Eurostile /usr/share/fonts/eurostile
    fc-cache -f -v >> ${LOG} 2>&1
    rm -f Eurostile.zip
    cd - >> ${LOG} 2>&1
  fi
  echo "Additional TrueType fonts installed on the system."
}

replace_menus() {
  # Install custom menu entries with enhanced translations.
  ENTRIESDIR="${CWD}/${VERSION}/menus"
  ENTRIES=$(ls ${ENTRIESDIR})
  MENUDIRS="/usr/share/applications \
            /usr/share/applications/kde4"
  echo "Installing custom desktop menu."
  for MENUDIR in ${MENUDIRS}
  do
    for ENTRY in ${ENTRIES}
    do
      if [ -r ${MENUDIR}/${ENTRY} ]
      then
        echo "Installing menu item: ${ENTRY}"
        cat ${ENTRIESDIR}/${ENTRY} > ${MENUDIR}/${ENTRY}
      fi
    done
  done
  echo "Custom desktop menu installed."
}

install_profile() {
  echo "Installing custom KDE profile."
  echo "Removing existing profile."
  rm -rf /etc/skel/.config
  mkdir /etc/skel/.config
  echo "Defining global options."
  cat ${CWD}/${VERSION}/kde/kdeglobals > /etc/skel/.config/kdeglobals
  echo "Defining default menu size."
  cat ${CWD}/${VERSION}/kde/dolphinrc > /etc/skel/.config/dolphinrc
  echo "Configuring desktop effects."
  cat ${CWD}/${VERSION}/kde/kwinrc > /etc/skel/.config/kwinrc
  echo "Configuring screen lock."
  cat ${CWD}/${VERSION}/kde/kscreenlockerrc > /etc/skel/.config/kscreenlockerrc
  echo "Configuring file indexing."
  cat ${CWD}/${VERSION}/kde/baloofilerc > /etc/skel/.config/baloofilerc
  echo "Custom KDE profile installed."
}

restore_profile() {
  if [ ! -d /etc/skel/.config ]
  then
    echo "Custom profiles are not installed." >&2
    exit 1
  fi
  if [[ "${OS}" =~ "CentOS" ]]; then
    SYSTEM="CentOS"
    echo "Linux distribution: ${SYSTEM}"
  elif [[ "${OS}" =~ "openSUSE" ]]; then
    SYSTEM="openSUSE"
    echo "Linux distribution: ${SYSTEM}"
  else
    echo "Unsupported Linux distribution." >&2
    exit 1
  fi
  for USER in ${USERS}
  do
    echo "Updating profile for user: ${USER}"
    rm -rf /home/${USER}/.cache
    rm -rf /home/${USER}/.config
    rm -rf /home/${USER}/.gnome2
    rm -rf /home/${USER}/.kde
    rm -rf /home/${USER}/.local
    rm -rf /home/${USER}/.nv
    cp -R /etc/skel/.config /home/${USER}/
    if [ "${SYSTEM}" == "CentOS" ]
    then 
      chown -R ${USER}:${USER} /home/${USER}/.config
    else
      chown -R ${USER}:users /home/${USER}/.config
    fi
  done
}

# Make sure the script is being executed with superuser privileges.
if [[ "${UID}" -ne 0 ]]
then
  echo 'Please run with sudo or as root.' >&2
  exit 1
fi

# Check parameters.
if [[ "${#}" -ne 1 ]]
then
  usage
  exit 1
fi
OPTION="${1}"
case "${OPTION}" in
  -1|--shell) 
    configure_shell
    ;;
  -2|--repos) 
    configure_repos
    ;;
  -3|--prune) 
    remove_cruft
    ;;
  -4|--extra) 
    install_extras
    ;;
  -5|--fonts) 
    install_fonts
    ;;
  -6|--menus) 
    replace_menus
    ;;
  -7|--kderc) 
    install_profile
    ;;
  -8|--users) 
    restore_profile
    ;;
  -9|--magic) 
    configure_shell
    configure_repos
    remove_cruft
    install_extras
    install_fonts
    replace_menus
    install_profile
    restore_profile
    ;;
  -h|--help) 
    usage
    exit 0
    ;;
  ?*) 
    usage
    exit 1
esac

exit 0
