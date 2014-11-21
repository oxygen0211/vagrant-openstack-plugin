require "log4r"

require 'vagrant/util/scoped_hash_override'

module VagrantPlugins
  module OpenStack
    module Action
      class CreateNetworkInterfaces
        include Vagrant::Util::ScopedHashOverride

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_openstack::action::create_network_interfaces")
        end

        def call(env)
          networks_to_configure = []
          env[:machine].config.vm.networks.each_with_index do |network, slot_number|
            type = network[0]
            original_options = network[1]
            next if type != :private_network
            next if original_options[:auto_config] === false
            next if slot_number == 0

            options = scoped_hash_override(original_options, :openstack)

            @logger.info "Configuring interface slot_number #{slot_number} options #{options}"

            network_to_configure = {
              :interface => slot_number,
            }

            if options[:ip]
              network_to_configure = {
                :type    => :static,
                :ip      => options[:ip],
                :netmask => "255.255.255.0",
              }.merge(network_to_configure)
            else
              network_to_configure[:type] = :dhcp
            end

            networks_to_configure.push(network_to_configure)
          end
          env[:ui].info I18n.t('vagrant.actions.vm.network.configuring')
          env[:machine].guest.capability(:configure_networks, networks_to_configure)
          @app.call(env)
        end
      end
    end
  end
end
