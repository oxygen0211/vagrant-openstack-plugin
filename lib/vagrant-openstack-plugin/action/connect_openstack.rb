require "fog"
require "log4r"

module VagrantPlugins
  module OpenStack
    module Action
      # This action connects to OpenStack, verifies credentials work, and
      # puts the OpenStack connection object into the `:openstack_compute` key
      # in the environment.
      class ConnectOpenStack
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_openstack::action::connect_openstack")
        end

        def call(env)
          # Get the configs
          config   = env[:machine].provider_config
          api_key  = config.api_key
          endpoint = config.endpoint
          username = config.username
          tenant = config.tenant
          region = config.region
          domain = config.domain
          project = config.project

          @logger.debug("Domain: #{domain}")
          # Pass proxy config down into the Fog::Connection object using
          # the `connection_options` hash.
          connection_options = {
            :proxy           => config.proxy,
            :ssl_verify_peer => config.ssl_verify_peer
          }

          # Prepare connection parameters for use with fog service
          # initialization (compute, storage, orchestration, ...).
          env[:fog_openstack_params] = {
            :provider           => :openstack,
            :connection_options => connection_options,
            :openstack_username => username,
            :openstack_api_key  => api_key,
            :openstack_auth_url => endpoint,
            :openstack_tenant   => tenant,
            :openstack_region   => region,
            :openstack_user_domain   => domain,
            :openstack_project_name => project,
            :openstack_project_domain => domain
          }

          @logger.info("Connecting to OpenStack...")
          @logger.debug("API connection params: #{connection_options.inspect}")
          @logger.info("Setting compute configuration")
          env[:openstack_compute] = Fog::Compute.new(
          env[:fog_openstack_params])

          if config.network || (config.networks && !config.networks.empty?)
            @logger.info("Setting network configuration")
            env[:openstack_network] = Fog::Network.new({
              :provider => :openstack,
              :connection_options => connection_options,
              :openstack_username => username,
              :openstack_api_key => api_key,
              :openstack_auth_url => endpoint,
              :openstack_tenant => tenant,
              :openstack_region => region,
              :openstack_user_domain => domain,
              :openstack_project_name => project,
              :openstack_project_domain => domain
              })
            end

            if config.disks && !config.disks.empty?
              @logger.info("Setting volume configuration")
              env[:openstack_volume] = Fog::Volume.new({
                :provider => :openstack,
                :connection_options => connection_options,
                :openstack_username => username,
                :openstack_api_key => api_key,
                :openstack_auth_url => endpoint,
                :openstack_tenant => tenant,
                :openstack_region => region,
                :openstack_user_domain   => domain,
                :openstack_project_name => project,
                :openstack_project_domain => domain
                })
              end

              @app.call(env)
            end
          end
        end
      end
    end
