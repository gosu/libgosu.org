task :deploy do
  sh "ssh $PROJECTS_HOST 'cd #{ENV['PROJECTS_ROOT']}/libgosu.org && git pull --rebase'"
end

task :default => :deploy
