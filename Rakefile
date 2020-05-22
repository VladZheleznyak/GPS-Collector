require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.libs << '.'
  t.test_files = FileList['test/**/test_*.rb']
end

task :default => :test