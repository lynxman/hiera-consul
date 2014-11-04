module Puppet::Parser::Functions
  newfunction(:consul_info, :type => :rvalue, :doc => <<-EOS
Parse the incoming consul info and return a value
    EOS
  ) do |args|

    data  = args[0]
    field = args[1]

    if data.is_a?(Hash)
      return data[field]
    elsif data.is_a?(Array)
      myreturn = []
      data.each { |myhash|
        myreturn << myhash[field]
      }
      return myreturn
    end

  end
end
