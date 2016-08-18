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
###    Modifications: George Liu (centminmod.com)

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
RAND4=$RANDOM
DATE=`date`
ADMINPASSWORD=$(echo "$(openssl rand 12 -base64)$(openssl rand 6 -base64)" | sed -e s'|/||g' -e 's|+||g')
ROOTPASSWORD=$(echo "$(openssl rand 12 -base64)$(openssl rand 6 -base64)" | sed -e s'|/||g' -e 's|+||g')
MYSQLEXTRA_FILE='/root/.my.cnf'
DATABASENAME=olsdbname
USERNAME=olsdbuser
USERPASSWORD=$(echo "$(openssl rand 12 -base64)$(openssl rand 6 -base64)" | sed -e s'|/||g' -e 's|+||g')
WORDPRESSPATH=$SERVER_ROOT
WORDPRESSWEBROOT="${WORDPRESSPATH}/wordpress"
WPPORT=80
ADMINPORT=7080

INSTALLWORDPRESS=0
INSTALLWORDPRESSPLUS=0

WPLANGUAGE=en
WPPASSWORD=`echo "$RAND3$DATE" |  md5sum | base64 | head -c 8`
WPUSER=wpuser
WPTITLE=MySite

SITEDOMAIN=*
EMAIL=

#All lsphp versions, keep using two digits to identify a version!!!
#otherwise, need to update the uninstall function which will check the version
LSPHPVERLIST=(54 55 56 70)

#default version
LSPHPVER=56

ALLERRORS=0
TEMPPASSWORD=
PASSWORDPROVIDE=

echoY()
{
    echo -e "\033[38;5;148m$@\033[39m"
}

echoG()
{
    FLAG=$1
    shift
    echo -e "\033[38;5;71m$FLAG\033[39m$@"
}

echoR()
{
    FLAG=$1
    shift
    echo -e "\033[38;5;203m$FLAG\033[39m$@"
}

# other variables
DIR_TMP=/svr-setup
# disable firewalld in favour of csf on centos 7
FIREWALLD_DISABLE='y'
CSF_LINKFILE="csf.tgz"
CSF_LINK="http://download.configserver.com/${CSF_LINKFILE}"

if [ ! -d "$DIR_TMP" ]; then
  mkdir -p "$DIR_TMP"
fi

if [ -f "${MYSQLEXTRA_FILE}" ]; then
  MYSQLOPT=" --defaults-extra-file=${MYSQLEXTRA_FILE}"
else
  MYSQLOPT=" -uroot -p$ROOTPASSWORD"
fi

