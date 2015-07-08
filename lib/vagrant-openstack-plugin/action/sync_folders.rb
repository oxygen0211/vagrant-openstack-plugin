#!/usr/bin/env ruby
require 'rubygems'
require 'log4r'
require 'vagrant/util/scoped_hash_override'
require 'net/ssh'
require 'net/sftp'
require 'find'
require 'digest'

module VagrantPlugins
  module OpenStack
    module Action
      # This middleware syncs the selected folder to the jiffybox instance.
      class SyncFolders
        include Vagrant::Util::ScopedHashOverride
        def initialize(app, env)
          @app    = app
                @logger = Log4r::Logger.new("vagrant_openstack::action::sync_folders")
        end

        def call(env)
          @app.call(env)
          ssh_info = env[:machine].ssh_info
          env[:machine].config.vm.synced_folders.each do |id, data|
            data = scoped_hash_override(data, :jiffybox)
            # Ignore disabled shared folders
            next if data[:disabled]
            hostpath  = File.expand_path(data[:hostpath], env[:root_path])
            guestpath = data[:guestpath]

            # Make sure there is a trailing slash on the host path to
            # avoid creating an additional directory
            hostpath = "#{hostpath}/" if hostpath !~ /\/$/

            env[:ui].info(I18n.t("vagrant_openstack.rsync_folder",
                                :hostpath => hostpath,
                                :guestpath => guestpath))

            # Create the host path if it doesn't exist and option flag is set
            if data[:create]
              begin
                FileUtils::mkdir_p(hostpath)
              rescue => err
                raise Errors::MkdirError,
                  :hostpath => hostpath,
                  :err => err
              end
            end

            # SYNCING IN RUBY
            local_path = hostpath
            remote_path = guestpath
            if !local_path.end_with? "/"
              local_path = local_path + "/"
            end
            if !remote_path.end_with? "/"
              remote_path = remote_path + "/"
            end
            file_perm = 0644
            dir_perm = 0755

            # Checking files to upload
            Net::SSH.start(ssh_info[:host], ssh_info[:username],  :keys => [ ssh_info[:private_key_path].first],  :timeout => 100, :keepalive => true) do |ssh|
              ssh.sftp.connect do |sftp|
              # Create the guest path
          ssh.exec("sudo mkdir -p '#{guestpath}';sudo chown -R vagrant '#{guestpath}'")
      
                # Sync folder structure
                Find.find(local_path) do |dir|
                  next if !File.stat(dir).directory?
                  # Ignore folders, starting with '.'
                  # next if File.basename(dir).to_s.starts_with?(".")
                  local_dir = "#{dir}"
                  # next if local_dir.to_s.starts_with?(".")
                  remote_dir = remote_path + local_dir.sub(local_path, '')
                  begin
                  # Check if remote path exists, if not, create it and set necessary permissions.
                    sftp.stat!(remote_dir)
                  rescue Net::SFTP::StatusException => e
                    raise unless e.code == 2
                    begin
                      sftp.mkdir!(remote_dir, :permissions => dir_perm)
                    rescue Net::SFTP::StatusException => e
                    end
                  end
                end

                # Sync files
                Find.find(local_path) do |file|
                  next if File.stat(file).directory?
                  local_file = "#{file}"
                  remote_file = remote_path + local_file.sub(local_path, '')
                  local_file_path = local_path + File.basename(file)
                  remote_file_path = remote_path + File.basename(file)

                  begin
                  # Check if file exists (then no error is thrown)
                    rstat = sftp.stat!(remote_file)
                  rescue Exception => e
                  # If file doesn't exist upload and do 'next'
                    raise unless e.code == 2
                    begin
                      sftp.upload!(file, remote_file)
                      sftp.setstat(remote_file, :permissions => file_perm)
                      # env[:ui].info(I18n.t("vagrant_jiffybox.uploaded_file", :file => File.basename(file), :path => remote_file))
                    rescue Exception => e
                    end
                  next
                  end

                  # If file exists, check modification time. Upload the file, if the file was modified.
                  if (File.stat(local_file).mtime > Time.at(rstat.mtime))
                    if(File.size(local_file) != rstat.size)
                    # env[:ui].info(I18n.t("vagrant_jiffybox.updated_file", :file => File.basename(file), :path => remote_file, :mode => "different size"))
                    sftp.upload!(file, remote_file)
                    else
                      r_file = sftp.file.open(remote_file)
                      l_file = File.open(File.expand_path(file), "rb")
                      if(!compare(ssh, l_file, remote_file_path))
                      # env[:ui].info(I18n.t("vagrant_jiffybox.updated_file", :file => File.basename(file), :path => remote_file, :mode => "different content"))
                      sftp.upload!(file, remote_file)
                      end
                    r_file.close
                    l_file.close
                    end
                  end
                end

                # Download changed files
                # syncDirDown(env, sftp, ssh, local_path, remote_path)
              end
            end
          end
        end

        def syncDirDown(env, sftp, ssh, local_path, remote_path)
          sftp.dir.entries(remote_path).each do |remote_file|
            if !remote_file.directory?
              local_file_path = local_path + remote_file.name
              remote_file_path = remote_path + remote_file.name
              rstat = sftp.stat!(remote_file_path)
              if !File.exists?(local_file_path)
              # env[:ui].info(I18n.t("vagrant_jiffybox.downloaded_file", :file => remote_file.name, :path => local_file_path))
              file_data = sftp.download!(remote_file_path, local_file_path)
              else
                local_file = File.open(local_file_path)
                if  (Time.at(rstat.mtime) > File.stat(local_file).mtime)
                  if(File.size(local_file) != rstat.size)
                  # env[:ui].info(I18n.t("vagrant_jiffybox.updated_file", :file => remote_file.name, :path => local_file_path, :mode => "different size"))
                  file_data = sftp.download!(remote_file_path, local_file_path)
                  else
                    r_file = sftp.file.open(remote_file_path)
                    l_file = File.open(local_file_path, "rb")
                    if(rstat.size < 100000000)
                      if(!compare(ssh, l_file, remote_file_path))
                      # env[:ui].info(I18n.t("vagrant_jiffybox.updated_file", :file => remote_file.name, :path => local_file_path, :mode => "different content"))
                      file_data = sftp.download!(remote_file_path, local_file_path)
                      end
                    end
                  r_file.close
                  l_file.close
                  end
                end
              end
            else
        dirname = local_path + remote_file.name
                unless File.directory?(dirname)
                  FileUtils.mkdir_p(dirname)
                end
                syncDirDown(env, sftp, ssh, local_path + remote_file.name + "/", remote_path + remote_file.name + "/")
            end
          end
        end

        # Compare the two files by MD5 Checksum
        def compare(ssh, local_file, remote_path)
          equals = false
          localMD5 = "#{Digest::MD5.hexdigest(local_file.read)}"
          ssh.exec! "md5sum #{remote_path}" do |ch, stream, data|
            if stream != :stderr
              remoteMD5 = data[0,32]
              if (localMD5 == remoteMD5)
              equals = true
              end
            end
          end
          return equals
        end
      end
    end
  end
end
