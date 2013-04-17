set :stages, %w(production staging)
set :default_stage, "production"
require 'capistrano/ext/multistage'
require 'bundler/capistrano'

set :application, "jruby_rails"


# set :scm, :git # You can set :scm explicitly or Capistrano will make an intelligent guess based on known version control directory names
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`
set :scm, :none
set :repository, "."
set :deploy_via, :copy

# if you want to clean up old releases on each deploy uncomment this:
after "deploy:restart",         "deploy:cleanup"

# Run rails database migrations after update:
after "deploy:update_code",     "deploy:migrate"


##########################################################################################
# RVM Tasks:
set :rvm_ruby_string, 'jruby-1.7.3@jruby_rails'
set :rvm_install_ruby_params, '--1.9'      # for jruby/rbx default to 1.9 mode

before 'deploy:setup', 'rvm:install_rvm'   # install RVM
before 'deploy:setup', 'rvm:install_ruby'  # install Ruby

require "rvm/capistrano"
##########################################################################################


#######################################################################
# Puma Tasks:
set :shared_children, shared_children << 'tmp/sockets'
require 'multi_json'
after 'deploy:stop', 'puma:stop'
after 'deploy:start', 'puma:start'
after 'deploy:restart', 'puma:restart'

_cset(:puma_cmd) { "#{fetch(:bundle_cmd, 'bundle')} exec puma" }
_cset(:pumactl_port) { 65534 }
_cset(:puma_state) { "#{shared_path}/sockets/puma.state" }
_cset(:puma_role) { :app }

_cset(:puma_params) { {
  'threads'       => '16:32',
  'environment'   => "#{fetch(:rails_env)}",
  'bind'          => "'unix://#{fetch(:shared_path)}/sockets/puma.sock'",
  'state'         => "#{fetch(:puma_state)}",
  'control'       => "'unix://#{fetch(:shared_path)}/sockets/pumactl.sock'",
  'control-token' => "foo"
  } }


namespace :puma do
  desc 'Start puma'
  task :start, :roles => lambda { fetch(:puma_role) }, :on_no_matching_servers => :continue do
    run "cd #{current_path} ; nohup #{fetch(:puma_cmd)} " + puma_params.map { |key, val| "--#{key} #{val}" }.join(' ') + " >> #{shared_path}/log/#{stage}.log 2>&1 &", :pty => false
  end

  desc 'Stop puma'
  task :stop, :roles => lambda { fetch(:puma_role) }, :on_no_matching_servers => :continue do
    run "curl --silent --request GET 'http://localhost:#{fetch(:pumactl_port)}/stop?token=#{puma_params['control-token']}'" do |channel, stream, data|
      begin
        puts data
        result = MultiJson.load(data, symbolize_keys: true)
        puts "Puma Application '#{application}' at '#{channel[:host]}' stopped successfully." if result[:status] == 'ok'
      rescue MultiJson::LoadError
        puts "Puma Application '#{application}' does not appear to be running at '#{channel[:host]}'."
      ensure
        run "rm -rf #{shared_path}/sockets/*.sock"
      end
    end
  end

  desc 'Restart puma'
  task :restart, :roles => lambda { fetch(:puma_role) }, :on_no_matching_servers => :continue do
    run "curl --silent --request GET 'http://localhost:#{fetch(:pumactl_port)}/restart?token=#{puma_params['control-token']}'" do |channel, stream, data|
      begin
        result = MultiJson.load(data, symbolize_keys: true)
        puts "Puma Application '#{application}' at '#{channel[:host]}' restarted successfully" if result[:status] == 'ok'
      rescue MultiJson::LoadError
        puts "Puma Application '#{application}' does not appear to be running at '#{channel[:host]}'... starting..."
        puma.start
      end
    end
  end
  
  desc "Status of the application"
  task :status, :roles => :app, :except => { :no_release => true } do
    run "curl --silent --request GET 'http://localhost:#{fetch(:pumactl_port)}/stats?token=#{fetch(:puma_control_token)}'" do |channel, stream, data|
      begin
        status = MultiJson.load(data, symbolize_keys: true)
        puts "Puma Application '#{application}' at '#{channel[:host]}' Thread Stats: Waiting: #{status[:backlog]}, Running: #{status[:running]}"
      rescue MultiJson::LoadError
        puts "Puma Application '#{application}' does not appear to be running at '#{channel[:host]}'"
      end
    end
  end
end

#####################################################
# Assets Tasks:

namespace :deploy do
  namespace :assets do
    task :precompile, :roles => assets_role, :except => { :no_release => true } do
      run <<-CMD.compact
        cd -- #{latest_release.shellescape} &&
        #{rake} RAILS_ENV=#{rails_env.to_s.shellescape} #{asset_env} assets:precompile
      CMD
    end
  end
end