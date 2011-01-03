class StatusesController < BaseController

  load_and_authorize_resource :status, :except => [:index]

  def create
    @status = Status.new(params[:status])

    @status.user = current_user

    respond_to do |format|
      if @status.save
        format.html { redirect_to :back }
        format.xml { render :xml => @status.to_xml }
        format.js
      else
        format.html {
          flash[:statuses_errors] = @status.errors.full_messages.to_sentence
          redirect_to :back
        }
        format.xml { render :xml => @status.errors.to_xml }
        format.js { render :template => 'statuses/errors', :locals => { :status => @status } }
      end
    end
  end

  def respond
    responds_to = Status.find(params[:id])
    @status = Status.new(params[:status])
    @status.in_response_to = responds_to
    @status.user = current_user

    respond_to do |format|
      if @status.save
        flash[:notice] = "Atividade enviada com sucesso"
      end
      format.js
    end
  end

  def index
    case params[:type]
    when 'User'
      @statusable = User.find(params[:id])
    when 'Space'
      @statusable = Space.find(params[:id])
    when 'Subject'
      @statusable = Subject.find(params[:id])
    end

    authorize! :read, @statusable

    @statuses = @statusable.recent_activity(params[:page])
    respond_to do |format|
      format.js
    end
  end

  def destroy
   @status.destroy
   # Deleta as respostas do Status
   Status.destroy_all(:in_response_to_id => @status.id,
                      :in_response_to_type => 'Status')
  end

end