csf_install() {
    local VERSION=
    if [ "x$OSVER" = "xCENTOS5" ] ; then
        VERSION=5
    elif [ "x$OSVER" = "xCENTOS6" ] ; then
        VERSION=6
    else #if [ "x$OSVER" = "xCENTOS7" ] ; then
        VERSION=7
    fi

    cd "$DIR_TMP"
    wget -cnv "$CSF_LINK"
    tar -xvzf "$CSF_LINKFILE"

    if [[ $(rpm -q perl-Crypt-SSLeay >/dev/null 2>&1; echo $?) != '0' ]] || [[ $(rpm -q perl-Net-SSLeay >/dev/null 2>&1; echo $?) != '0' ]]; then
        yum -y install perl-libwww-perl perl-Crypt-SSLeay perl-Net-SSLeay
    elif [[ -z "$(rpm -qa perl-libwww-perl)" ]]; then
        yum -y install perl-libwww-perl
    fi
    if [[ "$VERSION" = '7' ]]; then
        if [[ $(rpm -q perl-LWP-Protocol-https >/dev/null 2>&1; echo $?) != '0' ]]; then
            yum -y install perl-LWP-Protocol-https
        fi
    fi

    #tar xzf csf.tgz
    cd $DIR_TMP/csf
    sh install.sh

    # echo "Test IP Tables Modules..."

    # perl /etc/csf/csftest.pl
    cp -a /etc/csf/csf.conf /etc/csf/csf.conf-bak

    echo "CSF ports to csf.allow list..."
    sed -i 's/20,21,22,25,53,80,110,143,443,465,587,993,995/20,21,22,25,53,80,110,143,161,443,465,587,993,995,1110,1186,1194,2049,3000,3334,8080,8888,81,9312,9418,6081,6082,30865,30001:50011/g' /etc/csf/csf.conf

sed -i "s/TCP_OUT = \"/TCP_OUT = \"993,995,465,587,1110,1194,9418,/g" /etc/csf/csf.conf
sed -i "s/TCP6_OUT = \"/TCP6_OUT = \"993,995,465,587,/g" /etc/csf/csf.conf
sed -i "s/UDP_IN = \"/UDP_IN = \"67,68,1110,33434:33534,/g" /etc/csf/csf.conf
sed -i "s/UDP_OUT = \"/UDP_OUT = \"67,68,1110,33434:33534,/g" /etc/csf/csf.conf
sed -i "s/DROP_NOLOG = \"67,68,/DROP_NOLOG = \"/g" /etc/csf/csf.conf

    egrep '^UDP_|^TCP_|^DROP_NOLOG' /etc/csf/csf.conf

    # auto detect which SSHD port is default and auto update it for base
    # csf firewall template
    CSFSSHD_PORT='22'
    DETECTED_PORT=$(awk '/^Port / {print $2}' /etc/ssh/sshd_config)
    if [[ "$DETECTED_PORT" != '22' && -z "$(netstat -plant | grep sshd | grep ':22')" ]]; then
      echo "switching csf.conf SSHD port default from $CSFSSHD_PORT to detected SSHD port $DETECTED_PORT"
      sed -i "s/,${CSFSSHD_PORT},/,${DETECTED_PORT},/" /etc/csf/csf.conf
    fi
    if [[ "$(cat /etc/csf/csf.conf | grep TCP_IN | grep ',,')" ]] && [[ "$(netstat -plant | grep sshd | grep ":${CSFSSHD_PORT}")" ]]; then
      echo "correct bug that removed $CSFSSHD_PORT in CSF firewall TCP_IN entry"
      echo "https://community.centminmod.com/posts/34444/"
      sed -i "s/\,\,/,${CSFSSHD_PORT},/" /etc/csf/csf.conf
    fi
    
    echo "Disabling CSF Testing mode (activates firewall)..."
    sed -i 's/TESTING = "1"/TESTING = "0"/g' /etc/csf/csf.conf

    sed -i 's|USE_CONNTRACK = "1"|USE_CONNTRACK = "0"|g' /etc/csf/csf.conf
    sed -i 's/LF_IPSET = "0"/LF_IPSET = "1"/g' /etc/csf/csf.conf
    sed -i 's/LF_DSHIELD = "0"/LF_DSHIELD = "86400"/g' /etc/csf/csf.conf
    sed -i 's/LF_SPAMHAUS = "0"/LF_SPAMHAUS = "86400"/g' /etc/csf/csf.conf
    sed -i 's/LF_EXPLOIT = "300"/LF_EXPLOIT = "86400"/g' /etc/csf/csf.conf
    sed -i 's/LF_DIRWATCH = "300"/LF_DIRWATCH = "86400"/g' /etc/csf/csf.conf
    sed -i 's/LF_INTEGRITY = "3600"/LF_INTEGRITY = "0"/g' /etc/csf/csf.conf
    sed -i 's/LF_PARSE = "5"/LF_PARSE = "20"/g' /etc/csf/csf.conf
    sed -i 's/LF_PARSE = "600"/LF_PARSE = "20"/g' /etc/csf/csf.conf
    sed -i 's/PS_LIMIT = "10"/PS_LIMIT = "15"/g' /etc/csf/csf.conf
    sed -i 's/PT_LIMIT = "60"/PT_LIMIT = "0"/g' /etc/csf/csf.conf
    sed -i 's/PT_USERPROC = "10"/PT_USERPROC = "0"/g' /etc/csf/csf.conf
    sed -i 's/PT_USERMEM = "200"/PT_USERMEM = "0"/g' /etc/csf/csf.conf
    sed -i 's/PT_USERTIME = "1800"/PT_USERTIME = "0"/g' /etc/csf/csf.conf
    sed -i 's/PT_LOAD = "30"/PT_LOAD = "600"/g' /etc/csf/csf.conf
    sed -i 's/PT_LOAD_AVG = "5"/PT_LOAD_AVG = "15"/g' /etc/csf/csf.conf
    sed -i 's/PT_LOAD_LEVEL = "6"/PT_LOAD_LEVEL = "8"/g' /etc/csf/csf.conf
    sed -i 's/LF_FTPD = "10"/LF_FTPD = "3"/g' /etc/csf/csf.conf

    sed -i 's/LF_DISTATTACK = "0"/LF_DISTATTACK = "1"/g' /etc/csf/csf.conf
    sed -i 's/LF_DISTFTP = "0"/LF_DISTFTP = "1"/g' /etc/csf/csf.conf
    sed -i 's/LF_DISTFTP_UNIQ = "3"/LF_DISTFTP_UNIQ = "6"/g' /etc/csf/csf.conf
    sed -i 's/LF_DISTFTP_PERM = "3600"/LF_DISTFTP_PERM = "6000"/g' /etc/csf/csf.conf

    # enable CSF support of dynamic DNS
    # add your dynamic dns hostnames to /etc/csf/csf.dyndns and restart CSF
    # https://community.centminmod.com/threads/csf-firewall-info.25/page-2#post-10687
    sed -i 's/DYNDNS = \"0\"/DYNDNS = \"300\"/' /etc/csf/csf.conf
    sed -i 's/DYNDNS_IGNORE = \"0\"/DYNDNS_IGNORE = \"1\"/' /etc/csf/csf.conf

    if [[ ! -f /proc/user_beancounters ]] && [[ "$(uname -r | grep linode)" || "$(find /lib/modules/`uname -r` -name 'ipset')" ]]; then
        if [[ ! -f /usr/sbin/ipset ]]; then
            # CSF now has ipset support to offload large IP address numbers 
            # from iptables so uses less server resources to handle many IPs
            # does not work with OpenVZ VPS so only implement for non-OpenVZ
            yum -q -y install ipset ipset-devel
            sed -i 's/LF_IPSET = \"0\"/LF_IPSET = \"1\"/' /etc/csf/csf.conf
            sed -i 's/DENY_IP_LIMIT = \"100\"/DENY_IP_LIMIT = \"3000\"/' /etc/csf/csf.conf
            sed -i 's/DENY_TEMP_IP_LIMIT = \"100\"/DENY_TEMP_IP_LIMIT = \"3000\"/' /etc/csf/csf.conf
        elif [[ -f /usr/sbin/ipset ]]; then
            sed -i 's/LF_IPSET = \"0\"/LF_IPSET = \"1\"/' /etc/csf/csf.conf
            sed -i 's/DENY_IP_LIMIT = \"100\"/DENY_IP_LIMIT = \"3000\"/' /etc/csf/csf.conf
            sed -i 's/DENY_TEMP_IP_LIMIT = \"100\"/DENY_TEMP_IP_LIMIT = \"3000\"/' /etc/csf/csf.conf
        fi
    else
        sed -i 's/LF_IPSET = \"1\"/LF_IPSET = \"0\"/' /etc/csf/csf.conf
        sed -i 's/DENY_IP_LIMIT = \"100\"/DENY_IP_LIMIT = \"200\"/' /etc/csf/csf.conf
        sed -i 's/DENY_TEMP_IP_LIMIT = \"100\"/DENY_TEMP_IP_LIMIT = \"200\"/' /etc/csf/csf.conf
    fi

    sed -i 's/UDPFLOOD = \"0\"/UDPFLOOD = \"1\"/g' /etc/csf/csf.conf
    sed -i 's/UDPFLOOD_ALLOWUSER = \"named\"/UDPFLOOD_ALLOWUSER = \"named nsd\"/g' /etc/csf/csf.conf

    # whitelist the SSH client IP from initial installation to prevent some
    # instances of end user IP being blocked from CSF Firewall
        CMUSER_SSHCLIENTIP=$(echo $SSH_CLIENT | awk '{print $1}' | head -n1)
        csf -a $CMUSER_SSHCLIENTIP # initialinstall_userip
        echo "$CMUSER_SSHCLIENTIP" >> /etc/csf/csf.ignore

#######################################################
# check to see if csf.pignore already has custom apps added

CSFPIGNORECHECK=`grep -E '(user:nginx|user:nsd|exe:/usr/local/bin/memcached)' /etc/csf/csf.pignore`

if [[ -z $CSFPIGNORECHECK ]]; then

    echo "Adding Applications/Users to CSF ignore list..."
cat >>/etc/csf/csf.pignore<<EOF
pexe:/usr/local/lsws/bin/lshttpd.*
pexe:/usr/local/lsws/fcgi-bin/lsphp.*
exe:/usr/local/bin/memcached
cmd:/usr/local/bin/memcached
user:mysql
exe:/usr/sbin/mysqld 
cmd:/usr/sbin/mysqld
user:varnish
exe:/usr/sbin/varnishd
cmd:/usr/sbin/varnishd
exe:/sbin/portmap
cmd:portmap
exe:/usr/libexec/gdmgreeter
cmd:/usr/libexec/gdmgreeter
exe:/usr/sbin/avahi-daemon
cmd:avahi-daemon
exe:/sbin/rpc.statd
cmd:rpc.statd
exe:/usr/libexec/hald-addon-acpi
cmd:hald-addon-acpi
user:nsd
user:nginx
user:ntp
user:dbus
user:smmsp
user:postfix
user:dovecot
user:www-data
user:spamfilter
exe:/usr/libexec/dovecot/imap
exe:/usr/libexec/dovecot/pop3
exe:/usr/libexec/dovecot/anvil
exe:/usr/libexec/dovecot/auth
exe:/usr/libexec/dovecot/pop3-login
exe:/usr/libexec/dovecot/imap-login
exe:/usr/libexec/postfix
exe:/usr/libexec/postfix/bounce
exe:/usr/libexec/postfix/discard
exe:/usr/libexec/postfix/error
exe:/usr/libexec/postfix/flush
exe:/usr/libexec/postfix/local
exe:/usr/libexec/postfix/smtp
exe:/usr/libexec/postfix/smtpd
exe:/usr/libexec/postfix/pickup
exe:/usr/libexec/postfix/tlsmgr
exe:/usr/libexec/postfix/qmgr
exe:/usr/libexec/postfix/virtual
exe:/usr/libexec/postfix/proxymap
exe:/usr/libexec/postfix/anvil
exe:/usr/libexec/postfix/lmtp
exe:/usr/libexec/postfix/scache
exe:/usr/libexec/postfix/cleanup
exe:/usr/libexec/postfix/trivial-rewrite
exe:/usr/libexec/postfix/master
EOF

fi # check to see if csf.pignore already has custom apps added

    csf -u
    chkconfig csf on
    service csf restart
    csf -r

    chkconfig lfd on
    service lfd start

# if CentOS 7 is detected disable firewalld in favour 
# of csf iptables ip6tables for now
if [[ "$VERSION" = '7' ]]; then
    if [[ "$FIREWALLD_DISABLE" = [yY] ]]; then
        # disable firewalld
        systemctl disable firewalld
        systemctl stop firewalld
    
        # install iptables-services package
        yum -y install iptables-services
    
        # start iptables and ip6tables services
        systemctl start iptables
        systemctl start ip6tables
        systemctl enable iptables
        systemctl enable ip6tables
    else
        # leave firewalld enabled
        # disable CSF firewall instead
        service csf stop
        service lfd stop
        chkconfig csf off
        chkconfig lfd off

        # as CSF Firewall is disabled
        # need to setup firewalld permanent
        # services for default public zone
        firewall-cmd --permanent --zone=public --add-service=dns
        firewall-cmd --permanent --zone=public --add-service=ftp
        firewall-cmd --permanent --zone=public --add-service=http
        firewall-cmd --permanent --zone=public --add-service=https
        firewall-cmd --permanent --zone=public --add-service=imaps
        firewall-cmd --permanent --zone=public --add-service=mysql
        firewall-cmd --permanent --zone=public --add-service=pop3s
        firewall-cmd --permanent --zone=public --add-service=smtp
        firewall-cmd --permanent --zone=public --add-service=openvpn
        firewall-cmd --permanent --zone=public --add-service=nfs

        # firewall-cmd --reload
        systemctl restart firewalld
        firewall-cmd --zone=public --list-services

        # custom ports allowed if detected SSHD default port is not 22, ensure the custom SSHD port
        # number is whitelisted by firewalld
        FWDDETECTED_PORT=$(awk '/^Port / {print $2}' /etc/ssh/sshd_config)
        if [[ "$FWDDETECTED_PORT" = '22' ]]; then
          FIREWALLD_PORTS='1186 1194 8080 8888 81 9000 9001 9312 9418 10000 10500 10501 6081 6082 30865 3000-3050'
        else
          FIREWALLD_PORTS="$FWDDETECTED_PORT 1186 1194 8080 8888 81 9000 9001 9312 9418 10000 10500 10501 6081 6082 30865 3000-3050"
        fi

        for fp in $FIREWALLD_PORTS
          do
            firewall-cmd --permanent --zone=public --add-port=${fp}/tcp
        done

        firewall-cmd --reload
        firewall-cmd --zone=public --list-ports
    fi
fi
}

