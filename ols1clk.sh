#!/bin/bash
##############################################################################
#    Open LiteSpeed is an open source HTTP server.                           #
#    Copyright (C) 2013 - 2019 LiteSpeed Technologies, Inc.                  #
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


TEMPRANDSTR=
function getRandPassword
{
    dd if=/dev/urandom bs=8 count=1 of=/tmp/randpasswdtmpfile >/dev/null 2>&1
    TEMPRANDSTR=`cat /tmp/randpasswdtmpfile`
    rm /tmp/randpasswdtmpfile
    local DATE=`date`
    TEMPRANDSTR=`echo "$TEMPRANDSTR$RANDOM$DATE" |  md5sum | base64 | head -c 8`
}

OSNAMEVER=UNKNOWN
OSNAME=
OSVER=
OSTYPE=`uname -m`
MARIADBCPUARCH=

SERVER_ROOT=/usr/local/lsws
LSWSADMINCONFIG='/usr/local/lsws/admin/conf/admin_config.conf'
LSWSCONFIG='/usr/local/lsws/conf/httpd_config.conf'

#Current status
OLSINSTALLED=
MYSQLINSTALLED=
TESTGETERROR=no

getRandPassword
ADMINPASSWORD=$TEMPRANDSTR
getRandPassword
ROOTPASSWORD=$TEMPRANDSTR
getRandPassword
USERPASSWORD=$TEMPRANDSTR
getRandPassword
WPPASSWORD=$TEMPRANDSTR

ADMINPASSWORD=`echo "$RAND1$DATE" |  md5sum | base64 | head -c 8`
ROOTPASSWORD=`echo "$RAND2$DATE" |  md5sum | base64 | head -c 8`
MYSQLEXTRA_FILE='/root/.my.cnf'
MYSQLINSTALL='n'
DATABASENAME=olsdbname
USERNAME=olsdbuser

WORDPRESSPATH=$SERVER_ROOT/wordpress
WPPORT=8080
SSLWPPORT=8443
ADMINPORT=7080
INSTALLWORDPRESS=0
INSTALLWORDPRESSPLUS=0
FORCEYES=0
WPLANGUAGE=en
WPUSER=wpuser
WPTITLE=MySite
WPCLI_EXTRAPACKAGES='n'
WPCLIDIR='/root/wpcli'
WPCLILINK='https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar'

SITEDOMAIN=*
EMAIL=

#All lsphp versions, keep using two digits to identify a version!!!
#otherwise, need to update the uninstall function which will check the version
LSPHPVERLIST=(54 55 56 70 71 72 73 74)
MARIADBVERLIST=(10.0 10.1 10.2 10.3 10.4)

#default version
LSPHPVER=73
USEDEFAULTLSPHP=1
MARIADBVER=10.3
USEDEFAULTLSMARIADB=1

ALLERRORS=0
TEMPPASSWORD=

ACTION=INSTALL
FOLLOWPARAM=

CONFFILE=myssl.conf
CSR=example.csr
KEY=example.key
CERT=example.crt

MYGITHUBURL=https://raw.githubusercontent.com/litespeedtech/ols1clk/master/ols1clk.sh

function echoY
{
    FLAG=$1
    shift
    echo -e "\033[38;5;148m$FLAG\033[39m$@"
}

function echoG
{
    FLAG=$1
    shift
    echo -e "\033[38;5;71m$FLAG\033[39m$@"
}

function echoR
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

ols_tweaks() {
    if [ -d /usr/local/src/centminmod ]; then
        USER='nginx'       # change to your preferred user to run OLS
        GROUP='nginx'      # change to your preferred group to run OLS
    else
        USER='nobody'       # change to your preferred user to run OLS
        GROUP='nobody'      # change to your preferred group to run OLS
    fi
    echo
    echo "setup command shortcuts"
    echo "/usr/local/lsws/bin/lswsctrl start" > /usr/bin/lsstart
    echo "/usr/local/lsws/bin/lswsctrl stop" > /usr/bin/lsstop
    echo "/usr/local/lsws/bin/lswsctrl restart" > /usr/bin/lsrestart
    echo "/usr/local/lsws/bin/lswsctrl reload" > /usr/bin/lsreload
    chmod 0700 /usr/bin/lsstart
    chmod 0700 /usr/bin/lsstop
    chmod 0700 /usr/bin/lsrestart
    chmod 0700 /usr/bin/lsreload

    alias lsadedit='nano -w /usr/local/lsws/admin/conf/admin_config.conf'
    alias lsconf='nano -w /usr/local/lsws/conf/httpd_config.conf'
    echo "alias lsadedit='nano -w /usr/local/lsws/admin/conf/admin_config.conf'" >> /root/.bashrc
    echo "alias lsconf='nano -w /usr/local/lsws/conf/httpd_config.conf'" >> /root/.bashrc
    # /usr/local/lsws/admin/conf/admin_config.conf
    # sed -i 's/secure                1/secure                0/' $LSWSADMINCONFIG

    # /usr/local/lsws/conf/httpd_config.conf
    echo -n "General Tweaks"
    # sed -i 's/indexFiles                index.html/indexFiles                index.html index.php/g' ${LSWSCONFIG}
    sed -i "s/user                             nobody/user                             $USER/g" ${LSWSCONFIG}
    sed -i "s/group                            nobody/group                            $GROUP/g" ${LSWSCONFIG}
    sed -i 's|maxConnections               2000|maxConnections               100000|g' ${LSWSCONFIG}
    sed -i 's|maxSSLConnections            1000|maxSSLConnections            100000|g' ${LSWSCONFIG}
    # sed -i "s/inMemBufSize              60M/inMemBufSize              60M/g" ${LSWSCONFIG}
    echo " done"
    echo -n "Tuning Tweaks"
    # sed -i "s/smartKeepAlive          0/smartKeepAlive          1/g" ${LSWSCONFIG}
    # sed -i "s/sndBufSize              0/sndBufSize              65535/g" ${LSWSCONFIG}
    # sed -i "s/rcvBufSize              0/rcvBufSize              65535/g" ${LSWSCONFIG}
    # sed -i "s/maxCachedFileSize       4096/maxCachedFileSize       16384/g" ${LSWSCONFIG}
    # sed -i "s/totalInMemCacheSize     20M/totalInMemCacheSize     40M/g" ${LSWSCONFIG}
    # sed -i "s/maxMMapFileSize         256K/maxMMapFileSize         512K/g" ${LSWSCONFIG}
    # sed -i "s/totalMMapCacheSize      40M/totalMMapCacheSize      80M/g" ${LSWSCONFIG}
    echo " done"
    echo -n "External App lsphp5 Tweaks"
    # sed -i "s/maxConns                35/maxConns                50/g" ${LSWSCONFIG}
    # sed -i "s/PHP_LSAPI_CHILDREN=35/PHP_LSAPI_CHILDREN=50/g" ${LSWSCONFIG}
    # sed -i "s/memSoftLimit            2047M/memSoftLimit            2047M/g" ${LSWSCONFIG}
    # sed -i "s/memHardLimit            2047M/memHardLimit            2047M/g" ${LSWSCONFIG}
    # sed -i "s/procSoftLimit           400/procSoftLimit           1000/g" ${LSWSCONFIG}
    # sed -i "s/procHardLimit           500/procHardLimit           1200/g" ${LSWSCONFIG}
}

csf_install() {
    local VERSION=
    if [ "$OSNAMEVER" = "CENTOS5" ] ; then
        VERSION=5
    elif [ "$OSNAMEVER" = "CENTOS6" ] ; then
        VERSION=6
    elif [ "$OSNAMEVER" = "CENTOS7" ] ; then
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
    sed -i 's/20,21,22,25,53,80,110,143,443,465,587,993,995/20,21,22,25,53,80,110,143,161,443,465,587,993,995,1110,1186,1194,2049,8080,8081,8888,81,9418,30001:50011/g' /etc/csf/csf.conf

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
    which wget  >/dev/null 2>&1
    if [ $? != 0 ] ; then
        if [ "x$OSNAME" = "xcentos" ] ; then
            yum -y install wget
        else
            apt-get -y install wget
        fi

        which wget  >/dev/null 2>&1
        if [ $? != 0 ] ; then
            echoR "An error occured during wget installation."
            ALLERRORS=1
        fi
    fi
}

function display_license
{
    echoY '**********************************************************************************************'
    echoY '*                    Open LiteSpeed One click installation, Version 2.1                      *'
    echoY '*                    Copyright (C) 2016 - 2019 LiteSpeed Technologies, Inc.                  *'
    echoY '**********************************************************************************************'
}

