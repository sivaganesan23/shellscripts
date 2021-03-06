#!/bin/bash

## Script purpose is to install both application and web server.
LOG=/tmp/stack.log 
rm -f $LOG
APPUSER=student
APPHOME=/home/$APPUSER
TOMCAT_VER="9.0.13"
TOMCAT_MAJ_VER=$(echo $TOMCAT_VER | cut -d . -f1)
URL="http://mirrors.wuchna.com/apachemirror/tomcat/tomcat-${TOMCAT_MAJ_VER}/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz"
STUDENT_WAR_URL="https://github.com/citb33/project-documentation/raw/master/studentapp.war"

###DB Params
USERNAME=student 
PASSWORD=student1
DBURL=RDS-URL 
DBNAME=studentapp
JDBC_CON_URI='<Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxActive="100" maxIdle="30" maxWait="10000" username="USERNAME" password="PASSWORD" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://DBURL:3306/DBNAME"/>'
INDEX_HTML='<h1 style="text-align: center;"><strong>Welcome to Student Application</strong></h1>
<h1 style="text-align: center;"><strong>ON</strong></h1>
<p><strong><img style="display: block; margin-left: auto; margin-right: auto;" src="https://cdn-images-1.medium.com/max/1200/1*tFl-8wQUENETYLjX5mYWuA.png" alt="Image result for aws" width="478" height="251" /></strong></p>
<p style="text-align: center;"><a href="http://PUBLICIP/studentapp"><strong>Click here for application</strong></a></p>'


USER=$(id -u)
if [ $USER -ne 0 ]; then 
    echo -e "\e[31mYou should be a root user to execute this script\e[0m"
    exit 5
fi

Print() {
    echo -n -e "\e[35m$1 - "
}

Stat() {
    if [ "$1" == SKIP ]; then 
        echo -e "\e[36mSKIPPING\e[0m"
    elif [ $1 -eq 0 ]; then 
        echo -e "\e[32mSUCCESS\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

Print "Installing Java"
yum install java -y &>>$LOG 
Stat $?

id student &>/dev/null  
if [ $? -ne 0 ]; then 
    Print "Adding Application User"
    useradd $APPUSER
    Stat $?
else 
    Print "Adding Application User"
    Stat SKIP
fi

Print "Installing Tomcat"
if [ -d $APPHOME/apache-tomcat-$TOMCAT_VER ]; then 
    Stat SKIP
else 
    cd $APPHOME
    wget -qO- $URL | tar -xz 
fi
rm -rf $APPHOME/apache-tomcat-$TOMCAT_VER/webapps/*
Print "Downloading Student Application"
wget -qO $APPHOME/apache-tomcat-$TOMCAT_VER/webapps/studentapp.war $STUDENT_WAR_URL
Stat $?
chown student:student $APPHOME/apache-tomcat-$TOMCAT_VER -R 

Print "Configuring Tomcat"
sed -i -e '/TestDB/ d' -e "$ i $JDBC_CON_URI" $APPHOME/apache-tomcat-$TOMCAT_VER/conf/context.xml 
sed -i -e "s/USERNAME/$USERNAME/" -e "s/PASSWORD/$PASSWORD/" -e "s/DBURL/$DBURL/" -e "s/DBNAME/$DBNAME/" $APPHOME/apache-tomcat-$TOMCAT_VER/conf/context.xml
wget -q https://raw.githubusercontent.com/citb33/project-documentation/master/tomcat-init-script -O /etc/init.d/tomcat 
chmod +x /etc/init.d/tomcat
Stat $?

Print "Starting Tomcat"
systemctl enable tomcat &>>$LOG 
systemctl start tomcat &>>$LOG 
Stat $?

Print "Installing Web Server"
yum install httpd -y &>>$LOG 
Stat $?

Print "Configuring HTTPD"
PUBLICIP=$(curl -s ifconfig.me)
echo $INDEX_HTML | sed -e "s/PUBLICIP/$PUBLICIP/" >/var/www/html/index.html 
echo 'ProxyPass "/studentapp"  "http://localhost:8080/studentapp"
ProxyPassReverse "/studentapp"  "http://localhost:8080/studentapp"' >/etc/httpd/conf.d/tomcat.conf 
Stat $? 

Print "Starting HTTPD"
systemctl enable httpd &>>$LOG 
systemctl start httpd &>>$LOG 
Stat $?