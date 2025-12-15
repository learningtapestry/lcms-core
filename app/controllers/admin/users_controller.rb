# frozen_string_literal: true

module Admin
  class UsersController < AdminController
    include Queryable

    before_action :find_user, except: %i(index new create)
    before_action :set_query_params # from Queryable

    QUERY_ATTRS = %i(
      access_code
      email
    ).freeze
    QUERY_ATTRS_KEYS = QUERY_ATTRS

    def index
      @query = query_struct(@query_params)
      @users = users(@query)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      @user.generate_password
      if @user.save
        @user.send_reset_password_instructions
        redirect_to admin_users_path, notice: t(".success", user: @user.email)
      else
        render :new
      end
    end

    def edit; end

    def update
      if @user.update(user_params)
        redirect_to admin_users_path, notice: t(".success", user: @user.email)
      else
        @url = admin_user_path(@user)
        render :edit
      end
    end

    def destroy
      @user.destroy
      redirect_to admin_users_path, notice: t(".success")
    end

    def reset_password
      @user.send_reset_password_instructions
      redirect_to admin_users_path, notice: t(".success")
    end

    private

    def find_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:access_code, :email, :name, :role)
    end

    def users(query)
      queryset = User.all
      queryset = queryset.where("access_code ILIKE ?", "%#{query.access_code}%") if query.access_code.present?
      queryset = queryset.where("email ILIKE ?", "%#{query.email}%") if query.email.present?
      queryset.order(id: :asc).paginate(page: params[:page])
    end
  end
end
