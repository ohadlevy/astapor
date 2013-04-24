#!/bin/bash -x
# Deployement script for RHOS on RHEL 6.x
# Provides:
#   Puppet, Puppetmaster, Mysql, foreman (RC5) based upon EPEL6
#   SELINUX
# Requirements:
#   Lastest version of RHEL needed (Currently using RHEL 6.4 Beta)
#   System have to be registered to RHN
#   FQDN required for the PuppetMaster
#   NTP Recommended

PUPPET_MASTER="host1.example.org"
OPENSTACK_PUPPET_MODULES="https://github.com/derekhiggins/openstackpuppetmodules.git"
TRYSTACK_GIT="https://user:password@bitbucket.org/derekhiggins/trystack.git"
MYSQL_ADMIN_PASSWD='redhat'
MYSQL_PUPPET_PASSWD='puppet'

usage(){
    echo "Usage: $0 puppet | puppetmaster | mysql | foreman | all"
    exit 1
}

fatal(){
    echo "Fatal: $1"
    exit 1
}

puppet(){
  # Do not touch IPV6 - It works better with it than without (faster, no timeouts)
  #  augtool -s set /files/etc/sysctl.conf/#comment[last] Ipv6 
  #  augtool -s set /files/etc/sysctl.conf/net.ipv6.conf.all.disable_ipv6 1
  #  augtool -s set /files/etc/sysctl.conf/net.ipv6.conf.default.disable_ipv6 1
  #  augtool -s set /files/etc/sysctl.conf/net.ipv6.conf.lo.disable_ipv6 0
  #  sysctl -p

  # Get Puppet and some utilities
    # Add RHEL6 server-optional Red Hat software channel
    yum clean all
    yum-config-manager --enable rhel-6-server-optional-rpms
    # Add EPEL 6 repo and GPG key
    rpm -Uvh http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
    yum install -y screen puppet augeas

  # Configure Puppet agent
    augtool -s set /files/etc/puppet/puppet.conf/agent/server $PUPPET_MASTER
    augtool -s set /files/etc/puppet/puppet.conf/main/pluginsync true
    # SELinux - Allow puppet client
    setsebool -P puppet_manage_all_files true

  # Activate & run services
    chkconfig puppet on
####   service puppet start
}

