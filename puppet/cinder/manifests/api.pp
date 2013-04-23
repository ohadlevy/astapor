#
class cinder::api (
  $keystone_password,
  $keystone_enabled       = true,
  $keystone_tenant        = 'services',
  $keystone_user          = 'cinder',
  $keystone_auth_host     = 'localhost',
  $keystone_auth_port     = '35357',
  $keystone_auth_protocol = 'http',
  $package_ensure         = 'latest',
  $enabled                = true
) {

  include cinder::params

  Cinder_config<||> ~> Service['cinder-api']
  Cinder_config<||> ~> Exec['cinder-manage db_sync']
  Cinder_api_paste_ini<||> ~> Service['cinder-api']

  if $::cinder::params::api_package {
    Package['cinder-api'] -> Cinder_config<||>
    Package['cinder-api'] -> Cinder_api_paste_ini<||>
    Package['cinder-api'] -> Service['cinder-api']
    package { 'cinder-api':
      name    => $::cinder::params::api_package,
      ensure  => $package_ensure,
    }
  }

  if $enabled {
    $ensure = 'running'
  } else {
    $ensure = 'stopped'
  }

  service { 'cinder-api':
    name      => $::cinder::params::api_service,
    enable    => $enabled,
    ensure    => $ensure,
    require   => Package['cinder'],
  }

  if $keystone_enabled {
    cinder_config {
      'DEFAULT/auth_strategy':     value => 'keystone' ;
      'keystone_authtoken/service_protocol':  value => $keystone_auth_protocol;
      'keystone_authtoken/service_host':      value => $keystone_auth_host;
      'keystone_authtoken/service_port':      value => '5000';
      'keystone_authtoken/auth_protocol':     value => $keystone_auth_protocol;
      'keystone_authtoken/auth_host':         value => $keystone_auth_host;
      'keystone_authtoken/auth_port':         value => $keystone_auth_port;
      'keystone_authtoken/admin_tenant_name': value => $keystone_tenant;
      'keystone_authtoken/admin_user':        value => $keystone_user;
      'keystone_authtoken/admin_password':    value => $keystone_password;
    }
  }

  exec { 'cinder-manage db_sync':
    command     => $::cinder::params::db_sync_command,
    path        => '/usr/bin',
    user        => 'cinder',
    refreshonly => true,
    logoutput   => 'on_failure',
  }

}
