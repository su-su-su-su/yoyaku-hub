# frozen_string_literal: true

module Users
  class PasswordsController < Devise::PasswordsController
    def create
      self.resource = resource_class.send_reset_password_instructions(resource_params)
      yield resource if block_given?

      if successfully_sent?(resource)
        respond_to do |format|
          format.html do
            redirect_to after_sending_reset_password_instructions_path_for(resource_name),
              status: :see_other, notice: t('devise.passwords.send_instructions')
          end
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end
  end
end
