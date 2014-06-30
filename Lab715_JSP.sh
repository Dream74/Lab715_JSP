#!/bin/bash
# Auto Install Lab715_JSP Server
export JRE_1_7_0=java-1.7.0-openjdk.x86_64
export TOMCAT_7_URL=http://apache.cdpa.nsysu.edu.tw/tomcat/tomcat-7/v7.0.54/bin/apache-tomcat-7.0.54.tar.gz
export MYSQL_JDBC_URL=http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.0.8.tar.gz
export TOMCAT_DIR=/usr/local/src
export TOMCAT_PATH=$TOMCAT_DIR/apache-tomcat-7.0.54
export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.55.x86_64
export BASE_DIR=$(dirname $0)
export SQL_FILE=$BASE_DIR/hello.sql

echo 'Auto Install tomcat, mysql'
echo 'Author:Dream'
# 判斷 java 是否有無安裝 如果沒有安裝 安裝
test -e /usr/bin/java ||  yum install -y java-1.7.0-openjdk.x86_64
test -e /usr/bin/javac ||  yum install -y java-1.7.0-openjdk-devel.x86_64

test -e /usr/bin/java || exit 1

# 新增專門給 tomcat 使用的使用者與群組
useradd tomcat -M -U -s "/sbin/nologin" 2> /dev/null

# 檢查是否有安裝 tomcat 
echo 'install tomcat'
if [ ! -e $TOMCAT_PATH ]; then
# 下載 檢查本地端有無 tomcat src 
  test -e /tmp/apache-tomcat-7.0.54.tar.gz || \
# 如果沒有就下載
  wget $TOMCAT_7_URL -O /tmp/apache-tomcat-7.0.54.tar.gz && \
# 解壓縮
  tar xf /tmp/apache-tomcat-7.0.54.tar.gz -C /tmp && \
# 檢查解壓縮是否成功
  test -e /tmp/apache-tomcat-7.0.54 && \

# 檢查正確位子有無已經有複製一份過去
  test -e $TOMCAT_PATH || \
# 移動到正確的位子
  mv /tmp/apache-tomcat-7.0.54 $TOMCAT_DIR 
fi

# 檢查是否成功安裝
if [ ! -e $TOMCAT_PATH ]; then
# 如果沒有安裝成功就直接結束
  echo '安裝 tomcat 失敗' 
  exit 1 
fi

# 變更 tomcat 權限
chown -Rf tomcat:tomcat $TOMCAT_PATH || \
echo 'chown tomcat fail'


# 編譯 jsvc
# 檢查是否已經有先編譯完成
if [ ! -e $TOMCAT_PATH/bin/jsvc ]; then
# 檢查 jsvc
  if [ ! -e $TOMCAT_PATH/bin/commons-daemon-1.0.15-native-src ]; then
    tar xf $TOMCAT_PATH/bin/commons-daemon-native.tar.gz -C $TOMCAT_PATH/bin
  fi

# 下載編譯需要的環境
  test -e /usr/bin/gcc || yum install -y gcc
  test -e /usr/bin/make || yum install -y make

  cd $TOMCAT_PATH/bin/commons-daemon-1.0.15-native-src/unix && \
# 如果沒有就重新編譯一次
  ./configure  && make && \
# 複製 jsvc 到 tomcat/bin 底下
  cp $TOMCAT_PATH/bin/commons-daemon-1.0.15-native-src/unix/jsvc $TOMCAT_PATH/bin/
fi

# test firewall tomcat default port:8080
echo 'check firewall'
firewallPortRule=$(iptables-save | grep 8080 | cut -d ' ' -f 10)
if [ -z $firewallPortRule ] || [ $firewallPortRule != 'ACCEPT' ]; then
# allow port 8080 - 
  echo 'add iptables INPUT tcp 8080'
  iptables -I INPUT 1 -p tcp -m tcp --dport 8080 -j ACCEPT &&
  /etc/init.d/iptables save
fi 