puppetmaster(){
  # Get puppetmaster, Git (for puppet modules)
    yum install -y git puppet-server policycoreutils-python
   
  # Configure 
    # Activate puppet plugins (modules custom types & facts)
    augtool -s set /files/etc/puppet/puppet.conf/main/pluginsync true

    # Add Puppet Environments
    mkdir -p /etc/puppet/modules/{development,production}
    augtool -s set /files/etc/puppet/puppet.conf/development/modulepath /etc/puppet/modules/development:/etc/puppet/modules/common
    augtool -s set /files/etc/puppet/puppet.conf/production/modulepath /etc/puppet/modules/production:/etc/puppet/modules/common
    # Puppet Auth - Recommended to remove it after deployments
    augtool -s set /files/etc/puppet/puppet.conf/master/autosign \$confdir/autosign.conf { mode = 664 }


  # Get Puppet Modules
    # Openstack
    git clone --recursive $OPENSTACK_PUPPET_MODULES /tmp/ospuppetmodules
    find /tmp/ospuppetmodules \( -name ".fixtures.yml" -o -name ".gemfile" -o -name ".travis.yml" -o -name ."rspec" -o -name .git \) -exec rm -rf {} \;
    mv /tmp/ospuppetmodules/modules/* /etc/puppet/modules/production
    rm -rf /tmp/openstackpuppetmodules
    # Trystack
    git clone $TRYSTACK_GIT /etc/puppet/modules/production/trystack

    # SELinux 
    # Set type for /etc/puppet
    semanage fcontext -a -t puppet_etc_t '/etc/puppet(/.*)?'
    # DB use
    setsebool -P puppetmaster_use_db true
  # SELinux - align all configuration files
    restorecon -vvFR /etc/puppet/

  # Activate & run services
    chkconfig puppetmaster on
    service puppetmaster start

  # Is this still needed?
    chmod 644 /var/lib/puppet/ssl/private_keys/$(hostname -f).pem
    chmod 755 /var/lib/puppet/ssl/private_keys
}

prepmysql(){
  # FQDN is required
    hostname -f > /dev/null 2>&1
    [[ $? -eq 1 ]] && fatal "FQDN required for this host"

  # Get DBMS
    yum install -y mysql-server #ruby-devel mysql-devel gcc
  #  gem install mysql --no-ri --no-rdoc

  # Run service by default
    chkconfig mysqld on
    service mysqld start

  # Init mysql
    /usr/bin/mysqladmin -u root password "$MYSQL_ADMIN_PASSWD"
    /usr/bin/mysqladmin -u root -h $(hostname) password "$MYSQL_ADMIN_PASSWD"

  # Init puppet database
    cat >puppet-create-dbms.sql<<EOF
create database puppet;
GRANT ALL PRIVILEGES ON puppet.* TO puppet@localhost IDENTIFIED BY '$MYSQL_PUPPET_PASSWD';
commit;
EOF
    mysql -u root --password=$MYSQL_ADMIN_PASSWD < puppet-create-dbms.sql

  # Puppet.conf setup for mysql
    augtool -s set /files/etc/puppet/puppet.conf/master/storeconfigs true
    augtool -s set /files/etc/puppet/puppet.conf/master/dbadapter mysql
    augtool -s set /files/etc/puppet/puppet.conf/master/dbname puppet
    augtool -s set /files/etc/puppet/puppet.conf/master/dbuser puppet
    augtool -s set /files/etc/puppet/puppet.conf/master/dbpassword $MYSQL_PUPPET_PASSWD
    augtool -s set /files/etc/puppet/puppet.conf/master/dbserver localhost
    augtool -s set /files/etc/puppet/puppet.conf/master/dbsocket /var/lib/mysql/mysql.sock
}	

foreman(){
  # Get Foreman
    yum install -y http://yum.theforeman.org/rc/el6/x86_64/foreman-release-1.1RC5-1.el6.noarch.rpm
    yum install -y rubygem-redcarpet foreman foreman-proxy foreman-mysql foreman-mysql2

  # External Node Classification
    git clone git://github.com/theforeman/puppet-foreman.git /tmp/puppet-foreman
    cp /tmp/puppet-foreman/templates/external_node.rb.erb /etc/puppet/node.rb
    # Edit /etc/puppet/node.rb
    sed -i "s/<%= @foreman_url %>/http:\/\/$(hostname):3000/" /etc/puppet/node.rb
    sed -i 's/<%= @puppet_home %>/\/var\/lib\/puppet/' /etc/puppet/node.rb
    sed -i 's/<%= @facts %>/true/' /etc/puppet/node.rb
    sed -i 's/<%= @storeconfigs %>/false/' /etc/puppet/node.rb
    chmod 755 /etc/puppet/node.rb

    augtool -s set /files/etc/puppet/puppet.conf/master/external_nodes /etc/puppet/node.rb
    augtool -s set /files/etc/puppet/puppet.conf/master/node_terminus exec

  # Add Reports to Foreman
    cp /tmp/puppet-foreman/templates/foreman-report.rb.erb /usr/lib/ruby/site_ruby/1.8/puppet/reports/foreman.rb
    augtool -s set /files/etc/puppet/puppet.conf/master/reports foreman
    
  # Enable Foreman-proxy features
    sed -i -r 's/(:puppetca:).*/\1 true/' /etc/foreman-proxy/settings.yml
    sed -i -r 's/(:puppet:).*/\1 true/' /etc/foreman-proxy/settings.yml

  # Setup foreman DBMS for mysql
    sed -i -r "/production:/ {  
      N
      N
      N
      N
      s/(production:).*timeout.*/\1\n  adapter: mysql2\n  database: puppet\n  username: puppet\n  password: ${MYSQL_PUPPET_PASSWD}\n  host: localhost\n  socket: \"\/var\/lib\/mysql\/mysql.sock\"/ 
    }" /etc/foreman/database.yml

  # Init database
    cd /usr/share/foreman && RAILS_ENV=production rake db:migrate

  # Mysql Optimisation - can be done only once puppet database has been populated
    cat >puppet-index.sql<<EOF
create index exported_restype_title on resources (exported, restype, title(50));
EOF
    mysql -u root -p${MYSQL_ADMIN_PASSWD} -D puppet < puppet-index.sql

  # Activate & run services
    chkconfig foreman-proxy on
    service foreman-proxy start
    chkconfig foreman on
    service foreman start
}

post-install(){ 
  # Import modules in Foreman
    # Smart_proxy must be defined in Foreman
   cd /usr/share/foreman && rake puppet:import:puppet_classes[batch] RAILS_ENV=production

  # Import foreman parameters for hostgroups
}

# Main
[[ "$#" -lt 1 ]] && usage
[[ -z $PUPPET_MASTER ]] && fatal "Puppet Master host not defined" 
case "$1" in
     "puppet")
	puppet
        ;;
     "puppetmaster")
        puppetmaster
        ;;
     "mysql")
        prepmysql
        ;;
     "foreman")
        foreman 
        ;;
     "all")
        puppet
        puppetmaster
	prepmysql
        foreman
        ;;
     *) usage  
        ;;
esac
