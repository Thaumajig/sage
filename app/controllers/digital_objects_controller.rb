class DigitalObjectsController < ApplicationController
  before_action :set_project
  before_action :set_digital_object
  before_action :check_access

  layout 'control'

  helper ThumbnailHelper

  # Four images per row, seven rows.
  DEFAULT_PAGE_ITEMS = 28

  # GET /digital_objects
  # GET /digital_objects.json
  def index

    # Find the current page.
    page = current_page
    start_index = page * page_items
    end_index = start_index + page_items

    # Initialise previous and next pages.
    @previous_page = nil
    @next_page = nil

    # Determine if a previous page is possible.
    if page > 0
      @previous_page = page - 1
    end

    # Determine if a next page is possible.
    if end_index < @project.digital_objects.count
      @next_page = page + 1
    end

    # Retrieve a page of results or an empty array if none.
    @digital_objects = @project.object_index[start_index...end_index] || []
  end

  # GET /digital_objects/1
  # GET /digital_objects/1.json
  def show

    # New concept for quick create.
    @concept = Concept.new

    # Get object listing.
    items = @project.object_index

    # Get index of this object within listing.
    index = items.find_index(@digital_object)

    # Determine relative links.
    @index_page = index / page_items
    @random_item = items[Random.rand(items.count)].id
    @previous_item = nil
    @next_item = nil

    # Find previous item.
    if index > 0
      @previous_item = items[index - 1].id
    end

    # Find next item.
    if index < (items.count - 1)
      @next_item = items[index + 1].id
    end

    # Check valid algorithm.
    if !@digital_object.valid_algorithm?
      flash.now[:notice] = "The project's algorithm (#{@project.algorithm})"\
        " doesn't support objects. Using the default algorithm instead."
    end
  end

  # GET /digital_objects/new
  def new
    @digital_object = DigitalObject.new
    @have_google_authorisation = session[:access_token]
    # @google_authorisation_uri = GoogleDriveUtils.get_authorization_url(@project.id)
  end

  # GET /digital_objects/1/edit
  def edit
  end

  # POST /digital_objects
  # POST /digital_objects.json
  def create

    # Get location list.
    locations = digital_object_params[:location].lines

    # Flag to test whether new object could be saved.
    saved = true;

    # Modify params for each location, and use them to create objects.
    locations.each do |location|

      # Create digital object.
      saved &= DigitalObject.find_or_create_by(
        project_id: @project.id,
        location: location.chomp
      )
    end

    # Set notice.
    if locations.count > 1 && saved
      notice = "Digital objects were successfully created."
    elsif saved
      notice = "Digital object was successfully created."
    end

    respond_to do |format|
      if saved
        format.html { redirect_to project_digital_objects_path, notice: notice }
        format.json { render action: 'index', status: :created, location: @digital_object }
      else
        format.html { render action: 'new' }
        format.json { render json: @digital_object.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /digital_objects/1
  # PATCH/PUT /digital_objects/1.json
  def update
    respond_to do |format|
      if @digital_object.update(digital_object_params)
        format.html { redirect_to [@project, @digital_object], notice: 'Digital object was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @digital_object.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /digital_objects/1
  # DELETE /digital_objects/1.json
  def destroy
    @digital_object.destroy
    respond_to do |format|
      format.html { redirect_to project_digital_objects_url }
      format.json { head :no_content }
    end
  end

  # POST /objects/1/add_concept
  def add_concept
    set_concept

    unless @digital_object.concepts.include? @concept
      Annotation.create(
        digital_object_id: @digital_object.id,
        concept_id: @concept.id,
        user_id: session[:user_id],
        provenance: "Existing"
      )
    end

    respond_to do |format|
      format.html { redirect_to project_digital_object_path(@project, @digital_object) }
      format.js { render 'annotations.js.erb' }
    end
  end

  # POST /objects/1/add_created_concept
  def add_created_concept

    # Details.
    details = params.require(:concept).permit(:description)
    details[:project_id] = @project.id

    # Create new concept.
    @concept = Concept.match_or_create(details)

    # Attempt to save.
    if @concept

      # Associate new concept with this object.
      unless @digital_object.concepts.include? @concept
        Annotation.create(
          digital_object_id: @digital_object.id,
          concept_id: @concept.id,
          user_id: session[:user_id],
          provenance: "New"
        )
      end

      # Redirect with success.
      redirect_to project_digital_object_path(@project, @digital_object)
    else

      # Redirect with failure.
      redirect_to project_digital_object_path(@project, @digital_object),
        notice: 'Concept was not able to be created.'
    end
  end

  # POST /objects/1/remove_object
  def remove_concept
    set_concept

    if @digital_object.concepts.include? @concept
      @digital_object.concepts.destroy @concept
    end

    respond_to do |format|
      format.html { redirect_to project_digital_object_path(@project, @digital_object) }
      format.js { render 'annotations.js.erb' }
    end
  end

  # POST /objects/1/import_drive_folder
  def import_drive_folder

    # Get the specified folder.
    folder = params[:drive_folder]

    begin

      # Import folder.
      notice = GoogleDriveUtils.import_drive_folder(
        folder,
        @project.id,
        session[:access_token]
      )

    rescue ExpiredAuthError

      # Set notice and expire access_token.
      notice = "Your authorisation of SAGE to access Google Drive has " +
        "expired. Please renew authorisation to continue."
      session[:access_token].delete
    end

    # Redirect to object listing.
    redirect_to project_digital_objects_path(@project),
      notice: notice
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_digital_object

      # If params contains an id:
      if params[:id]

        # Check if the object exists.
        if DigitalObject.exists?(params[:id])

          # Set the digital object.
          @digital_object = DigitalObject.find(params[:id])
        else

          # Redirect on error.
          flash[:alert] = "The specified object was not found."
          redirect_to project_digital_objects_path(@project)
        end
      end
    end

    def set_concept
      @concept = Concept.find(params[:concept_id])
    end

    def set_project

      # Check if the project exists.
      if Project.exists?(params[:project_id])

        # Set the project.
        @project = Project.find(params[:project_id])
      else

        # Redirect on error.
        flash[:alert] = "The specified project was not found."
        redirect_to projects_path
      end
    end

    # Get the role of the user in this project.
    def set_user_role
      @user_role = UserRole.find_by(user_id: session[:user_id], project_id: params[:project_id])
    end

    # Find the number of page items.
    def page_items

      # Check if the user is a viewer.
      if @user_role.position.eql? "Viewer"
        return DEFAULT_PAGE_ITEMS
      else

        # Leave room for create button.
        return DEFAULT_PAGE_ITEMS - 1
      end
    end

    # Check authorisation before access.
    def check_access

      # Check if the user is logged in.
      if !@user
        flash[:notice] = "You are not logged in. Please log in to continue."
        redirect_to login_users_path
        return false
      end

      # Get the user's role in this project.
      set_user_role

      # Check user's role.
      if @user_role.nil?

        # User doesn't have a role in this project.
        flash[:notice] = "You don't have access to this project."
        redirect_to projects_path
        return false
      end

      # Define priviledges.
      view = ["show", "index"]
      annotate = ["add_concept", "remove_concept", "add_created_concept"]
      edit = ["new", "create", "update", "edit", "destroy",
        "import_drive_folder"]

      # Allocate priviledges to roles.
      priviledges = {
        "Viewer" => view,
        "Annotator" => view + annotate,
        "Contributor" => view + annotate + edit,
        "Administrator" => view + annotate + edit
      }

      # Allow requests with correct permissions.
      if priviledges[@user_role.position].include? params[:action]
        return true
      end

      # Otherwise, no permissions.
      redirect_to "/403.html"
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def digital_object_params
      params.require(:digital_object).permit(:location)
    end

    # Find the index of the first object in this page.
    def current_page

      # Clean and retrieve page param.
      /(?<page>\d+)/ =~ params[:page]

      # Check for no page.
      if !page

        # Default to zero.
        page = 0
      end

      # Return page.
      return page.to_i
    end
end
