#!/bin/bash
##############################################################################
#    Open LiteSpeed is an open source HTTP server.                           #
#    Copyright (C) 2013 - 2016 LiteSpeed Technologies, Inc.                  #
#                                                                            #
#    This program is free software: you can redistribute it and/or modify    #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation, either version 3 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    This program is distributed in the hope that it will be useful,         #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the            #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License       #
#    along with this program. If not, see http://www.gnu.org/licenses/.      #
##############################################################################

###    Author: dxu@litespeedtech.com (David Shue)

OSVER=UNKNOWN
OSTYPE=`uname -m`
SERVER_ROOT=/usr/local/lsws
ISCENTOS=

#Current status
OLSINSTALLED=
MYSQLINSTALLED=

#Generate webAdmin and mysql root password randomly
RAND1=$RANDOM
RAND2=$RANDOM
RAND3=$RANDOM
DATE=`date`
ADMINPASSWORD=$(echo "$(openssl rand 12 -base64)$(openssl rand 6 -base64)" | sed -e s'|/||g' -e 's|+||g')
ROOTPASSWORD=$(echo "$(openssl rand 12 -base64)$(openssl rand 6 -base64)" | sed -e s'|/||g' -e 's|+||g')
DATABASENAME=olsdbname
USERNAME=olsdbuser
USERPASSWORD=$(echo "$(openssl rand 12 -base64)$(openssl rand 6 -base64)" | sed -e s'|/||g' -e 's|+||g')
WORDPRESSPATH=$SERVER_ROOT
WPPORT=80
EMAIL=root@localhost
INSTALLWORDPRESS=0

#All lsphp versions, keep using two digits to identify a version!!!
#otherwise, need to update the uninstall function which will check the version
LSPHPVERLIST=(54 55 56 70)

#default version
LSPHPVER=56

ALLERRORS=0
TEMPPASSWORD=
PASSWORDPROVIDE=

echoYellow()
{
    echo -e "\033[38;5;148m$@\033[39m"
}

echoGreen()
{
    echo -e "\033[38;5;71m$@\033[39m"
}

echoRed()
{
    echo -e "\033[38;5;203m$@\033[39m"
}

function check_root
{
    local INST_USER=`id -u`
    if [ $INST_USER != 0 ] ; then
        echoRed "Sorry, only the root user can install."
        echo 
        exit 1
    fi
}

function check_wget
{
    which wget  > /dev/null 2>&1
    if [ $? != 0 ] ; then
        if [ "x$ISCENTOS" = "x1" ] ; then
            yum -y install wget
        else
            apt-get -y install wget
        fi
    
        which wget  > /dev/null 2>&1
        if [ $? != 0 ] ; then
            echoRed "An error occured during wget installation."
            ALLERRORS=1
        fi
    fi
}

function display_license
{
    echoYellow '/*********************************************************************************************'
    echoYellow '*                    Open LiteSpeed One click installation, Version 1.3                      *'
    echoYellow '*                    Copyright (C) 2016 LiteSpeed Technologies, Inc.                         *'
    echoYellow '*********************************************************************************************/'
}

function check_os
{
    OSVER=
    ISCENTOS=0
    
    if [ -f /etc/redhat-release ] ; then
        cat /etc/redhat-release | grep " 5." > /dev/null
        if [ $? = 0 ] ; then
            OSVER=CENTOS5
            ISCENTOS=1
        else
            cat /etc/redhat-release | grep " 6." > /dev/null
            if [ $? = 0 ] ; then
                OSVER=CENTOS6
                ISCENTOS=1
            else
                cat /etc/redhat-release | grep " 7." > /dev/null
                if [ $? = 0 ] ; then
                    OSVER=CENTOS7
                    ISCENTOS=1
                fi
            fi
        fi
    elif [ -f /etc/lsb-release ] ; then
        cat /etc/lsb-release | grep "DISTRIB_RELEASE=12." > /dev/null
        if [ $? = 0 ] ; then
            OSVER=UBUNTU12
        else
            cat /etc/lsb-release | grep "DISTRIB_RELEASE=14." > /dev/null
            if [ $? = 0 ] ; then
                OSVER=UBUNTU14
            else
                cat /etc/lsb-release | grep "DISTRIB_RELEASE=16." > /dev/null
                if [ $? = 0 ] ; then
                    OSVER=UBUNTU16
                fi
            fi
        fi    
    elif [ -f /etc/debian_version ] ; then
        cat /etc/debian_version | grep "^7." > /dev/null
        if [ $? = 0 ] ; then
            OSVER=DEBIAN7
        else
            cat /etc/debian_version | grep "^8." > /dev/null
            if [ $? = 0 ] ; then
                OSVER=DEBIAN8
            else
                cat /etc/debian_version | grep "^9." > /dev/null
                if [ $? = 0 ] ; then
                    OSVER=DEBIAN9
                fi
            fi
        fi
    fi

    if [ "x$OSVER" = "x" ] ; then
        echoRed "Sorry, currently one click installation only supports Centos(5-7), Debian(7-9) and Ubuntu(12,14,16)."
        echoRed "You can download the source code and build from it."
        echoRed "The url of the source code is https://github.com/litespeedtech/openlitespeed/releases."
        echo 
        exit 1
    else
        echoGreen "Current platform is $OSVER."
        export OSVER=$OSVER
        export ISCENTOS=$ISCENTOS
    fi
}


function update_centos_hashlib
{
    if [ "x$ISCENTOS" = "x1" ] ; then
        yum -y install python-hashlib
    fi
}

