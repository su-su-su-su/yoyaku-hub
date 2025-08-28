# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    # before_action :configure_sign_up_params, only: [:create]
    # before_action :configure_account_update_params, only: [:update]
    before_action :set_role, only: %i[new create]
    before_action :configure_sign_up_params, only: [:create]

    # GET /resource/sign_up
    def new
      build_resource({})
      if @role == 'stylist'
        render 'users/registrations/stylist_new'
      elsif @role == 'customer'
        render 'users/registrations/customer_new'
      else
        render :new
      end
    end

    # POST /resource
    def create
      build_resource(sign_up_params)
      resource.role = @role
      resource.save
      yield resource if block_given?
      if resource.persisted?
        handle_successful_signup
      else
        handle_failed_resource
      end
    end

    # GET /resource/edit
    # def edit
    #   super
    # end

    # PUT /resource
    def update
      if demo_mode? && current_user.email.include?('@example.com')
        redirect_back_with_toast(fallback_location: root_path, message: t('demo.profile_edit_disabled'), type: :error)
        return
      end
      super
    end

    # DELETE /resource
    # def destroy
    #   super
    # end

    # GET /resource/cancel
    # Forces the session data which is usually expired after sign
    # in to be expired now. This is useful if the user wants to
    # cancel oauth signing in/up in the middle of the process,
    # removing all OAuth session data.
    # def cancel
    #   super
    # end

    protected

    def set_role
      @role = if request.path.include?('stylists')
                'stylist'
              else
                'customer'
              end
    end

    def build_resource(hash = {})
      hash[:role] = @role
      super
    end

    def configure_sign_up_params
      devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
    end

    def after_sign_up_path_for(resource)
      if resource.role == 'stylist'
        edit_stylists_profile_path
      else
        edit_customers_profile_path

      end
    end

    private

    def handle_successful_signup
      if resource.active_for_authentication?
        handle_active_signup
      else
        handle_inactive_signup
      end
    end

    def handle_active_signup
      flash[:toast] = { message: I18n.t('devise.registrations.signed_up'), type: :success }
      sign_up(resource_name, resource)
      respond_with resource, location: after_sign_up_path_for(resource)
    end

    def handle_inactive_signup
      flash[:toast] =
        { message: I18n.t("devise.registrations.signed_up_but_#{resource.inactive_message}"), type: :info }
      expire_data_after_sign_in!
      respond_with resource, location: after_inactive_sign_up_path_for(resource)
    end

    def handle_failed_resource
      clean_up_passwords resource
      set_minimum_password_length
      render_registration_form
    end

    def render_registration_form
      case @role
      when 'stylist'
        render 'users/registrations/stylist_new', status: :unprocessable_entity
      when 'customer'
        render 'users/registrations/customer_new', status: :unprocessable_entity
      else
        render :new
      end
    end
    # If you have extra params to permit, append them to the sanitizer.
    # def configure_sign_up_params
    #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
    # end

    # If you have extra params to permit, append them to the sanitizer.
    # def configure_account_update_params
    #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
    # end

    # The path used after sign up.
    # def after_sign_up_path_for(resource)
    #   super(resource)
    # end

    # The path used after sign up for inactive accounts.
    # def after_inactive_sign_up_path_for(resource)
    #   super(resource)
    # end
  end
end
