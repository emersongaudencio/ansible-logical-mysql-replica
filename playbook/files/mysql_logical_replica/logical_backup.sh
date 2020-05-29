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

# os_type = ubuntu, debian, rhel, sles
os_type=
# os_version as demanded by the OS (codename, major release, etc.)
os_version=

msg(){
    type=$1 #${1^^}
    shift
    printf "[$type] %s\n" "$@" >&2
}

error(){
    msg error "$@"
    exit 1
}

identify_os(){
    arch=$(uname -m)
    # Check for RHEL/CentOS, Fedora, etc.
    if command -v rpm >/dev/null && [[ -e /etc/redhat-release || -e /etc/os-release ]]
    then
        os_type=rhel
        el_version=$(rpm -qa '(oraclelinux|sl|redhat|centos|fedora|system)-release(|-server)' --queryformat '%{VERSION}')
        case $el_version in
            1*) os_version=6 ;;
            2*) os_version=7 ;;
            5*) os_version=5 ; error "RHEL/CentOS 5 is no longer supported" "$supported" ;;
            6*) os_version=6 ;;
            7*) os_version=7 ;;
            8*) os_version=8 ; extra_options="module_hotfixes = 1" ;;
             *) error "Detected RHEL or compatible but version ($el_version) is not supported." "$supported"  "$otherplatforms" ;;
         esac
         if [[ $arch == aarch64 ]] && [[ $os_version != 7 ]]; then error "Only RHEL/CentOS 7 are supported for ARM64. Detected version: '$os_version'"; fi
    elif [[ -e /etc/os-release ]]
    then
        . /etc/os-release
        # Is it Debian?
        case $ID in
            debian)
                os_type=debian
                debian_version=$(< /etc/debian_version)
                case $debian_version in
                    8*) os_version=jessie ;;
                    9*) os_version=stretch ;;
                    10*) os_version=buster ;;
                     *) error "Detected Debian but version ($debian_version) is not supported." "$supported"  "$otherplatforms" ;;
                esac
                if [[ $arch == aarch64 ]]; then error "Debian is not currently supported for ARM64"; fi
                ;;
            ubuntu)
                os_type=ubuntu
                . /etc/lsb-release
                os_version=$DISTRIB_CODENAME
                case $os_version in
                    precise ) error 'Ubuntu version 12.04 LTS has reached End of Life and is no longer supported.' ;;
                    trusty ) ;;
                    xenial ) ;;
                    bionic ) ;;
                    *) error "Detected Ubuntu but version ($os_version) is not supported." "Only Ubuntu LTS releases are supported."  "$otherplatforms" ;;
                esac
                if [[ $arch == aarch64 ]]
                then
                    case $os_version in
                        xenial ) ;;
                        bionic ) ;;
                        *) error "Only Ubuntu 16/xenial & 18/bionic are supported for ARM64. Detected version: '$os_version'" ;;
                    esac
                fi
                ;;
        esac
    fi
    if ! [[ $os_type ]] || ! [[ $os_version ]]
    then
        error "Could not identify OS type or version." "$supported"
    fi
}

### Auto discovey of OS to identify which is the OS and version used it.
identify_os

if [[ $os_type == "rhel" ]]
then
    verify_mysql=`rpm -qa | grep MariaDB-client`
    if [[ $verify_mysql == "MariaDB-client"* ]]
    then
     echo "$verify_mysql is installed!"
     mysqldump_bin="mysqldump"
    fi

    if [[ $verify_mysql == "" ]]
    then
      verify_mysql=`rpm -qa | grep mysql-community-client`
    fi

    if [[ $verify_mysql == "" ]]
    then
      ### remove old packages ####
      yum -y remove mariadb-libs
      yum -y remove 'maria*'
      yum -y remove mysql mysql-server mysql-libs mysql-common mysql-community-common mysql-community-libs
      yum -y remove 'mysql*'
      yum -y remove MariaDB-common MariaDB-compat
      yum -y remove MariaDB-server MariaDB-client

      ### install pre-packages ####
      yum -y install yum-utils

      ### install mysql repo ####
      yum -y install https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
      yum-config-manager --disable mysql80-community
      yum-config-manager --enable mysql57-community

      ### installation mysql8 via yum ####
      yum -y install mysql-community-client
      yum -y install mysql-community-devel
      yum -y install mysql-shell
      yum -y install mysql-community-libs-compat
    fi

    verify_mydumper=`rpm -qa | grep mydumper`
    if [[ $verify_mydumper == "mydumper"* ]]
    then
    echo "$verify_mydumper is installed!"
    else
       if [[ $os_version == "7" ]]; then
          yum -y install https://github.com/maxbube/mydumper/releases/download/v0.9.5/mydumper-0.9.5-2.el7.x86_64.rpm
       elif [[ $os_version == "6" ]]; then
          yum -y install https://github.com/maxbube/mydumper/releases/download/v0.9.5/mydumper-0.9.5-2.el6.x86_64.rpm
      fi
    fi

    if [[ $verify_mysql == "mysql-community-client-5.6"* ]]; then
     mysqldump_bin="mysqldump --set-gtid-purged=OFF"
    elif [[ $verify_mysql == "mysql-community-client-5.7"* ]]; then
     mysqldump_bin="mysqldump --set-gtid-purged=OFF"
    elif [[ $verify_mysql == "mysql-community-client-8"* ]]; then
     mysqldump_bin="mysqldump --set-gtid-purged=OFF"
    else
     mysqldump_bin="mysqldump"
    fi