function install_ols_centos
{
    local VERSION=
    local ND=
    if [ "x$OSVER" = "xCENTOS5" ] ; then
        VERSION=5
    elif [ "x$OSVER" = "xCENTOS6" ] ; then
        VERSION=6
    else #if [ "x$OSVER" = "xCENTOS7" ] ; then
        VERSION=7
    fi

    if [ "x$LSPHPVER" = "x70" ] ; then
        ND=nd
        if [ "x$OSVER" = "xCENTOS5" ] ; then
            rpm -ivh http://repo.mysql.com/mysql-community-release-el5.rpm
        fi
    fi
    
    rpm -ivh http://rpms.litespeedtech.com/centos/litespeed-repo-1.1-1.el$VERSION.noarch.rpm
    yum -y install openlitespeed
    yum -y install epel-release
    yum -y install lsphp$LSPHPVER lsphp$LSPHPVER-common lsphp$LSPHPVER-gd lsphp$LSPHPVER-process lsphp$LSPHPVER-mbstring lsphp$LSPHPVER-mysql$ND lsphp$LSPHPVER-xml lsphp$LSPHPVER-mcrypt lsphp$LSPHPVER-pdo lsphp$LSPHPVER-imap
    if [ $? != 0 ] ; then
        echoRed "An error occured during openlitespeed installation."
        ALLERRORS=1
    else
        ln -sf $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp $SERVER_ROOT/fcgi-bin/lsphp5
    fi
}

function uninstall_ols_centos
{
    yum -y remove openlitespeed
    
    if [ "x$LSPHPVER" = "x56" ] ; then
        yum list installed | grep lsphp | grep process >  /dev/null 2>&1
        if [ $? = 0 ] ; then
            local LSPHPSTR=`yum list installed | grep lsphp | grep process`
            LSPHPVER=`echo $LSPHPSTR | awk '{print substr($0,6,2)}'`
            echoYellow "Current install lsphp version is $LSPHPVER"
        else
            echoRed "Uninstallation can not get the version infomation of the current installed lsphp."
            echoRed "Can not uninstall lsphp correctly."
            LSPHPVER=
        fi

    fi

    local ND=nd
    if [ "x$LSPHPVER" = "x70" ] ; then
        ND=nd
    fi
    
    if [ "x$LSPHPVER" != "x" ] ; then
        yum -y remove lsphp$LSPHPVER lsphp$LSPHPVER-common lsphp$LSPHPVER-gd lsphp$LSPHPVER-process lsphp$LSPHPVER-mbstring lsphp$LSPHPVER-mysql$ND lsphp$LSPHPVER-xml lsphp$LSPHPVER-mcrypt lsphp$LSPHPVER-pdo lsphp$LSPHPVER-imap
        if [ $? != 0 ] ; then
            echoRed "An error occured while uninstalling openlitespeed."
            ALLERRORS=1
        fi
    fi
    
    rm -rf $SERVER_ROOT/
}

function install_ols_debian
{
    local NAME=
    if [ "x$OSVER" = "xDEBIAN7" ] ; then
        NAME=wheezy
    elif [ "x$OSVER" = "xDEBIAN8" ] ; then
        NAME=jessie
    elif [ "x$OSVER" = "xDEBIAN9" ] ; then
        NAME=stretch
        
    elif [ "x$OSVER" = "xUBUNTU12" ] ; then
        NAME=precise
    elif [ "x$OSVER" = "xUBUNTU14" ] ; then
        NAME=trusty
    elif [ "x$OSVER" = "xUBUNTU16" ] ; then
        NAME=xenial
    fi

    echo "deb http://rpms.litespeedtech.com/debian/ $NAME main"  > /etc/apt/sources.list.d/lst_debian_repo.list
    wget -O /etc/apt/trusted.gpg.d/lst_debian_repo.gpg http://rpms.litespeedtech.com/debian/lst_debian_repo.gpg
    apt-get -y update
    apt-get -y install openlitespeed
    apt-get -y install lsphp$LSPHPVER lsphp$LSPHPVER-mysql lsphp$LSPHPVER-imap  

    if [ "x$LSPHPVER" != "x70" ] ; then
        apt-get -y install lsphp$LSPHPVER-gd lsphp$LSPHPVER-mcrypt 
    else
       apt-get -y install lsphp$LSPHPVER-common
    fi
    
    if [ $? != 0 ] ; then
        echoRed "An error occured during openlitespeed installation."
        ALLERRORS=1
    else
        ln -sf $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp $SERVER_ROOT/fcgi-bin/lsphp5
    fi
}


function uninstall_ols_debian
{
    apt-get -y --purge remove openlitespeed
    
    if [ "x$LSPHPVER" = "x56" ] ; then
        dpkg -l | grep lsphp | grep mysql >  /dev/null 2>&1
        if [ $? = 0 ] ; then
            local LSPHPSTR=`dpkg -l | grep lsphp | grep mysql`
            LSPHPVER=`echo $LSPHPSTR | awk '{print substr($2,6,2)}'`
            echoYellow "Current install lsphp version is $LSPHPVER"
        else
            echoRed "Uninstallation can not get the version infomation of the current installed lsphp."
            echoRed "Can not uninstall lsphp correctly."
            LSPHPVER=
        fi
    fi

    if [ "x$LSPHPVER" != "x" ] ; then
        apt-get -y --purge remove lsphp$LSPHPVER lsphp$LSPHPVER-mysql lsphp$LSPHPVER-imap
        
        if [ "x$LSPHPVER" != "x70" ] ; then
            apt-get -y --purge remove lsphp$LSPHPVER-gd lsphp$LSPHPVER-mcrypt
        else
            apt-get -y --purge remove lsphp$LSPHPVER-common
        fi
        
        if [ $? != 0 ] ; then
            echoRed "An error occured while uninstalling openlitespeed."
            ALLERRORS=1
        fi
    fi

    rm -rf $SERVER_ROOT/
}

