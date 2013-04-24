class trystack::swift_ringbuilder {
    #### Builder ####
    class { 'swift::ringbuilder':
      part_power     => '18',
      replicas       => '3',
      min_part_hours => 1,
      require        => Class['swift'],
    }

    # sets up an rsync db that can be used to sync the ring DB
    class { 'swift::ringserver':
      local_net_ip => "10.100.0.2",
    }
    
    @@swift::ringsync { ['account', 'object', 'container']:
     ring_server => $swift_local_net_ip
    }
    
    Ring_object_device <<| |>>
    Ring_container_device <<| |>>
    Ring_account_device <<| |>>
    
    firewall { '001 rsync incoming':
        proto    => 'tcp',
        dport    => ['873'],
        action   => 'accept',
    }
    
    if ($::selinux != "false"){
        selboolean{'rsync_export_all_ro':
            value => on,
            persistent => true,
        }
    }
}
