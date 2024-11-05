require 'rails_helper'

RSpec.describe "Customers", type: :request do
  describe "GET /dashboard" do
    it "returns http success" do
      get "/customers/dashboard"
      expect(response).to have_http_status(:success)
    end
  end

end