function check_os
{
    OSNAMEVER=
    OSNAME=
    OSVER=
    MARIADBCPUARCH=

    if [ -f /etc/redhat-release ] ; then
        cat /etc/redhat-release | grep " 6." >/dev/null
        if [ $? = 0 ] ; then
            OSNAMEVER=CENTOS6
            OSNAME=centos
            OSVER=6
        else
            cat /etc/redhat-release | grep " 7." >/dev/null
            if [ $? = 0 ] ; then
                OSNAMEVER=CENTOS7
                OSNAME=centos
                OSVER=7
                ISCENTOS=1
            else
                cat /etc/redhat-release | grep " 8." >/dev/null
                if [ $? = 0 ] ; then
                    OSNAMEVER=CENTOS8
                    OSNAME=centos
                    OSVER=8
                fi
            fi
        fi
    elif [ -f /etc/lsb-release ] ; then
        cat /etc/lsb-release | grep "DISTRIB_RELEASE=14." >/dev/null
        if [ $? = 0 ] ; then
            OSNAMEVER=UBUNTU14
            OSNAME=ubuntu
            OSVER=trusty
            MARIADBCPUARCH="arch=amd64,i386,ppc64el"
        else
            cat /etc/lsb-release | grep "DISTRIB_RELEASE=16." >/dev/null
            if [ $? = 0 ] ; then
                OSNAMEVER=UBUNTU16
                OSNAME=ubuntu
                OSVER=xenial
                MARIADBCPUARCH="arch=amd64,i386,ppc64el"

            else
                cat /etc/lsb-release | grep "DISTRIB_RELEASE=18." >/dev/null
                if [ $? = 0 ] ; then
                    OSNAMEVER=UBUNTU18
                    OSNAME=ubuntu
                    OSVER=bionic
                    MARIADBCPUARCH="arch=amd64"
                fi
            fi
        fi
    elif [ -f /etc/debian_version ] ; then
        cat /etc/debian_version | grep "^7." >/dev/null
        if [ $? = 0 ] ; then
            OSNAMEVER=DEBIAN7
            OSNAME=debian
            OSVER=wheezy
            MARIADBCPUARCH="arch=amd64,i386"
        else
            cat /etc/debian_version | grep "^8." >/dev/null
            if [ $? = 0 ] ; then
                OSNAMEVER=DEBIAN8
                OSNAME=debian
                OSVER=jessie
                MARIADBCPUARCH="arch=amd64,i386"
            else
                cat /etc/debian_version | grep "^9." >/dev/null
                if [ $? = 0 ] ; then
                    OSNAMEVER=DEBIAN9
                    OSNAME=debian
                    OSVER=stretch
                    MARIADBCPUARCH="arch=amd64,i386"
                else
                    cat /etc/debian_version | grep "^10." >/dev/null
                    if [ $? = 0 ] ; then
                        OSNAMEVER=DEBIAN10
                        OSNAME=debian
                        OSVER=buster
                        MARIADBCPUARCH="arch=amd64,i386"
                    fi
                fi
            fi
        fi
    fi

    if [ "x$OSNAMEVER" = "x" ] ; then
        echoR "Sorry, currently one click installation only supports Centos(6-8), Debian(7-10) and Ubuntu(14,16,18)."
        echoR "You can download the source code and build from it."
        echoR "The url of the source code is https://github.com/litespeedtech/openlitespeed/releases."
        echo
        exit 1
    else
        if [ "x$OSNAME" = "xcentos" ] ; then
            echoG "Current platform is "  "$OSNAME $OSVER."
        else
            export DEBIAN_FRONTEND=noninteractive
            echoG "Current platform is "  "$OSNAMEVER $OSNAME $OSVER."
        fi
    fi
}


function update_centos_hashlib
{
    if [ "x$OSNAME" = "xcentos" ] ; then
        yum -y install python-hashlib
    fi
}


function install_ols_centos
{
    local action=install
    if [ "x$1" = "xUpdate" ] ; then
        action=update
    elif [ "x$1" = "xReinstall" ] ; then
        action=reinstall
    fi

    local JSON=
    if [ "x$LSPHPVER" = "x70" ] || [ "x$LSPHPVER" = "x71" ] || [ "x$LSPHPVER" = "x72" ] || [ "x$LSPHPVER" = "x73" ] ; then
        JSON=lsphp$LSPHPVER-json
    fi


    yum -y $action epel-release
    rpm -Uvh http://rpms.litespeedtech.com/centos/litespeed-repo-1.1-1.el$OSVER.noarch.rpm
    yum -y $action openlitespeed

    #Sometimes it may fail and do a reinstall to fix
    if [ ! -e "$SERVER_ROOT/conf/httpd_config.conf" ] ; then
        yum -y reinstall openlitespeed
    fi

    if [ ! -e $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp ] ; then
        action=install
    fi

    #special case for lsphp-mysql
    if [ "x$action" = "xreinstall" ] ; then
        yum -y remove lsphp$LSPHPVER-mysqlnd
    fi
    yum -y install lsphp$LSPHPVER-mysqlnd

    LSPHP_EXTRA_YUM='lsphp73-bcmath lsphp73-dba lsphp73-enchant lsphp73-gmp lsphp73-intl lsphp73-opcache lsphp73-pecl-memcache lsphp73-pecl-memcached lsphp73-pecl-redis lsphp73-recode lsphp73-pspell lsphp73-snmp lsphp73-soap lsphp73-sodium lsphp73-tidy lsphp73-xmlrpc lsphp73-zip'
    yum -y $action lsphp$LSPHPVER lsphp$LSPHPVER-common lsphp$LSPHPVER-gd lsphp$LSPHPVER-process lsphp$LSPHPVER-mbstring lsphp$LSPHPVER-xml lsphp$LSPHPVER-mcrypt lsphp$LSPHPVER-pdo lsphp$LSPHPVER-imap $JSON $LSPHP_EXTRA_YUM

    if [ $? != 0 ] ; then
        echoR "An error occured during OpenLiteSpeed installation."
        ALLERRORS=1
    else
        ln -sf $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp $SERVER_ROOT/fcgi-bin/lsphpnew
        sed -i -e "s/fcgi-bin\/lsphp/fcgi-bin\/lsphpnew/g" "$SERVER_ROOT/conf/httpd_config.conf"
    fi
    ols_tweaks
    if [ ! -f /etc/csf/csf.conf ]; then
        csf_install
    fi
}

function uninstall_ols_centos
{
    yum -y remove openlitespeed
    if [ $? != 0 ] ; then
        echoR "An error occured while uninstalling OpenLiteSpeed."
        ALLERRORS=1
    fi

    #Need to find what is current lsphp version
    yum list installed | grep lsphp | grep process >/dev/null 2>&1
    if [ $? = 0 ] ; then
        local LSPHPSTR=`yum list installed | grep lsphp | grep process`
        LSPHPVER=`echo $LSPHPSTR | awk '{print substr($0,6,2)}'`
        echoY "The installed LSPHP version is $LSPHPVER"

        local JSON=
        if [ "x$LSPHPVER" = "x70" ] || [ "x$LSPHPVER" = "x71" ] || [ "x$LSPHPVER" = "x72" ] || [ "x$LSPHPVER" = "x73" ] ; then
            JSON=lsphp$LSPHPVER-json
        fi

        yum -y remove lsphp$LSPHPVER lsphp$LSPHPVER-common lsphp$LSPHPVER-gd lsphp$LSPHPVER-process lsphp$LSPHPVER-mbstring lsphp$LSPHPVER-mysqlnd lsphp$LSPHPVER-xml lsphp$LSPHPVER-mcrypt lsphp$LSPHPVER-pdo lsphp$LSPHPVER-imap $JSON lsphp*
        if [ $? != 0 ] ; then
            echoR "An error occured while uninstalling lsphp$LSPHPVER"
            ALLERRORS=1
        fi

    else
        yum -y remove lsphp*
        echoR "Uninstallation cannot get the currently installed LSPHP version."
        echoY "May not uninstall LSPHP correctly."
        LSPHPVER=
    fi

    rm -rf $SERVER_ROOT/
}

function install_ols_debian
{
    local action=
    if [ "x$1" = "xUpdate" ] ; then
        action="--only-upgrade"
    elif [ "x$1" = "xReinstall" ] ; then
        action="--reinstall"
    fi


    grep -Fq  "http://rpms.litespeedtech.com/debian/" /etc/apt/sources.list.d/lst_debian_repo.list
    if [ $? != 0 ] ; then
        echo "deb http://rpms.litespeedtech.com/debian/ $OSVER main"  > /etc/apt/sources.list.d/lst_debian_repo.list
    fi

    wget -O /etc/apt/trusted.gpg.d/lst_debian_repo.gpg http://rpms.litespeedtech.com/debian/lst_debian_repo.gpg
    wget -O /etc/apt/trusted.gpg.d/lst_repo.gpg http://rpms.litespeedtech.com/debian/lst_repo.gpg

    apt-get -y update
    apt-get -y install $action openlitespeed

    if [ ! -e $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp ] ; then
        action=
    fi
    apt-get -y install $action lsphp$LSPHPVER lsphp$LSPHPVER-mysql lsphp$LSPHPVER-imap lsphp$LSPHPVER-curl


    if [ "x$LSPHPVER" != "x70" ] && [ "x$LSPHPVER" != "x71" ] && [ "x$LSPHPVER" != "x72" ]  && [ "x$LSPHPVER" != "x73" ] ; then
        apt-get -y install $action lsphp$LSPHPVER-gd lsphp$LSPHPVER-mcrypt
    else
       apt-get -y install $action lsphp$LSPHPVER-common lsphp$LSPHPVER-json
    fi

    if [ $? != 0 ] ; then
        echoR "An error occured during OpenLiteSpeed installation."
        ALLERRORS=1
    else
        ln -sf $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp $SERVER_ROOT/fcgi-bin/lsphpnew
        sed -i -e "s/fcgi-bin\/lsphp/fcgi-bin\/lsphpnew/g" "$SERVER_ROOT/conf/httpd_config.conf"
    fi
}


