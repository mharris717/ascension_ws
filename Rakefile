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