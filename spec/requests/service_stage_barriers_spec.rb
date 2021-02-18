 require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to test the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator. If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails. There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.

RSpec.describe "/service_stage_barriers", type: :request do
  # ServiceStageBarrier. As you add validations to ServiceStageBarrier, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    skip("Add a hash of attributes valid for your model")
  }

  let(:invalid_attributes) {
    skip("Add a hash of attributes invalid for your model")
  }

  describe "GET /index" do
    it "renders a successful response" do
      ServiceStageBarrier.create! valid_attributes
      get service_stage_barriers_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      service_stage_barrier = ServiceStageBarrier.create! valid_attributes
      get service_stage_barrier_url(service_stage_barrier)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_service_stage_barrier_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "render a successful response" do
      service_stage_barrier = ServiceStageBarrier.create! valid_attributes
      get edit_service_stage_barrier_url(service_stage_barrier)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new ServiceStageBarrier" do
        expect {
          post service_stage_barriers_url, params: { service_stage_barrier: valid_attributes }
        }.to change(ServiceStageBarrier, :count).by(1)
      end

      it "redirects to the created service_stage_barrier" do
        post service_stage_barriers_url, params: { service_stage_barrier: valid_attributes }
        expect(response).to redirect_to(service_stage_barrier_url(ServiceStageBarrier.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new ServiceStageBarrier" do
        expect {
          post service_stage_barriers_url, params: { service_stage_barrier: invalid_attributes }
        }.to change(ServiceStageBarrier, :count).by(0)
      end

      it "renders a successful response (i.e. to display the 'new' template)" do
        post service_stage_barriers_url, params: { service_stage_barrier: invalid_attributes }
        expect(response).to be_successful
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) {
        skip("Add a hash of attributes valid for your model")
      }

      it "updates the requested service_stage_barrier" do
        service_stage_barrier = ServiceStageBarrier.create! valid_attributes
        patch service_stage_barrier_url(service_stage_barrier), params: { service_stage_barrier: new_attributes }
        service_stage_barrier.reload
        skip("Add assertions for updated state")
      end

      it "redirects to the service_stage_barrier" do
        service_stage_barrier = ServiceStageBarrier.create! valid_attributes
        patch service_stage_barrier_url(service_stage_barrier), params: { service_stage_barrier: new_attributes }
        service_stage_barrier.reload
        expect(response).to redirect_to(service_stage_barrier_url(service_stage_barrier))
      end
    end

    context "with invalid parameters" do
      it "renders a successful response (i.e. to display the 'edit' template)" do
        service_stage_barrier = ServiceStageBarrier.create! valid_attributes
        patch service_stage_barrier_url(service_stage_barrier), params: { service_stage_barrier: invalid_attributes }
        expect(response).to be_successful
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested service_stage_barrier" do
      service_stage_barrier = ServiceStageBarrier.create! valid_attributes
      expect {
        delete service_stage_barrier_url(service_stage_barrier)
      }.to change(ServiceStageBarrier, :count).by(-1)
    end

    it "redirects to the service_stage_barriers list" do
      service_stage_barrier = ServiceStageBarrier.create! valid_attributes
      delete service_stage_barrier_url(service_stage_barrier)
      expect(response).to redirect_to(service_stage_barriers_url)
    end
  end
end