function uninstall_ols_debian
{
    apt-get -y --purge remove openlitespeed

    dpkg -l | grep lsphp | grep mysql >/dev/null 2>&1
    if [ $? = 0 ] ; then
        local LSPHPSTR=`dpkg -l | grep lsphp | grep mysql`
        LSPHPVER=`echo $LSPHPSTR | awk '{print substr($2,6,2)}'`
        echoY "The installed LSPHP version is $LSPHPVER"

        if [ "x$LSPHPVER" != "x70" ] && [ "x$LSPHPVER" != "x71" ] && [ "x$LSPHPVER" != "x72" ] && [ "x$LSPHPVER" != "x73" ] ; then
            apt-get -y --purge remove lsphp$LSPHPVER-gd lsphp$LSPHPVER-mcrypt
        else
            apt-get -y --purge remove lsphp$LSPHPVER-common
        fi

        apt-get -y --purge remove lsphp$LSPHPVER lsphp$LSPHPVER-mysql lsphp$LSPHPVER-imap 'lsphp*'
        if [ $? != 0 ] ; then
            echoR "An error occured while uninstalling OpenLiteSpeed/LSPHP."
            ALLERRORS=1
        fi
    else
        apt-get -y --purge remove lsphp*
        echoR "Uninstallation cannot get the currently installed LSPHP version."
        echoR "May not uninstall LSPHP correctly."
        LSPHPVER=
    fi

    rm -rf $SERVER_ROOT/
}

function install_wordpress
{
    if [ ! -e "$WORDPRESSPATH" ] ; then
        local WPDIRNAME=`dirname $WORDPRESSPATH`
        local WPBASENAME=`basename $WORDPRESSPATH`
        mkdir -p "$WPDIRNAME"

        cd "$WPDIRNAME"

        wget --no-check-certificate http://wordpress.org/latest.tar.gz
        tar -xzvf latest.tar.gz  >/dev/null 2>&1
        rm latest.tar.gz
        if [ "x$WPBASENAME" != "xwordpress" ] ; then
            mv wordpress/ $WPBASENAME/
        fi


        wget -q -r --level=0 -nH --cut-dirs=2 --no-parent https://plugins.svn.wordpress.org/litespeed-cache/trunk/ --reject html -P $WORDPRESSPATH/wp-content/plugins/litespeed-cache/
        chown -R --reference=$SERVER_ROOT/autoupdate  $WORDPRESSPATH

        # setup permalinks
        installwpcli
        pushd $WORDPRESSPATH
        \wp rewrite structure '/%post_id%/%postname%/' --allow-root
        echo > "$WORDPRESSPATH/.htaccess"
        echo '# BEGIN WordPress' >> "$WORDPRESSPATH/.htaccess"
        echo '<IfModule mod_rewrite.c>' >> "$WORDPRESSPATH/.htaccess"
        echo 'RewriteEngine On' >> "$WORDPRESSPATH/.htaccess"
        echo 'RewriteBase /' >> "$WORDPRESSPATH/.htaccess"
        echo 'RewriteRule ^index\.php$ - [L]' >> "$WORDPRESSPATH/.htaccess"
        echo 'RewriteCond %{REQUEST_FILENAME} !-f' >> "$WORDPRESSPATH/.htaccess"
        echo 'RewriteCond %{REQUEST_FILENAME} !-d' >> "$WORDPRESSPATH/.htaccess"
        echo 'RewriteRule . /index.php [L]' >> "$WORDPRESSPATH/.htaccess"
        echo '</IfModule>' >> "$WORDPRESSPATH/.htaccess"
        echo '# END WordPress' >> "$WORDPRESSPATH/.htaccess"
        /usr/local/lsws/bin/lswsctrl restart
        popd

        cd -
    else
        echoY "$WORDPRESSPATH exists, will use it."
    fi
}



function setup_wordpress
{
    if [ -e "$WORDPRESSPATH/wp-config-sample.php" ] ; then
        sed -e "s/database_name_here/$DATABASENAME/" -e "s/username_here/$USERNAME/" -e "s/password_here/$USERPASSWORD/" "$WORDPRESSPATH/wp-config-sample.php" > "$WORDPRESSPATH/wp-config.php"
        if [ -e "$WORDPRESSPATH/wp-config.php" ] ; then
            chown  -R --reference="$WORDPRESSPATH/wp-config-sample.php"   "$WORDPRESSPATH/wp-config.php"
            echoG "Finished setting up WordPress."
        else
            echoR "WordPress setup failed. You may not have sufficient privileges to access $WORDPRESSPATH/wp-config.php."
            ALLERRORS=1
        fi
    else
        echoR "WordPress setup failed. File $WORDPRESSPATH/wp-config-sample.php does not exist."
        ALLERRORS=1
    fi
}


function test_mysql_password
{
    if [[ -f /root/.my.cnf && "$(awk -F '=' '/password=/ {print $2}' /root/.my.cnf)" ]]; then
        ROOTPASSWORD=$(awk -F '=' '/password=/ {print $2}' /root/.my.cnf)
        CURROOTPASSWORD=$ROOTPASSWORD
    else
        CURROOTPASSWORD=$ROOTPASSWORD
    fi
    TESTPASSWORDERROR=0

    mysqladmin -uroot -p$CURROOTPASSWORD password $CURROOTPASSWORD
    if [ $? != 0 ] ; then
        #Sometimes, mysql will treat the password error and restart will fix it.
        service mysql restart
        if [ $? != 0 ] && [ "x$OSNAME" = "xcentos" ] ; then
            service mysqld restart
        fi

        mysqladmin -uroot -p$CURROOTPASSWORD password $CURROOTPASSWORD
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
                mysqladmin -uroot -p$answer password $answer
                if [ $? = 0 ] ; then
                    CURROOTPASSWORD=$answer
                else
                    echoR "root password is incorrect. 1 attempt remaining."
                    printf '\033[31mPlease input the current root password:\033[0m'
                    read answer
                    mysqladmin -uroot -p$answer password $answer
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
    fi

    export TESTPASSWORDERROR=$TESTPASSWORDERROR
    if [ "x$TESTPASSWORDERROR" = "x1" ] ; then
        export CURROOTPASSWORD=
    else
        export CURROOTPASSWORD=$CURROOTPASSWORD
    fi
}

function setupmycnf
{
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
# by eva2000 centminmod.com

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

[mariadb-10.2]
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
}

