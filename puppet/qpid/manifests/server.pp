# Class: qpid::server
#
# This module manages the installation and config of the qpid server
class qpid::server(
  $running = 'running',
  $auth   = 'yes'
) {

  package {"qpid-cpp-server":
      ensure => installed,
  }

  service {"qpidd":
      ensure  => $running,
      enable  => true,
      require => Package["qpid-cpp-server"],
      subscribe => File['/etc/qpidd.conf'],
  }

  file { "/etc/qpidd.conf":
    content => template('qpid/qpidd.conf.erb'),
    mode    => '0644',
  }

}
