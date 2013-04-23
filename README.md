---
= Astapor

Configurations to set up foreman quickly, install openstack puppet modules
and rapidly provision openstack compute & controller nodes with puppet.

This install is based on the redhat packstack quickstart rpm that can be found here: http://openstack.redhat.com/Quickstart with a few modifications
 - ntp module added
 - nova module "default_target" function added

Prerequisites:

RHEL 6.4
 - This *should* work on other operating systems, but has only been tested on RHEL6.4

At least 3 machines
 - You need 1 machine to run foreman, 1 machine to run the openstack controller
   and at least  one openstack compute node

Machines subscribed + configured
 - These machines should already be running RHEL 6.4, subscribed, have their
   networking (with FQDN) set up, be able to reach each other, etc

= Instructions

1. scp foreman_server.sh to your foreman host
2. sh foreman_server.sh on your foreman host
3. This will result in a running foreman instance on your machine! 
4. scp puppet/* to {foreman_host}:/etc/puppet/manifests/production
5. Log in to foreman. The default username and password are admin/changeme
6. Set up your smart proxy in foreman!
  a. Select MORE -> CONFIGURATION -> SMART PROXIES
  b. Select NEW PROXY
  c. Name it whatever you want, eg proxy1
  d. Set the URL to the FQDN of this machine
  e. Set the port to 8443
  f. Select SUBMIT
7. Import your shiny new puppet modules in foreman!
  a. Select MORE -> CONFIGURATION -> PUPPET CLASSES
  b. Select Import from {SmartProxyName}
  c. Select SUBMIT
8. Set up host groups for openstack controller & compute
  a. Select MORE -> CONFIGURATION -> HOST GROUPS
  b. Enter "openstack-compute" as the name
  c. Enviroment -> Production
  d. Smart Proxy -> {SmartProxyName}
  e. Click the "puppet classes" tab
  f. Select + next to TryStack and TryStack::Compute
  g. Select SUBMIT
  h. Repeat this step for openstack-controller, replacing TryStack::Compute with TryStack::Controller and name with openstack-controller
9. Define global parameters
  a. Select MORE -> CONFIGURATION -> GLOBAL PARAMETERS
  b. This is where you have to enter all of the information for your environment
  c. Read the "answers" file that ships in this repo. For each "answer" in the answer file, 
     enter a new parameter with that name. You *MUST* have every parameter in the answer file.
  d. You can make most of the passwords whatever you want. The pacemaker priv/pub, pub & private network interface  & network ranges apply to your controller node. 
10. You're done setting up the server! Time to set up the controller node.
11. scp foreman_client.sh to your client nodes. 
  a. Replace puppetmaster with FQDN of your foreman server
  b. On the foreman server, cat {controller_host} >> /etc/puppet/autosign.conf
  c. Run foreman_client.sh
12. Give puppet a test run (puppetd --test). This will register it with the foreman server
13. On the foreman server, click on "HOSTS". You should see your host.
  a. Click on your hostname. Click EDIT in the top right.
  b. Select openstack-controller under hostgroup. 
  c. Click SUBMIT
  d. On your client, run puppet agent -tv. This will take quite a while (~10 min)
  e. You're done setting up the controller node! Let's set up a compute node
14. Repeat step 11 & 12 for your compute node. 
15. On the foreman server, click on HOSTS. You should see your host.
  a. Click on your compute node hostname. Click EDIT in the top right
  b. Select openstack-compute under hostgroup
  c. Click SUBMIT
  d. On your client, run puppet agent -tv. This will take a while (~5 min)
16. You have your compute node setup! Get to openstacking
