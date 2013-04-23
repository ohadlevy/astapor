Puppet::Type.newtype(:nova_config) do
  
  def self.default_target
    "/etc/nova/nova.conf"
  end

  ensurable

  newparam(:name, :namevar => true) do
    desc 'Section/setting name to manage from nova/nova.conf'
    newvalues(/^(\S+|\S+\/\S+)$/)
  end

  newproperty(:value) do
    desc 'The value of the setting to be defined.'
    munge do |v|
      v.to_s.strip
    end
  end

  validate do
    if self[:ensure] == :present
      if self[:value].nil? || self[:value] == ''
        raise Puppet::Error, "Property value must be set for #{self[:name]} when ensure is present"
      end
    end
  end
end