function install_wordpress
{
    if [ ! -e "$WORDPRESSPATH" ] ; then 
        mkdir -p "$WORDPRESSPATH"
    fi

    cd "$WORDPRESSPATH"
    wget --no-check-certificate http://wordpress.org/latest.tar.gz
    tar -xzvf latest.tar.gz  >  /dev/null 2>&1
    rm latest.tar.gz
    
    wget -q -r -nH --cut-dirs=2 --no-parent https://plugins.svn.wordpress.org/litespeed-cache/trunk/ --reject html -P $WORDPRESSPATH/wordpress/wp-content/plugins/litespeed-cache/
    chown -R --reference=autoupdate  $WORDPRESSPATH/wordpress
    
    cd -
}



function setup_wordpress
{
    if [ -e "$WORDPRESSPATH/wordpress/wp-config-sample.php" ] ; then
        sed -e "s/database_name_here/$DATABASENAME/" -e "s/username_here/$USERNAME/" -e "s/password_here/$USERPASSWORD/" "$WORDPRESSPATH/wordpress/wp-config-sample.php" > "$WORDPRESSPATH/wordpress/wp-config.php"
        if [ -e "$WORDPRESSPATH/wordpress/wp-config.php" ] ; then
            chown  -R --reference="$WORDPRESSPATH/wordpress/wp-config-sample.php"   "$WORDPRESSPATH/wordpress/wp-config.php"
            echoGreen "Finished setting up WordPress."
        else
            echoRed "WordPress setup failed. You may not have enough privileges to access $WORDPRESSPATH/wordpress/wp-config.php."
            ALLERRORS=1
        fi
    else
        echoRed "WordPress setup failed. File $WORDPRESSPATH/wordpress/wp-config-sample.php does not exist."
        ALLERRORS=1
    fi
}


function test_mysql_password
{
    CURROOTPASSWORD=$ROOTPASSWORD
    TESTPASSWORDERROR=0
    
    #test it is the current password
    mysqladmin -uroot -p$CURROOTPASSWORD password $CURROOTPASSWORD
    if [ $? != 0 ] ; then
        printf '\033[31mPlease input the current root password:\033[0m'
        read answer
        mysqladmin -uroot -p$answer password $answer
        if [ $? = 0 ] ; then
            CURROOTPASSWORD=$answer
        else
            echoRed "root password is incorrect. 2 attempts remaining."
            printf '\033[31mPlease input the current root password:\033[0m'
            read answer
            mysqladmin -u root -p$answer password $answer
            if [ $? = 0 ] ; then
                CURROOTPASSWORD=$answer
            else
                echoRed "root password is incorrect. 1 attempt remaining."
                printf '\033[31mPlease input the current root password:\033[0m'
                read answer
                mysqladmin -u root -p$answer password $answer
                if [ $? = 0 ] ; then
                    CURROOTPASSWORD=$answer
                else
                    echoRed "root password is incorrect. 0 attempts remaining."
                    echo
                    TESTPASSWORDERROR=1
                fi
            fi
        fi
    fi

    export CURROOTPASSWORD=$CURROOTPASSWORD
    export TESTPASSWORDERROR=$TESTPASSWORDERROR
}

mariadbplugins() {
    echo "------------------------------------------------"
    echo "Installing MariaDB 10 plugins"
    echo "------------------------------------------------"
    echo "mysql -e \"INSTALL SONAME 'metadata_lock_info';\""
    mysql -e "INSTALL SONAME 'metadata_lock_info';"
    echo "mysql -e \"INSTALL SONAME 'query_cache_info';\""
    mysql -e "INSTALL SONAME 'query_cache_info';"
    echo "mysql -e \"INSTALL SONAME 'query_response_time';\""
    mysql -e "INSTALL SONAME 'query_response_time';"
    # echo "------------------------------------------------"
    # echo "Installing MariaDB 10 XtraDB Engine plugin"
    # echo "------------------------------------------------"
    # echo "mysql -e \"INSTALL SONAME 'ha_xtradb';\""
    # mysql -e "INSTALL SONAME 'ha_xtradb';"
    echo "mysql -t -e \"SELECT * FROM mysql.plugin;\""
    mysql -t -e "SELECT * FROM mysql.plugin;"
    echo "mysql -t -e \"SHOW PLUGINS;\""
    mysql -t -e "SHOW PLUGINS;"
    echo "mysql -t -e \"SHOW ENGINES;\""
    mysql -t -e "SHOW ENGINES;"
}