# 新增一個使用者{Lab715_JSP} 讓 我的系統可以透過這使用者上傳
# 我的系統會自動上傳到 tomcat web Root 目錄下
# web path: $TOMCAT_PATH/webapps/ROOT
# 我會設定 Lab715_JSP 家目錄為到 $TOMCAT_PATH/webapps/ROOT/Lab715_JSP
# 利用這方式 只要打開瀏覽器看 $SERVER_IP:8080/Lab715_JSP/XXX 就可以直接看他們上傳的 JSP

# 檢查是否有此目錄
test -e $TOMCAT_PATH/webapps/ROOT/lab715_JSP || \
# 沒有這目錄就新增
sudo -u tomcat mkdir $TOMCAT_PATH/webapps/ROOT/lab715_JSP
# 把這目錄設定為只要是 tomcat 群組就可以寫入
chmod g+w $TOMCAT_PATH/webapps/ROOT/lab715_JSP

# lab715_JSP 
# -M -N :不用建立自己的家目錄, 群組
# -G    :並且加入到 tomcat 群組
# -p    :設定密碼
# -d    :指定家目錄
echo 'create user'
useradd lab715_JSP -M -N -G tomcat -d $TOMCAT_PATH/webapps/ROOT/lab715_JSP  2> /dev/null
# 設定密碼
echo 'Dream' | passwd lab715_JSP --stdin > /dev/null

# install mysql
echo 'install mysql..'
test -e /usr/bin/mysql || yum install -y mysql.x86_64 
test -e /usr/bin/mysqld_safe || yum install -y mysql-server.x86_64

# tomcat add JDBC lib
echo 'tomcat add jdbc lib'
if [ ! -e /tmp/mysql-connector-java-5.0.8 ]; then
  wget $MYSQL_JDBC_URL -O /tmp/mysql-connector-java-5.0.8.tar.gz
  
  tar xf /tmp/mysql-connector-java-5.0.8.tar.gz -C /tmp 

  cp /tmp/mysql-connector-java-5.0.8/mysql-connector-java-5.0.8-bin.jar $TOMCAT_PATH/lib
fi

# tomcat start
echo 'tomcat start'
$TOMCAT_PATH/bin/daemon.sh stop
$TOMCAT_PATH/bin/daemon.sh start

service mysqld start 

echo 'init mysql'
echo  "
-- create database
CREATE DATABASE IF NOT EXISTS lab715_JSP ;

-- use database
use lab715_JSP ;

-- create table
CREATE TABLE IF NOT EXISTS test ( \
  id INT(11) NOT NULL auto_increment, \
  name char(35) NOT NULL default '', \
  PRIMARY KEY(id) \
) ;

-- delete all data
DELETE FROM test ;

-- init
INSERT INTO test (name) VALUES('Dream');
INSERT INTO test (name) VALUES('Hsia');
INSERT INTO test (name) VALUES('LuoBoy');

-- DROP USER 'lab715_JSP'@'localhost' ;
-- create jsp use user
CREATE USER 'lab715_JSP'@'localhost' IDENTIFIED BY 'dream';
" | mysql 

# 如果 lab715_JSP 使用者已經存在，會導致再一次 Create user 會 error
# 所以無法執行下面指令，所以在這邊分成兩邊
echo "
SET PASSWORD FOR 'lab715_JSP'@'localhost' = PASSWORD('dream');

grant all on lab715_JSP.* to 'lab715_JSP'@'localhost' ;
" | mysql

# 加入到開機自動執行
# tomcat
if [ ! -e /etc/init.d/tomcat ]; then
  
  ln -s $TOMCAT_PATH/bin/daemon.sh /etc/init.d/tomcat
  sed -i '22a export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.55.x86_64 \
	      #chkconfig:345 99 01 ' /etc/init.d/tomcat
  chown root:root /etc/init.d/tomcat
  chmod 755 /etc/init.d/tomcat
fi 
chkconfig --level 345 tomcat on 
# mysql
chkconfig --level 345 mysqld on
echo 'Done'
