# LAMP from souce on debian

The script builds from source, tests and deploys the LAMP stack on a Debian machine. All installed packages are placed in /opt/ <br>
To run: `sudo bash lamp_install <apache_ver> <mariadb_ver> <php_ver>`

### Features:
- The version of Apache, MariaDB and PHP can be selected when running the script. Each of them is verified before running the script.
- The following are built from source: Apache, MariaDB, PHP, APR, APR-util, PCRE, expat.
- Apache, MariaDB, PHP are all tested by actually running them, not only by checking the version with `-v`.
- Tests if Apache and PHP are able to communicate with each other.
- Cleans up after itself, no extra files will be left over.
- Exits as soon as there is an issue with any of the packages without needlessly continuing on.
- No user input is needed at any point, can be left to run without monitoring.
