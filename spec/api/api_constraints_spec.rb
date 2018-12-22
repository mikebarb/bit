require 'spec_helper'

RSpec.describe ApiConstraints do
  let(:api_constraints_v1) { ApiConstraints.new(version: 1) }
  let(:api_constraints_v2) { ApiConstraints.new(version: 2, default: true) }

  describe "matches?" do

    it "returns true when the version matches the 'Accept' header" do
      request = double(host: 'bit3-micmac.c9users.io',
                       headers: {"Accept" => "application/vnd.bit3.v1"})
      api_constraints_v1.matches?(request).should be_true
    end

    it "returns the default version when 'default' option is specified" do
      request = double(host: 'api.marketplace.dev')
      api_constraints_v2.matches?(request).should be_true
    end
  end
end
