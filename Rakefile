require 'mharris_ext'

task :copy_ember do
  cmds = []
  cmds << "cd /code/orig/ascension_web"
  cmds << "bundle exec middleman build"
  cmds << "rm -rf /code/orig/ascension_ws/public"
  cmds << "cp -r /code/orig/ascension_web/build /code/orig/ascension_ws/public"

  cmd = cmds.join(" && ")
  puts cmd
  puts `#{cmd}`
end

task :heroku_push do
  ec "gt push heroku master"
end

task :bundle_install do
  ec "bundle install"
end

task :release => [:bundle_install,:copy_ember]