# app/controllers/comments_controller.rb
class CommentsController < ApplicationController
  before_action :project
  before_action :comment, except: :create

  # GET /projects/:project_id/comments/:id
  def show
    chain_array = []
    @comment.add_to_chain(chain_array)

    respond_to do |format|
      format.json { render json: chain_array.as_json, status: :ok }
    end
  end

  # POST /projects/:project_id/comments
  def create
    @project.comments.create!(comment_text: comment_params[:comment_text], user: current_user)
    redirect_to project_path(@project), flash: { success: 'Comment Added.' }
  rescue ActiveRecord::RecordInvalid
    redirect_to project_path(@project), flash: { error: 'Failed to add comment, please try again.' }
  end

  # PUT /projects/:project_id/comments/:id
  def update
    verify_author

    Comment.transaction do
      @new_comment = @project.comments.create!(comment_text: comment_params[:comment_text], user: current_user, replacing: @comment)
      @comment.update!(replaced_by: @new_comment)
    end

    redirect_to project_path(@project, anchor: "comment[#{@new_comment.id}]"), flash: { success: 'Comment updated.' }
  rescue ActiveRecord::RecordInvalid
    redirect_back(fallback_location: project_path(@project), flash: { error: 'Failed to update comment, please try again.' })
  end

  # DELETE /projects/:project_id/comments/:id
  def destroy
    verify_author unless current_user.admin

    @comment.destroy

    redirect_back(fallback_location: project_path(@project), flash: { success: 'Comment removed.' })
  end

  private

  def verify_author
    verification_redirect unless @comment.owner?(current_user)
  end

  def verification_redirect
    redirect_to project_path(@project), flash: { error: 'You do not have permission to do that.' }
  end

  def project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    redirect_back(fallback_location: projects_path, flash: { error: 'Project was not found.' })
  end

  def comment
    @comment = Comment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_back(fallback_location: project_path(@project), flash: { error: 'Comment was not found.' })
  end

  def comment_params
    params.require(:comment).permit(:comment_text)
  end
end