function check_root
{
    local INST_USER=`id -u`
    if [ $INST_USER != 0 ] ; then
        echoR "Sorry, only the root user can install."
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
            echoR "An error occured during wget installation."
            ALLERRORS=1
        fi
    fi
}

function display_license
{
    echoY '**********************************************************************************************'
    echoY '*                    Open LiteSpeed One click installation, Version 1.4                      *'
    echoY '*                    Copyright (C) 2016 LiteSpeed Technologies, Inc.                         *'
    echoY '**********************************************************************************************'
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
        echoR "Sorry, currently one click installation only supports Centos(5-7), Debian(7-9) and Ubuntu(12,14,16)."
        echoR "You can download the source code and build from it."
        echoR "The url of the source code is https://github.com/litespeedtech/openlitespeed/releases."
        echo 
        exit 1
    else
        echoG "Current platform is  "  $OSVER.
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
    yum -y install lsphp$LSPHPVER* --exclude=lsphp$LSPHPVER-xcache* --exclude=lsphp$LSPHPVER-mysql --exclude=lsphp$LSPHPVER-mysql56 --exclude=lsphp$LSPHPVER-debuginfo --exclude=lsphp$LSPHPVER-ioncube-loader --exclude=lsphp$LSPHPVER-dbg

    if [ $? != 0 ] ; then
        echoR "An error occured during openlitespeed installation."
        ALLERRORS=1
    else
        echo "ln -sf $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp $SERVER_ROOT/fcgi-bin/lsphp5"
        ln -sf $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp $SERVER_ROOT/fcgi-bin/lsphp5
        if [ ! -f /usr/bin/php ]; then
            ln -s $SERVER_ROOT/lsphp$LSPHPVER/bin/php /usr/bin/php
        else
            ln -s $SERVER_ROOT/lsphp$LSPHPVER/bin/php /usr/bin/lsphp
        fi
        if [ ! -f /usr/bin/php-config ]; then
            ln -s $SERVER_ROOT/lsphp$LSPHPVER/bin/php-config /usr/bin/php-config
        else
            ln -s $SERVER_ROOT/lsphp$LSPHPVER/bin/php-config /usr/bin/lsphp-config
        fi
        if [ ! -f /usr/bin/phpize ]; then
            ln -s $SERVER_ROOT/lsphp$LSPHPVER/bin/phpize /usr/bin/phpize
        else
            ln -s $SERVER_ROOT/lsphp$LSPHPVER/bin/phpize /usr/bin/lsphpize
        fi
        if [ ! -f /usr/bin/phpdbg ]; then
            ln -s $SERVER_ROOT/lsphp$LSPHPVER/bin/phpdbg /usr/bin/phpdbg
        else
            ln -s $SERVER_ROOT/lsphp$LSPHPVER/bin/phpdbg /usr/bin/lsphpdbg
        fi
        # cmd shortcuts
        echo "service lsws stop" >/usr/bin/lsstop ; chmod 700 /usr/bin/lsstop
        echo "service lsws start" >/usr/bin/lsstart ; chmod 700 /usr/bin/lsstart
        echo "service lsws restart" >/usr/bin/lsrestart ; chmod 700 /usr/bin/lsrestart
        echo "service lsws reload" >/usr/bin/lsreload ; chmod 700 /usr/bin/lsreload
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
            echoY "Current install lsphp version is $LSPHPVER"
        else
            echoR "Uninstallation can not get the version infomation of the current installed lsphp."
            echoR "Can not uninstall lsphp correctly."
            LSPHPVER=
        fi

    fi

    local ND=nd
    if [ "x$LSPHPVER" = "x70" ] ; then
        ND=nd
    fi
    
    if [ "x$LSPHPVER" != "x" ] ; then
        yum -y remove lsphp$LSPHPVER* --exclude=lsphp$LSPHPVER-xcache* --exclude=lsphp$LSPHPVER-mysql --exclude=lsphp$LSPHPVER-mysql56 --exclude=lsphp$LSPHPVER-debuginfo --exclude=lsphp$LSPHPVER-ioncube-loader

        if [ $? != 0 ] ; then
            echoR "An error occured while uninstalling openlitespeed."
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
        echoR "An error occured during openlitespeed installation."
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
            echoY "Current install lsphp version is $LSPHPVER"
        else
            echoR "Uninstallation can not get the version infomation of the current installed lsphp."
            echoR "Can not uninstall lsphp correctly."
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
            echoR "An error occured while uninstalling openlitespeed."
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
            echoG "Finished setting up WordPress."
        else
            echoR "WordPress setup failed. You may not have enough privileges to access $WORDPRESSPATH/wordpress/wp-config.php."
            ALLERRORS=1
        fi
    else
        echoR "WordPress setup failed. File $WORDPRESSPATH/wordpress/wp-config-sample.php does not exist."
        ALLERRORS=1
    fi
}