function install_mysql
{
    local VERSION=
    if [ "x$OSVER" = "xCENTOS5" ] ; then
        VERSION=5
    elif [ "x$OSVER" = "xCENTOS6" ] ; then
        VERSION=6
    else #if [ "x$OSVER" = "xCENTOS7" ] ; then
        VERSION=7
    fi
    if [ "x$ISCENTOS" = "x1" ] ; then
        echo "rpm --import http://yum.mariadb.org/RPM-GPG-KEY-MariaDB"
        rpm --import http://yum.mariadb.org/RPM-GPG-KEY-MariaDB

    ################################################
    if [[ "$VERSION" = '7' ]]; then
        if [ "$(uname -m)" == 'x86_64' ]; then
cat > "/etc/yum.repos.d/mariadb.repo" <<EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
        else
cat > "/etc/yum.repos.d/mariadb.repo" <<EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
        fi
    fi
    ################################################
    if [[ "$VERSION" = '6' ]]; then
        if [ "$(uname -m)" == 'x86_64' ]; then
cat > "/etc/yum.repos.d/mariadb.repo" <<EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos6-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
        else
cat > "/etc/yum.repos.d/mariadb.repo" <<EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos6-x86
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
        fi
    fi
    ################################################

        # only run for CentOS 6.x
        if [[ "$VERSION" != '7' ]]; then
            echo ""
            echo "Check for existing mysql-server packages"
            OLDMYSQLSERVER=`rpm -qa | grep 'mysql-server' | head -n1`
            if [[ ! -z "$OLDMYSQLSERVER" ]]; then
                echo "rpm -e --nodeps $OLDMYSQLSERVER"
                rpm -e --nodeps $OLDMYSQLSERVER
            fi
        fi # VERSION != 7
        
        # only run for CentOS 7.x
        if [[ "$VERSION" = '7' ]]; then
            echo ""
            echo "Check for existing mariadb packages"
            OLDMYSQLSERVER=`rpm -qa | grep 'mariadb-server' | head -n1`
            if [[ ! -z "$OLDMYSQLSERVER" ]]; then
                echo "rpm -e --nodeps $OLDMYSQLSERVER"
                rpm -e --nodeps $OLDMYSQLSERVER
            fi
            echo ""
            echo "Check for existing mariadb-libs package"
            OLDMYSQL_LIBS=`rpm -qa | grep 'mariadb-libs' | head -n1`
            if [[ ! -z "$OLDMYSQL_LIBS" ]]; then
                # echo "rpm -e --nodeps $OLDMYSQL_LIBS"
                # rpm -e --nodeps $OLDMYSQL_LIBS
                echo "rpm -e --nodeps mariadb-libs"
                rpm -e --nodeps mariadb-libs
            fi
        fi # VERSION != 7
        
        # only run for CentOS 7.x
        if [[ "$VERSION" = '7' ]]; then
            # for CentOS 7.x and excluding default mariadb 
            # opting for mariadb official yum repo instead
            if [[ ! `grep exclude /etc/yum.conf` ]]; then
                echo
                # echo "Can't find exclude line in /etc/yum.conf... adding exclude line for mariadb*"
                # echo "exclude=mariadb*">> /etc/yum.conf
            fi
        fi # VERSION = 7
        
        # set /etc/my.cnf templates
        # setmycnf
        
        # check mariadb.repo
        echo
        echo "check /etc/yum.repos.d/mariadb.repo"
        cat /etc/yum.repos.d/mariadb.repo
        
        # only run for CentOS 6.x
        if [[ "$VERSION" != '7' ]]; then
            echo ""
            echo "*************************************************"
            echo "MariaDB 10.1.x YUM install..."
            echo "yum -y install MariaDB-client MariaDB-common MariaDB-compat MariaDB-devel MariaDB-server MariaDB-shared --disablerepo=epel"
            echo "*************************************************"
            echo ""
            time yum -y install MariaDB-client MariaDB-common MariaDB-compat MariaDB-devel MariaDB-server MariaDB-shared --disablerepo=epel
            cp -a /etc/my.cnf /etc/my.cnf-newold
        elif [[ "$VERSION" = '7' ]]; then
            # run for CentOS 7.x
            echo "time yum -q -y install perl-DBI"
            time yum -q -y install perl-DBI
        
            echo ""
            echo "*************************************************"
            echo "MariaDB 10.1.x YUM install..."
            echo "yum -y install MariaDB-client MariaDB-common MariaDB-compat MariaDB-devel MariaDB-server MariaDB-shared"
            echo "*************************************************"
            echo ""
            time yum -y install MariaDB-client MariaDB-common MariaDB-compat MariaDB-devel MariaDB-server MariaDB-shared
            cp -a /etc/my.cnf /etc/my.cnf-newold
        fi # VERSION != 7

        if [ $? != 0 ] ; then
            echoRed "An error occured during installation of MariaDB-Server. Please fix this error and try again."
            echoRed "Aborting installation!"
            exit 1
        fi

cat >> "/etc/my.cnf" <<FFF


[mariadb-10.1]
innodb_file_format = Barracuda
innodb_file_per_table = 1

## wsrep specific
# wsrep_on=OFF
# wsrep_provider
# wsrep_cluster_address
# binlog_format=ROW
# default_storage_engine=InnoDB
# innodb_autoinc_lock_mode=2
# innodb_doublewrite=1
# query_cache_size=0

# 2 variables needed to switch from XtraDB to InnoDB plugins
#plugin-load=ha_innodb
#ignore_builtin_innodb

## MariaDB 10 only save and restore buffer pool pages
## warm up InnoDB buffer pool on server restarts
innodb_buffer_pool_dump_at_shutdown=1
innodb_buffer_pool_load_at_startup=1
innodb_buffer_pool_populate=0
## Disabled settings
performance_schema=OFF
innodb_stats_on_metadata=OFF
innodb_sort_buffer_size=2M
innodb_online_alter_log_max_size=128M
query_cache_strip_comments=0
log_slow_filter =admin,filesort,filesort_on_disk,full_join,full_scan,query_cache,query_cache_miss,tmp_table,tmp_table_on_disk

# Defragmenting unused space on InnoDB tablespace
innodb_defragment=1
innodb_defragment_n_pages=7
innodb_defragment_stats_accuracy=0
innodb_defragment_fill_factor_n_recs=20
innodb_defragment_fill_factor=0.9
innodb_defragment_frequency=40
FFF

        sed -i 's/skip-pbxt/#skip-pbxt/g' /etc/my.cnf
        sed -i 's/innodb_use_purge_thread = 4/innodb_purge_threads=1/g' /etc/my.cnf
        sed -i 's/innodb_extra_rsegments/#innodb_extra_rsegments/g' /etc/my.cnf
        sed -i 's/innodb_adaptive_checkpoint/innodb_adaptive_flushing_method/g' /etc/my.cnf
        sed -i 's|ignore-db-dir|ignore_db_dirs|g' /etc/my.cnf
        sed -i 's|^innodb_thread_concurrency|#innodb_thread_concurrency|g' /etc/my.cnf
        sed -i 's|^skip-federated|#skip-federated|g' /etc/my.cnf
        sed -i 's|^skip-pbxt|#skip-pbxt|g' /etc/my.cnf
        sed -i 's|^skip-pbxt_statistics|#skip-pbxt_statistics|g' /etc/my.cnf
        sed -i 's|^skip-archive|#skip-archive|g' /etc/my.cnf
        sed -i 's|^innodb_buffer_pool_dump_at_shutdown|#innodb_buffer_pool_dump_at_shutdown|g' /etc/my.cnf
        sed -i 's|^innodb_buffer_pool_load_at_startup|#innodb_buffer_pool_load_at_startup|g' /etc/my.cnf
        service mysql start
    else
        apt-get -y -f --force-yes install mysql-server
        if [ $? != 0 ] ; then
            echoRed "An error occured during installation of Mysql-server. Please fix this error and try again."
            echoRed "You may want to manually run the command 'apt-get -y -f --force-yes install mysql-server' to check. Aborting installation!"
            exit 1
        fi
        #mysqld start
        service mysql start
    fi
    
    if [ $? != 0 ] ; then
        echoRed "An error occured during starting service of Mysql-server. "
        echoRed "Please fix this error and try again. Aborting installation!"
        exit 1
    fi
    
    #mysql_secure_installation
    #mysql_install_db
    # mysqladmin -u root password $ROOTPASSWORD
    mysql -e "DROP USER ''@'localhost';" >/dev/null 2>&1
    mysql -e "DROP USER ''@'`hostname`';" >/dev/null 2>&1
    mysql -e "DROP DATABASE test;" >/dev/null 2>&1
    mysql -e "UPDATE mysql.user SET Password = PASSWORD('$ROOTPASSWORD') WHERE User = 'root'; FLUSH PRIVILEGES;" >/dev/null 2>&1
    if [ $? = 0 ] ; then
        echoGreen "Mysql root password set to $ROOTPASSWORD"
cat > "/root/.my.cnf" <<EOF
[client]
user=root
password=$ROOTPASSWORD
EOF
    else
        #test it is the current password
        mysqladmin -uroot -p$ROOTPASSWORD password $ROOTPASSWORD
        if [ $? = 0 ] ; then
            echoGreen "Mysql root password is $ROOTPASSWORD"
        else
            echoRed "Failed to set Mysql root password to $ROOTPASSWORD, it may already have a root password."
            printf '\033[31mInstallation must know the password for the next step settings.\033[0m'
            test_mysql_password
            
            if [ "x$TESTPASSWORDERROR" = "x1" ] ; then
                echoYellow "If you forget your password you may stop the mysqld service and run the following command to reset it,"
                echoYellow "mysqld_safe --skip-grant-tables &"
                echoYellow "mysql --user=root mysql"
                echoYellow "update user set Password=PASSWORD('new-password') where user='root'; flush privileges; exit; "
                echoRed "Aborting installation."
                echo
                exit 1
            fi
        
            if [ "x$CURROOTPASSWORD" != "x$ROOTPASSWORD" ] ; then
                echoYellow "Current mysql root password is $CURROOTPASSWORD, it will be changed to $ROOTPASSWORD."
                printf '\033[31mDo you still want to change it?[y/N]\033[0m '
                read answer
                echo

                if [ "x$answer" != "xY" ] && [ "x$answer" != "xy" ] ; then
                    echoGreen "OK, mysql root password not changed." 
                    ROOTPASSWORD=$CURROOTPASSWORD
                else
                    mysqladmin -u root -p$CURROOTPASSWORD password $ROOTPASSWORD
                    if [ $? = 0 ] ; then
                        echoGreen "OK, mysql root password changed to $ROOTPASSWORD."
                    else
                        echoRed "Failed to change mysql root password, it is still $CURROOTPASSWORD."
                        ROOTPASSWORD=$CURROOTPASSWORD
                    fi
                fi
            fi
        fi
    fi
    mariadbplugins
}

