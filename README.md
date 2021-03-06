# ansible-logical-mysql-replica
### Deploy MySQL Master-Slave using logical backup strategy

# Translation in English en-us

 In this file, I will present and demonstrate how to Migrate your database in an automated and easy way.

 For this, I will be using the scenario described down below:
 ```
 1 Linux server for Ansible
 ```

 First of all, we have to prepare our Linux environment to use Ansible

 Please have a look below how to install Ansible on CentOS/Red Hat:
 ```
 yum install ansible -y
 ```
 Well now that we have Ansible installed already, we need to install git to clone our git repository on the Linux server, see below how to install it on CentOS/Red Hat:
 ```
 yum install git -y
 ```

 Copying the script packages using git:
 ```
 cd /root
 git clone https://github.com/emersongaudencio/ansible-logical-mysql-replica.git
 ```
 Alright then after we have installed Ansible and git and clone the git repository. We have to generate ssh heys to share between the Ansible control machine and the database machines. Let see how to do that down below.

 To generate the keys, keep in mind that is mandatory to generate the keys inside of the directory who was copied from the git repository, see instructions below:
 ```
 cd /root/ansible-logical-mysql-replica
 ssh-keygen -f ansible
 ```
 After that you have had generated the keys to copy the keys to the database machines, see instructions below:
 ```
 ssh-copy-id -i ansible.pub 172.16.122.146
 ```

 Please edit the file called hosts inside of the ansible git directory :
 ```
 vi hosts
 ```
 Please add the hosts that you want to install your database and save the hosts file, see an example below:

 ```
 # This is the default ansible 'hosts' file.
 #

 ## [dbservers]
 ##
 ## db01.intranet.mydomain.net
 ## db02.intranet.mydomain.net
 ## 10.25.1.56
 ## 10.25.1.57

 [galeracluster]
 db-intermidiate-01 ansible_ssh_host=172.16.122.154
 dbmysql57 ansible_ssh_host=172.16.122.146
 dbmysql57ec2 ansible_ssh_host=3.85.219.208
 ```

 For testing if it is all working properly, run the command below :
 ```
 ansible -m ping dbmysql57 -v
 ansible -m ping dbmysql57ec2 -v
 ```

 Alright finally we can run execute our script for On-premises MySQL/MariaDB Servers using Ansible as we planned to, run the command below:
 ```
 sh run_mysql_logical_replica.sh dbmysql57 1 1 "migration_user" "test-77d2f78c-d99b-4d38-93d5-8bb5d6dd5379" 172.16.122.146 "migration_user" "test-77d2f78c-d99b-4d38-93d5-8bb5d6dd5379" 172.16.122.154 replication_user 74a6bf6d1c9f99b94e75ff27d2636fbb "/backup"
 ```
 ### Parameters specification (Standalone to Standalone):
 #### run_mysql_logical_replica.sh
 Parameter    | Value           | Mandatory   | Order        | Accepted values
 ------------ | ------------- | ------------- | ------------- | -------------
 hostname or group-name listed on hosts files | dbmysql57 | Yes | 1 | hosts who are placed inside of the hosts file
 setup replication | 1 | Yes | 2 | 0 to not enable replication and 1 to enable replication
 scenario | 1 | Yes | 3 | 1 to enable replication on Standalone and 2 to enable replication on AWS RDS
 mysql user from source database | migration_user | Yes | 4 | mysql user for taking our backup on the source database
 mysql password from source database | test-77d2f78c-d99b-4d38-93d5-8bb5d6dd5379 | Yes | 5 | mysql password for taking our backup on the source database
 server address from source database | 172.16.122.146 | Yes | 6 | ip address or dns name of the source database
 mysql user from destination database | migration_user | Yes | 7 | mysql user for taking the backup on the destination database
 mysql password from destination database | test-77d2f78c-d99b-4d38-93d5-8bb5d6dd5379 | Yes | 8 | mysql password for taking the backup on the destination database
 server address from destination database | 172.16.122.154 | Yes | 9 | ip address or dns name of the source database
 mysql user to setup replication streaming | replication_user | Yes | 10 | mysql user to setup replication streaming from the source database to destination database
 mysql password to setup replication streaming | 74a6bf6d1c9f99b94e75ff27d2636fbb | Yes | 11 | mysql password to setup replication streaming from the source database to destination database
 directory to store the backup | "/backup" | Yes | 12 | directory to store the backup


 Alright finally we can run execute our script for AWS RDS MySQL/MariaDB using Ansible as we planned to, run the command below:
 ```
 sh run_mysql_logical_replica.sh dbmysql57ec2 1 2 "migration_user" "test-77d2f78c-d99b-4d38-93d5-8bb5d6dd5379" 10.70.2.59 "migration_user" "test-77d2f78c-d99b-4d38-93d5-8bb5d6dd5379" rds-mariadb102.cn65x7webqto.us-east-1.rds.amazonaws.com replication_user 74a6bf6d1c9f99b94e75ff27d2636fbb "/backup"
 ```
 ### Parameters specification (Standalone to AWS):
 #### run_mysql_logical_replica.sh
 Parameter    | Value           | Mandatory   | Order        | Accepted values
 ------------ | ------------- | ------------- | ------------- | -------------
 hostname or group-name listed on hosts files | dbmysql57ec2 | Yes | 1 | hosts who are placed inside of the hosts file
 setup replication | 1 | Yes | 2 | 0 to not enable replication and 1 to enable replication
 scenario | 2 | Yes | 3 | 1 to enable replication on Standalone and 2 to enable replication on AWS RDS
 mysql user from source database | migration_user | Yes | 4 | mysql user for taking our backup on the source database
 mysql password from source database | test-77d2f78c-d99b-4d38-93d5-8bb5d6dd5379 | Yes | 5 | mysql password for taking our backup on the source database
 server address from source database | 10.70.2.59 | Yes | 6 | ip address or dns name of the source database
 mysql user from destination database | migration_user | Yes | 7 | mysql user for taking the backup on the destination database
 mysql password from destination database | test-77d2f78c-d99b-4d38-93d5-8bb5d6dd5379 | Yes | 8 | mysql password for taking the backup on the destination database
 server address from destination database | rds-mariadb102.cn65x7webqto.us-east-1.rds.amazonaws.com | Yes | 9 | ip address or dns name of the source database
 mysql user to setup replication streaming | replication_user | Yes | 10 | mysql user to setup replication streaming from the source database to destination database
 mysql password to setup replication streaming | 74a6bf6d1c9f99b94e75ff27d2636fbb | Yes | 11 | mysql password to setup replication streaming from the source database to destination database
 directory to store the backup | "/backup" | Yes | 12 | directory to store the backup


Suggested grants privileges to a MySQL User for Migration purpose on the source database:

```
############ Setting a proper privileges towards a database #####
GRANT USAGE ON *.* TO 'migration_user'@'%' IDENTIFIED BY 'test-77d2f78c-d99b-4d38-93d5-8bb5d6dd5379';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, PROCESS, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER ON *.* TO 'migration_user'@'%' WITH GRANT OPTION;
flush privileges;
```

Suggested grants privileges to a MySQL User for Migration purpose on the destination database:

```
############ Setting a proper privileges towards a database #####
GRANT USAGE ON *.* TO 'migration_user'@'%' IDENTIFIED BY 'test-77d2f78c-d99b-4d38-93d5-8bb5d6dd5379';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, PROCESS, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER ON *.* TO 'migration_user'@'%' WITH GRANT OPTION;
flush privileges;
```

Suggested grants privileges to a MySQL User for replication purpose on the source database:

```
############ Setting a proper privileges towards a database #####
CREATE USER replication_user@'%' IDENTIFIED BY 'YOURPASSWORD';
GRANT REPLICATION SLAVE ON *.* TO replication_user@'%';
flush privileges;
```