function install_mysql
{
    if [ "x$OSNAME" = "xcentos" ] ; then

        #Add mariadb repo here if not exist
        local REPOFILE=/etc/yum.repos.d/MariaDB.repo
        if [ ! -f $REPOFILE ] ; then
            local CENTOSVER=
            if [ "x$OSTYPE" != "xx86_64" ] ; then
                CENTOSVER=centos$OSVER-x86
            else
                CENTOSVER=centos$OSVER-amd64
            fi

            cat >> $REPOFILE <<END
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/$MARIADBVER/$CENTOSVER
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1

END
        fi
        if [ "x$OSNAMEVER" = "xCENTOS8" ] ; then
            yum install -y boost-program-options
            yum --disablerepo=AppStream install -y MariaDB-server MariaDB-client
        else
            yum -y install MariaDB-server MariaDB-client
        fi
        if [ $? != 0 ] ; then
            echoR "An error occured during installation of MariaDB. Please fix this error and try again."
            echoR "You may want to manually run the command 'yum -y install MariaDB-server MariaDB-client' to check. Aborting installation!"
            exit 1
        fi
    else

        if [ "x$OSNAMEVER" = "xDEBIAN7" ] ; then
            apt-get install python-software-properties
            apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
        elif [ "x$OSNAMEVER" = "xDEBIAN8" ] ; then
            apt-get install software-properties-common
            apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
        elif [ "x$OSNAMEVER" = "xDEBIAN9" ] ; then
            apt-get install software-properties-common
            apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8

        elif [ "x$OSNAMEVER" = "xUBUNTU12" ] ; then
            apt-get install python-software-properties
            apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
        elif [ "x$OSNAMEVER" = "xUBUNTU14" ] ; then
            apt-get install software-properties-common
            apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
        elif [ "x$OSNAMEVER" = "xUBUNTU16" ] ; then
            apt-get install software-properties-common
            apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
        elif [ "x$OSNAMEVER" = "xUBUNTU18" ] ; then
            apt-get install software-properties-common
            apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
        fi

        grep -Fq  "http://mirror.jaleco.com/mariadb/repo/" /etc/apt/sources.list.d/mariadb_repo.list
        if [ $? != 0 ] ; then
            echo "deb [$MARIADBCPUARCH] http://mirror.jaleco.com/mariadb/repo/$MARIADBVER/$OSNAME $OSVER main"  > /etc/apt/sources.list.d/mariadb_repo.list
        fi
        apt-get update
        apt-get -y -f --force-yes install mariadb-server
        if [ $? != 0 ] ; then
            echoR "An error occured during installation of MariaDB. Please fix this error and try again."
            echoR "You may want to manually run the command 'apt-get -y -f --force-yes install mariadb-server' to check. Aborting installation!"
            exit 1
        fi

    fi
    if [ "x$OSNAMEVER" = "xCENTOS8" ] || [ "x$OSNAMEVER" = "xCENTOS7" ] ; then
        systemctl enable mariadb
        systemctl start  mariadb
    else
        service mysql start
    fi
    if [ $? != 0 ] ; then
        echoR "An error occured when starting the MariaDB service. "
        echoR "Please fix this error and try again. Aborting installation!"
        exit 1
    fi

    #mysql_secure_installation
    #mysql_install_db

    mysql -uroot -e "update mysql.user set plugin='' where user='root';"
    mysql -uroot -e "flush privileges;"
    #service mysql restart

    mysqladmin -uroot password $ROOTPASSWORD
    if [ $? = 0 ] ; then
        echoG "MySQL root password set to $ROOTPASSWORD"
        CURROOTPASSWORD=$ROOTPASSWORD
    else
        #test it is the current password
        mysqladmin -uroot -p$ROOTPASSWORD password $ROOTPASSWORD
        if [ $? = 0 ] ; then
            echoG "MySQL root password is $ROOTPASSWORD"
            CURROOTPASSWORD=$ROOTPASSWORD
        else
            echoR "Failed to set MySQL root password to $ROOTPASSWORD, it may already have a root password."
            printf '\033[31mInstallation must know the password for the next step.\033[0m'
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
                echoY "Current MySQL root password is $CURROOTPASSWORD, it will be changed to $ROOTPASSWORD."
                printf '\033[31mDo you still want to change it?[y/N]\033[0m '
                read answer
                echo

                if [ "x$answer" != "xY" ] && [ "x$answer" != "xy" ] ; then
                    echoG "OK, MySQL root password not changed."
                    ROOTPASSWORD=$CURROOTPASSWORD
                else
                    mysqladmin -uroot -p$CURROOTPASSWORD password $ROOTPASSWORD
                    if [ $? = 0 ] ; then
                        echoG "OK, MySQL root password changed to $ROOTPASSWORD."
                    else
                        echoR "Failed to change MySQL root password, it is still $CURROOTPASSWORD."
                        ROOTPASSWORD=$CURROOTPASSWORD
                    fi
                fi
            fi
        fi
    fi
}

function setup_mysql
{
    local ERROR=

    #delete user if exists because I need to set the password
    mysql -uroot -p$ROOTPASSWORD  -e "DELETE FROM mysql.user WHERE User = '$USERNAME@localhost';"

    echo `mysql -uroot -p$ROOTPASSWORD -e "SELECT user FROM mysql.user"` | grep "$USERNAME" >/dev/null
    if [ $? = 0 ] ; then
        echoG "user $USERNAME exists in mysql.user"
    else
        mysql -uroot -p$ROOTPASSWORD  -e "CREATE USER $USERNAME@localhost IDENTIFIED BY '$USERPASSWORD';"
        if [ $? = 0 ] ; then
            mysql -uroot -p$ROOTPASSWORD  -e "GRANT ALL PRIVILEGES ON *.* TO '$USERNAME'@localhost IDENTIFIED BY '$USERPASSWORD';"
        else
            echoR "Failed to create MySQL user $USERNAME. This user may already exist. If it does not, another problem occured."
            echoR "Please check this and update the wp-config.php file."
            ERROR="Create user error"
        fi
    fi

    mysql -uroot -p$ROOTPASSWORD  -e "CREATE DATABASE IF NOT EXISTS $DATABASENAME;"
    if [ $? = 0 ] ; then
        mysql -uroot -p$ROOTPASSWORD  -e "GRANT ALL PRIVILEGES ON $DATABASENAME.* TO '$USERNAME'@localhost IDENTIFIED BY '$USERPASSWORD';"
    else
        echoR "Failed to create database $DATABASENAME. It may already exist. If it does not, another problem occured."
        echoR "Please check this and update the wp-config.php file."
        if [ "x$ERROR" = "x" ] ; then
            ERROR="Create database error"
        else
            ERROR="$ERROR and create database error"
        fi
    fi
    mysql -uroot -p$ROOTPASSWORD  -e "flush privileges;"

    if [ "x$ERROR" = "x" ] ; then
        echoG "Finished MySQL setup without error."
    else
        echoR "Finished MySQL setup - some error(s) occured."
    fi
}

function resetmysqlroot
{
    if [ "x$OSNAMEVER" = "xCENTOS8" ]; then
        MYSQLNAME='mariadb'
    else
        MYSQLNAME=mysql
    fi
    service $MYSQLNAME stop
    if [ $? != 0 ] && [ "x$OSNAME" = "xcentos" ] ; then
        service $MYSQLNAME stop
    fi

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
        echoY "MySQL-server not installed."
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
            mysql -uroot -p$ROOTPASSWORD  -e "DELETE FROM mysql.user WHERE User = '$USERNAME@localhost';"
            mysql -uroot -p$ROOTPASSWORD  -e "DROP DATABASE IF EXISTS $DATABASENAME;"
            echoY "Database purged."
        fi
    fi
}

function uninstall_result
{
    if [ "x$ALLERRORS" = "x0" ] ; then
        echoG "Uninstallation finished."
    else
        echoY "Uninstallation finished - some error(s) occured. Please check these as you may need to manually fix them."
    fi
    echo
}


function install_ols
{
    local STATUS=Install
    if [ "x$OLSINSTALLED" = "x1" ] ; then
        OLS_VERSION=$(cat "$SERVER_ROOT"/VERSION)
        wget -O "$SERVER_ROOT"/release.tmp  http://open.litespeedtech.com/packages/release?ver=$OLS_VERSION
        LATEST_VERSION=$(cat "$SERVER_ROOT"/release.tmp)
        rm "$SERVER_ROOT"/release.tmp
        if [ "x$OLS_VERSION" = "x$LATEST_VERSION" ] ; then
            STATUS=Reinstall
            echoY "OpenLiteSpeed is already installed with the latest version, will attempt to reinstall it."
        else
            STATUS=Update
            echoY "OpenLiteSpeed is already installed and newer version is available, will attempt to update it."
        fi
    fi

    if [ "x$OSNAME" = "xcentos" ] ; then
        echo "$STATUS on Centos"
        install_ols_centos $STATUS
    else
        echo "$STATUS on Debian/Ubuntu"
        install_ols_debian $STATUS
    fi
}


