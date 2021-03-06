# app/controllers/projects_controller.rb
class ProjectsController < ApplicationController
  before_action :project_params, only: %i[create update]
  before_action :project, except: %i[index new create]
  before_action :category, only: :index
  before_action :redirect, only: %i[edit update destroy], unless: -> { project_owner? }
  before_action :verify_public, :increment_viewcount, only: :show
  before_action :update_flag, only: :update, if: -> { flag_resolved? }

  # GET /projects
  def index
    @projects = Project.includes(:user).is_public

    @projects = @projects.not_flagged(current_user.id) unless current_user.admin

    @projects = case @category
                when 'recent'
                  @projects.most_recent
                when 'popular'
                  @projects.most_popular
                when 'discussed'
                  @projects.most_discussed
                else
                  raise "Unknown Project Category [#{@category}]"
                end

    @projects = @projects.search(search_params[:query]) if search_params[:query].present?
  end

  # GET /projects/:id
  def show
    @current_user_like = @project.likes.find_by(user: current_user)
    @count = @project.likes.count
    @tooltip = @project.likes.tooltip + (@count > 20 ? "\nand #{@count - 20} more..." : '')
    @project.likes.build(user: current_user, project: @project) unless @current_user_like
    @comments = @project.comments.originals
  end

  # GET /projects/new
  def new
    @project = Project.new

    render 'new'
  end

  # POST /projects
  def create
    @project = current_user.projects.create(project_params)

    if @project.valid?
      flash[:success] = 'Successfully created project!'
      redirect_to project_path(@project)
    else
      flash[:error] = 'Error creating project.'
      render 'new'
    end
  end

  # GET /projects/:id/edit
  def edit
    render 'edit'
  end

  # PUT /projects/:id
  def update
    @project.update(name: project_params[:name], summary: project_params[:summary],
                    public: project_params[:public], content: project_params[:content])

    flash[:success] = 'Successfully updated project!' if @project.valid?
    flash[:error] = 'Error updating project' unless @project.valid?

    redirect_to @project.valid? ? project_path(@project) : edit_project_path(@project)
  end

  # DELETE /projects/:id
  def destroy
    @project.destroy

    redirect_to projects_path, flash: success('delete')
  end

  private

  def project
    projects = Project.includes(:user, :comments, :likes)
    projects = projects.not_flagged(current_user.id) unless current_user.admin
    @project = projects.find(params[:id])
    @last_unresolved_flag = @project.last_unresolved_flag
  rescue ActiveRecord::RecordNotFound
    redirect_back(fallback_location: projects_path, flash: { error: 'Project was not found.' })
  end

  def project_params
    params.require(:project).permit(:name, :summary, :public, :content, :flag_comment, :flag_resolved)
  end

  def search_params
    params.permit(:query)
  end

  def category
    @categories = %w[recent popular discussed]
    @category = if params[:category].present? && @categories.include?(params[:category].downcase)
                  params[:category]
                else
                  'recent'
                end
  end

  def redirect
    redirect_back(fallback_location: projects_path, flash: { error: 'You cannot do that action.' })
  end

  def success(action)
    { success: "Project successfully #{action}d." }
  end

  def increment_viewcount
    return if project_owner?

    @project.update!(view_count: @project.view_count + 1)
  end

  def verify_public
    return if @project.public || current_user == @project.user

    redirect_back(fallback_location: projects_path, flash: { error: 'Project was not found.' })
  end

  def project_owner?
    @project.user == current_user
  end

  def flag_resolved?
    project_params[:flag_resolved].present? && !project_params[:flag_resolved].to_i.zero?
  end

  def update_flag
    @last_unresolved_flag.update!(user_resolved: true)
  end
end
