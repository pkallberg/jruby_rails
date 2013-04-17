set :user, "nfs_cue"
set :group, "nfs_cue"
set :use_sudo, false


set :deploy_to, "/home/nfs_cue/#{application}"

role :web, "nfs_cue@centos-wind"                          # Your HTTP server, Apache/etc
role :app, "nfs_cue@centos-wind"                          # This may be the same as your `Web` server
role :db,  "nfs_cue@centos-wind", :primary => true # This is where Rails migrations will run
role :db,  "nfs_cue@centos-wind"

set :rails_env,   'production'