function gen_selfsigned_cert
{
    # source outside config file
    if [ -e $CONFFILE ] ; then
        source $CONFFILE 2>/dev/null
        if [ $? != 0 ]; then
            . $CONFFILE
        fi
    fi

    # set default value
    if [ "${SSL_COUNTRY}" = "" ] ; then
        SSL_COUNTRY=US
    fi

    if [ "${SSL_STATE}" = "" ] ; then
        SSL_STATE="New Jersey"
    fi

    if [ "${SSL_LOCALITY}" = "" ] ; then
        SSL_LOCALITY=Virtual
    fi

    if [ "${SSL_ORG}" = "" ] ; then
        SSL_ORG=LiteSpeedCommunity
    fi

    if [ "${SSL_ORGUNIT}" = "" ] ; then
        SSL_ORGUNIT=Testing
    fi

    if [ "${SSL_HOSTNAME}" = "" ] ; then
        SSL_HOSTNAME=webadmin
    fi

    if [ "${SSL_EMAIL}" = "" ] ; then
        SSL_EMAIL=.
    fi

cat > /tmp/req.cnf <<EOF
[req]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt = no
[req_distinguished_name]
C = ${SSL_COUNTRY}
ST = ${SSL_STATE}
L = ${SSL_LOCALITY}
O = ${SSL_ORG}
OU = ${SSL_ORGUNIT}
CN = ${SSL_HOSTNAME}
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${SSL_HOSTNAME}
DNS.2 = *.${SSL_HOSTNAME}
EOF

cat > /tmp/v3ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${SSL_HOSTNAME}
DNS.2 = *.${SSL_HOSTNAME}
EOF

echo
cat /tmp/req.cnf
echo
cat /tmp/v3ext.cnf


# Create the certificate signing request
echo "openssl req -new -newkey rsa:2048 -sha256 -nodes -out ${CSR} -keyout ${KEY} -config /tmp/req.cnf"
openssl req -new -newkey rsa:2048 -sha256 -nodes -out ${CSR} -keyout ${KEY} -config /tmp/req.cnf
echo "openssl req -noout -text -in ${CSR} | grep DNS"
openssl req -noout -text -in ${CSR} | grep DNS
echo "openssl x509 -req -days 36500 -sha256 -in ${CSR} -signkey ${KEY} -out ${CERT} -extfile /tmp/v3ext.cnf"
openssl x509 -req -days 36500 -sha256 -in ${CSR} -signkey ${KEY} -out ${CERT} -extfile /tmp/v3ext.cnf

rm -f /tmp/req.cnf
rm -f /tmp/v3ext.cnf

# self-signed ssl cert with SANs
cat > /tmp/req.cnf <<EOF
[req]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt = no
[req_distinguished_name]
C = ${SSL_COUNTRY}
ST = ${SSL_STATE}
L = ${SSL_LOCALITY}
O = ${SSL_ORG}
OU = ${SSL_ORGUNIT}
CN = ${SSL_HOSTNAME}
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${SSL_HOSTNAME}
DNS.2 = *.${SSL_HOSTNAME}
EOF

cat > /tmp/v3ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${SSL_HOSTNAME}
DNS.2 = *.${SSL_HOSTNAME}
EOF
    
    cd "$CERTDIR"
    curve=prime256v1
    echo "openssl ecparam -out ${KEY}.ecc -name $curve -genkey"
    openssl ecparam -out ${KEY}.ecc -name $curve -genkey
    echo "openssl req -new -sha256 -key ${KEY}.ecc -nodes -out ${CSR}.ecc -config /tmp/req.cnf"
    openssl req -new -sha256 -key ${KEY}.ecc -nodes -out ${CSR}.ecc -config /tmp/req.cnf
    openssl req -noout -text -in ${CSR}.ecc | grep DNS
    echo "openssl x509 -req -days 36500 -sha256 -in ${CSR}.ecc -signkey ${KEY}.ecc -out ${CERT}.ecc -extfile /tmp/v3ext.cnf"
    openssl x509 -req -days 36500 -sha256 -in ${CSR}.ecc -signkey ${KEY}.ecc -out ${CERT}.ecc -extfile /tmp/v3ext.cnf

    rm -f /tmp/req.cnf
    rm -f /tmp/v3ext.cnf

    \cp -f ${KEY}   $SERVER_ROOT/conf/${KEY}.rsa
    \cp -f ${CERT}  $SERVER_ROOT/conf/${CERT}.rsa
    mv -f ${KEY}   $SERVER_ROOT/conf/${KEY}
    mv -f ${CERT}  $SERVER_ROOT/conf/${CERT}
    chmod 0600 $SERVER_ROOT/conf/${KEY}.rsa
    chmod 0600 $SERVER_ROOT/conf/${CERT}.rsa
    chmod 0600 $SERVER_ROOT/conf/${KEY}
    chmod 0600 $SERVER_ROOT/conf/${CERT}

    \cp -f ${KEY}.ecc   $SERVER_ROOT/conf/${KEY}.ecc
    \cp -f ${CERT}.ecc  $SERVER_ROOT/conf/${CERT}.ecc
    chmod 0600 $SERVER_ROOT/conf/${KEY}.ecc
    chmod 0600 $SERVER_ROOT/conf/${CERT}.ecc

    echo
    openssl x509 -noout -text < "$SERVER_ROOT/conf/${CERT}"
    echo
    openssl x509 -noout -text < "$SERVER_ROOT/conf/${CERT}.ecc"
    echo
}


function set_ols_password
{
    #setup password
    ENCRYPT_PASS=`"$SERVER_ROOT/admin/fcgi-bin/admin_php" -q "$SERVER_ROOT/admin/misc/htpasswd.php" $ADMINPASSWORD`
    if [ $? = 0 ] ; then
        echo "admin:$ENCRYPT_PASS" > "$SERVER_ROOT/admin/conf/htpasswd"
        if [ $? = 0 ] ; then
            echoY "Finished setting OpenLiteSpeed WebAdmin password to $ADMINPASSWORD."
            echoY "Finished updating server configuration."

        else
            echoY "OpenLiteSpeed WebAdmin password not changed."
        fi
    fi

}




function config_server
{
    if [ -e "$SERVER_ROOT/conf/httpd_config.conf" ] ; then
        sed -i -e "s/adminEmails/adminEmails $EMAIL\n#adminEmails/" "$SERVER_ROOT/conf/httpd_config.conf"
        sed -i -e "s/8088/$WPPORT/" "$SERVER_ROOT/conf/httpd_config.conf"
        sed -i -e "s/ls_enabled/ls_enabled   1\n#/" "$SERVER_ROOT/conf/httpd_config.conf"

        cat >> $SERVER_ROOT/conf/httpd_config.conf <<END

listener Defaultssl {
address                 *:$SSLWPPORT
secure                  1
map                     Example *
keyFile                 $SERVER_ROOT/conf/$KEY
certFile                $SERVER_ROOT/conf/$CERT
}

END
        chown -R lsadm:lsadm $SERVER_ROOT/conf/
    else
        echoR "$SERVER_ROOT/conf/httpd_config.conf is missing. It appears that something went wrong during OpenLiteSpeed installation."
        ALLERRORS=1
    fi
}


function config_server_wp
{
    if [ -e "$SERVER_ROOT/conf/httpd_config.conf" ] ; then
        cat $SERVER_ROOT/conf/httpd_config.conf | grep "virtualhost wordpress" >/dev/null
        if [ $? != 0 ] ; then
            sed -i -e "s/adminEmails/adminEmails $EMAIL\n#adminEmails/" "$SERVER_ROOT/conf/httpd_config.conf"
            sed -i -e "s/ls_enabled/ls_enabled   1\n#/" "$SERVER_ROOT/conf/httpd_config.conf"

            VHOSTCONF=$SERVER_ROOT/conf/vhosts/wordpress/vhconf.conf

            cat >> $SERVER_ROOT/conf/httpd_config.conf <<END

virtualhost wordpress {
vhRoot                  $WORDPRESSPATH
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


listener wordpressssl {
address                 *:$SSLWPPORT
secure                  1
map                     wordpress $SITEDOMAIN
keyFile                 $SERVER_ROOT/conf/$KEY
certFile                $SERVER_ROOT/conf/$CERT
}

listener wordpressssl_ecdsa {
address                 *:$((SSLWPPORT+1))
secure                  1
map                     wordpress $SITEDOMAIN
keyFile                 $SERVER_ROOT/conf/${KEY}.ecc
certFile                $SERVER_ROOT/conf/${CERT}.ecc
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
    rewriteFile           $WORDPRESSPATH/.htaccess

  }
}

END
            chown -R lsadm:lsadm $SERVER_ROOT/conf/
        fi


    else
        echoR "$SERVER_ROOT/conf/httpd_config.conf is missing. It appears that something went wrong during OpenLiteSpeed installation."
        ALLERRORS=1
    fi
}


function activate_cache
{
    cat > $WORDPRESSPATH/activate_cache.php <<END
<?php
include '$WORDPRESSPATH/wp-load.php';
include_once '$WORDPRESSPATH/wp-admin/includes/plugin.php';
include_once '$WORDPRESSPATH/wp-admin/includes/file.php';
define('WP_ADMIN', true);
activate_plugin('litespeed-cache/litespeed-cache.php', '', false, false);

END
    $SERVER_ROOT/fcgi-bin/lsphp5 $WORDPRESSPATH/activate_cache.php
    rm $WORDPRESSPATH/activate_cache.php
}


function getCurStatus
{
    if [ -e $SERVER_ROOT/bin/openlitespeed ] ; then
        OLSINSTALLED=1
    else
        OLSINSTALLED=0
    fi

    which mysqladmin  >/dev/null 2>&1
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
    echoY "Finished setting OpenLiteSpeed WebAdmin password to $ADMINPASSWORD."
}


