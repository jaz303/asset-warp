Asset Warp
==========

&copy; 2010 Jason Frame [ [jason@onehackoranother.com](mailto:jason@onehackoranother.com) / [@jaz303](http://twitter.com/jaz303) ]  
Released under the MIT License.

Asset Warp is a Rack middleware for performing JIT image manipulation. It proxies incoming requests to arbitrary URLs (either internal or external) and applies named sets of transformations called "profiles".

Asset Warp was originally implemented as a Rails plugin and over the last three years has seen solid production use across many apps. This Rack extraction, however, should be considered alpha quality software until any kinks are ironed out.

Requirements
------------

  * A working ImageMagick installation
  * MiniMagick gem

The Basics
----------

The Asset Warp middleware (`AssetWarp`) is instantiated with a context object (`AssetWarp::Context`). A context is a configuration object and contains three things:

  * the URL prefix for assets to be handled by Asset Warp
  * a set of asset sources mapping incoming URLs to the URL of the original, unaltered, asset (original assets might reside on the same server, but it's not necessary)
  * a set of named profiles implementing the actual image transformations
  
The first thing to do is create a context, passing an optional block for customisation:

    context = AssetWarp::Context.new do |c|
      ...
    end

The URL prefix can be set either via the constructor, or with an explicit setter. The default
prefix is simply `'a'`.

    # Following two lines are equivalent and tell Asset Warp to intercept requests
    # whose path is prefixed by /assets/. Start/end slashes are optional, and prefix
    # may contain intermediate slashes.
    AssetWarp::Context.new('assets')
    context.prefix = '/assets/'
    
Next up are mappings. Asset Warp handles URLs with the format:

    $PREFIX/:source/:id[/:profile]

So an incoming request for `$PREFIX/avatars/2139/small` would map to the asset source `avatars`, with asset ID `2139` and profile `small`. If the original versions of our avatars were found at `/avatars/:id`, we'd set up the following mapping:

    c.map('avatars', '/avatars/:id')
    
Because of the leading slash, Asset Warp knows to prepend the request host/port. If the avatars were on another server, that's supported too:

    c.map('avatars', 'http://cdn.example.com/avatars/:id')
    
By default, Asset Warp requires that asset IDs be numeric and uses the `original` profile if the request path contains none. These defaults can be overridden:

    # Set a very permissive ID restriction and default to 'small' profile
    c.map('avatars', '/avatars/:id', :id => /^[^\/]+$/,
                                     :default_profile => 'small')
    
For situations where simple string substitutions don't cut it, a block form is supported too. The block receives the asset ID and Rack environment as parameters and should return the URL of the original asset:

    c.map('avatars') do |asset_id, env|
      "http://cdn.example.com/#{asset_id.upcase}"
    end

Profiles are the workhorses of Asset Warp, and are basically blocks that manipulate blobs. You define profiles with either the `profile` or `image_profile` methods; `image_profile()` will create a profile that operates only on images and returns a 404 for all other file types, whereas profiles created by `profile()` operates on all files:

    c.image_profile('thumb') do |blob|
      blob.crop_resize(100, 100)
    end
    
    # This profile is defined by default, no need to create it yourself
    c.profile('original') do |blob|
      # do nothing
    end

Finally, tell Rack to use the middleware:

    use AssetWarp, context
  
Blob Documentation
------------------

Profile blocks receive an instance of `AssetWarp::Blob` as their parameter. The following methods are available:

**Predicates:**

  * `web_safe_image?` - returns true if blob is a web-safe image (i.e. JPEG, GIF or PNG)
  * `pdf?` - returns true if blob is a PDF
  * `content_type` - returns MIME type of image

**Transformations:**

  * `reduce(width, height)` - reduce image, maintaining aspect-ratio; no-op if image is already smaller than target dimensions
  * `reduce!(width, height)` - as above, but does not maintain aspect-ratio
  * `resize(width, height)` - resize image, maintaining aspect-ratio
  * `resize!(width, height)` - resize image, not maintaining aspect-ratio
  * `crop(width, height, gravity = 'Center')` - crops image to a given size with configurable gravity
  * `crop_resize(width, height, gravity = 'Center')` - resizes image proportionally, then crops to match target dimensions
  * `rounded_corners(radius, options = {})` - add rounded corners to image; only valid option is `:color`
  * `grayscale` - convert image to grayscale.
  * `negate` - negate image colors

Example
-------

The repository contains a working test application in the `rack-test` directory. Just clone, `cd` and `rackup`. Once you're up and running, try these URLs:

    # Original files
    http://localhost:3000/a/img/berk.gif
    http://localhost:3000/a/img/clouds.jpg
    http://localhost:3000/a/img/test.txt
    
    # Original files (explicit profile)
    http://localhost:3000/a/img/berk.gif/original
    http://localhost:3000/a/img/clouds.jpg/original
    http://localhost:3000/a/img/test.txt/original
    
    # Thumbnails
    http://localhost:3000/a/img/berk.gif/rounded-thumb
    http://localhost:3000/a/img/clouds.jpg/rounded-thumb
    http://localhost:3000/a/img/test.txt/rounded-thumb
    
    # Main images
    http://localhost:3000/a/img/berk.gif/main-image
    http://localhost:3000/a/img/clouds.jpg/main-image
    http://localhost:3000/a/img/test.txt/main-image
    
Note the difference between requesting `test.txt` with the `rounded-thumb` and `main-image` profiles: `rounded-thumb` is declared as an image profile so it returns a 404 because `test.txt` is not an image. `main-image` is a standard profile so the text file is allowed to pass through unaltered.

Here's the `config.ru` that made this possible:

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
      c.map 'file', :id => /^[^\/]+$/ do |asset_id, env|
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

Hey, isn't this slow and inefficient?
-------------------------------------

Yes. Put a cache in front of it.

Hey, isn't this vulnerable to a cache-polluting DoS attack?
-----------------------------------------------------------

Yes. An attacker could request every possible asset/profile combination, regardless of whether your site actually referenced it, thus filling your cache with crap.

Is this really a problem? Your application might not have many assets/profiles, or it might use every asset/profile combination. In these cases, there's no reason to worry.

If it *is* a problem, there are a couple of possible solutions:

  * Restrict profile availability based on asset source. For example, avatars might only be needed in 2 sizes, so deny all other profiles. This one is on the TODO list.
  * Consult a whitelist to decide whether a profile can be applied. This is slightly more involved, but the basic idea is to insert a database row for each valid asset/profile combination - you'd probably write a helper to do this transparently in your view. Before proxying a request, Asset Warp would check for the corresponding row in the database, bailing out if it wasn't found (possible implementation: guard blocks on sources which return a boolean).

Known Issues
------------

  * rounded corners with background color don't work. My ImageMagick-fu ran out.
  
TODO
----

  * Gem release
  * PDF thumbnail generation
  * Refactor profiles to accept MIME-type constraints
  * Implement :only/:except rules for limiting profiles available to asset sources
  * Support loading context from file
  * Allow disabling of default profile
  * Write some tests?
  
Possible future improvements
----------------------------

  * Audio/video manipulation?
  * Render file-type icons based on content type? (or possibly redirect)
  