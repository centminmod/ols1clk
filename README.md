# ols1clk
========

Description
--------

ols1clk is a one-click installation script for OpenLiteSpeed. Using this script,
you can quickly and easily install OpenLiteSpeed with it’s default settings. We
also provide a **-w** parameter that will install WordPress at the same time but
it must still be configured through the wp-config.php page. A MariaDB database
can also be set up using this script if needed. If you already have a WordPress
installation running on another server, it can be imported into OpenLiteSpeed
with no hassle using the **--wordpresspath** parameter. To completely install
WordPress with your OpenLiteSpeed installation, skipping the need for the
wp-config.php page, use the **--wordpressplus** flag. This can be used with
**--wpuser**, **--wppassword**, **--wplang**, and **--sitetitle** to configure
each of the settings normally set by wp-config.php.

Installing forked [centminmod](https://github.com/centminmod/ols1clk/tree/centminmod) branch for CentOS changes only; 
--------

Forked branch has following changes for CentOS 6 or CentOS 7 only ported from my [Centmin Mod LEMP Project](https://centminmod.com):

* uses default MariaDB 10.3 installed by Centmin Mod already so skips MySQL server install
* revise the mysql root user password setup (set /root/.my.cnf as well) and remove testing the mysql root user password
* if detected CSF doesn't exit, installs by default CSF Firewall and auto detects if system supports IPSET and installs & configures CSF for IPSET support
* revised the selection of default LSAPI PHP YUM packages installed.
* changes default HTTP listen port to 8080 and default HTTPS listen port to 8443 unless you specify `--listenport` and `--ssllistenport` flags.

Install

    git clone -b centminmod-2019 --depth=1 https://github.com/centminmod/ols1clk
    cd ols1clk
    ./ols1clk.sh -e youremail@domain.com --listenport 81 --ssllistenport 448

Install with PHP 7.x

    git clone -b centminmod-2019 --depth=1 https://github.com/centminmod/ols1clk
    cd ols1clk
    ./ols1clk.sh -e youremail@domain.com --lsphp 73 --listenport 81 --ssllistenport 448

If want to install Wordpress with default HTTP listen port to 8080 and default HTTPS listen port to 8443

    git clone -b centminmod-2019 --depth=1 https://github.com/centminmod/ols1clk
    cd ols1clk
    ./ols1clk.sh -e youremail@domain.com --lsphp 73 -w --dbname WPDATABASENAME --dbuser WPUSERNAME

If want to install Wordpress and HTTP listen on port 81 and HTTPS on port 448 and do manual web GUI install

    git clone -b centminmod-2019 --depth=1 https://github.com/centminmod/ols1clk
    cd ols1clk
    ./ols1clk.sh -e youremail@domain.com --lsphp 73 -w --dbname WPDATABASENAME --dbuser WPUSERNAME --listenport 81 --ssllistenport 448

If want to install Wordpress and HTTP listen on port 81 and HTTPS on port 448 and do automated full install

    git clone -b centminmod-2019 --depth=1 https://github.com/centminmod/ols1clk
    cd ols1clk
    ./ols1clk.sh --wordpressplus wp.domain.com -e youremail@domain.com --lsphp 73 -w --dbname WPDATABASENAME --dbuser WPUSERNAME --listenport 81 --ssllistenport 448

Running ols1clk
--------

ols1clk can be run in the following way:
*./ols1clk.sh [options] [options] …*

When run with no options, ols1clk will install OpenLiteSpeed with the default
settings and values.

####Possible Options:
* **--adminpassword(-a) [PASSWORD]:** To set set the WebAdmin password for OpenLiteSpeed instead of a random one.
  * If you omit **[PASSWORD]**, ols1clk will prompt you to provide this password during installation.
* **--email(-e) EMAIL:** to set the administrator email.
* **--lsphp VERSION:** to set LSPHP version, such as 56. We currently support versions 54, 55, 56, and 70.
* **--mariadbver VERSION:** to set MariaDB server version, such as 10.1. We currently support versions 10.0, 10.1, and 10.2.
* **--wordpress(-w):** to install and setup WordPress. You will still need to access the /wp-admin/wp-config.php file by browser to complete WordPress installation.
* **--wordpressplus SITEDOMAIN:** to install, setup, and configure WordPress, eliminating the need to use the wp-config.php setup. 
* **--wordpresspath WORDPRESSPATH:** to specify a location for the new WordPress installation or use an existing WordPress installation.
* **--dbrootpassword(-r) [PASSWORD]:** to set the MySQL server root password instead of using a random one.
  * If you omit **[PASSWORD]**, ols1clk will prompt you to provide this password during installation.
* **--dbname DATABASENAME:** to set the database name to be used by WordPress.
* **--dbuser DBUSERNAME:** to set the WordPress username in the database.
* **--dbpassword [PASSWORD]:** to set the WordPress table password in MySQL instead of using a random one.
  * If you omit **[PASSWORD]**, ols1clk will prompt you to provide this password during installation.
* **--listenport LISTENPORT:** to set the HTTP server listener port, default is 80.
* **--ssllistenport LISTENPORT:** to set the HTTPS server listener port, default is 443.
* **--wpuser WORDPRESSUSER:** to set the WordPress admin user for WordPress dashboard login. Default value is wpuser.
* **--wppassword [PASSWORD]:** to set the WordPress admin user password for WordPress dashboard login.
  * If you omit **[PASSWORD]**, ols1clk will prompt you to provide this password during installation.
* **--wplang WORDPRESSLANGUAGE:** to set the WordPress language. Default value is "en" for English.
* **--sitetitle WORDPRESSSITETITLE:** To set the WordPress site title. Default value is mySite.
* **--uninstall:** to uninstall OpenLiteSpeed and remove the installation directory.
* **--purgeall:** to uninstall OpenLiteSpeed, remove the installation directory, and purge all data in MySQL.
* **--version(-v):** to display version information.
* **--help(-h):** to display usage.

Get in Touch
--------

OpenLiteSpeed has a [Google Group](https://groups.google.com/forum/#!forum/openlitespeed-development). If you find a bug, want to request new features, or just want to talk about OpenLiteSpeed, this is the place to do it.