function uninstall
{
    if [ "x$OLSINSTALLED" = "x1" ] ; then
        echoY "Uninstalling ..."
        $SERVER_ROOT/bin/lswsctrl stop
        if [ "x$OSNAME" = "xcentos" ] ; then
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

function read_password
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


function check_value_follow
{
    FOLLOWPARAM=$1
    local PARAM=$1
    local KEYWORD=$2

    #test if first letter is - or not.
    if [ "x$1" = "x-n" ] || [ "x$1" = "x-e" ] || [ "x$1" = "x-E" ] ; then
        FOLLOWPARAM=
    else
        local PARAMCHAR=`echo $1 | awk '{print substr($0,1,1)}'`
        if [ "x$PARAMCHAR" = "x-" ] ; then
            FOLLOWPARAM=
        fi
    fi

    if [ "x$FOLLOWPARAM" = "x" ] ; then
        if [ "x$KEYWORD" != "x" ] ; then
            echoR "Error: '$PARAM' is not a valid '$KEYWORD', please check and try again."
            usage
            exit 1
        fi
    fi
}


function fixLangTypo
{
    #Now change type for chinese
    LANGSTR=`echo "$WPLANGUAGE" | awk '{print tolower($0)}'`
    if [ "x$LANGSTR" = "xzh_cn" ] || [ "x$LANGSTR" = "xzh-cn" ] || [ "x$LANGSTR" = "xcn" ] ; then
        WPLANGUAGE=zh_CN
    fi

    if [ "x$LANGSTR" = "xzh_tw" ] || [ "x$LANGSTR" = "xzh-tw" ] || [ "x$LANGSTR" = "xtw" ] ; then
        WPLANGUAGE=zh_TW
    fi

}

function updatemyself
{
    local CURMD=`md5sum "$0" | cut -d' ' -f1`
    local SERVERMD=`md5sum  <(wget $MYGITHUBURL -O- 2>/dev/null)  | cut -d' ' -f1`
    if [ "x$CURMD" = "x$SERVERMD" ] ; then
        echoG "You already have the latest version installed."
    else
        wget -O "$0" $MYGITHUBURL
        CURMD=`md5sum "$0" | cut -d' ' -f1`
        if [ "x$CURMD" = "x$SERVERMD" ] ; then
            echoG "Updated."
        else
            echoG "Tried to update but seems to be failed."
        fi
    fi
}

function usage
{
    echoY "USAGE:                             " "$0 [options] [options] ..."
    echoY "OPTIONS                            "
    echoG " --adminpassword(-a) [PASSWORD]    " "To set the WebAdmin password for OpenLiteSpeed instead of using a random one."
    echoG "                                   " "If you omit [PASSWORD], ols1clk will prompt you to provide this password during installation."
    echoG " --email(-e) EMAIL                 " "To set the administrator email."
    echoG " --lsphp VERSION                   " "To set the LSPHP version, such as 56. We currently support versions '${LSPHPVERLIST[@]}'."
    echoG " --mariadbver VERSION              " "To set MariaDB version, such as 10.3. We currently support versions '${MARIADBVERLIST[@]}'."
    echoG " --wordpress(-w)                   " "To install and setup WordPress. You will still need to access the /wp-admin/wp-config.php"
    echoG "                                   " "file by browser to complete WordPress installation."
    echoG " --wordpressplus SITEDOMAIN        " "To install, setup, and configure WordPress, eliminating the need to use the wp-config.php setup."
    echoG " --wordpresspath WORDPRESSPATH     " "To specify a location for the new WordPress installation or use an existing WordPress installation."

    echoG " --dbrootpassword(-r) [PASSWORD]   " "To set the database root password instead of using a random one."
    echoG "                                   " "If you omit [PASSWORD], ols1clk will prompt you to provide this password during installation."
    echoG " --dbname DATABASENAME             " "To set the database name to be used by WordPress."
    echoG " --dbuser DBUSERNAME               " "To set the WordPress username in the database."
    echoG " --dbpassword [PASSWORD]           " "To set the WordPress table password in MySQL instead of using a random one."
    echoG "                                   " "If you omit [PASSWORD], ols1clk will prompt you to provide this password during installation."
    echoG " --listenport LISTENPORT           " "To set the HTTP server listener port, default is 80."
    echoG " --ssllistenport LISTENPORT        " "To set the HTTPS server listener port, default is 443."

    echoG " --wpuser WORDPRESSUSER            " "To set the WordPress admin user for WordPress dashboard login. Default value is wpuser."
    echoG " --wppassword [PASSWORD]           " "To set the WordPress admin user password for WordPress dashboard login."
    echoG "                                   " "If you omit [PASSWORD], ols1clk will prompt you to provide this password during installation."
    echoG " --wplang WORDPRESSLANGUAGE        " "To set the WordPress language. Default value is \"en\" for English."
    echoG " --sitetitle WORDPRESSSITETITLE    " "To set the WordPress site title. Default value is mySite."

    echoG " --uninstall                       " "To uninstall OpenLiteSpeed and remove installation directory."
    echoG " --purgeall                        " "To uninstall OpenLiteSpeed, remove installation directory, and purge all data in MySQL."
    echoG " --quiet                           " "Set to quiet mode, won't prompt to input anything."

    echoG " --version(-v)                     " "To display version information."
    echoG " --update                          " "To update ols1clk from github."
    echoG " --help(-h)                        " "To display usage."
    echo
    echoY "EXAMPLES                           "
    echoG "./ols1clk.sh                       " "To install the latest version of OpenLiteSpeed with a random WebAdmin password."
    echoG "./ols1clk.sh --lsphp 72            " "To install the latest version of OpenLiteSpeed with lsphp72."
    echoG "./ols1clk.sh -a 123456 -e a@cc.com " "To install the latest version of OpenLiteSpeed with WebAdmin password  \"123456\" and email a@cc.com."
    echoG "./ols1clk.sh -r 123456 -w          " "To install OpenLiteSpeed with WordPress and MySQL root password \"123456\"."
    echoG "./ols1clk.sh -a 123 -r 1234 --wordpressplus a.com"  ""
    echo  "                                   To install OpenLiteSpeed with a fully configured WordPress installation at \"a.com\" using WebAdmin password \"123\" and MySQL root password \"1234\"."
    echoG "./ols1clk.sh -a 123 -r 1234 --wplang zh_CN --sitetitle mySite --wordpressplus a.com"  ""
    echo  "                                   To install OpenLiteSpeed with a fully configured Chinese (China) language WordPress installation at \"a.com\" using WebAdmin password \"123\",  MySQL root password \"1234\", and WordPress site title \"mySite\"."
    echo

}

function uninstall_warn
{
    if [ "x$FORCEYES" != "x1" ] ; then
        echo
        printf "\033[31mAre you sure you want to uninstall? Type 'Y' to continue, otherwise will quit.[y/N]\033[0m "
        read answer
        echo

        if [ "x$answer" != "xY" ] && [ "x$answer" != "xy" ] ; then
            echoG "Uninstallation aborted!"
            exit 0
        fi
        echo
    fi
}

function test_page
{
    local URL=$1
    local KEYWORD=$2
    local PAGENAME=$3

    rm -rf tmp.tmp
    wget --no-check-certificate -O tmp.tmp  $URL >/dev/null 2>&1
    grep "$KEYWORD" tmp.tmp  >/dev/null 2>&1

    if [ $? != 0 ] ; then
        echoR "Error: $PAGENAME failed."
        TESTGETERROR=yes
    else
        echoG "OK: $PAGENAME passed."
    fi
    rm tmp.tmp
}


function test_ols_admin
{
    test_page https://localhost:7080/ "LiteSpeed WebAdmin" "test webAdmin page"
}

function test_ols
{
    test_page http://localhost:$WPPORT/  Congratulation "test Example HTTP vhost page"
    test_page https://localhost:$SSLWPPORT/  Congratulation "test Example HTTPS vhost page"
}

function test_wordpress
{
    test_page http://localhost:8088/  Congratulation "test Example vhost page"
    test_page http://localhost:$WPPORT/ "data-continue" "test wordpress HTTP first page"
    test_page https://localhost:$SSLWPPORT/ "data-continue" "test wordpress HTTPS first page"
}

function test_wordpress_plus
{
    test_page http://localhost:8088/  Congratulation "test Example vhost page"
    test_page http://$SITEDOMAIN:$WPPORT/ hello-world "test wordpress HTTP first page"
    test_page https://$SITEDOMAIN:$SSLWPPORT/ hello-world "test wordpress HTTPS first page"
}

installwpcli() {
    mkdir -p $WPCLIDIR
    if [ ! -f /usr/bin/git ]; then
        yum -q -y install git
    fi
    if [[ ! -f /usr/bin/wp ]]; then
        echo ""
        if [ -s /usr/bin/wp ]; then
            echo "/usr/bin/wp [found]"
        else
            echo "Error: /usr/bin/wp not found !!! Downloading now......"
            wget -4cnv --no-check-certificate $WPCLILINK -O /usr/bin/wp --tries=3 
            ERROR=$?
            if [[ "$ERROR" != '0' ]]; then
                echo "Error: /usr/bin/wp download failed."
                exit 1
            else 
                echo "Download done."
            fi
        fi
        if [ -f /usr/bin/wp ]; then
            chmod 0700 /usr/bin/wp
        fi
        echo ""
        if [ -s "${WPCLIDIR}/wp-completion.bash" ]; then
            echo "${WPCLIDIR}/wp-completion.bash [found]"
        else
            echo "Error: ${WPCLIDIR}/wp-completion.bash not found !!! Downloading now......"
            wget -4cnv --no-check-certificate https://github.com/wp-cli/wp-cli/raw/master/utils/wp-completion.bash -O ${WPCLIDIR}/wp-completion.bash --tries=3 
            ERROR=$?
            if [[ "$ERROR" != '0' ]]; then
                echo "Error: ${WPCLIDIR}/wp-completion.bash download failed."
                exit $ERROR
            else 
                echo "Download done."
            fi
        fi
        echo ""
        WPCLICHECK=$(grep 'WP-CLI' /root/.bash_profile)
        if [[ "$(id -u)" -ne '0' ]]; then
            WPCLICHECK=$(grep 'WP-CLI' $HOME/.bash_profile)
        fi
        if [[ -z "$WPCLICHECK" ]]; then
            echo ""
            echo "" >> /root/.bash_profile
            #echo "# Composer scripts" >> /root/.bash_profile
            #echo "PATH=$HOME/.wp-cli/bin:$PATH" >> /root/.bash_profile
            #echo "" >> /root/.bash_profile
            echo "# WP-CLI completions" >> /root/.bash_profile
            echo "source ${WPCLIDIR}/wp-completion.bash" >> /root/.bash_profile
            if [[ "$(id -u)" -ne '0' ]]; then
                echo ""
                echo "" >> $HOME/.bash_profile
                echo "# WP-CLI completions" >> $HOME/.bash_profile
                echo "source ${WPCLIDIR}/wp-completion.bash" >> $HOME/.bash_profile
            fi
        fi
        WPALIASCHECK=$(grep 'allow-root' /root/.bashrc)
        if [[ "$(id -u)" -ne '0' ]]; then
            WPALIASCHECK=$(grep 'allow-root' $HOME/.bashrc)
        fi
        if [[ -z "$WPALIASCHECK" ]]; then
            echo "alias wp='wp --allow-root'" >> /root/.bashrc
            if [[ "$(id -u)" -ne '0' ]]; then
                echo "alias wp='wp --allow-root'" >> $HOME/.bashrc
            fi
        fi
        echo "-------------------------------------------------------------"
        echo "wp-cli info"
        /usr/bin/wp --info --allow-root
        echo "-------------------------------------------------------------"
        
        echo ""
        echo "-------------------------------------------------------------"
        echo "wp-cli install completed"
        echo "Read http://wp-cli.org/ for full usage info"
    fi
}


#####################################################################################
####   Main function here
#####################################################################################
display_license

while [ "$1" != "" ] ; do
    case $1 in
        -a | --adminpassword )      check_value_follow "$2" ""
                                    if [ "x$FOLLOWPARAM" != "x" ] ; then
                                        shift
                                    fi
                                    ADMINPASSWORD=$FOLLOWPARAM
                                    ;;

        -e | --email )              check_value_follow "$2" "email address"
                                    shift
                                    EMAIL=$FOLLOWPARAM
                                    ;;

             --lsphp )              check_value_follow "$2" "LSPHP version"
                                    shift
                                    cnt=${#LSPHPVERLIST[@]}
                                    for (( i = 0 ; i < cnt ; i++ ))
                                    do
                                        if [ "x$1" = "x${LSPHPVERLIST[$i]}" ] ; then
                                            LSPHPVER=$1
                                            USEDEFAULTLSPHP=0
                                        fi
                                    done
                                    ;;

             --mariadbver )         check_value_follow "$2" "MariaDB version"
                                    shift
                                    cnt=${#MARIADBVERLIST[@]}
                                    for (( i = 0 ; i < cnt ; i++ ))
                                    do
                                        if [ "x$1" = "x${MARIADBVERLIST[$i]}" ] ; then
                                            MARIADBVER=$1
                                            USEDEFAULTLSMARIADB=0
                                        fi
                                    done
                                    ;;

        -w | --wordpress )          INSTALLWORDPRESS=1
                                    ;;

             --wordpressplus )      check_value_follow "$2" "domain"
                                    shift
                                    SITEDOMAIN=$FOLLOWPARAM
                                    INSTALLWORDPRESS=1
                                    INSTALLWORDPRESSPLUS=1
                                    ;;

             --wordpresspath )      check_value_follow "$2" "WordPress path"
                                    shift
                                    WORDPRESSPATH=$FOLLOWPARAM
                                    INSTALLWORDPRESS=1
                                    ;;

        -r | --dbrootpassword )     check_value_follow "$2" ""
                                    if [ "x$FOLLOWPARAM" != "x" ] ; then
                                        shift
                                    fi
                                    ROOTPASSWORD=$FOLLOWPARAM
                                    ;;

             --dbname )             check_value_follow "$2" "database name"
                                    shift
                                    DATABASENAME=$FOLLOWPARAM
                                    ;;
             --dbuser )             check_value_follow "$2" "database username"
                                    shift
                                    USERNAME=$FOLLOWPARAM
                                    ;;
             --dbpassword )         check_value_follow "$2" ""
                                    if [ "x$FOLLOWPARAM" != "x" ] ; then
                                        shift
                                    fi
                                    USERPASSWORD=$FOLLOWPARAM
                                    ;;

             --listenport )         check_value_follow "$2" "HTTP listen port"
                                    shift
                                    WPPORT=$FOLLOWPARAM
                                    ;;
             --ssllistenport )      check_value_follow "$2" "HTTPS listen port"
                                    shift
                                    SSLWPPORT=$FOLLOWPARAM
                                    ;;

             --wpuser )             check_value_follow "$2" "WordPress user"
                                    shift
                                    WPUSER=$1
                                    ;;

             --wppassword )         check_value_follow "$2" ""
                                    if [ "x$FOLLOWPARAM" != "x" ] ; then
                                        shift
                                    fi
                                    WPPASSWORD=$FOLLOWPARAM
                                    ;;

             --wplang )             check_value_follow "$2" "WordPress language"
                                    shift
                                    WPLANGUAGE=$FOLLOWPARAM
                                    fixLangTypo
                                    ;;

             --sitetitle )          check_value_follow "$2" "WordPress website title"
                                    shift
                                    WPTITLE=$FOLLOWPARAM
                                    ;;

             --uninstall )          ACTION=UNINSTALL
                                    ;;

             --purgeall )           ACTION=PURGEALL
                                    ;;

             --quiet )              FORCEYES=1
                                    ;;

        -v | --version )            exit 0
                                    ;;

             --update )             updatemyself
                                    exit 0
                                    ;;

        -h | --help )               usage
                                    exit 0
                                    ;;

        * )                         usage
                                    exit 0
                                    ;;
    esac
    shift
