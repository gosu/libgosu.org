require "erb"

# Heavily inspired by http://stackoverflow.com/a/10241263
Page = Struct.new(:title, :basename) do
  def write
    File.open("#{basename}.html", "w") do |io|
      io.write render("layout")
    end
  end
  
  def render(template)
    content = File.read("erb/#{template}.html.erb")
    erb = ERB.new(content)
    erb.result(binding)
  end
end

PAGES = [
  Page.new("Hello", "index"),
  Page.new("Ruby", "ruby"),
  Page.new("C++ / iOS", "cpp"),
]

# We could use Rake rules here: http://www.virtuouscode.com/2014/04/23/rake-part-3-rules/
# ...but it doesn't really seem worth the effort, given that this task is super fast.
desc "Build all HTML pages"
task :build do
  PAGES.each &:write
end

desc "Deploy all HTML pages to libgosu.org (requires git commit/push)"
task :deploy => :build do
  sh "ssh $PROJECTS_HOST 'cd #{ENV['PROJECTS_ROOT']}/libgosu.org && git pull --rebase'"
end

task :default => :build
