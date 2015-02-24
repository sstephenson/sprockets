require 'sprockets'

# Render dot format at
#   http://mdaines.github.io/viz.js/form.html

env = Sprockets::Environment.new

def p(from, to, label = nil)
  from = from.inspect.sub('/', '/\n')
  to = to.inspect.sub('/', '/\n')
  label = label.to_s.inspect
  puts "  #{from} -> #{to} [label=#{label}]"
end

puts "digraph {"
puts "  node [shape=plaintext];"
env.config[:registered_transformers].each do |from, values|
  if env.mime_types[from]
    label = env.config[:preprocessors][from].map { |p|
      p.respond_to?(:name) ? p.name : p.class.name
    }.join(", ")
    ext = env.mime_types[from][:extensions].first
    p("read #{ext}", from, label)
  end
  values.keys.each do |to|
    p(from, to)
  end
end
puts "}"
