module Puppet::Parser::Functions
  newfunction(:consul_info, :type => :rvalue, :doc => <<-EOS
Parse the incoming consul info and return a value
    EOS
  ) do |args|

    data  = args[0]
    field = args[1]
    if args[2]
      separator = args[2]
    else
      separator = ":"
    end
    debug("consul-info() :: Determined that my separator is \"#{separator}\"")

    if field.is_a?(Array)
      field_iterator = field
      debug("consul-info() :: Field is an Array, importing as it is #{field_iterator}")
    elsif field.is_a?(String)
      field_iterator = []
      field_iterator.push(field)
      debug("consul-info() :: Field is a text string, converting to array #{field_iterator}")
    elsif field.is_a?(Hash)
      raise(Puppet::ParseError, 'consul_info() does not accept a hash as your field argument')
    end

    if data.is_a?(Hash)
      myendstring = ""
      debug ("consul-info() :: Data is a hash")
      field_iterator.each do |myfield|
        myendstring << "#{data[myfield]}#{separator}"
      end
      myreturn = myendstring.gsub(/#{Regexp.escape(separator)}$/, '')
    elsif data.is_a?(Array)
      debug ("consul_info() :: Data is an array")
      myreturn = []
      data.each do |mydata|
        myendstring = ""
        field_iterator.each do |myfield|
          myendstring << "#{mydata[myfield]}#{separator}"
        end
        myreturn << myendstring.gsub(/#{Regexp.escape(separator)}$/, '')
      end
    else
      raise(Puppet::ParseError, "consul_info() does not know how to treat data #{data}")
    end

    debug("consul_info() returning #{myreturn}")
    return myreturn

  end
end
