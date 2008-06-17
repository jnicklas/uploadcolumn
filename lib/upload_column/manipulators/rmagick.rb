module UploadColumn
  
  UploadError = Class.new(StandardError) unless defined?(UploadError)
  ManipulationError = Class.new(UploadError) unless defined?(ManipulationError)
  
  module Manipulators
    
    module RMagick
      
      def load_manipulator_dependencies #:nodoc:
        require 'RMagick'
      end
      
      def process!(instruction = nil, &block)
        if instruction.is_a?(Proc)
          manipulate!(&instruction)
        elsif instruction.to_s =~ /^c(\d+x\d+)$/
          crop_resized!($1)
        elsif instruction.to_s =~ /^(\d+x\d+)$/
          resize!($1)
        end
        manipulate!(&block) if block
      end
      
      # Convert the image to format
      def convert!(format)
        manipulate! do |img|
          img.format = format.to_s.upcase
          img
        end
      end
      
      # Resize the image so that it will not exceed the dimensions passed
      # via geometry, geometry should be a string, formatted like '200x100' where
      # the first number is the height and the second is the width
      def resize!( geometry )
        manipulate! do |img|
          img.change_geometry( geometry ) do |c, r, i|
            i.resize(c,r)
          end
        end
      end

      # Resize and crop the image so that it will have the exact dimensions passed
      # via geometry, geometry should be a string, formatted like '200x100' where
      # the first number is the height and the second is the width
      def crop_resized!( geometry )
        manipulate! do |img|
          h, w = geometry.split('x')
          img.crop_resized(h.to_i,w.to_i)
        end
      end
      
      def manipulate!
        image = ::Magick::Image.read(self.path)
        
        if image.size > 1
          list = ::Magick::ImageList.new
          image.each do |frame|
            list << yield( frame )
          end
          list.write(self.path)
        else
          yield( image.first ).write(self.path)
        end
      rescue ::Magick::ImageMagickError => e
        # this is a more meaningful error message, which we could catch later
        raise ManipulationError.new("Failed to manipulate with rmagick, maybe it is not an image? Original Error: #{e}")
      end
      
    end
    
  end
  
end