done


check_root
check_os
getCurStatus
#test if have $SERVER_ROOT , and backup it

if [ "x$ACTION" = "xUNINSTALL" ] ; then
    uninstall_warn
    uninstall
    uninstall_result
    exit 0
fi

if [ "x$ACTION" = "xPURGEALL" ] ; then
    uninstall_warn

    if [ "x$ROOTPASSWORD" = "x" ] ; then
        passwd=
        echoY "Please input the MySQL root password: "
        read passwd
        ROOTPASSWORD=$passwd
    fi

    uninstall
    purgedatabase
    uninstall_result
    exit 0
fi

if [ "x$OSNAMEVER" = "xUBUNTU18" ] || [ "x$OSNAMEVER" = "xDEBIAN9" ] ; then
    if [ "x$LSPHPVER" = "x54" ] || [ "x$LSPHPVER" = "x55" ] || [ "x$LSPHPVER" = "x56" ] ; then
       echoY "We do not support lsphp$LSPHPVER on $OSNAMEVER, lsphp71 will be used instead."
       LSPHPVER=71
   fi
fi


if [ "x$EMAIL" = "x" ] ; then
    if [ "x$SITEDOMAIN" = "x*" ] ; then
        EMAIL=root@localhost
    else
        EMAIL=root@$SITEDOMAIN
    fi
fi

read_password "$ADMINPASSWORD" "webAdmin password"
ADMINPASSWORD=$TEMPPASSWORD


if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
    read_password "$ROOTPASSWORD" "MySQL root password"
    ROOTPASSWORD=$TEMPPASSWORD
    read_password "$USERPASSWORD" "MySQL user password"
    USERPASSWORD=$TEMPPASSWORD
fi

if [ "x$INSTALLWORDPRESSPLUS" = "x1" ] ; then
    read_password "$WPPASSWORD" "WordPress admin password"
    WPPASSWORD=$TEMPPASSWORD
fi


if [ "x$USEDEFAULTLSPHP" = "x1" ] ; then
    if [ "x$INSTALLWORDPRESS" = "x1" ] && [ -e "$WORDPRESSPATH/wp-config.php" ] ; then
        #For existing wordpress, choose lsphp56 as default
        LSPHPVER=56
    fi
fi

if [ "x$USEDEFAULTLSMARIADB" = "x1" ] ; then
    if [ "x$INSTALLWORDPRESS" = "x1" ] && [ -e "$WORDPRESSPATH/wp-config.php" ] ; then
        #For existing wordpress, choose MariaDB10.1 as default
        MARIADBVER=10.1
    fi
