# frozen_string_literal: true

namespace :diagrammer do
  desc 'Generate a standalone HTML database diagram'
  task :generate, [:output] => :environment do |_task, args|
    output = args[:output] || Rails.root.join('dbdiagram.html')
    path = Diagrammer.generate(output: output)

    puts "Generated #{path}"
  end
end
