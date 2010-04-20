class AssetWarp
  module MIME
    WEB_SAFE_IMAGE_MAP = {
      'image/jpeg'  => 'jpg',
      'image/pjpeg' => 'jpg',
      'image/gif'   => 'gif',
      'image/png'   => 'png',
    }.freeze
    
    PDF = 'application/pdf'
    
    CONTENT_CLASSES = {
      :pdf => [PDF],
      :web_safe_image => WEB_SAFE_IMAGE_MAP.keys
    }
    
    def self.expand_content_class(symbol)
      CONTENT_CLASSES[symbol] || []
    end
    
    def self.pdf?(content_type)
      PDF == content_type
    end
    
    def self.web_safe_image?(content_type)
      WEB_SAFE_IMAGE_MAP.key?(content_type)
    end
  end
end