test_mysql_password() {
    # disable test mysql root password function
    echo ""
}

function test_mysql_password_disabled
{
    CURROOTPASSWORD=$ROOTPASSWORD
    TESTPASSWORDERROR=0
    
    #test it is the current password
    mysqladmin -uroot -p"${CURROOTPASSWORD}" password $CURROOTPASSWORD
    if [ $? != 0 ] ; then
        printf '\033[31mPlease input the current root password:\033[0m'
        read answer
        mysqladmin -uroot -p$answer password $answer
        if [ $? = 0 ] ; then
            CURROOTPASSWORD=$answer
        else
            echoR "root password is incorrect. 2 attempts remaining."
            printf '\033[31mPlease input the current root password:\033[0m'
            read answer
            mysqladmin -u root -p$answer password $answer
            if [ $? = 0 ] ; then
                CURROOTPASSWORD=$answer
            else
                echoR "root password is incorrect. 1 attempt remaining."
                printf '\033[31mPlease input the current root password:\033[0m'
                read answer
                mysqladmin -u root -p$answer password $answer
                if [ $? = 0 ] ; then
                    CURROOTPASSWORD=$answer
                else
                    echoR "root password is incorrect. 0 attempts remaining."
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
    if [ "x$ISCENTOS" = "x1" ] ; then
        yum -y install mysql-server
        if [ $? != 0 ] ; then
            echoR "An error occured during installation of Mysql-server. Please fix this error and try again."
            echoR "You may want to manually run the command 'yum -y install mysql-server' to check. Aborting installation!"
            exit 1
        fi
        service mysqld start
    else
        apt-get -y -f --force-yes install mysql-server
        if [ $? != 0 ] ; then
            echoR "An error occured during installation of Mysql-server. Please fix this error and try again."
            echoR "You may want to manually run the command 'apt-get -y -f --force-yes install mysql-server' to check. Aborting installation!"
            exit 1
        fi
        #mysqld start
        service mysql start
    fi
    
    if [ $? != 0 ] ; then
        echoR "An error occured during starting service of Mysql-server. "
        echoR "Please fix this error and try again. Aborting installation!"
        exit 1
    fi
    
    #mysql_secure_installation
    #mysql_install_db
    mysqladmin -u root password $ROOTPASSWORD
    if [ $? = 0 ] ; then
        echoG "Mysql root password set to $ROOTPASSWORD"
    else
        #test it is the current password
        mysqladmin -uroot -p$ROOTPASSWORD password $ROOTPASSWORD
        if [ $? = 0 ] ; then
            echoG "Mysql root password is $ROOTPASSWORD"
        else
            echoR "Failed to set Mysql root password to $ROOTPASSWORD, it may already have a root password."
            printf '\033[31mInstallation must know the password for the next step settings.\033[0m'
            test_mysql_password
            
            if [ "x$TESTPASSWORDERROR" = "x1" ] ; then
                echoY "If you forget your password you may stop the mysqld service and run the following command to reset it,"
                echoY "mysqld_safe --skip-grant-tables &"
                echoY "mysql --user=root mysql"
                echoY "update user set Password=PASSWORD('new-password') where user='root'; flush privileges; exit; "
                echoR "Aborting installation."
                echo
                exit 1
            fi
        
            if [ "x$CURROOTPASSWORD" != "x$ROOTPASSWORD" ] ; then
                echoY "Current mysql root password is $CURROOTPASSWORD, it will be changed to $ROOTPASSWORD."
                printf '\033[31mDo you still want to change it?[y/N]\033[0m '
                read answer
                echo

                if [ "x$answer" != "xY" ] && [ "x$answer" != "xy" ] ; then
                    echoG "OK, mysql root password not changed." 
                    ROOTPASSWORD=$CURROOTPASSWORD
                else
                    mysqladmin -u root -p$CURROOTPASSWORD password $ROOTPASSWORD
                    if [ $? = 0 ] ; then
                        echoG "OK, mysql root password changed to $ROOTPASSWORD."
                    else
                        echoR "Failed to change mysql root password, it is still $CURROOTPASSWORD."
                        ROOTPASSWORD=$CURROOTPASSWORD
                    fi
                fi
            fi
        fi
    fi
}

