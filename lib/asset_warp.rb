require 'mini_magick'
require 'net/http'
require 'uri'

MiniMagick::Image.class_eval do
  def convert(*args)
    args.unshift(@path)
    args.push(@path)
    
    command = "convert #{args.join(' ')}"
    output = `#{command}`
    
    if $? != 0
      raise MiniMagickError, "ImageMagick command (#{command}) failed: Error Given #{$?}"
    else
      output
    end
  end
end

class AssetWarp
  def initialize(app, context)
    @app, @context = app, context
  end
  
  def call(env)
    if resolved_asset = @context.resolve(env)
      begin
        asset_url, profile_name = *resolved_asset
        uri = URI.parse(asset_url)
        
        begin
          res = Net::HTTP.start(uri.host, uri.port) { |http| http.get(uri.path) }
          raise unless Net::HTTPSuccess === res
        rescue => e
          return [502, {'Content-Type' => 'text/plain'}, 'Bad Gateway']
        end
        
        blob = Blob.new(res.body, res['Content-Type'])
        if  @context[profile_name].call(blob)
          [200, {'Content-Type' => blob.content_type}, blob.data]
        else
          [404, {'Content-Type' => 'text/plain'}, 'Not Found']
        end
        
      rescue
        [500, {'Content-Type' => 'text/plain'}, 'Internal Server Error']
      end
    else
      @app.call(env)
    end
  end
  
  autoload :Context,  File.dirname(__FILE__) + '/asset_warp/context'
  autoload :Blob,     File.dirname(__FILE__) + '/asset_warp/blob'
end