function setup_mysql
{
    local ERROR=

    #delete user if exists because I need to set the password
    mysql -uroot -p$ROOTPASSWORD  -e "DELETE FROM mysql.user WHERE User = '$USERNAME@localhost';" 
    
    echo `mysql -uroot -p$ROOTPASSWORD -e "SELECT user FROM mysql.user"` | grep "$USERNAME" > /dev/nul
    if [ $? = 0 ] ; then
        echoGreen "user $USERNAME exists in mysql.user"
    else
        mysql -uroot -p$ROOTPASSWORD  -e "CREATE USER $USERNAME@localhost IDENTIFIED BY '$USERPASSWORD';"
        if [ $? = 0 ] ; then
            mysql -uroot -p$ROOTPASSWORD  -e "GRANT ALL PRIVILEGES ON *.* TO '$USERNAME'@localhost IDENTIFIED BY '$USERPASSWORD';"
        else
            echoRed "Failed to create mysql user $USERNAME. This user may already exist or a problem occured."
            echoRed "Please check this and update the wp-config.php file."
            ERROR="Create user error"
        fi
    fi
    
    mysql -uroot -p$ROOTPASSWORD  -e "CREATE DATABASE IF NOT EXISTS $DATABASENAME;"
    if [ $? = 0 ] ; then
        mysql -uroot -p$ROOTPASSWORD  -e "GRANT ALL PRIVILEGES ON $DATABASENAME.* TO '$USERNAME'@localhost IDENTIFIED BY '$USERPASSWORD';"
    else
        echoRed "Failed to create database $DATABASENAME. It may already exist or a problem occured."
        echoRed "Please check this and update the wp-config.php file."
        if [ "x$ERROR" = "x" ] ; then
            ERROR="Create database error"
        else
            ERROR="$ERROR and create database error"
        fi  
    fi
    mysql -uroot -p$ROOTPASSWORD  -e "flush privileges;"
   
    if [ "x$ERROR" = "x" ] ; then
        echoGreen "Finished mysql setup without error."
    else
        echoRed "Finished mysql setup - some error occured."
    fi
}

