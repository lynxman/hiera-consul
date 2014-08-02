# Hiera backend for Consul
class Hiera
  module Backend
    class Consul_backend

      def initialize
        require 'net/http'
        require 'net/https'
        require 'json'
        @config = Config[:consul]
        @consul = Net::HTTP.new(@config[:host], @config[:port])
        @consul.read_timeout = @config[:http_read_timeout] || 10
        @consul.open_timeout = @config[:http_connect_timeout] || 10

        if @config[:use_ssl]
          @consul.use_ssl = true

          if @config[:ssl_verify] == false
            @consul.verify_mode = OpenSSL::SSL::VERIFY_NONE
          else
            @consul.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end

          if @config[:ssl_cert]
            store = OpenSSL::X509::Store.new
            store.add_cert(OpenSSL::X509::Certificate.new(File.read(@config[:ssl_ca_cert])))
            @consul.cert_store = store

            @consul.key = OpenSSL::PKey::RSA.new(File.read(@config[:ssl_cert]))
            @consul.cert = OpenSSL::X509::Certificate.new(File.read(@config[:ssl_key]))
          end
        else
          @consul.use_ssl = false
        end
      end

      def lookup(key, scope, order_override, resolution_type)

        answer = nil

        # Extract multiple etcd paths from the configuration file
        paths = @config[:paths].map { |p| Backend.parse_string(p, scope, { 'key' => key }) }
        paths.insert(0, order_override) if order_override

        paths.each do |path|
          Hiera.debug("[hiera-consul]: Lookup #{path}/#{key} on #{@config[:host]}:#{@config[:port]}")
          if "#{path}/#{key}".match("//")
            Hiera.debug("[hiera-consul]: The specified path #{path}/#{key} is malformed, skipping")
            next
          end
          httpreq = Net::HTTP::Get.new("#{path}/#{key}")
          begin
            result = @consul.request(httpreq)
          rescue Exception => e
            Hiera.debug("[hiera-consul]: bad request key")
            raise Exception, e.message unless @config[:failure] == 'graceful'
            next
          end
          unless result.kind_of?(Net::HTTPSuccess)
            Hiera.debug("[hiera-consul]: bad http response from #{@config[:host]}:#{@config[:port]}#{path}")
            Hiera.debug("[hiera-consul]: HTTP response code was #{result.code}")
            next
          end
          Hiera.debug("[hiera-consul]: Answer was #{result.body}")
          answer = self.parse_result(result.body)
          next unless answer
          break
        end
        answer
      end

      def parse_result(res)
        require 'base64'
        answer = nil
        # Consul always returns an array
        res_array = JSON.parse(res)
        if res_array.is_a?(Array)
          answer = Base64.decode64(res_array.first['Value'])
        end
        answer
      end

    end
  end
end
