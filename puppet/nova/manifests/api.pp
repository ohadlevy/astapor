#
# installs and configures nova api service
#
# * admin_password
# * enabled
# * ensure_package
# * auth_strategy
# * auth_host
# * auth_port
# * auth_protocol
# * admin_tenant_name
# * admin_user
# * enabled_apis
#
class nova::api(
  $admin_password,
  $enabled           = false,
  $ensure_package    = 'present',
  $auth_strategy     = 'keystone',
  $auth_host         = '127.0.0.1',
  $auth_port         = 35357,
  $auth_protocol     = 'http',
  $admin_tenant_name = 'services',
  $admin_user        = 'nova',
  $admin_password    = 'passw0rd',
  $api_bind_address  = '0.0.0.0',
  $enabled_apis      = 'ec2,osapi_compute,metadata',
  $volume_api_class  = 'nova.volume.cinder.API'
) {

  include nova::params
  require keystone::python

  Package<| title == 'nova-api' |> -> Exec['nova-db-sync']
  Package<| title == 'nova-api' |> -> Nova_config<| |>

  Package<| title == 'nova-common' |> -> Class['nova::api']

  Nova_config<| |> ~> Exec['post-nova_config']
  Nova_config<| |> ~> Service['nova-api']

  class {'cinder::client':
     notify         => Service[$::nova::params::api_service_name],
  }

  nova::generic_service { 'api':
    enabled        => $enabled,
    ensure_package => $ensure_package,
    package_name   => $::nova::params::api_package_name,
    service_name   => $::nova::params::api_service_name,
  }

  nova_config {
    'DEFAULT/api_paste_config':     value => '/etc/nova/api-paste.ini';
    'DEFAULT/enabled_apis':         value => $enabled_apis;
    'DEFAULT/volume_api_class':     value => $volume_api_class;
    'DEFAULT/ec2_listen':           value => $api_bind_address;
    'DEFAULT/osapi_compute_listen': value => $api_bind_address;
    'DEFAULT/metadata_listen':      value => $api_bind_address;
    'DEFAULT/osapi_volume_listen':  value => $api_bind_address;
  }

  # These parameters can be configured in nova.conf instead of
  # nova-api-paste.ini: see http://docs.openstack.org/developer/keystone/configuringservices.html
  nova_config {
    'keystone_authtoken/auth_host':         value => $auth_host;
    'keystone_authtoken/auth_port':         value => $auth_port;
    'keystone_authtoken/auth_protocol':     value => $auth_protocol;
    'keystone_authtoken/admin_tenant_name': value => $admin_tenant_name;
    'keystone_authtoken/admin_user':        value => $admin_user;
    'keystone_authtoken/admin_password':    value => $admin_password;
  }

  if 'occiapi' in $enabled_apis {
    if !defined(Package['python-pip']) {
        package {'python-pip':
                ensure => latest,
        }
    }
    if !defined(Package['pyssf']){
        package {'pyssf':
            provider => pip,
            ensure   => latest,
            require  => Package['python-pip']
        }
    }
    package { 'openstackocci' :
      provider  => 'pip',
      ensure    => latest,
      require => Package['python-pip'],
    }
  }

  # I need to ensure that I better understand this resource
  # this is potentially constantly resyncing a central DB
  exec { "nova-db-sync":
    command     => "/usr/bin/nova-manage db sync",
    refreshonly => "true",
    subscribe   => Exec['post-nova_config'],
  }

}
