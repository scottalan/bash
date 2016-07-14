#!/bin/bash

# Alias used to run drush commands. Set this variable.
DRUSH_ALIAS="@mysite"

# Set some colors.
RED=$'\033[31m';
GREEN=$'\033[32m';
YELLOW=$'\033[33m';
NC=$'\033[0m';

SCRIPT="$(basename $0)"

function ok() {
  echo -e "${GREEN}$1${NC}\n"
}

function notice() {
  echo -e -n "${YELLOW}$1${NC}\n"
}

function warn() {
  echo -e "${RED}$1${NC}\n"
}

function error_exit() {
  warn "${SCRIPT}: at LINE: ${1}: Message: ${2}" 1>&2
  show_help
  exit 1
}

function show_help() {

  echo "Examples:
    --oa-version=2.65
    --user=(BITBUCKET_USER)
    --branch=(BRANCH)
    ./oa_update.sh --oa-version=2.65 --offline --no-backup"

  echo ""

  echo "Options:
    -h | --help            Show help
    -a | --oa-version      The version of Open Atrium to use for the upgrade. (Required if --bit-user not defined)
    -u | --user            The bitbucket or github user that has access to the Repo. If this option
                           is used it will trigger a code update from the repo. (Required if --oa-version not defined)
    -r | --branch          Defaults to 'master'.
    -o | --offline         Sets the 'maintenance_mode' variable to TRUE taking the site offline. -- Requires no arguments
    -n | --no-backup       Skips backing up the database and codebase. -- Requires no arguments
    -g | --git             Uses Github
    -b | --bitbucket       Uses Bitbucket
    -s | --ssh             Uses ssh instead of https url"

  echo ""

  exit 1;
}

# Set some defaults
BRANCH="master"
REPO_USER=""
GITHUB=0
BITBUCKET=0
SSH=0

ARGS=$(getopt -o "ha:u:b:on" --long "help,oa-version:,bit-user:,bit-branch:,offline,no-backup" -n "${PROGNAME}" -- "$@")

if [ $? -ne 0 ]; then
  warn "Missing required option."
  show_help
fi

eval set -- "$ARGS"

# Extract the options and any arguments.
while true; do
  case "$1" in
    -h|--help) show_help; shift ;;
    -o|--offline) MAINTENANCE_MODE=true; ok "Site will be taken offline."; shift ;;
    -n|--no-backup) NO_BACKUP=true; warn "The database and codebase WILL NOT be backed up."; shift ;;
    -a|--oa-version) OA_VERSION="$2"; ok "Open Atrium v$2 will be installed."; shift; shift ;;
    -u|--user) UPGRADE_CODE=true; REPO_USER="$2"; ok "The user: $2 will be used to access Github or BitBucket."; shift; shift ;;
    -r|--branch) BRANCH="$2"; ok "Code will be checked out from the $BRANCH branch on Github or Bitbucket."; shift; shift ;;
    -g|--git) GITHUB=true; ok "Using Github."; shift; shift ;;
    -b|--bitbucket) BITBUCKET=true; ok "Using Bitbucket."; shift; shift ;;
    -s|--ssh) SSH=true; ok "Using SSH to clone repository."; shift; shift ;;
    --) shift; break ;;
    *) break ;;
  esac
done

# Location of drush.
DRUSH_PATH="$(which drush)"
check_drush=${DRUSH_PATH: (-5)}

# Check for drush.
if [ "$check_drush" != "drush" ]; then
  error_exit $LINENO "Drush could not be found. Drush is required for this script to run."
fi

# Need to check for drupalorg_drush
if [ ! -d "${HOME}/.drush/drupalorg_drush" ]; then
  error_exit $LINENO "Please run 'drush dl drupalorg_drush' and ensure that it is located in '${HOME}/.drush/'.\
  If it isn't then move it there."
fi

# Full drush command using the alias. (i.e., drush @jnj)
DRUSH="drush $DRUSH_ALIAS"

# Current date and time.
DATE=`date +%Y-%m-%d_%I-%M-%S`

SCRIPT_DIR=`pwd -P`

# Path to drupal root according to the drush alias file.
DRUPAL="$(${DRUSH} dd)"

# Name of the Drupal root directory. (e.g., drupal_root).
DRUPAL_DIR="$(basename ${DRUPAL})"

# Directory the contains: drupal_root, jj_oa_scripts, etc.
DRUPAL_PARENT="$(dirname ${DRUPAL})"

# Path to drupal root.
DRUPAL="$(${DRUSH} dd)"

# Check for index.php.
if [ ! -f ${DRUPAL}/index.php ]; then
  error_exit $LINENO "Drush was unable to find index.php at: $DRUPAL"
fi

# Check for required args.
if [[ ! ${UPGRADE_CODE}  ||  ${SSH} ]] && [ ! ${OA_VERSION} ]; then
  error_exit $LINENO "You must provide at least one: '--oa-version=[version]' or '--bit-user=[user] OR --ssh=true'. You can use both --oa-version=[VERSION] and one of the others.."
fi

ok "Enter the path to your repo: "
read -p "" repo_response

REPO=${repo_response}

ok "The Drupal Root directory was located at: ${DRUPAL}."
ok "Your repo is located at: https://${REPO_USER}@bitbucket.org/${REPO}.git."
ok "Is the information above correct? (y/n): "
read -p "" check_response

case ${check_response} in
  [yY])
    CONTINUE=1
    ;;
  *)
    CONTINUE=0
    ;;
esac

