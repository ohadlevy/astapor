# Astapor

Configurations to set up foreman quickly, install openstack puppet modules
and rapidly provision openstack compute & controller nodes with puppet.

This install is based on the redhat packstack quickstart rpm that can be found here: http://openstack.redhat.com/Quickstart with a few modifications
 - ntp module added
 - nova module "default_target" function added

Prerequisites:

RHEL 6.4
 * This *should* work on other operating systems, but has only been tested on RHEL6.4

At least 3 machines
 * 1 Foreman Host
 * 1 OpenStack Controller Node
 * 1+ OpenStack Compute Nodes 

Preconfiguration - these machines should be:
 * Running RHEL 6.4
 * Correctly subscribed & updated
 * Have a FQDN resolvable by others on the network
 * Network setup between 3 node types described above

## Instructions
1. Run foreman_server.sh. This will install foreman, setup your smart proxy, default
   host groups, some global variables, and install the OpenStack puppet classes
2. When the installer is done, login to foreman https://FQDN/. Default login is admin/changeme
3. You need to configure some parameters for your environment.
  * Navigate to MORE -> CONFIGURATION -> GLOBAL PARAMETERS
  * Edit anything with EDIT ME to something sensible for your environment
4. Now you need to register hosts. foreman_server.sh generated /tmp/foreman_client.sh. scp that
   to your compute & controller nodes. Run it on each. It will install puppet and register it
   with your foreman server
5. In the foreman UI, select HOSTS. Choose the host that you want to be the controller node
6. Select EDIT HOST. Change HOSTGROUPS to OpenStack Controller Node.
7. Run puppet agent on the node (puppet agent -tv)
8. Repeat this process for each compute node, but set the HOSTGROUP to OpenStack Compute Node
9. Voila!
