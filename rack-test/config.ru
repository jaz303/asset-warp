#\ -p 3000

require File.dirname(__FILE__) + '/../lib/asset_warp'

# Create a context object describing our configuration
# Context objects allow multiple Asset Wrap instances to live inside a single process
context = AssetWarp::Context.new do |c|
  
  # Set Asset Warp to intercept all requests beginning with /a/
  # (can also be set via constructor - defaults to 'a')
  c.prefix = 'a'
  
  # Maps /a/img/foo.gif/profile-name to /images/foo.gif
  # The profile name is optional and in this case defaults to 'original'
  c.map 'img', '/images/:id', :id => /^[^\/]+$/, :default_profile => 'original'
  
  # Maps /a/files/foo.gif/profile-name to filesystem path
  # Note: you need to return a file:// URI
  # This example is insecure! For example only!
  c.map 'file', :id => /^[^\/]+$/,
                :default_profile => false,
                :only => %w(rounded-thumb main-image) do |asset_id, env|
    "file://" + File.expand_path(File.dirname(__FILE__)) + '/files/' + asset_id
  end
  
  # Define an image profile
  # Image profiles operate only on web-safe images
  # If they encounter any other content types they will return a 404
  c.image_profile 'rounded-thumb' do |b|
    b.crop_resize(50, 50)
    b.rounded_corners(15)
  end
  
  # Define a standard profile
  # Standard profiles operate on everything and, to be honest, aren't much use.
  # A single standard profile, 'original', is used internally as a no-op for viewing original asset
  c.profile 'main-image' do |b|
    if b.web_safe_image?
      b.resize!(400, 300)
    end
  end
  
end

use AssetWarp, context

# Serve our source images statically - Asset Warp proxies these
use Rack::Static, :urls => ["/images"], :root => "public"

# Dummy app
class MyApp
	def call(env)
		[ 200, {'Content-Type' => 'text/plain'}, env['REQUEST_PATH'] ]
	end
end

run MyApp.new
