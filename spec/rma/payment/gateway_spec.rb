# frozen_string_literal: true

RSpec.describe Rma::Payment::Gateway do
  it "has a version number" do
    expect(Rma::Payment::Gateway::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
