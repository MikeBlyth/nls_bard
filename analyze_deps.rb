require 'bundler'

Bundler.load.dependencies.each do |dep|
  spec = dep.to_spec
  puts "#{spec.name} (#{spec.version}):"
  spec.dependencies.each do |sub_dep|
    puts "  #{sub_dep.name} (#{sub_dep.requirement})"
  end
  puts
end