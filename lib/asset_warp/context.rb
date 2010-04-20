class AssetWarp
  class Context
    attr_accessor :prefix
    
    def initialize(prefix = 'a')
      self.prefix = prefix
      @sources, @profiles = {}, {}
      profile 'original'
      yield self if block_given?
      self
    end
    
    def prefix=(new_prefix)
      new_prefix = new_prefix + '/' unless new_prefix[-1,1] == '/'
      new_prefix = '/' + new_prefix unless new_prefix[0,1] == '/'
      @prefix = new_prefix
    end
    
    def [](name)
      @profiles[name.to_s]
    end
    
    def resolve(env)
      path = env['REQUEST_PATH']
      if path.index(@prefix) == 0
        chunks = path[@prefix.length..path.length - 1].split('/')
        if chunks.length == 2 || chunks.length == 3
          if source = @sources[chunks[0]]
            if chunks[1] =~ source[:id]
              if chunks.length == 3 && chunks.last.length > 0
                profile = chunks.last
              else
                profile = source[:default_profile]
              end
              if @profiles.key?(profile)
                if source[:target].is_a?(String)
                  url = source[:target].gsub(':id', chunks[1])
                else
                  url = source[:target].call(chunks[1], env)
                end
                if url.is_a?(String) && url[0..0] == '/'
                  url = 'http://' + env['HTTP_HOST'] + url
                end
                return [url, profile]
              end
            end
          end
        end
      end
      nil
    end
    
    # e.g. map('assets', '/assets/:id/:profile')
    #      map('user_images', 'http://foobar.com/:id')
    #      map('foo') { |thing| }
    def map(asset_category, *args, &block)
      target = block_given? ? block : args.shift
      options = args.shift || {}
      unless (target.is_a?(Proc) || target.is_a?(String)) && options.is_a?(Hash)
        raise ArgumentError, "map expects string or block target and optional options hash"
      end
      options[:target] = target
      options[:id] ||= /^\d+$/
      options[:default_profile] ||= 'original'
      @sources[asset_category] = options
    end
    
    class Profile
      def initialize(block)
        @block = block
      end
      
      # apply profile to blob, return false if profile cannot be applied
      def call(blob)
        @block.call(blob) if @block
        true
      end
    end
    
    class ImageProfile < Profile
      def call(blob)
        if blob.web_safe_image?
          super
        else
          false
        end
      end
    end
    
    def profile(name, &block)
      add_profile(name, Profile.new(block))
    end
    
    def image_profile(name, &block)
      add_profile(name, ImageProfile.new(block))
    end
    
  private
  
    def add_profile(name, profile)
      name = name.to_s
      raise ArgumentError, "duplicate profile '#{name}'" if @profiles.key?(name)
      @profiles[name] = profile
    end
    
  end
end