install_mariadb() {
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

cat > "/etc/my.cnf" <<EFF
[client]
socket=/var/lib/mysql/mysql.sock

[mysqld]
local-infile=0
ignore-db-dir=lost+found
character-set-server=utf8
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock

#bind-address=127.0.0.1
# optimized my.cnf for MariaDB 10
# by eva2000
# centminmod.com

#tmpdir=/home/mysqltmp

innodb=ON
#skip-federated
#skip-pbxt
#skip-pbxt_statistics
#skip-archive
#skip-name-resolve
#old_passwords
back_log = 75
max_connections = 300
key_buffer_size = 32M
myisam_sort_buffer_size = 32M
myisam_max_sort_file_size = 2048M
join_buffer_size = 64K
read_buffer_size = 64K
sort_buffer_size = 128K
table_definition_cache = 4096
table_open_cache = 2048
thread_cache_size = 64
wait_timeout = 1800
connect_timeout = 10
tmp_table_size = 32M
max_heap_table_size = 32M
max_allowed_packet = 32M
max_seeks_for_key = 1000
group_concat_max_len = 1024
max_length_for_sort_data = 1024
net_buffer_length = 16384
max_connect_errors = 100000
concurrent_insert = 2
read_rnd_buffer_size = 256K
bulk_insert_buffer_size = 8M
# query_cache boost for MariaDB >10.1.2+
# https://community.centminmod.com/posts/30811/
query_cache_limit = 512K
query_cache_size = 16M
query_cache_type = 1
query_cache_min_res_unit = 2K
query_prealloc_size = 262144
query_alloc_block_size = 65536
transaction_alloc_block_size = 8192
transaction_prealloc_size = 4096
default-storage-engine = InnoDB

log_warnings=1
slow_query_log=0
long_query_time=1
slow_query_log_file=/var/lib/mysql/slowq.log
log-error=/var/log/mysqld.log

# innodb settings
innodb_large_prefix=1
innodb_purge_threads=1
innodb_file_format = Barracuda
innodb_file_per_table = 1
innodb_open_files = 1000
innodb_data_file_path= ibdata1:10M:autoextend
innodb_buffer_pool_size = 48M

## https://mariadb.com/kb/en/mariadb/xtradbinnodb-server-system-variables/#innodb_buffer_pool_instances
#innodb_buffer_pool_instances=2

innodb_log_files_in_group = 2
innodb_log_file_size = 128M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 2
innodb_thread_concurrency = 0
innodb_lock_wait_timeout=50
innodb_flush_method = O_DIRECT
innodb_support_xa=1

# 200 * # DISKS
innodb_io_capacity = 150
innodb_io_capacity_max = 2000
innodb_read_io_threads = 2
innodb_write_io_threads = 2

# mariadb settings
[mariadb]
#thread-handling = pool-of-threads
#thread-pool-size= 20
#mysql --port=3307 --protocol=tcp
#extra-port=3307
#extra-max-connections=1

userstat = 0
key_cache_segments = 1
aria_group_commit = none
aria_group_commit_interval = 0
aria_log_file_size = 32M
aria_log_purge_type = immediate 
aria_pagecache_buffer_size = 8M
aria_sort_buffer_size = 8M
EFF

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
            echoRed "An error occured during installation of MariaDB-server. Please fix this error and try again."
            echoRed "You may want to manually run the command 'apt-get -y -f --force-yes install mysql-server' to check. Aborting installation!"
            exit 1
        fi
        #mysqld start
        service mysql start
    fi
    
    if [ $? != 0 ] ; then
        echoRed "An error occured during starting service of MariaDB-server. "
        echoRed "Please fix this error and try again. Aborting installation!"
        exit 1
    fi
    
    #mysql_secure_installation
    #mysql_install_db
    # mysqladmin -u root password "$ROOTPASSWORD"
    mysql -e "DROP USER ''@'localhost';" >/dev/null 2>&1
    mysql -e "DROP USER ''@'`hostname`';" >/dev/null 2>&1
    mysql -e "DROP DATABASE test;" >/dev/null 2>&1
    mysql -e "UPDATE mysql.user SET Password = PASSWORD('$ROOTPASSWORD') WHERE User = 'root'; FLUSH PRIVILEGES;" >/dev/null 2>&1
    if [ $? = 0 ] ; then
        echoG "Mysql root password set to $ROOTPASSWORD"
cat > "/root/.my.cnf" <<EOF
[client]
user=root
password=$ROOTPASSWORD
EOF
    else
        #test it is the current password
        mysqladmin${MYSQLOPT} password "$ROOTPASSWORD"
        if [ $? = 0 ] ; then
            echoG "Mysql root password is $ROOTPASSWORD"
        else
            echoRed "Failed to set Mysql root password to $ROOTPASSWORD, it may already have a root password."
            printf '\033[31mInstallation must know the password for the next step settings.\033[0m'
            test_mysql_password
            
            if [ "x$TESTPASSWORDERROR" = "x1" ] ; then
                echoY "If you forget your password you may stop the mysqld service and run the following command to reset it,"
                echoY "mysqld_safe --skip-grant-tables &"
                echoY "mysql --user=root mysql"
                echoY "update user set Password=PASSWORD('new-password') where user='root'; flush privileges; exit; "
                echoRed "Aborting installation."
                echo
                exit 1
            fi
        
            if [ "x$CURROOTPASSWORD" != "x$ROOTPASSWORD" ] ; then
                echoY "Current mysql root password is $CURROOTPASSWORD, it will be changed to $ROOTPASSWORD."
                printf '\033[31mDo you still want to change it?[y/N]\033[0m '
                read answer
                echo

                if [ "x$answer" != "xY" ] && [ "x$answer" != "xy" ] ; then
                    echoG "OK, mysql root password not changed." 
                    ROOTPASSWORD=$CURROOTPASSWORD
                else
                    mysqladmin -u root -p"${CURROOTPASSWORD}" password "$ROOTPASSWORD"
                    if [ $? = 0 ] ; then
                        echoG "OK, mysql root password changed to $ROOTPASSWORD."
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
    # echo "mysql${MYSQLOPT} -e \"DELETE FROM mysql.user WHERE User = '$USERNAME@localhost';\""
    mysql${MYSQLOPT} -e "DELETE FROM mysql.user WHERE User = '$USERNAME@localhost';" 
    
    echo `mysql${MYSQLOPT} -e "SELECT user FROM mysql.user"` | grep "$USERNAME" > /dev/null
    if [ $? = 0 ] ; then
        echoG "user $USERNAME exists in mysql.user"
    else
        mysql${MYSQLOPT} -e "CREATE USER $USERNAME@localhost IDENTIFIED BY '$USERPASSWORD';"
        if [ $? = 0 ] ; then
            mysql${MYSQLOPT} -e "GRANT ALL PRIVILEGES ON *.* TO '$USERNAME'@localhost IDENTIFIED BY '$USERPASSWORD';"
        else
            echoR "Failed to create mysql user $USERNAME. This user may already exist or a problem occured."
            echoR "Please check this and update the wp-config.php file."
            ERROR="Create user error"
        fi
    fi
    
    mysql${MYSQLOPT} -e "CREATE DATABASE IF NOT EXISTS $DATABASENAME;"
    if [ $? = 0 ] ; then
        mysql${MYSQLOPT} -e "GRANT ALL PRIVILEGES ON $DATABASENAME.* TO '$USERNAME'@localhost IDENTIFIED BY '$USERPASSWORD';"
    else
        echoR "Failed to create database $DATABASENAME. It may already exist or a problem occured."
        echoR "Please check this and update the wp-config.php file."
        if [ "x$ERROR" = "x" ] ; then
            ERROR="Create database error"
        else
            ERROR="$ERROR and create database error"
        fi  
    fi
    mysql${MYSQLOPT} -e "flush privileges;"
   
    if [ "x$ERROR" = "x" ] ; then
        echoG "Finished mysql setup without error."
    else
        echoR "Finished mysql setup - some error occured."
    fi
}

