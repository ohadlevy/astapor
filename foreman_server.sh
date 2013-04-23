# start with a subscribed RHEL6 box
yum install -y yum-utils yum-rhn-plugin

rpm -Uvh http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum-config-manager --enable rhel-6-server-optional-rpms
yum clean all

# install dependent packages
yum install -y augeas puppet git policycoreutils-python

# enable ip forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf

# disable selinux in /etc/selinux/config
# TODO: selinux policy
setenforce 0

export PUPPETMASTER='puppet.example.org'

# Set PuppetServer
augtool -s set /files/etc/puppet/puppet.conf/agent/server $PUPPETMASTER

# Puppet Plugins
augtool -s set /files/etc/puppet/puppet.conf/main/pluginsync true

# TODO: correctly configure iptables
service iptables stop

# Get foreman-installer modules
git clone --recursive https://github.com/theforeman/foreman-installer.git /root/foreman-installer -b 1.1.1

# Install Foreman
puppet -v --modulepath=/root/foreman-installer -e "include puppet, puppet::server, passenger, foreman_proxy, foreman"
