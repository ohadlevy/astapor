class trystack::swift_common {

    #### Common ####
    class { 'ssh::server::install': }
    
    Class['swift'] -> Service <| |>
    class { 'swift':
        swift_hash_suffix => $swift_shared_secret,
        package_ensure    => latest,
    }
    
    # We need to disable this while rsync causes AVC's
    exec{'setenforce 0':
      path => '/usr/sbin',
      notify => Class['swift']
    }

}
