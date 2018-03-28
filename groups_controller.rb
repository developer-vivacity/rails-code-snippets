class GroupsController < ApplicationController
  
  before_action :set_group, only: [:show, :edit, :update, :destroy] #get the data from set_group method and set that data in show,edit,update and destroy methods
  before_filter :authenticate_admin!, only: [:index] # only admin user can access the data of index method
  before_filter :authenticate_instructor! # only instructor type users are allowed to access

  require 'csv'
  require 'active_support/core_ext/date/conversions'

  
  def index
    @groups = Group.paginate(:page => params[:page]) #fetch the group data along with per page limit
  end

 
  def show
  
  end

  def new

    @group = Group.new #cretae a new group object in memory
    @group.stack_templates.build #create a new stack template object with that group in memory
  end

  def create
    if params[:class_project_name].present? and !params[:class_project_name].blank? and !params[:class_project_name].nil?# check all conditions with class_project_name attribute 
      if ClassProject.exists? title: params[:class_project_name] # class_project_name with title exists
          group_project_cat = ClassProject.find_by_title(params[:class_project_name]) # get class project data by title of that class project
          params["group"]["class_project_id"] = group_project_cat.id # id of group_project_cat will become the class_project_id of group
      else
         rr = ClassProject.new(title: params[:class_project_name]) #create new object for class project with that title
         if rr.save # save condition
          params["group"]["class_project_id"] = rr.id # id of saved class project will become the class_project_id of group
         end
      end
    end
    @group = Group.new(group_params) # create a new object for group with group parameters in memory
    
    respond_to do |format|
      if @group.save # is successfully saved in database 

        if @group.enable_stack_scheduler? && @group.enable_shutdown_only? 
          @vr_1 = @group.schd_shutdown_time # scheduled shutdown time of a group is stored in variable
        end

        if @group.enable_stack_scheduler? && @group.enable_startup_only?
          @vr_2 = @group.schd_startup_time # scheduled startup time of a group is stored in variable
        end



        if current_user.has_role? :instructor
          current_user.groups << @group
        end
        if @group.enable_start_time
          # Deleteting existing jobs
          @alljobsofgrp = Delayed::Job.where("handler LIKE '%name: #{@group.name}%'").where("handler LIKE '%method_name: :will_start_at_without_delay%'")
          if @alljobsofgrp.length > 0
            @alljobsofgrp.destroy_all
          end
          # Deleteting existing jobs

          @group.update_attribute(:status, false)
          @group.delay.will_start_at
        end
      
        if @group.enable_expire_time

          # Deleteting existing jobs
          @alljobsofgrp = Delayed::Job.where("handler LIKE '%name: #{@group.name}%'").where("handler LIKE '%method_name: :will_expire_on_without_delay%'")
          if @alljobsofgrp.length > 0
            @alljobsofgrp.destroy_all
          end
          # Deleteting existing jobs

          @group.delay.will_expire_on
        end
        if @group.lab_life_in_days.present?

          # Deleteting existing jobs
          @alljobsofgrp = Delayed::Job.where("handler LIKE '%name: #{@group.name}%'").where("handler LIKE '%method_name: :will_expire_on_without_delay%'")
          if @alljobsofgrp.length > 0
            @alljobsofgrp.destroy_all
          end
          # Deleteting existing jobs

          @group.delay(run_at: @group.lab_life_in_days.days.from_now).will_expire_on
        end

        if @group.enable_stack_scheduler? && @group.enable_shutdown_only?
          if @vr_1 != @group.schd_shutdown_time
              # Deleteting existing jobs
              @alljobsofgrp = Delayed::Job.where("handler LIKE '%name: #{@group.name}%'").where("handler LIKE '%method_name: :shutdown%'")
              if @alljobsofgrp.length > 0
                @alljobsofgrp.destroy_all
              end
              # Deleteting existing jobs

              if checkiffuture1.future?
               @group.delay(run_at: checkiffuture1,priority: -1).shutdown(@group) 
              end
          else
            flash[:alert] = "Already saved time for shutdown!! please change time and save again"
          end
        end

        if @group.enable_stack_scheduler? && @group.enable_startup_only?
          if @vr_2 != @group.schd_startup_time
            # Deleteting existing jobs
            @alljobsofgrp = Delayed::Job.where("handler LIKE '%name: #{@group.name}%'").where("handler LIKE '%method_name: :startup%'")
            if @alljobsofgrp.length > 0
              @alljobsofgrp.destroy_all
            end
            # Deleteting existing jobs
            if checkiffuture1.future?
              @group.delay(run_at: checkiffuture1,priority: -1).startup(@group)
            end
          else
            flash[:alert] = "Already saved time for startup !! please change time and save again"
          end
        end


        if current_user.has_role? :instructor
        format.html { redirect_to '/my_classes', notice: 'Class was successfully created.' }
        else
         format.html { redirect_to groups_path, notice: 'Class was successfully created.' }
        end
        format.json { render :show, status: :created, location: @group }
      else
        format.html { render :new }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
      user_id = User.where("group_id = ?", @group.id).pluck(:id) # Finding those user ids where group_id is equal to id of group
      @stack = Stack.where("user_id IN (?)", user_id) # Finding stacks of those user ids
      @stack_template_id = GroupStackTemplate.where("group_id = ?", @group.id).pluck(:stack_template_id) # finding stact template ids where group_id is equal to the id of group
      @stack_template = StackTemplate.where("id IN (?)", @stack_template_id) # finding those stack templates where ids are mapped with stack_template_id  
  end

  def update
    if params[:class_project_name].present? and !params[:class_project_name].blank? and !params[:class_project_name].nil? # class_project_name conditions
      if ClassProject.exists? title: params[:class_project_name]
          group_project_cat = ClassProject.find_by_title(params[:class_project_name]) # finding class project data by title
          params["group"]["class_project_id"] = group_project_cat.id # id of group_project_cat is also become the class_project_id of group
      else
         rr = ClassProject.new(title: params[:class_project_name]) # creating new object for class project i memory with title
         if rr.save
          params["group"]["class_project_id"] = rr.id # id of saved class project will become the class_project_id of group
         end
      end
    end
    respond_to do |format|
      if @group.enable_stack_scheduler? && @group.enable_shutdown_only?
        @vr_1 = @group.schd_shutdown_time
      end

      if @group.enable_stack_scheduler? && @group.enable_startup_only?
        @vr_2 = @group.schd_startup_time
      end

      if @group.update(group_params)

        if current_user.has_role? :instructor
        current_user.groups << @group
        end
        if @group.enable_start_time

          # Deleteting existing jobs
          @alljobsofgrp = Delayed::Job.where("handler LIKE '%name: #{@group.name}%'").where("handler LIKE '%method_name: :will_start_at_without_delay%'")
          if @alljobsofgrp.length > 0
            @alljobsofgrp.destroy_all
          end
          # Deleteting existing jobs

          @group.update_attribute(:status, false)

          if @group.will_start_on.present?
           timezone_of_group = @group.schd_timzone
           date_in_group_timezone = @group.will_start_on.in_time_zone(timezone_of_group)
           @group.will_start_on = date_in_group_timezone.in_time_zone('Pacific Time (US & Canada)')
           @group.delay.will_start_at
          end
        end
       
        if @group.enable_expire_time

          # Deleteting existing jobs
          @alljobsofgrp = Delayed::Job.where("handler LIKE '%name: #{@group.name}%'").where("handler LIKE '%method_name: :will_expire_on_without_delay%'")
          if @alljobsofgrp.length > 0
            @alljobsofgrp.destroy_all
          end
          # Deleteting existing jobs

          if @group.will_expires_on.present?
          
            timezone_of_group = @group.schd_timzone
            date_in_group_timezone = @group.will_expires_on.in_time_zone(timezone_of_group)
            @group.will_expires_on = date_in_group_timezone.in_time_zone('Pacific Time (US & Canada)')
         
            @group.delay.will_expire_on
          end

        end
        if @group.lab_life_in_days.present?

          # Deleteting existing jobs
          @alljobsofgrp = Delayed::Job.where("handler LIKE '%name: #{@group.name}%'").where("handler LIKE '%method_name: :will_expire_on_without_delay%'")
          if @alljobsofgrp.length > 0
            @alljobsofgrp.destroy_all
          end
          # Deleteting existing jobs

          @group.delay(run_at: @group.lab_life_in_days.days.from_now).will_expire_on
        end

        if @group.enable_stack_scheduler? && @group.enable_shutdown_only?
         
          if @vr_1 != @group.schd_shutdown_time
            # Deleteting existing jobs
            @alljobsofgrp = Delayed::Job.where("handler LIKE '%name: #{@group.name}%'").where("handler LIKE '%method_name: :shutdown%'")
            if @alljobsofgrp.length > 0
              @alljobsofgrp.destroy_all
            end
            # Deleteting existing jobs
            if checkiffuture1.future?
              @group.delay(run_at: checkiffuture1,priority: -1).shutdown(@group)
            end
          else
            flash[:alert] = "Already saved time for shutdown!! please change time and save again"
          end
        end

        if @group.enable_stack_scheduler? && @group.enable_startup_only?
        
          if @vr_2 != @group.schd_startup_time
            # Deleteting existing jobs
            @alljobsofgrp = Delayed::Job.where("handler LIKE '%name: #{@group.name}%'").where("handler LIKE '%method_name: :startup%'")
            if @alljobsofgrp.length > 0
              @alljobsofgrp.destroy_all
            end
            # Deleteting existing jobs
              if checkiffuture1.future?
                @group.delay(run_at: checkiffuture1,priority: -1).startup(@group)
              end
              
          else
            flash[:alert] = "Already saved time for startup !! please change time and save again"
          end
        end
        
        if current_user.has_role? :instructor
        format.html { redirect_to '/my_classes', notice: 'Class was successfully updated.' }
        else
         format.html { redirect_to groups_path, notice: 'Class was successfully updated.' }
        end
        format.json { render :show, status: :ok, location: @group }
      else
        format.html { render :edit }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @group.destroy # to delete a group
    respond_to do |format|
      format.html { redirect_to groups_url, notice: 'Class was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def instructor_groups
    @groups =  current_user.groups.paginate(:page => params[:page]) # all the group data of currently logged in user will generate along with per page limit 
  end


  def import
    if params[:file].present? # to check the presence of file

    csvimport = Group.import(params[:file],params[:group_id]) # to import the file and group_id from group

    if csvimport.length > 0
      invalidemail = csvimport.map(&:inspect).join("<br/>").html_safe # to check email is valid or not
      redirect_to params["created_for_group"], notice: "User imported successfully. <br> Record Skipped: #{invalidemail}"
    else
      redirect_to params["created_for_group"], notice: 'User imported successfully'
    end

    else
    redirect_to params["created_for_group"], notice: 'no csv file present'
    end
  end

  def time_in_timezone
    @timezone1 =  Time.now.in_time_zone(params[:timezone]).to_datetime # Finding the current date and time in specified timezone or timezone by parameter 
    respond_to do |format|
      format.json {  render json: { timezone: @timezone1 }          }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_group
      @group = Group.find(params[:id])
    end
    # Never trust parameters from the scary internet, only allow the white list through.
    def group_params
      params.require(:group).permit(:name, :desc, :will_expires_on, :class_project_id, :status, :maximum_stack_limit, :enable_stack_scheduler, :schd_timzone, :schd_shutdown_time, :schd_startup_time,:show_inputs,:enable_expire_time,:enable_start_time,:will_start_on,:maximum_number_of_users, :invite_code, :enable_startup_only, :enable_shutdown_only,:lab_life_in_days,:stack_template_id, stack_template_ids:[])
    end
end