function resetmysqlroot
{
    MYSQLNAME=mysql
    if [ "x$ISCENTOS" = "x1" ] ; then
        MYSQLNAME=mysql
    fi
    
    service $MYSQLNAME stop
    
    DEFAULTPASSWD=$1
    
    echo "update user set Password=PASSWORD('$DEFAULTPASSWD') where user='root'; flush privileges; exit; " > /tmp/resetmysqlroot.sql
    mysqld_safe --skip-grant-tables &
    #mysql --user=root mysql < /tmp/resetmysqlroot.sql
    mysql --user=root mysql -e "update user set Password=PASSWORD('$DEFAULTPASSWD') where user='root'; flush privileges; exit; "
    sleep 1            
    service $MYSQLNAME restart
}

function purgedatabase
{
    if [ "x$MYSQLINSTALLED" != "x1" ] ; then
        echoYellow "Mysql-server not installed."
    else
        local ERROR=0
        test_mysql_password

        if [ "x$TESTPASSWORDERROR" = "x1" ] ; then
            echoRed "Failed to purge database."
            echo
            ERROR=1
            ALLERRORS=1
            #ROOTPASSWORD=123456
            #resetmysqlroot $ROOTPASSWORD
        else
            ROOTPASSWORD=$CURROOTPASSWORD
        fi
        

        if [ "x$ERROR" = "x0" ] ; then
            mysql -uroot -p$ROOTPASSWORD  -e "DELETE FROM mysql.user WHERE User = '$USERNAME@localhost';"  
            mysql -uroot -p$ROOTPASSWORD  -e "DROP DATABASE IF EXISTS $DATABASENAME;"
            echoYellow "Database purged."
        fi
    fi
}

function uninstall_result
{
    if [ "x$ALLERRORS" = "x0" ] ; then
        echoGreen "Uninstallation finished."
    else
        echoYellow "Uninstallation finished - some errors occured. Please check these as you may need to manually fix them."
    fi  
    echo
}


function install_ols
{
    if [ "x$ISCENTOS" = "x1" ] ; then
        echo "Install on Centos"
        install_ols_centos
    else
        echo "Install on Debian/Ubuntu"
        install_ols_debian
    fi
}

function config_server
{
    if [ -e "$SERVER_ROOT/conf/httpd_config.conf" ] ; then
        cat $SERVER_ROOT/conf/httpd_config.conf | grep "virtualhost wordpress" > /dev/nul
        if [ $? != 0 ] ; then
            sed -i -e "s/adminEmails/adminEmails $EMAIL\n#adminEmails/" "$SERVER_ROOT/conf/httpd_config.conf"
            VHOSTCONF=$SERVER_ROOT/conf/vhosts/wordpress/vhconf.conf

            cat >> $SERVER_ROOT/conf/httpd_config.conf <<END 

virtualhost wordpress {
vhRoot                  $WORDPRESSPATH/wordpress/
configFile              $VHOSTCONF
allowSymbolLink         1
enableScript            1
restrained              0
setUIDMode              2
}

listener wordpress {
address                 *:$WPPORT
secure                  0
map                     wordpress *
}


module cache {
param <<<PARAMFLAG

enableCache         1
qsCache             1
reqCookieCache      1
respCookieCache     1
ignoreReqCacheCtrl  1
ignoreRespCacheCtrl 0
expireInSeconds     2000
maxStaleAge         1000
enablePrivateCache  1
privateExpireInSeconds 1000                      
checkPrivateCache   1
checkPublicCache    1
maxCacheObjSize     100000000

PARAMFLAG
}

END
    
            mkdir -p $SERVER_ROOT/conf/vhosts/wordpress/
            cat > $VHOSTCONF <<END 
docRoot                   \$VH_ROOT/
index  {
  useServer               0
  indexFiles              index.php
}

context / {
  type                    NULL
  location                \$VH_ROOT
  allowBrowse             1
  indexFiles              index.php
 
  rewrite  {
    enable                1
    inherit               1
    rules                 <<<END_rules
    rewriteFile           $WORDPRESSPATH/wordpress/.htaccess

END_rules

  }
}

END
            chown -R lsadm:lsadm $WORDPRESSPATH/conf/
        fi
        
        #setup password
        ENCRYPT_PASS=`"$SERVER_ROOT/admin/fcgi-bin/admin_php" -q "$SERVER_ROOT/admin/misc/htpasswd.php" $ADMINPASSWORD`
        if [ $? = 0 ] ; then
            echo "admin:$ENCRYPT_PASS" > "$SERVER_ROOT/admin/conf/htpasswd"
            if [ $? = 0 ] ; then
                echoYellow "Finished setting OpenLiteSpeed webAdmin password to $ADMINPASSWORD."
                echoYellow "Finished updating server configuration."
                
                #write the password file for record and remove the previous file.
                echo "WebAdmin password is [$ADMINPASSWORD]." > $SERVER_ROOT/password
            else
                echoYellow "OpenLiteSpeed webAdmin password not changed."
            fi
        fi
    else
        echoRed "$SERVER_ROOT/conf/httpd_config.conf is missing, it seems that something went wrong during openlitespeed installation."
        ALLERRORS=1
    fi
}