elif [[ $os_type == "ubuntu" ]]
then
    verify_mysql=`dpkg -l | grep MariaDB-client | awk 'NR==1{print $2}'`
    if [[ $verify_mysql == "MariaDB-client"* ]]
    then
     echo "$verify_mysql is installed!"
     mysqldump_bin="mysqldump"
    fi

    if [[ $verify_mysql == "" ]]
    then
      verify_mysql=`dpkg -l | grep mysql-client | awk 'NR==1{print $2}'`
    fi

    if [[ $verify_mysql == "" ]]
    then
      ### installation mysql client via apt ####
      sudo apt-get update -y
      sudo apt install mysql-client-5.7 -y
    fi

    verify_mydumper=`dpkg -l | grep mydumper | awk '{print $2}'`
    if [[ $verify_mydumper == "mydumper"* ]]
    then
    echo "$verify_mydumper is installed!"
    else
       if [[ $os_version == "bionic" ]]; then
         cd /tmp
         wget https://github.com/maxbube/mydumper/releases/download/v0.9.5/mydumper_0.9.5-2.xenial_amd64.deb
         sudo dpkg -i mydumper_0.9.5-2.xenial_amd64.deb
       elif [[ $os_version == "xenial" ]]; then
         cd /tmp
         wget https://github.com/maxbube/mydumper/releases/download/v0.9.5/mydumper_0.9.5-2.xenial_amd64.deb
         sudo dpkg -i mydumper_0.9.5-2.xenial_amd64.deb
       elif [[ $os_version == "trusty" ]]; then
         cd /tmp
         wget https://github.com/maxbube/mydumper/releases/download/v0.9.5/mydumper_0.9.5-2.trusty_amd64.deb
         sudo dpkg -i mydumper_0.9.5-2.trusty_amd64.deb
      fi
    fi

    if [[ $verify_mysql == "mysql-client-5.6"* ]]; then
     mysqldump_bin="mysqldump --set-gtid-purged=OFF"
    elif [[ $verify_mysql == "mysql-client-5.7"* ]]; then
     mysqldump_bin="mysqldump --set-gtid-purged=OFF"
    elif [[ $verify_mysql == "mysql-client-8"* ]]; then
     mysqldump_bin="mysqldump --set-gtid-purged=OFF"
    else
     mysqldump_bin="mysqldump"
    fi
fi

echo "$mysqldump_bin is the binary used for this execution process!"

if [ "$VAR_STANDALONE_DBaaS" == "3" ]; then
  extra_options="--lock-all-tables"
  VAR_AWS_RDS=1
elif [ "$VAR_STANDALONE_DBaaS" == "2" ]; then
  extra_options=""
  VAR_AWS_RDS=1
else
  extra_options=""
fi

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

mydumper -u $backup_user -p $backup_pass -h $master_server_address --regex '^(?!(mysql\.|test\.|sys\.))' ${extra_options} --trx-consistency-only -t 4 -m --rows=500000 --compress -o ${backup_path}/data
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
  if [ $? -eq 0 ]; then
    echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB replication streaming has been successfully completed!" >> $general_log_file
  else
    echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB replication streaming has been failed!" >> $general_log_file
    exit 1
  fi
elif [ "$VAR_CONFIG_REPLICATION" == "1" -a "$VAR_AWS_RDS" == "1" ]; then
  ### configure and setup replication streaming between master and replica ####
  binlog_file=$(cat ${backup_path}/data/metadata | awk 'NR==3{print $2}')
  binlog_pos=$(cat ${backup_path}/data/metadata | awk 'NR==4{print $2}')
  ### setting up replicatin streaming
  mysql --user=$restore_user --password=$restore_pass --host=$replica_server_address --force -e "CALL mysql.rds_set_external_master ('$master_server_address', 3306, '$replication_user', '$replication_pass', '$binlog_file', $binlog_pos, 0);";
  mysql --user=$restore_user --password=$restore_pass --host=$replica_server_address --force -e "CALL mysql.rds_start_replication;";
  if [ $? -eq 0 ]; then
    echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB replication streaming has been successfully completed!" >> $general_log_file
  else
    echo "[`date +%d/%m/%Y" "%H:%M:%S`] - DB replication streaming has been failed!" >> $general_log_file
    exit 1
  fi
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
