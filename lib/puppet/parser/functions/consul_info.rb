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

    if field.is_a?(Array)
      field_iterator = field
    elsif field.is_a?(String)
      field_iterator = []
      field_iterator.push(field)
    elsif field.is_a?(Hash)
      raise(Puppet::ParseError, 'consul_info() does not accept a hash as your field argument')
    end

    if data.is_a?(Hash)
      myendstring = ""
      field_iterator.each do |myfield|
        myendstring << "#{data[myfield]}#{separator}"
      end
      return myendstring.gsub(/#{Regexp.escape(separator)}$/, '')
    elsif data.is_a?(Array)
      myreturn = []
      data.each do |mydata|
        myendstring = ""
        field_iterator.each do |myfield|
          myendstring << "#{mydata[myfield]}#{separator}"
        end
        myreturn << myendstring.gsub(/#{Regexp.escape(separator)}$/, '')
      end
      return myreturn
    end

  end
end
