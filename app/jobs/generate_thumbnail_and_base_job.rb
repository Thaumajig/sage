class GenerateThumbnailAndBaseJob < ActiveJob::Base
  queue_as :default

  # Generate a thumbnail for the given object.
  def perform(object_id, x, y)

    # Load object.
    object = DigitalObject.find(object_id)

    # Check if the object doesn't have a thumbnail base.
    if object.thumbnail_base.nil?

      # If this is the case, generate one.
      object.generate_thumbnail_base(object.location)
    end

    # If the thumbnail base is not a SVG image:
    if object.thumbnail_base !~ /\.svg\z/

      # Generate digest.
      digest = Digest::SHA256.hexdigest object.thumbnail_base

      # If the thumbnail hasn't already been generated:
      unless File.exist? "public/thumbnails/#{digest}_#{x}x#{y}.jpg"

        # Generate a thumbnail.
        object.generate_thumbnail(x, y, digest)
      end
    end
  end
end
