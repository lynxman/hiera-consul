require 'puppetlabs_spec_helper/rake_tasks'

desc 'Start consul server for testing'
task :consul_dev do
  exec 'consul agent -config-file spec/fixtures/consul.json'
end

desc 'Start consul server for testing'
task :consul_ssl do
  exec 'consul agent -config-file spec/fixtures/consul_ssl.json'
end