function resetmysqlroot
{
    MYSQLNAME=mysql
    if [ "x$ISCENTOS" = "x1" ] ; then
        MYSQLNAME=mysql
    fi
    
    service "$MYSQLNAME" stop
    
    DEFAULTPASSWD=$1
    
    echo "update user set Password=PASSWORD('$DEFAULTPASSWD') where user='root'; flush privileges; exit; " > /tmp/resetmysqlroot.sql
    mysqld_safe --skip-grant-tables &
    #mysql --user=root mysql < /tmp/resetmysqlroot.sql
    mysql --user=root mysql -e "update user set Password=PASSWORD('$DEFAULTPASSWD') where user='root'; flush privileges; exit; "
    sleep 1            
    service "$MYSQLNAME" restart
}

function purgedatabase
{
    if [ "x$MYSQLINSTALLED" != "x1" ] ; then
        echoY "MariaDB-server not installed."
    else
        local ERROR=0
        test_mysql_password

        if [ "x$TESTPASSWORDERROR" = "x1" ] ; then
            echoR "Failed to purge database."
            echo
            ERROR=1
            ALLERRORS=1
            #ROOTPASSWORD=123456
            #resetmysqlroot $ROOTPASSWORD
        else
            ROOTPASSWORD=$CURROOTPASSWORD
        fi
        

        if [ "x$ERROR" = "x0" ] ; then
            mysql${MYSQLOPT} -e "DELETE FROM mysql.user WHERE User = '$USERNAME@localhost';"  
            mysql${MYSQLOPT} -e "DROP DATABASE IF EXISTS $DATABASENAME;"
            echoY "Database purged."
        fi
    fi
}

function uninstall_result
{
    if [ "x$ALLERRORS" = "x0" ] ; then
        echoG "Uninstallation finished."
    else
        echoY "Uninstallation finished - some errors occured. Please check these as you may need to manually fix them."
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
        cat $SERVER_ROOT/conf/httpd_config.conf | grep "virtualhost wordpress" > /dev/null
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
map                     wordpress $SITEDOMAIN
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
                echoY "Finished setting OpenLiteSpeed webAdmin password to $ADMINPASSWORD."
                echoY "Finished updating server configuration."
                
                #write the password file for record and remove the previous file.
                echo "WebAdmin password is [$ADMINPASSWORD]." > $SERVER_ROOT/password
            else
                echoY "OpenLiteSpeed webAdmin password not changed."
            fi
        fi
    else
        echoR "$SERVER_ROOT/conf/httpd_config.conf is missing, it seems that something went wrong during openlitespeed installation."
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
    echoY "Finished setting OpenLiteSpeed webAdmin password to $ADMINPASSWORD."
}


function uninstall
{
    if [ "x$OLSINSTALLED" = "x1" ] ; then
        echoY "Uninstalling ..."
        $SERVER_ROOT/bin/lswsctrl stop
        if [ "x$ISCENTOS" = "x1" ] ; then
            echo "Uninstall on Centos"
            uninstall_ols_centos
        else
            echo "Uninstall on Debian/Ubuntu"
            uninstall_ols_debian
        fi
        echoG Uninstalled.
    else
        echoY "OpenLiteSpeed not installed."
    fi
}

function readPassword
{
    if [ "x$1" != "x" ] ; then 
        TEMPPASSWORD=$1
    else
        passwd=
        echoY "Please input password for $2(press enter to get a random one):"
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
    #test if first letter is - or not.
    local PARAMCHAR=`echo $1 | awk '{print substr($0,1,1)}'`
    if [ "x$PARAMCHAR" = "x-" ] ; then 
        PASSWORDPROVIDE=
    else
        PASSWORDPROVIDE=$1
    fi
}



