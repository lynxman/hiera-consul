# Hiera backend for Consul
class Hiera
  module Backend
    class Consul_backend

      def initialize()
        require 'net/http'
        require 'net/https'
        require 'json'
        @config = Config[:consul]
        if (@config[:host] && @config[:port])
          @consul = Net::HTTP.new(@config[:host], @config[:port])
        else
          raise "[hiera-consul]: Missing minimum configuration, please check hiera.yaml"
        end

        @consul.read_timeout = @config[:http_read_timeout] || 10
        @consul.open_timeout = @config[:http_connect_timeout] || 10
        @cache = {}

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

            @consul.key = OpenSSL::PKey::RSA.new(File.read(@config[:ssl_key]))
            @consul.cert = OpenSSL::X509::Certificate.new(File.read(@config[:ssl_cert]))
          end
        else
          @consul.use_ssl = false
        end
        build_cache!
      end

      def lookup(key, scope, order_override, resolution_type)

        answer = nil

        paths = @config[:paths].map { |p| Backend.parse_string(p, scope, { 'key' => key }) }
        paths.insert(0, order_override) if order_override

        paths.each do |path|
          if path == 'services'
            if @cache.has_key?(key)
              answer = @cache[key]
              return answer
            end
          end
          Hiera.debug("[hiera-consul]: Lookup #{path}/#{key} on #{@config[:host]}:#{@config[:port]}")
          # Check that we are not looking somewhere that will make hiera crash subsequent lookups
          if "#{path}/#{key}".match("//")
            Hiera.debug("[hiera-consul]: The specified path #{path}/#{key} is malformed, skipping")
            next
          end
          # We only support querying the catalog or the kv store
          if path !~ /^\/v\d\/(catalog|kv)\//
            Hiera.debug("[hiera-consul]: We only support queries to catalog and kv and you asked #{path}, skipping")
            next
          end
          answer = wrapquery("#{path}/#{key}")
          next unless answer
          break
        end
        answer
      end

      def parse_result(res)
          require 'base64'
          answer = nil
          if res == "null"
            Hiera.debug("[hiera-consul]: Jumped as consul null is not valid")
            return answer
          end
          # Consul always returns an array
          res_array = JSON.parse(res)
          # See if we are a k/v return or a catalog return
          if res_array.length > 0
            if res_array.first.include? 'Value'
              if res_array.first['Value'] == nil
                # The Value is nil so we return it directly without trying to decode it ( which would fail )
                return answer
              else
                answer = Base64.decode64(res_array.first['Value'])
              end
            else
              answer = res_array
            end
          else
            Hiera.debug("[hiera-consul]: Jumped as array empty")
          end
          return answer
      end

      private

      def token(path)
        # Token is passed only when querying kv store
        if @config[:token] and path =~ /^\/v\d\/kv\//
          return "?token=#{@config[:token]}"
        else
          return nil
        end
      end

      def wrapquery(path)

          httpreq = Net::HTTP::Get.new("#{path}#{token(path)}")
          answer = nil
          begin
            result = @consul.request(httpreq)
          rescue Exception => e
            Hiera.debug("[hiera-consul]: Could not connect to Consul")
            raise Exception, e.message unless @config[:failure] == 'graceful'
            return answer
          end
          unless result.kind_of?(Net::HTTPSuccess)
            Hiera.debug("[hiera-consul]: HTTP response code was #{result.code}")
            return answer
          end
          Hiera.debug("[hiera-consul]: Answer was #{result.body}")
          answer = parse_result(result.body)
          return answer
      end

      def build_cache!
          services = wrapquery('/v1/catalog/services')
          return nil unless services.is_a? Hash
          services.each do |key, value|
            service = wrapquery("/v1/catalog/service/#{key}")
            next unless service.is_a? Array
            service.each do |node_hash|
              node = node_hash['Node']
              node_hash.each do |property, value|
                # Value of a particular node
                next if property == 'ServiceID'
                unless property == 'Node'
                  @cache["#{key}_#{property}_#{node}"] = value
                end
                unless @cache.has_key?("#{key}_#{property}")
                  # Value of the first registered node
                  @cache["#{key}_#{property}"] = value
                  # Values of all nodes
                  @cache["#{key}_#{property}_array"] = [value]
                else
                  @cache["#{key}_#{property}_array"].push(value)
                end
              end
            end
          end
          Hiera.debug("[hiera-consul]: Cache #{@cache}")
      end

    end
  end
end
