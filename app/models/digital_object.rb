class DigitalObject < ActiveRecord::Base

  has_many :annotations, dependent: :destroy
  has_many :concepts, through: :annotations
  belongs_to :project

  validates :location, presence: true

  before_save :update_details, if: :location_changed?
  after_create :create_thumbnails

  # Map algorithms to names.
  ALGORITHMS = {
    '' => SAGA::Object,
    'SAGA' => SAGA::Object,
    'SAGA-Refined' => SAGA::Object_Refined,
    'Shuffle' => Shuffle::Object,
    'Annotated' => Annotated::Object,
    'None' => None::Object,
    'All' => All::Object,
    'Vote' => TagRecommendationStrategies::Vote,
    'VotePlus' => TagRecommendationStrategies::VotePlus,
    'Sum' => TagRecommendationStrategies::Sum,
    'SumPlus' => TagRecommendationStrategies::SumPlus
  }

  # Find entities by annotation.
  def related

    # Return the entities associated with this element.
    return concepts.to_a
  end

  # Wrap self in an algorithm.
  def algorithm(specific = nil)

    # Get algorithm name. Check specific for overrides, then project.
    name = specific || project.algorithm

    # If a valid algorithm name wasn't provided, use default.
    if !ALGORITHMS.key? name
      name = ""
    end

    # Return object.
    return ALGORITHMS[name].new(self)
  end

  # Check if valid algorithm has been provided.
  def valid_algorithm?(algorithm = project.algorithm)

    # True if blank or registered algorithm.
    return (!algorithm || (ALGORITHMS.key? algorithm))
  end

  # Get a thumbnail for the specified size and object.
  def thumbnail(x, y)

    # If the thumbnail hasn't been set for this object:
    if thumbnail_url.nil?

      # Generate thumbnail url.
      generate_thumbnail_url
    end

    # Retrieve a thumbnail for this object.
    Thumbnail.find_for(thumbnail_url, x, y)
  end

  # Check if the object's location is likely to be a link.
  def has_uri?

    # Compare location with a valid URI's regexp.
    return location =~ %r{\A#{URI::regexp}\z}
  end

  # Update the object's details when changing locations.
  def update_details

    # Check new location for needed conversions.
    check_conversions

    # Check for flattening.
    check_flatten

    # Update filename.
    set_filename

    # Update thumbnail.
    reset_thumbnail_url

    # Indicate save can continue.
    return true
  end

  # Private methods.
  private

  # Checks if a given location should be changed before saving, particularly
  # when using other services as content providers.
  def check_conversions

    # Define locations with ID captures.
    google_drive = %r{\Ahttps://drive.google.com/open\?id=(?<file_id>\w+)\z}
    google_apis = %r{\Ahttps://www.googleapis.com/drive/v2/files/(?<file_id>\w+)\z}

    # Check Google Drive locations.
    if (data = google_drive.match location)
      self.location = "https://docs.google.com/uc?id=#{data[:file_id]}"
    end

    # Check Google APIs locations.
    if (data = google_apis.match location)
      self.location = "https://docs.google.com/uc?id=#{data[:file_id]}"
    end
  end

  # Check if two or more objects shall be flattened:
  def check_flatten

    # Find all digital objects with the same project id and location.
    same_objects = DigitalObject.where(
      project_id: project_id,
      location: location
    ).to_a

    # Remove self.
    same_objects.delete(self)

    # If other objects have the same attributes:
    if same_objects.count > 0

      # For each object:
      same_objects.each do |same_object|

        # Flatten that object into this object.
        flatten(same_object)
      end
    end
  end

  # Set the filename for the object.
  def set_filename

    # If the source is not a URI:
    if location !~ %r{\A#{URI::regexp}\z}

      # Filename should be text.
      self.filename = location

    # The source is a URI.
    else

      # Attempt to fetch resource data.
      begin

        # Check if Google resource.
        if location =~ GoogleDriveUtils::GOOGLE_DOCS_REGEXP

          # Define regular expression.
          google_docs = %r{\Ahttps://docs.google.com/uc\?id=(?<file_id>\w+)\z}

          # Capture filename.
          data = google_docs.match location

          # Form APIs URL.
          apis_location = "https://www.googleapis.com/drive/v2/files/#{data[:file_id]}"

          # Fetch resource's information using key.
          information = RestClient.get(
            apis_location, { params: { key: ENV["GOOGLE_API_KEY"] } }
          )

          # Update filename based on resource information.
          self.filename = JSON.parse(information)["title"]

        # Otherwise, does not need an access key.
        else

          # Update filename based on resource information.
          self.filename = File.basename(location)
        end

      # Rescue in the event of an error.
      rescue RestClient::Exception

        # Use a missing filename.
        self.filename = "Missing"
      end
    end
  end

  # Resets the thumbnail url every time the location changes.
  def reset_thumbnail_url

    # Set thumbnail url to nil.
    self.thumbnail_url = nil

    # Allow save to continue.
    return true
  end

  # Generates this object's thumbnail URL.
  def generate_thumbnail_url

    # Initialise to default.
    self.thumbnail_url = location

    # Define locations with ID captures.
    wcl_location = %r{\Ahttps://docs.google.com/uc\?id=(?<file_id>\w+)\z}

    # Check Google locations.
    if (data = wcl_location.match location)
      self.thumbnail_url = "https://www.googleapis.com/drive/v2/files/#{data[:file_id]}"
    end

    # Commit changes.
    self.save
  end

  # Schedule for common thumbnail sizes to be created.
  def create_thumbnails

    # Create the common thumbnail sizes.
    Thumbnail::COMMON_SIZES.each do |size|
      thumbnail(size,size)
    end
  end

  # Flatten another digital object into this one.
  def flatten(other_object)

    # Go through the other object's annotations.
    Annotation.where(digital_object: other_object).each do |prospective|

      # Check if already annotated.
      unless concepts.include? prospective.concept

        # Modify annotation.
        prospective.update(digital_object_id: id)
      end
    end

    # Accept other object's thumbnail base (e.g. if a custom thumbnail base).
    thumbnail_url = other_object.thumbnail_url

    # Destroy the flattened object.
    other_object.destroy
  end
end
