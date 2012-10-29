# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','radix','version.rb'])
spec = Gem::Specification.new do |s| 
  s.name = 'radix'
  s.version = Radix::VERSION
  s.author = 'Your Name Here'
  s.email = 'your@email.address.com'
  s.homepage = 'http://your.website.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'A description of your project'
# Add your other files here if you make them
  s.files = %w(
bin/radix
lib/radix/version.rb
lib/radix.rb
  )
  s.require_paths << 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc','radix.rdoc']
  s.rdoc_options << '--title' << 'radix' << '--main' << 'README.rdoc' << '-ri'
  s.bindir = 'bin'
  s.executables << 'radix'
  s.add_development_dependency('rake')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('aruba')
  s.add_development_dependency('pry')
  s.add_development_dependency('pusher')
  s.add_development_dependency('pusher-client')
  s.add_development_dependency('msgpack')
  s.add_development_dependency('ruby-xz')
  s.add_development_dependency('Ascii85')
  s.add_development_dependency('ohai')
  s.add_development_dependency('eventmachine')
  s.add_runtime_dependency('gli','2.4.1')
end
