class ProjectsController < ApplicationController
  def new
    @project = Project.new
  end

  def create
    @project = Project.new(params[:project])
    if @project.save
      redirect_to root_path, :notice => "#{@project.name} successfully added."
    else
      flash[:error] = "There was a problem adding the project."
      render :action => :new
    end
  end

  def show
    @project = Project.find_by_name(params[:project_name])
    if @project.nil?
      render :text => 'Unknown project', :status => :not_found
    else
      @build = @project.latest_build
      respond_to do |format|
        format.html {}
        format.png do
          filename = status_to_filename(@project.last_complete_build_status)
          send_file File.join(Rails.public_path, "images/badge/#{filename}.png"), :disposition => 'inline', :content_type => Mime::Type.lookup_by_extension('png')
        end
      end
    end
  end

  def status_to_filename(status)
    return 'failed' if status == 'timeout'
    return status if ['passed', 'failed'].include?(status)
    return 'unknown'
  end

  def force
    project = Project.find_by_name(params[:project_name])
    if project
      project.force_build
      redirect_to :back
    else
      render :text => 'Unknown project', :status => :not_found
    end
  end

  def index
    respond_to do |format|
      format.json { render :json => Project.all.to_json(:except => [:created_at, :modified_at], :methods => [:activity, :last_complete_build_status]) }
    end
  end
end
