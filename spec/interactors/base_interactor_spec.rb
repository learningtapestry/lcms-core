# frozen_string_literal: true

require "rails_helper"

describe BaseInteractor do
  # Test implementation class
  class TestInteractor < BaseInteractor
    attr_reader :result

    def run
      @result = context[:value] * 2
    end
  end

  # Test implementation that fails
  class FailingInteractor < BaseInteractor
    def run
      fail!("Something went wrong")
      fail!("Another error")
    end
  end

  describe ".call" do
    it "creates an instance and calls run" do
      interactor = TestInteractor.call(value: 5)
      expect(interactor.result).to eq 10
    end

    it "returns the interactor instance" do
      interactor = TestInteractor.call(value: 5)
      expect(interactor).to be_a(TestInteractor)
    end
  end

  describe "#initialize" do
    it "sets the context" do
      interactor = TestInteractor.new({ key: "value" })
      expect(interactor.send(:context)).to eq({ key: "value" })
    end

    it "initializes errors as empty array" do
      interactor = TestInteractor.new({})
      expect(interactor.errors).to eq([])
    end

    it "sets options as instance variables" do
      interactor = TestInteractor.new({}, foo: "bar", baz: 123)
      expect(interactor.instance_variable_get(:@foo)).to eq "bar"
      expect(interactor.instance_variable_get(:@baz)).to eq 123
    end
  end

  describe "#success?" do
    context "when no errors occurred" do
      it "returns true" do
        interactor = TestInteractor.call(value: 5)
        expect(interactor.success?).to be true
      end
    end

    context "when errors occurred" do
      it "returns false" do
        interactor = FailingInteractor.call({})
        expect(interactor.success?).to be false
      end
    end
  end

  describe "#errors" do
    it "returns the list of errors" do
      interactor = FailingInteractor.call({})
      expect(interactor.errors).to eq(["Something went wrong", "Another error"])
    end
  end

  describe "#error_msg" do
    it "returns errors joined by comma" do
      interactor = FailingInteractor.call({})
      expect(interactor.error_msg).to eq("Something went wrong, Another error")
    end

    context "when no errors" do
      it "returns empty string" do
        interactor = TestInteractor.call(value: 5)
        expect(interactor.error_msg).to eq("")
      end
    end
  end

  describe "#run" do
    it "raises NotImplementedError when called on base class" do
      interactor = BaseInteractor.new({})
      expect { interactor.run }.to raise_error(NotImplementedError)
    end
  end

  describe "#fail!" do
    it "adds error to errors collection" do
      interactor = FailingInteractor.call({})
      expect(interactor.errors).to include("Something went wrong")
    end
  end
end
