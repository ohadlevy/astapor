class trystack::cinder {
  class {'cinder::base':
      rabbit_password => '',
      sql_connection => "mysql://cinder:${cinder_db_password}@10.100.0.222/cinder"
  }
  
  cinder_config{
      "DEFAULT/rpc_backend": value => "cinder.openstack.common.rpc.impl_qpid";
      "DEFAULT/qpid_hostname": value => "10.100.0.222";
      "DEFAULT/glance_host": value => "10.100.0.222";
  }
  
  class {'cinder::api':
      keystone_password => "${cinder_user_password}",
      keystone_tenant => "services",
      keystone_user => "cinder",
      keystone_auth_host => "10.100.0.222",
  }
  
  class {'cinder::scheduler':
  }
  
  class {'cinder::volume':
  }
  
  class {'cinder::volume::iscsi':
      iscsi_ip_address => '10.100.0.2'
  }
  
  firewall { '001 cinder incoming':
      proto    => 'tcp',
      dport    => ['3260', '8776'],
      action   => 'accept',
  }

}
