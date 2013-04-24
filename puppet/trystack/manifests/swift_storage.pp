class trystack::swift_storage inherits trystack::swift_common {

  #### Storage ####
  class { 'swift::storage::all':
    storage_local_net_ip => $::ipaddress_em1,
    require => Class['swift'],
  }
  
  swift::storage::ext4 { "lvswift":
       device => "/dev/vg_${$::hostname}/lv_swift",
  }

  if(!defined(File['/srv/node'])) {
    file { '/srv/node':
      owner  => 'swift',
      group  => 'swift',
      ensure => directory,
      require => Package['openstack-swift'],
    }
  }

  @@ring_object_device { "$::ipaddress_em1:6000/lv_swift":
   zone        => 1,
   weight      => 10, }
  @@ring_container_device { "$::ipaddress_em1:6001/lv_swift":
   zone        => 1,
   weight      => 10, }
  @@ring_account_device { "$::ipaddress_em1:6002/lv_swift":
   zone        => 1,
   weight      => 10, }
  @@ring_object_device { "$::ipaddress_em1:6000/lv_swift":
   zone        => 2,
   weight      => 10, }
  @@ring_container_device { "$::ipaddress_em1:6001/lv_swift":
   zone        => 2,
   weight      => 10, }
  @@ring_account_device { "$::ipaddress_em1:6002/lv_swift":
   zone        => 2,
   weight      => 10, }
  @@ring_object_device { "$::ipaddress_em1:6000/lv_swift":
   zone        => 3,
   weight      => 10, }
  @@ring_container_device { "$::ipaddress_em1:6001/lv_swift":
   zone        => 3,
   weight      => 10, }
  @@ring_account_device { "$::ipaddress_em1:6002/lv_swift":
   zone        => 3,
   weight      => 10, }

  swift::ringsync{["account","container","object"]:
      ring_server => '10.100.0.2',
      before => Class['swift::storage::all'],
      require => Class['swift'],
  }
  
  firewall { '001 swift storage incoming':
      proto    => 'tcp',
      dport    => ['6000', '6001', '6002', '873'],
      action   => 'accept',
  }

}