function usage
{
    echoY "Usage:                             " "$0 [options] [options] ..."
    echoY "Options:                           "
    echoG " --adminpassword(-a) [PASSWORD]    " "To set the webAdmin password for openlitespeed instead of using a random one."
    echoG "                                   " "If you omit [PASSWORD], ols1clk will prompt you to provide this password during installation."
    echoG " --email(-e) EMAIL                 " "To set the email of the administrator."
    echoG " --lsphp VERSION                   " "To set the version of lsphp, such as 56, now we support '${LSPHPVERLIST[@]}'."
    echoG " --wordpress(-w)                   " "Set to install and setup wordpress, ....FIXME......"
    echoG " --wordpressplus SITEDOMAIN        " "Set to install and setup wordpress, .........FIXME............."
    echoG " --wordpresspath WORDPRESSPATH     " "To specify a location for new wordpress install ot use an existing wordpress installation."
    echoG " --dbrootpassword(-r) [PASSWORD]   " "To set the mysql server root password instead of using a random one."
    echoG "                                   " "If you omit [PASSWORD], ols1clk will prompt you to provide this password during installation."
    echoG " --dbname DATABASENAME             " "To set the database name to be used by wordpress."
    echoG " --dbuser DBUSERNAME               " "To set the username of wordpress in mysql."
    echoG " --dbpassword [PASSWORD]           " "To set the password of the table used by wordpress in mysql instead of using a random one."
    echoG "                                   " "If you omit [PASSWORD], ols1clk will prompt you to provide this password during installation."
    echoG " --listenport WORDPRESSPORT        " "To set the listener port, default is 80."
    
    echoG " --wpuser WORDPRESSUSER            " "To set the wordpress user for admin login to wordpress dashboard"
    echoG " --wppassword [PASSWORD]           " "To set the wordpress user for admin login to wordpress dashboard"
    echoG " --wplang WORDPRESSLANGUAGE        " "To set the wordpress language"
    echoG " --sitetitle WORDPRESSSITETITLE    " "To set the wordpress site title"
    
    echoG " --uninstall                       " "To uninstall OpenLiteSpeed and remove installation directory."
    echoG " --purgeall                        " "To uninstall OpenLiteSpeed, remove installation directory, and purge all data in mysql."
    echoG " --version(-v)                     " "To display version information."
    echoG " --help(-h)                        " "To display usage."
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
        -a | --adminpassword )      check_password_follow $2
                                    if [ "x$PASSWORDPROVIDE" != "x" ] ; then
                                        shift
                                    fi
                                    ADMINPASSWORD=$PASSWORDPROVIDE
                                    ;;

        -e | --email )              shift
                                    EMAIL=$1
                                    ;;
                                    
             --lsphp )              shift
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
                                    
             --wordpressplus )      shift
                                    SITEDOMAIN=$1
                                    INSTALLWORDPRESS=1
                                    INSTALLWORDPRESSPLUS=1
                                    ;;
                                    
             --wordpresspath )      shift
                                    WORDPRESSPATH=$1
                                    INSTALLWORDPRESS=1
                                    ;;
                                    
        -r | --dbrootpassword )     check_password_follow $2
                                    if [ "x$PASSWORDPROVIDE" != "x" ] ; then
                                        shift
                                    fi
                                    ROOTPASSWORD=$PASSWORDPROVIDE
                                    ;;

             --dbname )             shift
                                    DATABASENAME=$1
                                    ;;
             --dbuser )             shift
                                    USERNAME=$1
                                    ;;
             --dbpassword )         check_password_follow $2
                                    if [ "x$PASSWORDPROVIDE" != "x" ] ; then
                                        shift
                                    fi
                                    USERPASSWORD=$PASSWORDPROVIDE
                                    ;;
                                    
             --listenport )         shift
                                    WPPORT=$1
                                    ;;
                         

             --wpuser )             shift
                                    WPUSER=$1
                                    ;;
             --wppassword )         check_password_follow $2
                                    if [ "x$PASSWORDPROVIDE" != "x" ] ; then
                                        shift
                                    fi
                                    WPPASSWORD=$PASSWORDPROVIDE
                                    ;;
                                    
             --wplang )             shift
                                    WPLANGUAGE=$1
                                    ;;
                                    
             --sitetitle )          shift
                                    WPTITLE=$1
                                    ;;
                                    
        -v | --version )            exit 0
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
       echoY "We do not support lsphp7 on Centos 5, will use lsphp56."
       LSPHPVER=56
   fi
fi

if [ "x$EMAIL" = "x" ] ; then
    if [ "x$SITEDOMAIN" = "x*" ] ; then
        EMAIL=root@localhost
    else
        EMAIL=root@$SITEDOMAIN
    fi
fi

readPassword "$ADMINPASSWORD" "webAdmin password"
ADMINPASSWORD=$TEMPPASSWORD
readPassword "$ROOTPASSWORD" "mysql root password"
ROOTPASSWORD=$TEMPPASSWORD
readPassword "$USERPASSWORD" "mysql user password"
USERPASSWORD=$TEMPPASSWORD
if [ "x$INSTALLWORDPRESSPLUS" = "x1" ] ; then
    readPassword "$WPPASSWORD" "Wordpress admin password"
    WPPASSWORD=$TEMPPASSWORD
fi

echo
echoR "Starting to install openlitespeed to $SERVER_ROOT/ with below parameters,"
echoY "WebAdmin password:        " "$ADMINPASSWORD"
echoY "WebAdmin email:           " "$EMAIL"
echoY "Mysql root Password:      " "$ROOTPASSWORD"
echoY "Database name:            " "$DATABASENAME"
echoY "Database username:        " "$USERNAME"
echoY "Database password:        " "$USERPASSWORD"
echoY "lsphp version:            " "$LSPHPVER"


WORDPRESSINSTALLED=
if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
    echoY "Install wordpress:        " Yes
    echoY "WordPress listenport:     " "$WPPORT"
    echoY "Web site domain:          " "$SITEDOMAIN"
    
    if [ "x$INSTALLWORDPRESSPLUS" = "x1" ] ; then
        echoY "Wordpress plus:           " Yes
        echoY "Wordpress language:       " "$WPLANGUAGE"
        echoY "Wordpress site title:     " "$WPTITLE"
        echoY "Wordpress username:       " "$WPUSER"
        echoY "Wordpress password:       " "$WPPASSWORD"
    else
        echoY "Wordpress plus:           " No
    fi
    
    
    if [ -e "$WORDPRESSPATH/wordpress/wp-config.php" ] ; then
        echoY "WordPress location:       " "$WORDPRESSPATH.(Exsiting)"
        WORDPRESSINSTALLED=1
    else
        echoY "WordPress location:       " "$WORDPRESSPATH.(New install)"
        WORDPRESSINSTALLED=0
    fi


