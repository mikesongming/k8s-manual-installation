#!/bin/bash

# close GUI
systemctl set-default multi-user.target

# close SELinux
systemctl stop firewalld && systemctl disable firewalld
sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/sysconfig/selinux

# disabling SWAP
swapoff -a
sed -i ' / swap / s/^/#/' /etc/fstab

# enforcing bridge iptables
cat > /etc/sysctl.d/k8s.conf <<EOF 
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
EOF

# configure limits
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf
echo "* soft nproc 65536" >> /etc/security/limits.conf
echo "* hard nproc 65536" >> /etc/security/limits.conf
echo "* soft memlock unlimited" >> /etc/security/limits.conf
echo "* hard memlock unlimited" >> /etc/security/limits.conf

yum isntall -y yum-utils
yum install -y epel-release

# yum set aliyun source
yum-config-manager --add-repo http://mirrors.aliyun.com/repo/Centos-7.repo
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.orig
mv /etc/yum.repos.d/Centos-7.repo /etc/yum.repos.d/CentOS-Base.repo  

yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum makecache fast
yum -y update
yum group install "Development Tools"
yum -y install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel sip-devel tcl-devel
