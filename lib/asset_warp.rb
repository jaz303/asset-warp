require 'mime/types'
require 'mini_magick'
require 'net/http'
require 'uri'

MiniMagick::Image.class_eval do
  def convert(*args)
    args.unshift(@path)
    args.push(@path)
    raw_convert(*args)
  end
  
  def raw_convert(*args)
    command = "convert #{args.join(' ')}"
    output = `#{command}`
    
    if $? != 0
      raise ::MiniMagick::MiniMagickError, "ImageMagick command (#{command}) failed: Error Given #{$?}"
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
        asset, profile_name = *resolved_asset
        asset = URI.parse(asset) if asset.is_a?(String)
        
        case asset.scheme
        when 'http', 'https'
          # don't do sub-request for internal proxying, just rewrite env and
          # let it pass through
          if asset.host == env['SERVER_NAME'] && asset.port == env['SERVER_PORT'].to_i
            env['REQUEST_PATH'] = asset.path
            env['PATH_INFO']    = asset.path 
            env['REQUEST_URI']  = asset.request_uri
            env['QUERY_STRING'] = asset.query
            res = @app.call(env)
            return res unless res.first == 200
            data, content_type = res[2], res[1]['Content-Type']
          else
            begin
              res = Net::HTTP.start(asset.host, asset.port) { |http| http.get(asset.path) }
              raise unless Net::HTTPSuccess === res
              data, content_type = res.body, res['Content-Type']
            rescue StandardError
              return [502, {'Content-Type' => 'text/plain'}, 'Bad Gateway']
            end
          end
        when 'file'
          data = File.read(asset.path)
          mime_type_list = ::MIME::Types.type_for(asset.path)
          if mime_type_list.length > 0
            content_type = mime_type_list.first.to_s
          else
            content_type = 'application/octet-stream'
          end
        else
          raise "supported URI schemes are http, https and file"
        end
        
        blob = Blob.new(data, content_type)
        if @context[profile_name].call(blob)
          [200, {'Content-Type' => blob.content_type, 'Content-Length' => blob.data.length.to_s}, blob.data]
        else
          [404, {'Content-Type' => 'text/plain'}, 'Not Found']
        end
        
      rescue StandardError => e
        [500, {'Content-Type' => 'text/plain'}, 'Internal Server Error']
      end
    else
      @app.call(env)
    end
  end
  
  autoload :Context,  File.dirname(__FILE__) + '/asset_warp/context'
  autoload :Blob,     File.dirname(__FILE__) + '/asset_warp/blob'
  autoload :MIME,     File.dirname(__FILE__) + '/asset_warp/mime'
end