fi

echo
echoR "Starting to install OpenLiteSpeed to $SERVER_ROOT/ with the parameters below,"
echoY "WebAdmin password:        " "$ADMINPASSWORD"
echoY "WebAdmin email:           " "$EMAIL"
echoY "LSPHP version:            " "$LSPHPVER"
echoY "MariaDB version:          " "$MARIADBVER"


WORDPRESSINSTALLED=
if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
    echoY "Install WordPress:        " Yes
    echoY "Permalinks Structure: " "/%post_id%/%postname%/"
    echoY "WordPress .htaccess: " "$WORDPRESSPATH/.htaccess"
    echoY "WordPress HTTP port:      " "$WPPORT"
    if [ -f "$SERVER_ROOT/conf/${CERT}.ecc" ]; then
        echoY "WordPress RSA 2048 bit HTTPS port:     " "$SSLWPPORT"
        echoY "WordPress RSA 2048 bit HTTPS cert: " "$SERVER_ROOT/conf/$CERT"
        echoY "WordPress ECDSA 256bit HTTPS port:     " "$((SSLWPPORT+1))"
        echoY "WordPress ECDSA 256bit HTTPS cert: " "$SERVER_ROOT/conf/${CERT}.ecc"
    else
        echoY "WordPress HTTPS port:     " "$SSLWPPORT"
    fi
    echoY "Web site domain:          " "$SITEDOMAIN"
    echoY "MySQL root Password:      " "$ROOTPASSWORD"
    echoY "Database name:            " "$DATABASENAME"
    echoY "Database username:        " "$USERNAME"
    echoY "Database password:        " "$USERPASSWORD"

    if [ "x$INSTALLWORDPRESSPLUS" = "x1" ] ; then
        echoY "WordPress plus:           " Yes
        echoY "WordPress language:       " "$WPLANGUAGE"
        echoY "WordPress site title:     " "$WPTITLE"
        echoY "WordPress username:       " "$WPUSER"
        echoY "WordPress password:       " "$WPPASSWORD"
    else
        echoY "WordPress plus:           " No
    fi


    if [ -e "$WORDPRESSPATH/wp-config.php" ] ; then
        echoY "WordPress location:       " "$WORDPRESSPATH (Exsiting)"
        WORDPRESSINSTALLED=1
    else
        echoY "WordPress location:       " "$WORDPRESSPATH (New install)"
        WORDPRESSINSTALLED=0
    fi
else
    echoY "Server HTTP port:         " "$WPPORT"
    echoY "Server HTTPS port:        " "$SSLWPPORT"
fi

echo

if [ "x$FORCEYES" != "x1" ] ; then
    printf '\033[31mAre these settings correct? Type n to quit, otherwise will continue.[Y/n]\033[0m '
    read answer
    echo

    if [ "x$answer" = "xN" ] || [ "x$answer" = "xn" ] ; then
        echoG "Aborting installation!"
        exit 0
    fi
    echo
fi


####begin here#####
update_centos_hashlib
check_wget
install_ols

#write the password file for record and remove the previous file.
echo "WebAdmin username is [admin], password is [$ADMINPASSWORD]." > $SERVER_ROOT/password


set_ols_password
gen_selfsigned_cert

if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
    if [ "x$MYSQLINSTALLED" != "x1" ] ; then
        if [[ "$MYSQLINSTALL" = [yY] ]]; then
            install_mysql
        else
            echo "skip install_mysql"
        fi
    else
        test_mysql_password
    fi

    if [ "x$WORDPRESSINSTALLED" != "x1" ] ; then
        install_wordpress
        setup_wordpress

        if [ "x$TESTPASSWORDERROR" = "x1" ] ; then
            echoY "MySQL setup bypassed, can not get root password."
        else
            ROOTPASSWORD=$CURROOTPASSWORD
            setup_mysql
        fi
    fi

    config_server_wp
    echo "mysql root password is [$ROOTPASSWORD]." >> $SERVER_ROOT/password
else
    #normal ols installation without wordpress
    config_server

fi

if [ "x$WPPORT" = "x80" ] ; then
    echoY "Trying to stop some web servers that may be using port 80."
        killall -9 apache  >/dev/null 2>&1
    killall -9 apache2  >/dev/null 2>&1
    killall -9 httpd    >/dev/null 2>&1
    killall -9 nginx    >/dev/null 2>&1
fi

echo ols1clk > "$SERVER_ROOT/PLAT"
$SERVER_ROOT/bin/lswsctrl stop >/dev/null 2>&1
$SERVER_ROOT/bin/lswsctrl start


if [ "x$INSTALLWORDPRESSPLUS" = "x1" ] ; then
    if [ "x$WPPORT" != "x80" ] ; then
        INSTALLURL=http://$SITEDOMAIN:$WPPORT/wp-admin/install.php
    else
        INSTALLURL=http://$SITEDOMAIN/wp-admin/install.php
    fi

    wget $INSTALLURL >/dev/null 2>&1
    sleep 5

    #echo "wget --post-data 'language=$WPLANGUAGE' --referer=$INSTALLURL $INSTALLURL?step=1"
    wget --no-check-certificate --post-data "language=$WPLANGUAGE" --referer=$INSTALLURL $INSTALLURL?step=1 >/dev/null 2>&1
    sleep 1

    #echo "wget --post-data 'weblog_title=$WPTITLE&user_name=$WPUSER&admin_password=$WPPASSWORD&pass1-text=$WPPASSWORD&admin_password2=$WPPASSWORD&pw_weak=on&admin_email=$EMAIL&Submit=Install+WordPress&language=$WPLANGUAGE' --referer=$INSTALLURL?step=1 $INSTALLURL?step=2 "
    wget --no-check-certificate --post-data "weblog_title=$WPTITLE&user_name=$WPUSER&admin_password=$WPPASSWORD&pass1-text=$WPPASSWORD&admin_password2=$WPPASSWORD&pw_weak=on&admin_email=$EMAIL&Submit=Install+WordPress&language=$WPLANGUAGE" --referer=$INSTALLURL?step=1 $INSTALLURL?step=2  >/dev/null 2>&1

    activate_cache
    echo "WordPress administrator username is [$WPUSER], password is [$WPPASSWORD]." >> $SERVER_ROOT/password
fi

chmod 600 "$SERVER_ROOT/password"
echoY "Please be aware that your password was written to file '$SERVER_ROOT/password'."

if [ "x$ALLERRORS" = "x0" ] ; then
    echoY "------------------------------------------------------------------------------"
    echoG "Congratulations! Installation finished."
    echoY "------------------------------------------------------------------------------"
    echoG "Server Config file at $SERVER_ROOT/conf/httpd_config.conf"
    echoG "PHP php.ini file at /usr/local/lsws/php/php.ini"
    echoG "PHP Config Scan Dir at /usr/local/lsws/lsphp$LSPHPVER/etc/php.d/"
    echoG "Please access http://localhost:$ADMINPORT/ for admin console with password = $ADMINPASSWORD."
    if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
        echoG "Wordpress site vhost file at $VHOSTCONF"
        echoG "Wordpress web root at ${WORDPRESSPATH}"
        echoG "Wordpress $DATABASENAME with username: $USERNAME password: $USERPASSWORD"
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
    echo "/usr/local/lsws/lsphp${LSPHPVER}/bin/php -v"
    /usr/local/lsws/lsphp${LSPHPVER}/bin/php -v

    echo
    echoG "MariaDB Installed:"
    $(which rpm) -qa | grep -i MariaDB

    echo
else
    echoY "Installation finished. Some errors seem to have occured, please check this as you may need to manually fix them."
fi  

if [ "x$INSTALLWORDPRESSPLUS" = "x0" ] && [ "x$INSTALLWORDPRESS" = "x1" ] ; then
    echoG "Please access http://localhost:$WPPORT/ to finish setting up your WordPress site."
    echoG "And also you may want to activate the LiteSpeed Cache plugin to get better performance."
fi

echo
echoY "Testing ..."
test_ols_admin
if [ "x$INSTALLWORDPRESS" = "x1" ] ; then
    if [ "x$INSTALLWORDPRESSPLUS" = "x1" ] ; then
        test_wordpress_plus
    else
        test_wordpress
    fi
else
    test_ols
fi

if [ "x${TESTGETERROR}" = "xyes" ] ; then
    echoG "Errors were encountered during testing. In many cases these errors can be solved manually by referring to installation logs."
    echoG "Service loading issues can sometimes be resolved by performing a restart of the web server."
    echoG "Reinstalling the web server can also help if neither of the above approaches resolve the issue."
fi

echo
echoG "If you run into any problems, they can sometimes be fixed by running with the --purgeall flag and reinstalling."
echoG "If you have an existing certificate and private key for your site, you will need to replace the $KEY and $CERT in $SERVER_ROOT/conf with these files."
echoG 'Thanks for using "OpenLiteSpeed One click installation".'
echoG "Enjoy!"
echo
echo
