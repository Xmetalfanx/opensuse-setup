#!/bin/bash
#
# opensuse-setup.sh
#
# (c) Niki Kovacs 2019 <info@microlinux.fr>

# OpenSUSE Leap version
VERSION="15.1"

# Current directory
CWD=$(pwd)

# Defined users
USERS="$(ls -A /home)"

# Remove these packages
CRUFT=$(egrep -v '(^\#)|(^\s+$)' ${CWD}/${VERSION}/zypper/useless-packages.txt)

# Install these packages
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

# Log
LOG="/tmp/$(basename "${0}" .sh).log"
echo > ${LOG}

REPONAME[1]="oss"
REPOSITE[1]="${MIRROR}/distribution/leap/${VERSION}/repo/oss"
PRIORITY[1]="99"

REPONAME[2]="non-oss"
REPOSITE[2]="${MIRROR}/distribution/leap/${VERSION}/repo/non-oss"
PRIORITY[2]="99"

REPONAME[3]="oss-updates"
REPOSITE[3]="${MIRROR}/update/leap/${VERSION}/oss"
PRIORITY[3]="99"

REPONAME[4]="non-oss-updates"
REPOSITE[4]="${MIRROR}/update/leap/${VERSION}/non-oss"
PRIORITY[4]="99"

REPONAME[5]="nvidia"
REPOSITE[5]="${NVIDIA}/opensuse/leap/${VERSION}"
PRIORITY[5]="99"

REPONAME[6]="packman"
REPOSITE[6]="${PACKMAN}/openSUSE_Leap_${VERSION}"
PRIORITY[6]="90"

REPONAME[7]="dvdcss"
REPOSITE[7]="${DVDCSS}/openSUSE_Leap_${VERSION}"
PRIORITY[7]="99"

REPONAME[8]="kde"
REPOSITE[8]="${KDEXTRA}/openSUSE_Leap_${VERSION}"
PRIORITY[8]="100"

REPONAME[9]="recode"
REPOSITE[9]="${RECODE}/openSUSE_Leap_${VERSION}"
PRIORITY[9]="99"

REPONAME[10]="vagrant"
REPOSITE[10]="${VAGRANT}/openSUSE_Leap_${VERSION}"
PRIORITY[10]="90"

# Number of repositories
REPOS=${#REPONAME[*]}

usage() {
  echo "Usage: ${0} OPTION"
  echo 'OpenSUSE Leap KDE post-install configuration.'
  echo 'Options:'
  echo '  -1, --shell    Configure Bash and Vim.'
  echo '  -2, --repos    Setup official and third-party repositories.'
  echo '  -3, --prune    Remove unneeded applications.'
  echo '  -4, --extra    Install additional applications.'
  echo '  -5, --fonts    Install Microsoft and Apple fonts.'
  echo '  -6, --menus    Configure custom menu entries.'
  echo '  -h, --help     Show this message.'

}

configure_shell() {
  echo 'Configuring Bash shell for root.'
  cat ${CWD}/${VERSION}/bash/root-bashrc > /root/.bashrc
  echo 'Configuring Bash shell for users.'
  cat ${CWD}/${VERSION}/bash/user-alias > /etc/skel/.alias
  if [ ! -z "${USERS}" ]
  then
    for USER in ${USERS}
    do
      cat ${CWD}/${VERSION}/bash/user-alias > /home/${USER}/.alias
      chown ${USER}:users /home/${USER}/.alias
    done
  fi
  echo 'Configuring Vim.'
  cat ${CWD}/${VERSION}/vim/vimrc > /etc/vimrc
  echo 'Configuring Xterm.'
  cat ${CWD}/${VERSION}/xterm/Xresources > /root/.Xresources
  cat ${CWD}/${VERSION}/xterm/Xresources > /etc/skel/.Xresources
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
  echo 'Refreshing repository information.'
  echo 'This might take a moment...'
  zypper --gpg-auto-import-keys refresh >> ${LOG} 2>&1
  if [ "${?}" -ne 0 ]
  then
    echo "Could not refresh repository information." >&2
    exit 1
  fi
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
  # Download and install Microsoft TrueType fonts
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
  -h|--help) 
    usage
    exit 0
    ;;
  ?*) 
    usage
    exit 1
esac

exit 0