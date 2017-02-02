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
        Hiera.debug("[hiera-consul]: Key = #{key}, Scope = #{scope.inspect}, Order_override = #{order_override.inspect}, Resoulution_type = #{resolution_type.inspect}")

        answer = nil

        paths = @config[:paths].map { |p| Backend.parse_string(p, scope, { 'key' => key }) }
        Hiera.debug("[hiera-consul] Initial paths = #{paths.inspect}")
        paths.insert(0, order_override) if order_override
        Hiera.debug("[hiera-debug] Overriden paths = #{paths.inspect}")

        if resolution_type == :hash
          recursive = true
        else
          recursive = false
        end
        Hiera.debug("[hiera-consul]: Recursive = #{recursive}")

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
          answer = wrapquery("#{path}/#{key}", recursive, resolution_type)
          next unless answer
          break
        end
        answer
      end

      def parse_result(res, res_type=nil)
          Hiera.debug("[hiera-consul]: res_type = #{res_type.inspect}")
          require 'base64'
          answer = nil
          if res == "null"
            Hiera.debug("[hiera-consul]: Jumped as consul null is not valid")
            return answer
          end
          Hiera.debug("[hiera-consul]: recursive = #{@recursive.inspect}")
          # Consul always returns an array
          res_array = JSON.parse(res)
          Hiera.debug("[hiera-consul]: res_array length = #{res_array.length}, contents = #{res_array.inspect}")
          # See if we are a k/v return or a catalog return
          if res_array.length > 0
            Hiera.debug("[hiera-consul]: First = #{res_array.first.inspect}")
            if res_array.first.include? 'Value'
              case res_type
              when :hash
                Hiera.debug("[hiera-consul]: Constructing hash response")
                answer = {}
                res_array.each do |hash|
                  Hiera.debug("[hiera-consul]: Processing entry: #{hash.inspect}")
                  value = !hash['Value'].nil? ? Base64.decode64(hash['Value']) : nil
                  answer[hash['Key']] = value
                end
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

      def wrapquery(path, recurse=false, res_type=nil)
        Hiera.debug("[hiera-consul]: wrapquery recursive = #{recurse}, res_type = #{res_type.inspect}")
        if recurse
          httpreq = Net::HTTP::Get.new("#{path}?recurse")
        else
          httpreq = Net::HTTP::Get.new("#{path}")
        end
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
          answer = parse_result(result.body, res_type)
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
              node_hash.each do |property, pvalue|
                # Value of a particular node
                next if property == 'ServiceID'
                unless property == 'Node'
                  @cache["#{key}_#{property}_#{node}"] = pvalue
                end
                unless @cache.has_key?("#{key}_#{property}")
                  # Value of the first registered node
                  @cache["#{key}_#{property}"] = pvalue
                  # Values of all nodes
                  @cache["#{key}_#{property}_array"] = [pvalue]
                else
                  @cache["#{key}_#{property}_array"].push(pvalue)
                end
              end
            end
          end
          Hiera.debug("[hiera-consul]: Cache #{@cache}")
      end

    end
  end
end