function runScript() {

if [ ${CONTINUE} = 1 ]; then

  kill_oa_upgrade() {
    error_exit "Something went wrong. The upgrade has failed. Check above ^ \
    for errors."
  }
  # If we get an error we want to stop the upgrade.
  #set -e; trap kill_oa_upgrade ERR

  if [ ${GITHUB} ]; then
    if [ ${SSH} ]; then
      REPO_URL="git@github.com:${REPO_USER}/${REPO}.git"
    else
      REPO_URL="https://github.com/${REPO_USER}/${REPO}.git"
    fi
  fi

  if [ ${BITBUCKET} ]; then
    if [ ${SSH} ]; then
    REPO_URL="git@bitbucket.org:${REPO}.git"
    else
    REPO_URL="https://${REPO_USER}@bitbucket.org/${REPO}.git"
    fi
  fi

  if [ ${MAINTENANCE_MODE} ]; then
    notice "Taking the site offline for the update..."
    ${DRUSH} vset maintenance_mode TRUE
  fi

  if [ ! ${NO_BACKUP} ]; then
    # Check for the database backup directory and create it if it doesn't exist.
    if [ ! -d ${DRUPAL_PARENT}/db_backup ]; then
      ok "Creating a database backup directory at: ${DRUPAL_PARENT}/db_backup"
      mkdir -m 775 ${DRUPAL_PARENT}/db_backup
    fi

    # Check for the code backup directory and create it if it doesn't exist.
    if [ ! -d ${DRUPAL_PARENT}/_temp_${DRUPAL_DIR} ]; then
      ok "Creating a directory for codebase backups at: ${DRUPAL_PARENT}/_temp_${DRUPAL_DIR}"
      mkdir -m 775 ${DRUPAL_PARENT}/_temp_${DRUPAL_DIR}
    fi

    # Backup the database via drush.
    cd ${DRUPAL}
    ok "Backing up the database... "
    ${DRUSH} sql-dump --result-file=${DRUPAL_PARENT}/db_backup/${DATE}.sql
    ok "Done."

    # Archive the sites directory just in case.
    ok "Archiving the sites directory at: ${DRUPAL_PARENT}/_temp_${DRUPAL_DIR}/... "
    tar -czf ${DRUPAL_PARENT}/_temp_${DRUPAL_DIR}/_temp_sites.tar.gz sites
    ok "Done."
  fi

  # If we want the codebase we pull it in before the upgrade.
  if [ ${UPGRADE_CODE} ]; then
    cd ${DRUPAL}/sites/all
    # Check for a .git directory.
    if [ -d ".git" ]; then
      # We found an existing .git directory, use awk to find the remote name.
      REMOTE="$(git remote -v | grep ":${REPO}" | awk '!x[$1]++ {print $1}')"

      # Stash any changed files save by the date.
      ok "Stashing changes if there are any... "
      git stash save ${DATE}

      # Get the latest code.
      ok "Fetching ${REMOTE}... "
      git fetch ${REMOTE}

      # We could already be on the 'master' branch.
      MASTER="$(git symbolic-ref HEAD 2>/dev/null | cut -d"/" -f 3)"
      if [ ${MASTER} = 'master' ]; then
        ok "Already on master branch so pulling in the latest code... "
        git pull ${REMOTE} ${BRANCH}
      else
        ok "Checking out and tracking ${REMOTE}/${BRANCH}... "
        # Remove 'master' branch if there is one
        git branch -D master
        git checkout --track ${REMOTE}/${BRANCH}
      fi
    else
      # No .git directory found so just remove the directory and clone it again.
      notice "No '.git' directory found. Removing sites/all and cloning the repo... "
      rm -rf ${DRUPAL}/sites/all
      notice "sites/all removed... "
      ok "Cloning the BitBucket repo to 'sites/all'... "
      git clone https://${REPO_USER}@bitbucket.org/${REPO}.git ${DRUPAL}/sites/all
      ok "Done. "

      ok "Code from BitBucket in sites/all has been updated!"
    fi
  fi

  if [ ${OA_VERSION} ]; then
    # Clone Open Atrium adjacent to $DRUPAL. We will use the build script that comes with it.
    ok "Cloning Open Atrium to: ${DRUPAL_PARENT}/openatrium"
    # Remove existing 'openatrium' directory.
    rm -rf ${DRUPAL_PARENT}/openatrium
    ok "Cloning branch 7.x-${OA_VERSION}... "
    git clone --branch 7.x-${OA_VERSION} https://git.drupal.org/project/openatrium.git ${DRUPAL_PARENT}/openatrium
    ok "Done. "
    cd ${DRUPAL_PARENT}/openatrium
    ok "Running the OA build script. Upgrading Open Atrium... "
    "$(./build.sh ${DRUPAL})"
    ok "Done. "
  fi

  if [[ ${UPGRADE_CODE} && ! ${OA_VERSION} ]]; then
    ok "Running database updates... "
    ${DRUSH} updb -y
    ok "Reverting all features... "
    ${DRUSH} fra -y
    ok "Clearing cache... "
    ${DRUSH} cc all
  fi

  if [ ${MAINTENANCE_MODE} ]; then
    notice "Bringing the site back online..."
    ${DRUSH} vset maintenance_mode FALSE
  fi

  if [ ${OA_VERSION} ]; then
    notice "Removing the openatrium directory at: ${DRUPAL_PARENT}/"
    rm -rf ${DRUPAL_PARENT}/openatrium

    ok "Open Atrium has been upgraded to version: ${OA_VERSION}!"
  fi

  notice "Visit your site at $(${DRUSH} status | grep 'Site URI' | awk '{print $4}')"
fi

}

if [ ${CONTINUE} ]; then
  runScript | tee ${DATE}-oa-update.log
fi
