#!/bin/bash
# Parameters configuration

VAR_CONFIG_REPLICATION=${1}
VAR_STANDALONE_DBaaS=${2}
VAR_SOURCE_BACKUP_USER=${3}
VAR_SOURCE_BACKUP_PASS=${4}
VAR_SOURCE_MASTER_SERVER_ADDRESS=${5}
VAR_DESTINATION_RESTORE_USER=${6}
VAR_DESTINATION_RESTORE_PASS=${7}
VAR_DESTINATION_REPLICA_SERVER_ADDRESS=${8}
VAR_DESTINATION_REPLICATION_USER=${9}
VAR_DESTINATION_REPLICATION_PASS=${10}
VAR_BACKUP_DIRECTORY=${11}

backup_path=${VAR_BACKUP_DIRECTORY}
before="$(date +%s)"
today=`date +%Y-%m-%d`
general_log_file="$backup_path/general_bkp-full_$today.log"

#### master details #####
backup_user=${VAR_SOURCE_BACKUP_USER}
backup_pass=${VAR_SOURCE_BACKUP_PASS}
master_server_address=${VAR_SOURCE_MASTER_SERVER_ADDRESS}

#### replica details #####
restore_user=${VAR_DESTINATION_RESTORE_USER}
restore_pass=${VAR_DESTINATION_RESTORE_PASS}
replica_server_address=${VAR_DESTINATION_REPLICA_SERVER_ADDRESS}

replication_user=${VAR_DESTINATION_REPLICATION_USER}
replication_pass=${VAR_DESTINATION_REPLICATION_PASS}

# create directories for full backup
if [ ! -d ${backup_path} ]
   then
    mkdir -p ${backup_path}/data
    chmod 755 ${backup_path}
else
    mkdir -p ${backup_path}/data
    chmod 755 ${backup_path}
fi

verify_mydumper=`rpm -qa | grep mydumper`
verify_os_version=`cat /etc/system-release`
if [[ $verify_mydumper == "mydumper"* ]]
then
echo "$verify_mydumper is installed!"
else
   if [[ $verify_os_version == "CentOS Linux release 7."* ]]
   then
      yum -y install https://github.com/maxbube/mydumper/releases/download/v0.9.5/mydumper-0.9.5-2.el7.x86_64.rpm
   else
      yum -y install https://github.com/maxbube/mydumper/releases/download/v0.9.5/mydumper-0.9.5-2.el6.x86_64.rpm
   fi
fi

verify_mysql=`rpm -qa | grep MariaDB-client`
if [[ $verify_mysql == "MariaDB-client"* ]]
then
 mysqldump_bin="mysqldump"
fi

if [[ $verify_mysql == "" ]]
then
  verify_mysql=`rpm -qa | grep mysql-community-client`
else
  yum -y install mysql
fi

echo $verify_mysql

if [[ $verify_mysql == "mysql-community-client-5.5"* ]]; then
 mysqldump_bin="mysqldump"
elif [[ $verify_mysql == "mysql-community-client-5.6"* ]]; then
 mysqldump_bin="mysqldump --set-gtid-purged=OFF"
elif [[ $verify_mysql == "mysql-community-client-5.7"* ]]; then
 mysqldump_bin="mysqldump --set-gtid-purged=OFF"
elif [[ $verify_mysql == "mysql-community-client-8"* ]]; then
 mysqldump_bin="mysqldump --set-gtid-purged=OFF"
else
 mysqldump_bin="mysqldump"
fi

echo $mysqldump_bin

### Get list of databases who will be back it up ###
databases=`mysql --user=$backup_user --password=$backup_pass --host=$master_server_address -e "SELECT replace(GROUP_CONCAT(SCHEMA_NAME),',',' ') as list_databases FROM information_schema.SCHEMATA WHERE SCHEMA_NAME NOT IN('common_schema', 'information_schema','mysql','performance_schema','sys');" | tr -d "|" | grep -v list_databases`

echo "[`date +%d/%m/%Y" "%H:%M:%S`] - BEGIN REPLICA" >> $general_log_file
echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB List: $databases" >> $general_log_file

### struture-only backup ###
$mysqldump_bin --user=$backup_user --password=$backup_pass --host=$master_server_address --single-transaction --no-data --skip-triggers -v --databases $databases > $backup_path/structure_full_$today.sql
if [ $? -eq 0 ]; then
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Structure backup has been successfully completed!" >> $general_log_file
else
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Structure backup has been failed!" >> $general_log_file
  exit 1
fi

$mysqldump_bin --user=$backup_user --password=$backup_pass --host=$master_server_address --single-transaction --no-data --no-create-info --skip-triggers --routines --skip-opt -v --databases $databases > $backup_path/routines_full_$today.sql
if [ $? -eq 0 ]; then
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Routines backup has been successfully completed!" >> $general_log_file
else
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Routines backup has been failed!" >> $general_log_file
  exit 1
fi

$mysqldump_bin --user=$backup_user --password=$backup_pass --host=$master_server_address --single-transaction --no-data --no-create-info --skip-routines --triggers --skip-opt -v --databases $databases > $backup_path/triggers_full_$today.sql
if [ $? -eq 0 ]; then
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Triggers backup has been successfully completed!" >> $general_log_file
else
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Triggers backup has been failed!" >> $general_log_file
  exit 1
