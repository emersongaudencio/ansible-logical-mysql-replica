#!/bin/bash

export SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PYTHON_BIN=/usr/bin/python
export ANSIBLE_CONFIG=$SCRIPT_PATH/ansible.cfg

cd $SCRIPT_PATH

VAR_HOST="$1"
VAR_CONFIG_REPLICATION="$2"
VAR_STANDALONE_DBaaS="$3"
VAR_SOURCE_BACKUP_USER="$4"
VAR_SOURCE_BACKUP_PASS="$5"
VAR_SOURCE_MASTER_SERVER_ADDRESS="$6"
VAR_DESTINATION_RESTORE_USER="$7"
VAR_DESTINATION_RESTORE_PASS="$8"
VAR_DESTINATION_REPLICA_SERVER_ADDRESS="$9"
VAR_DESTINATION_REPLICATION_USER="$10"
VAR_DESTINATION_REPLICATION_PASS="$11"
VAR_BACKUP_DIRECTORY="$12"

if [ "${VAR_HOST}" == '' ] ; then
  echo "No host specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_CONFIG_REPLICATION}" == '' ] ; then
  echo "No Config replication specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_STANDALONE_DBaaS}" == '' ] ; then
  echo "No Standalone/DBaaS specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_SOURCE_BACKUP_USER}" == '' ] ; then
  echo "No Source Backup User specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_SOURCE_BACKUP_PASS}" == '' ] ; then
  echo "No Source Backup Password specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_SOURCE_MASTER_SERVER_ADDRESS}" == '' ] ; then
  echo "No Source Master Server Address specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_DESTINATION_RESTORE_USER}" == '' ] ; then
  echo "No Source Backup User specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_DESTINATION_RESTORE_PASS}" == '' ] ; then
  echo "No Source Backup Password specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_DESTINATION_REPLICA_SERVER_ADDRESS}" == '' ] ; then
  echo "No Source Master Server Address specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_CONFIG_REPLICATION}" == '1' ] ; then
  if [ "${VAR_DESTINATION_REPLICATION_USER}" == '' ] ; then
    echo "Destination replication user was not specified. Please have a look at README file for futher information!"
    exit 1
  fi

  if [ "${VAR_DESTINATION_REPLICATION_PASS}" == '' ] ; then
    echo "Destination replication password was not specified. Please have a look at README file for futher information!"
    exit 1
  fi
fi

if [ "${VAR_BACKUP_DIRECTORY}" == '' ] ; then
  echo "Backup directory was not specified. Please have a look at README file for futher information!"
  exit 1
fi

### Ping host ####
ansible -i $SCRIPT_PATH/hosts -m ping $VAR_HOST -v

### MySQL Logical replica ####
ansible-playbook -v -i $SCRIPT_PATH/hosts -e "{config_replication: '$VAR_CONFIG_REPLICATION', standalone_dbaas: '$VAR_STANDALONE_DBaaS', source_backup_user: '$VAR_SOURCE_BACKUP_USER', source_backup_pass: '$VAR_SOURCE_BACKUP_PASS', source_master_server_address: '$VAR_SOURCE_MASTER_SERVER_ADDRESS', destination_restore_user: '$VAR_DESTINATION_RESTORE_USER', destination_restore_pass: '$VAR_DESTINATION_RESTORE_PASS', destination_replica_server_address: '$VAR_DESTINATION_REPLICA_SERVER_ADDRESS', destination_replication_user: '$VAR_DESTINATION_REPLICATION_USER', destination_replication_pass: '$VAR_DESTINATION_REPLICATION_PASS', backup_directory: '$VAR_BACKUP_DIRECTORY'}" $SCRIPT_PATH/playbook/mysql_logical_replica.yml -l $VAR_HOST