function getCurStatus
{
    if [ -e $SERVER_ROOT/bin/openlitespeed ] ; then
        OLSINSTALLED=1
    else
        OLSINSTALLED=0
    fi
 
    which mysqladmin  > /dev/null 2>&1
    if [ $? = 0 ] ; then
        MYSQLINSTALLED=1
    else
        MYSQLINSTALLED=0
    fi
    
}

function changeOlsPassword
{
    LSWS_HOME=$SERVER_ROOT
    ENCRYPT_PASS=`"$LSWS_HOME/admin/fcgi-bin/admin_php" -q "$LSWS_HOME/admin/misc/htpasswd.php" $ADMINPASSWORD`
    echo "$ADMIN_USER:$ENCRYPT_PASS" > "$LSWS_HOME/admin/conf/htpasswd"
    echoYellow "Finished setting OpenLiteSpeed webAdmin password to $ADMINPASSWORD."
}


function uninstall
{
    if [ "x$OLSINSTALLED" = "x1" ] ; then
        echoYellow "Uninstalling ..."
        $SERVER_ROOT/bin/lswsctrl stop
        if [ "x$ISCENTOS" = "x1" ] ; then
            echo "Uninstall on Centos"
            uninstall_ols_centos
        else
            echo "Uninstall on Debian/Ubuntu"
            uninstall_ols_debian
        fi
        echoGreen Uninstalled.
    else
        echoYellow "OpenLiteSpeed not installed."
    fi
}

function readPassword
{
    if [ "x$1" != "x" ] ; then 
        TEMPPASSWORD=$1
    else
        passwd=
        echoYellow "Please input password for $2(press enter to get a random one):"
        read passwd
        if [ "x$passwd" = "x" ] ; then
            local RAND=$RANDOM
            local DATE0=`date`
            TEMPPASSWORD=`echo "$RAND0$DATE0" |  md5sum | base64 | head -c 8`
        else
            TEMPPASSWORD=$passwd
        fi
    fi
}


function check_password_follow
{
    if [ "x$1" = "x--" ] ; then 
        PASSWORDPROVIDE=$2
    else
        PASSWORDPROVIDE=
    fi
}



function usage
{
    echoGreen "Usage: $0 [options] [options] ..."
    echoGreen "Options:"
    echoGreen "        -a, --adminpassword [-- webAdminPassword], to set the webAdmin password for openlitespeed instead of using a random one."
    echoGreen "            If you omit [-- webAdminPassword], ols1clk will prompt you to provide this password during installation."
    echoGreen "        -e, --email EMAIL, to set the email of the administrator."
    echoGreen "            --lsphpversion VERSION, to set the version of lsphp, such as 56, now we support '${LSPHPVERLIST[@]}'."
    echoGreen "        -w, --wordpress, set to install and setup wordpress."
    echoGreen "            --wordpresspath WORDPRESSPATH, to use an existing wordpress installation instead of a new wordpress install."
    echoGreen "        -r, --rootpassworddb [-- mysqlRootPassword], to set the mysql server root password instead of using a random one."
    echoGreen "            If you omit [-- mysqlRootPassword], ols1clk will prompt you to provide this password during installation."
    echoGreen "        -d, --databasename DATABASENAME, to set the database name to be used by wordpress."
    echoGreen "        -u, --usernamedb DBUSERNAME, to set the username of wordpress in mysql."
    echoGreen "        -p, --passworddb [-- databasePassword], to set the password of the table used by wordpress in mysql instead of using a random one."
    echoGreen "            If you omit [-- databasePassword], ols1clk will prompt you to provide this password during installation."
    echoGreen "        -l, --listenport WORDPRESSPORT, to set the listener port, default is 80."
    echoGreen "            --uninstall, to uninstall OpenLiteSpeed and remove installation directory."
    echoGreen "            --purgeall, to uninstall OpenLiteSpeed, remove installation directory, and purge all data in mysql."
    echoGreen "        -h, --help, to display usage."
    echo
}

#####################################################################################
####   Main function here
#####################################################################################
display_license
check_root
check_os
getCurStatus
#test if have $SERVER_ROOT , and backup it

