# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'color_pound_spec_reporter'
gem 'minitest'
gem 'minitest-reporters'
gem 'rack'

# Use postgresql as the database for Active Record
gem 'pg'

gem 'rgeo-geojson'

gem 'rubocop'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
end

group :development do
end
