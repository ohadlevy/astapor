#!/usr/bin/ruby
#
# Copyright 2013 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require 'rubygems'
require 'json'
require 'logger'
require 'rest-client'

# Default
@params_file_name = 'foreman-params.json'
@log_file         = STDOUT

def param?(key)
  @params.key?(key) && !@params[key].empty?
end

def get_env_id(env)
  envs = JSON.load(@client['environments'].get)
  env  = envs.detect { |e| e['environment'].key?('name') }
  env['environment']['id']
end

def get_class(name)
  res = @client['puppetclasses'].get(:params => { :search => name })
  JSON.load(res)
end

def get_class_ids(classes)
  ids = []
  classes.each do |puppetclasses|
    get_class(puppetclasses).each do |puppetclass|
      puppetclass[1].each do |details|
        ids << details['puppetclass']['id']
      end
    end
  end
  ids
end

def create(cmd, data)
  response = @client[cmd].post(data)
rescue RestClient::UnprocessableEntity => e
  @log.warn("POST KO: #{data} => #{e.response}")
else
  @log.info("POST OK: #{data}")
end

def create_proxy(proxy)
  raise 'Incorrect or missing Proxy definitions' unless param?('proxy')
  data = { :smart_proxy => { :name => proxy['name'], :url => proxy['host'] } }
  create('smart_proxies', data)
end

def create_globals(globals)
  raise 'Incorrect or missing Global Parameters definitions' unless param?('globals')
  globals.each do |name, value|
    data = { :common_parameter => { :name => name, :value => value } }
    create('common_parameters', data)
  end
end

def create_hostgroups(hostgroups)
  raise 'Incorrect or missing Hostgroups definitions' unless param?('hostgroups')
  hostgroups.each do |hostgroup|
    env_id      = get_env_id(hostgroup[1]['environment'])
    classes_ids = get_class_ids(hostgroup[1]['puppetclasses'])
    create('hostgroups', :hostgroup => {
             :name => hostgroup[0],
             :environment_id => env_id,
             :puppetclass_ids => classes_ids
           })
  end
end

def create_puppetos(puppetos)
  raise 'Incorrect or missing Puppet Modules definitions' unless puppetos
  puppetos.each do |e|
    options = e['options'] if e.has_key?('options') && !e['options'].empty?
    puts "git clone #{options} #{e['source']} #{e['destination']}"
  end
end

def update(cmd, data)
  response = @client[cmd].put(data)
rescue RestClient::UnprocessableEntity => e
  @log.warn("PUT KO: #{data} => #{e.response}")
else
  @log.info("PUT OK: #{data}")
end

def update_settings(settings)
  settings.each do|s|
    results = @client['settings'].get(:params => { :search => s['name'] })
    server_setting = JSON.load(results)[0]
    puts server_setting
    update( 'settings/'+server_setting['setting']['id'].to_s(), :setting => {
              :value => s['value'] })
  end
end

def usage
  puts "Usage: #{File.basename($0)} proxy | globals | hostgroups"
  puts " Multiple commands can be used at same time"
  exit
end

def init
  # Logs
  @log = Logger.new(@log_file)
  @log.datetime_format = "%d/%m/%Y %H:%M:%S"
  $DEBUG ? @log.level = Logger::DEBUG : @log.level = Logger::INFO

  # JSON parameters
  raise "Missing file #{@params_file_name}" if !File.exist?(@params_file_name)
  params_file      = File.open(@params_file_name)
  @params          = JSON.load(params_file.read)

  # Session
  raise 'Incorrect or missing Host definitions' unless param?('host')
  @client = RestClient::Resource.new('https://' + @params['host']['name'] + '/api',
                                     :user => @params['host']['user'],
                                     :password => @params['host']['passwd'],
                                     :headers => { :accept => :json })
end

begin
  # Options
  usage unless ARGV[0]
  until ARGV[0] !~ /^-./
    case ARGV[0]
    when '-c', '--config-file='
      ARGV.shift
      @params_file_name = ARGV[0]
    when '-l', '--log-file='
      ARGV.shift
      @log_file         = ARGV[0]
    end
    ARGV.shift
  end
  init

  # Command
  usage unless ARGV[0]
  until ARGV.empty?
    case ARGV[0]
    when 'proxy'
      create_proxy(@params['proxy'])
    when 'globals'
      create_globals(@params['globals'])
    when 'hostgroups'
      create_hostgroups(@params['hostgroups'])
    when 'settings'
      update_settings(@params['settings'])
    else
      usage
    end
    ARGV.shift
  end
rescue RuntimeError => e
  @log.fatal(e)
  exit
end

