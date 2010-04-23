class AssetWarp
  class Blob
    attr_reader :content_type
    
    def initialize(data, content_type)
      @data, @content_type = data, content_type
    end
    
    def extension
      if web_safe_image?
        MIME::WEB_SAFE_IMAGE_MAP[content_type]
      elsif pdf?
        'pdf'
      else
        raise
      end
    end
    
    def data
      @image ? @image.to_blob : @data
    end
    
    def image
      @image ||= ::MiniMagick::Image.from_blob(@data)
    end
    
    # Predicates
    
    def web_safe_image?
      MIME.web_safe_image?(content_type)
    end
    
    def pdf?
      MIME.pdf?(content_type)
    end
    
    def content_type
      @content_type
    end
    
    # Image Mutations
    
    # change format
    def format(new_format)
      image.format(new_format)
      @content_type = MIME.mime_type_for_format(new_format)
    end
    
    # reduce, maintaining aspect ratio
    def reduce(width, height)
      image.geometry "#{width}x#{height}>"
    end

    # reduce, don't maintain aspect ratio
    def reduce!(width, height)
      image.geometry "#{width}x#{height}>!"
    end

    # resize, maintaining aspect ratio
    def resize(width, height)
      image.geometry "#{width}x#{height}"
    end

    # resize, don't maintain aspect ratio
    def resize!(width, height)
      image.geometry "#{width}x#{height}!"
    end

    def crop(width, height, gravity = 'Center')
      image.combine_options do |c|
        apply_crop(c, width, height, gravity)
      end
    end

    def crop_resize(width, height, gravity = 'Center')
      image.combine_options do |c|
        c.geometry "x#{height}"
        c.geometry "#{width}<"
        apply_crop(c, width, height, gravity)
      end
    end

    def rounded_corners(radius, options = {})

      # FIXME: somebody please fix this
      if false && options[:color]
        command = <<-CODE
          "(" +clone -format png -threshold -1
            -draw 'fill #{options[:color]}FF polygon 0,0 0,#{radius} #{radius},0 fill #FFFFFF00 circle #{radius},#{radius} #{radius},0'
            "(" +clone -flip ")" -compose Multiply -composite
            "(" +clone -flop ")" -compose Multiply -composite
          ")" +matte -compose src -composite
        CODE
      else
        format 'png'
        command = <<-CODE
          "(" +clone -threshold -1
            -draw 'fill black polygon 0,0 0,#{radius} #{radius},0 fill white circle #{radius},#{radius} #{radius},0'
            "(" +clone -flip ")" -compose Multiply -composite
            "(" +clone -flop ")" -compose Multiply -composite
          ")" +matte -compose CopyOpacity -composite
        CODE
      end

      command.gsub!(/\n+/, ' ')
      image.convert command

    end
    
    def grayscale
      image.colorspace "Gray"
    end

    def negate
      image.negate
    end

  private

    def apply_crop(builder, width, height, gravity)
      builder.gravity gravity, '+repage'
      builder.crop "#{width}x#{height}+0+0!"
    end

  end
end