# frozen_string_literal: true

require 'rake/testtask'
require 'benchmark'
require './lib/processor'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.libs << '.'
  t.test_files = FileList['test/**/test_*.rb']
end

# TODO: in a real-life app it should be a dedicated lib/tasks/add_rnd_points.rb file
# https://edelpero.svbtle.com/everything-you-always-wanted-to-know-about-writing-good-rake-tasks-but-were-afraid-to-ask
desc 'Adds random points to the table'
task :add_rnd_points, [:amount] do |_, args|
  amount = args[:amount]&.to_i || 10_000

  points = {
    'Points' => Array.new(amount) do
      { 'type' => 'Point', 'coordinates' => [rand(-180...180), rand(-90...90)] }
    end
  }

  time = Benchmark.measure {
    Processor.add_points(points)
  }

  puts "#{amount} points added, realtime = #{time.real}s, #{(amount / time.real).to_i} points per second"

  # On my desktop the velocity is 30k points per second.
  # The polygon example from README.md takes ~2.2 seconds on 65k points
end

task default: :test