while [ "$1" != "" ]; do
    case $1 in
        -a | --adminpassword )      check_password_follow $2 $3
                                    if [ "x$PASSWORDPROVIDE" != "x" ] ; then
                                        shift
                                        shift
                                    fi
                                    ADMINPASSWORD=$PASSWORDPROVIDE
                                    ;;

        -e | --email )              shift
                                    EMAIL=$1
                                    ;;
                                    
             --lsphpversion )       shift
                                    #echo lsphpversion: $1
                                    cnt=${#LSPHPVERLIST[@]}
                                    for (( i = 0 ; i < cnt ; i++ ))
                                    do
                                        if [ "x$1" = "x${LSPHPVERLIST[$i]}" ] ; then
                                            LSPHPVER=$1
                                        fi
                                    done
                                    ;;                                    
                                    
        -w | --wordpress )          INSTALLWORDPRESS=1
                                    ;;
             --wordpresspath )      shift
                                    WORDPRESSPATH=$1
                                    INSTALLWORDPRESS=1
                                    ;;
                                    
        -r | --rootpassworddb )     check_password_follow $2 $3
                                    if [ "x$PASSWORDPROVIDE" != "x" ] ; then
                                        shift
                                        shift
                                    fi
                                    ROOTPASSWORD=$PASSWORDPROVIDE
                                    ;;

        -d | --databasename )       shift
                                    DATABASENAME=$1
                                    ;;
        -u | --usernamedb )         shift
                                    USERNAME=$1
                                    ;;
        -p | --passworddb )         check_password_follow $2 $3
                                    if [ "x$PASSWORDPROVIDE" != "x" ] ; then
                                        shift
                                        shift
                                    fi
                                    USERPASSWORD=$PASSWORDPROVIDE
                                    ;;
                                    
        -l | --listenport )         shift
                                    WPPORT=$1
                                    ;;
        -h | --help )               usage
                                    exit 0
                                    ;;
            --uninstall )           uninstall
                                    uninstall_result
                                    exit 0
                                    ;;
            --purgeall )            uninstall
                                    purgedatabase
                                    uninstall_result
                                    exit 0
                                    ;;
        * )                         usage
                                    exit 0
                                    ;;
    esac
    shift
done



if [ "x$OSVER" = "xCENTOS5" ] ; then
   if [ "x$LSPHPVER" = "x70" ] ; then
       echoYellow "We do not support lsphp7 on Centos 5, will use lsphp56."
       LSPHPVER=56
   fi
fi


readPassword "$ADMINPASSWORD" "webAdmin password"
ADMINPASSWORD=$TEMPPASSWORD
readPassword "$ROOTPASSWORD" "mysql root password"
ROOTPASSWORD=$TEMPPASSWORD
readPassword "$USERPASSWORD" "mysql user password"
USERPASSWORD=$TEMPPASSWORD

echo
echoRed    "Starting to install openlitespeed to $SERVER_ROOT/ with below parameters,"
echoYellow "WebAdmin password: $ADMINPASSWORD"
echoYellow "WebAdmin email: $EMAIL"
echoYellow "Mysql root Password: $ROOTPASSWORD"
echoYellow "Database name: $DATABASENAME"
echoYellow "Database username: $USERNAME"
echoYellow "Database password: $USERPASSWORD"
echoYellow "lsphp version: $LSPHPVER"


WORDPRESSINSTALLED=
if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
    echoYellow "Install wordpress: Yes"
    if [ -e "$WORDPRESSPATH/wordpress/wp-config.php" ] ; then
        echoYellow "Use exsiting WordPress install: $WORDPRESSPATH."
        WORDPRESSINSTALLED=1
    else
        echoYellow "WordPress will be installed to $WORDPRESSPATH."
        WORDPRESSINSTALLED=0
    fi
    echoYellow "WordPress listener port: $WPPORT"

else
    echoYellow "Install WordPress: No"
fi

echo
printf '\033[31mIs the settings correct? Type n to quit, otherwise will continue.[Y/n]\033[0m '
read answer
echo

if [ "x$answer" = "xN" ] || [ "x$answer" = "xn" ] ; then
    echoGreen "Aborting installation!" 
    exit 0
fi
echo 


####begin here#####
update_centos_hashlib
check_wget

if [ "x$OLSINSTALLED" = "x1" ] ; then
    echoYellow "OpenLiteSpeed is already installed, will attempt to update it."
fi
install_ols


if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
    if [ "x$MYSQLINSTALLED" != "x1" ] ; then
        install_mysql
    else
        test_mysql_password
    fi    

    if [ "x$WORDPRESSINSTALLED" != "x1" ] ; then
        install_wordpress
        setup_wordpress
    
        if [ "x$TESTPASSWORDERROR" = "x1" ] ; then
            echoYellow "Mysql setup byppassed due to not know the root password."
        else
            ROOTPASSWORD=$CURROOTPASSWORD
            setup_mysql
        fi
    fi
    
    config_server
    
    if [ "x$WPPORT" = "x80" ] ; then
        echoYellow "Trying to stop some web servers that may be using port 80."
        killall -9 apache2  >  /dev/null 2>&1
        killall -9 httpd    >  /dev/null 2>&1
    fi
fi

$SERVER_ROOT/bin/lswsctrl stop
$SERVER_ROOT/bin/lswsctrl start

echo "mysql root password is [$ROOTPASSWORD]." >> $SERVER_ROOT/password
echoYellow "Please be aware that your password was written to file '$SERVER_ROOT/password'." 

if [ "x$ALLERRORS" = "x0" ] ; then
    echoGreen "Congratulations! Installation finished."
    if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
        echoGreen "Please access http://localhost:$WPPORT/ to finish setting up your WordPress site."
        echoGreen "And also you may want to activate Litespeed Cache plugin to get better performance."
    fi
else
    echoYellow "Installation finished. It seems some errors occured, please check this as you may need to manually fix them."
    if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
        echoGreen "Please access http://localhost:$WPPORT/ to finish setting up your WordPress site."
        echoGreen "And also you may want to activate Litespeed Cache plugin to get better performance."
    fi
fi  
echo
echoGreen "If you run into any problems, they can sometimes be fixed by purgeall and reinstalling."
echoGreen 'Thanks for using "OpenLiteSpeed One click installation".'
echoGreen "Enjoy!"
echo
echo