fi

mydumper -u $backup_user -p $backup_pass -h $master_server_address --regex '^(?!(mysql\.|test\.|sys\.))' --trx-consistency-only -t 4 -m --rows=500000 --compress -o ${backup_path}/data
if [ $? -eq 0 ]; then
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Data-Only backup has been successfully completed!" >> $general_log_file
else
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Data-Only backup has been failed!" >> $general_log_file
  exit 1
fi

### Restore on the new replica server #####
### Restoring db structure
cat $backup_path/structure_full_$today.sql | sed -e 's/DEFINER=`[A-Za-z0-9_]*`@`[A-Za-z0-9_]*`//g' > $backup_path/temp_structure_full_$today.sql
cat $backup_path/temp_structure_full_$today.sql | sed -e 's/SQL SECURITY DEFINER//g' > $backup_path/fixed_structure_full_$today.sql
mysql --user=$restore_user --password=$restore_pass --host=$replica_server_address --force  <  $backup_path/fixed_structure_full_$today.sql
if [ $? -eq 0 ]; then
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Structure restore has been successfully completed!" >> $general_log_file
else
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Structure restore has been failed!" >> $general_log_file
  exit 1
fi

### Restoring db data-only
myloader -u $restore_user --password=$restore_pass --host=$replica_server_address -t 4 -d ${backup_path}/data
if [ $? -eq 0 ]; then
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Data-only restore has been successfully completed!" >> $general_log_file
else
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB Data-only restore has been failed!" >> $general_log_file
  exit 1
fi

### Restoring db routines
cat $backup_path/routines_full_$today.sql | sed -e 's/DEFINER=`[A-Za-z0-9_]*`@`[A-Za-z0-9_]*`//g' > $backup_path/temp_routines_full_$today.sql
cat $backup_path/temp_routines_full_$today.sql | sed -e 's/SQL SECURITY DEFINER//g' > $backup_path/fixed_routines_full_$today.sql
mysql --user=$restore_user --password=$restore_pass --host=$replica_server_address --force <  $backup_path/fixed_routines_full_$today.sql
if [ $? -eq 0 ]; then
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB routines restore has been successfully completed!" >> $general_log_file
else
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB routines restore has been failed!" >> $general_log_file
  exit 1
fi

### Restoring db triggers
cat $backup_path/triggers_full_$today.sql | sed -e 's/DEFINER=`[A-Za-z0-9_]*`@`[A-Za-z0-9_]*`//g' > $backup_path/temp_triggers_full_$today.sql
cat $backup_path/temp_triggers_full_$today.sql | sed -e 's/SQL SECURITY DEFINER//g' > $backup_path/fixed_triggers_full_$today.sql
mysql --user=$restore_user --password=$restore_pass --host=$replica_server_address --force <  $backup_path/fixed_triggers_full_$today.sql
if [ $? -eq 0 ]; then
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB triggers restore has been successfully completed!" >> $general_log_file
else
  echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB triggers restore has been failed!" >> $general_log_file
  exit 1
fi

if [ "$VAR_CONFIG_REPLICATION" == "1" -a "$VAR_STANDALONE_DBaaS" == "1" ]; then
  ### configure and setup replication streaming between master and replica ####
  binlog_file=$(cat ${backup_path}/data/metadata | awk 'NR==3{print $2}')
  binlog_pos=$(cat ${backup_path}/data/metadata | awk 'NR==4{print $2}')
  ### setting up replicatin streaming
  mysql --user=$restore_user --password=$restore_pass --host=$replica_server_address --force -e "CHANGE MASTER TO MASTER_HOST = '$master_server_address' , MASTER_USER = '$replication_user' , MASTER_PASSWORD = '$replication_pass', MASTER_LOG_FILE='$binlog_file', MASTER_LOG_POS=$binlog_pos;";
  mysql --user=$restore_user --password=$restore_pass --host=$replica_server_address --force -e "START SLAVE;";
elif [ "$VAR_CONFIG_REPLICATION" == "1" -a "$VAR_STANDALONE_DBaaS" == "2" ]; then
  ### configure and setup replication streaming between master and replica ####
  binlog_file=$(cat ${backup_path}/data/metadata | awk 'NR==3{print $2}')
  binlog_pos=$(cat ${backup_path}/data/metadata | awk 'NR==4{print $2}')
  ### setting up replicatin streaming
  mysql --user=$restore_user --password=$restore_pass --host=$replica_server_address --force -e "CALL mysql.rds_set_external_master ('$master_server_address', 3306, '$replication_user', '$replication_pass', '$binlog_file', $binlog_pos, 0);";
  mysql --user=$restore_user --password=$restore_pass --host=$replica_server_address --force -e "CALL mysql.rds_start_replication;";
fi

# Calculating time
after="$(date +%s)"
elapsed="$(expr $after - $before)"
hours=$(($elapsed / 3600))
elapsed=$(($elapsed - $hours * 3600))
minutes=$(($elapsed / 60))
seconds=$(($elapsed - $minutes * 60))

echo "[`date +%d/%m/%Y" "%H:%M:%S`] - STATS: Total time of backup: $hours hours $minutes minutes $seconds seconds" >> $general_log_file
echo "[`date +%d/%m/%Y" "%H:%M:%S`] - END REPLICA" >> $general_log_file