else
    echoY "Install WordPress:        " "No"
fi

echo
printf '\033[31mIs the settings correct? Type n to quit, otherwise will continue.[Y/n]\033[0m '
read answer
echo

if [ "x$answer" = "xN" ] || [ "x$answer" = "xn" ] ; then
    echoG "Aborting installation!" 
    exit 0
fi
echo 


####begin here#####
update_centos_hashlib
check_wget

if [ "x$OLSINSTALLED" = "x1" ] ; then
    echoY "OpenLiteSpeed is already installed, will attempt to update it."
fi
install_ols
if [ "x$ISCENTOS" = "x1" ] ; then
  csf_install
fi

if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
    if [ "x$MYSQLINSTALLED" != "x1" ] ; then
        if [ "x$ISCENTOS" = "x1" ] ; then
            install_mariadb
        else
            install_mysql
        fi
    else
        test_mysql_password
    fi    

    if [ "x$WORDPRESSINSTALLED" != "x1" ] ; then
        install_wordpress
        setup_wordpress
    
        if [ "x$TESTPASSWORDERROR" = "x1" ] ; then
            echoY "Mysql setup byppassed due to not know the root password."
        else
            ROOTPASSWORD=$CURROOTPASSWORD
            setup_mysql
        fi
    fi
    
    config_server
    
    if [ "x$WPPORT" = "x80" ] ; then
        if [ "x$ISCENTOS" = "x1" ] ; then
            if [[ "$(rpm -ql httpd >/dev/null 2>&1; echo $?)" = '0' ]]; then
                if [ -f /etc/init.d/httpd ]; then
                    service httpd stop
                    chkconfig httpd off
                fi
                if [[ "$(systemctl is-enabled httpd.service)" = 'enabled' ]]; then
                    systemctl stop httpd.service
                    systemctl disable httpd.service
                else
                    systemctl disable httpd.service
                fi
            fi
        else
            echoY "Trying to stop some web servers that may be using port 80."
            killall -9 apache2  >/dev/null 2>&1
            killall -9 httpd    >/dev/null 2>&1
        fi
    fi
fi

$SERVER_ROOT/bin/lswsctrl stop
$SERVER_ROOT/bin/lswsctrl start

echo "mysql root password is [$ROOTPASSWORD]." >> $SERVER_ROOT/password

if [ "x$INSTALLWORDPRESSPLUS" = "x1" ] ; then
    if [ "x$WPPORT" != "x80" ] ; then
        INSTALLURL=http://$SITEDOMAIN:$WPPORT/wp-admin/install.php
    else
        INSTALLURL=http://$SITEDOMAIN/wp-admin/install.php
    fi

    wget $INSTALLURL>  /dev/null 2>&1
    sleep 5
    
    #echo "wget --post-data 'language=$WPLANGUAGE' --referer=$INSTALLURL $INSTALLURL?step=1"
    wget --no-check-certificate --post-data "language=$WPLANGUAGE" --referer=$INSTALLURL $INSTALLURL?step=1>  /dev/null 2>&1
    sleep 1
    
    #echo "wget --post-data 'weblog_title=$WPTITLE&user_name=$WPUSER&admin_password=$WPPASSWORD&pass1-text=$WPPASSWORD&admin_password2=$WPPASSWORD&pw_weak=on&admin_email=$EMAIL&Submit=Install+WordPress&language=$WPLANGUAGE' --referer=$INSTALLURL?step=1 $INSTALLURL?step=2 "
    wget --no-check-certificate --post-data "weblog_title=$WPTITLE&user_name=$WPUSER&admin_password=$WPPASSWORD&pass1-text=$WPPASSWORD&admin_password2=$WPPASSWORD&pw_weak=on&admin_email=$EMAIL&Submit=Install+WordPress&language=$WPLANGUAGE" --referer=$INSTALLURL?step=1 $INSTALLURL?step=2  >  /dev/null 2>&1

    echo "wordpress administrator username is [$WPUSER], password is [$WPPASSWORD]." >> $SERVER_ROOT/password
fi


echoY "Please be aware that your password was written to file '$SERVER_ROOT/password'." 

if [ "x$ALLERRORS" = "x0" ] ; then
    echo
    echoY "------------------------------------------------------------------------------"
    echoG "Congratulations! Installation finished."
    echoY "------------------------------------------------------------------------------"
    echoG "Server Config file at $SERVER_ROOT/conf/httpd_config.conf"
    echoG "PHP php.ini file at /usr/local/lsws/php/php.ini"
    echoG "PHP Config Scan Dir at /usr/local/lsws/lsphp$LSPHPVER/etc/php.d/"
    echoG "Please access http://localhost:$ADMINPORT/ for admin console with password = $ADMINPASSWORD."
    if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
        echoG "Wordpress site vhost file at $VHOSTCONF"
        echoG "Wordpress web root at ${WORDPRESSPATH}/wordpress"
        echoG "Wordpress $DATABASENAME with username: $USERNAME password: $USERPASSWORD"
        echoG "Please access http://localhost:$WPPORT/ to finish setting up your WordPress site."
        echoG "And also you may want to activate Litespeed Cache plugin to get better performance."
    fi
    echo
    echoG "OLS Version Installed:"
    if [ -f /usr/local/lsws/modules/modpagespeed.so ]; then
        echo "$(/usr/local/lsws/bin/openlitespeed --version) with modpagespeed $(strings /usr/local/lsws/modules/modpagespeed.so | awk -F "/" '/\/home\/buildbot\/build\// {print $5}' | uniq)"
    else
        echo "$(/usr/local/lsws/bin/openlitespeed --version) without modpagespeed"
    fi

    echo
    echoG "PHPV Version Installed:"
    /usr/bin/php -v

    echo
    echoG "MariaDB 10.1 Installed:"
    $(which rpm) -qa | grep -i MariaDB

    echo
else
    echoY "Installation finished. It seems some errors occured, please check this as you may need to manually fix them."
    if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
        echoG "Please access http://localhost:$WPPORT/ to finish setting up your WordPress site."
        echoG "And also you may want to activate Litespeed Cache plugin to get better performance."
    fi
fi  
echo
echoG "If you run into any problems, they can sometimes be fixed by purgeall and reinstalling."
echoG 'Thanks for using "OpenLiteSpeed One click installation".'
echoG "Enjoy!"
echo
echo
