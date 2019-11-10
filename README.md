# Post-installation setup script for OpenSUSE Leap KDE

(c) Niki Kovacs 2019 

This repository provides an "automagic" post-installation setup script for
OpenSUSE Leap KDE. 

# Quick & Dirty

Perform the following steps.

  1. Install OpenSUSE Leap KDE.

  2. Open a terminal (Konsole) as root (`su -`).

  3. Grab the script: `git clone https://github.com/kikinovak/opensuse-setup`

  4. Change into the new directory: `cd opensuse-setup`

  5. Run the script: `./opensuse-setup --magic`

  6. Grab a cup of coffee while the script does all the work.

# Customizing a Linux desktop

Turning a vanilla Linux installation into a full-blown desktop with bells and
whistles always boils down to a series of more or less time-consuming
operations:

  * Customize the Bash shell: prompt, aliases, etc.

  * Customize the Vim editor.

  * Setup official and third-party repositories.

  * Remove some unneeded applications.

  * Install all missing applications.

  * Enhance multimedia capabilities with various codecs and plugins.

  * Install Microsoft and Apple fonts for better interoperability.

  * Edit application menu entries.

  * Configure the KDE desktop for better usability.

The `opensuse-setup.sh` script performs all of these operations.

Configure Bash and Vim:
```
# ./opensuse-setup.sh --shell
```
Setup official and third-party repositories:
```
# ./opensuse-setup.sh --repos
```
Remove unneeded applications:
```
# ./opensuse-setup.sh --prune
```
Install additional applications:
```
# ./opensuse-setup.sh --extra
```
Install Microsoft and Apple fonts:
```
# ./opensuse-setup.sh --fonts
```
Configure custom menu entries:
```
# ./opensuse-setup.sh --menus
```
Install custom KDE profile:
```
# ./opensuse-setup.sh --kderc
```
Apply custom KDE profile for existing users:
```
# ./opensuse-setup.sh --users
```
Perform all of the above in one go:
```
# ./opensuse-setup.sh --magic
```
Display help message:
```
# ./opensuse-setup.sh --help
```
If you want to know what exactly goes on under the hood, open a second terminal
and view the logs:
```
$ tail -f /tmp/opensuse-setup.log
```

