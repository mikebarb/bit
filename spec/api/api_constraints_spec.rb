require 'spec_helper'
require 'api_constraints'

RSpec.describe ApiConstraints do
  let(:api_constraints_v1) { ApiConstraints.new(version: 1, default: false) }
  let(:api_constraints_v2) { ApiConstraints.new(version: 2, default: true) }

  context "version in 'Accept' header" do
    it "matches ApiConstraints with same version" do
      request = double(host: 'bit3-micmac.c9users.io',
                       headers: {"Accept" => "application/vnd.bit3.v1"})
      expect(api_constraints_v1.matches?(request)).to eq(true)
    end

    it "does not match ApiConstraints with different version" do
      request = double(host: 'bit3-micmac.c9users.io',
                       headers: {"Accept" => "application/vnd.bit3.v2"})
      expect(api_constraints_v1.matches?(request)).to eq(false)
    end
  end
  context "version not present in 'Accept' header" do
    it "so default ApiConstraints invoked" do
      request = double(host: 'bit3-micmac.c9users.io')
      expect(api_constraints_v2.matches?(request)).to eq(true)
    end

    #it "so non-default ApiConstraints are not invoked" do
    #  request = double(host: 'bit3-micmac.c9users.io')
    #  expect(api_constraints_v1.matches?(request)).to eq(false)
    #end
  end

end
