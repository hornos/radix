module Radix
  module Plugins
	  def require_plugins(dir="plugins")
		  Find.find( File.dirname(__FILE__)+"/plugins" ) do |f|
        if File.file?(f)
          puts "loading plugin: #{File.basename(f)}"
          require_relative(f)
        end
      end
    end
  end
end
