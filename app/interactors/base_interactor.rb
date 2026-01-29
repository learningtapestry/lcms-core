# frozen_string_literal: true

# Base class for implementing the Interactor pattern.
#
# Interactors encapsulate business logic into single-purpose objects.
# Each interactor performs one specific task and reports success or failure.
#
# @abstract Subclass and override {#run} to implement custom business logic.
#
# @example Creating a custom interactor
#   class CreateUser < BaseInteractor
#     def run
#       user = User.new(context)
#       if user.save
#         @result = user
#       else
#         fail!(user.errors.full_messages.join(', '))
#       end
#     end
#
#     attr_reader :result
#   end
#
# @example Using an interactor
#   interactor = CreateUser.call(name: 'John', email: 'john@example.com')
#   if interactor.success?
#     puts "User created: #{interactor.result.id}"
#   else
#     puts "Error: #{interactor.error_msg}"
#   end
#
class BaseInteractor
  # Creates and executes the interactor in a single call.
  #
  # This is the primary entry point for running an interactor.
  # It instantiates the interactor with the given context and options,
  # then invokes the {#run} method.
  #
  # @param context [Hash, Object] the input data for the interactor
  # @param options [Hash] additional options to be set as instance variables
  # @return [BaseInteractor] the interactor instance after execution
  def self.call(context, options = {})
    interactor = new(context, options)
    interactor.run
    interactor
  end

  # Initializes a new interactor instance.
  #
  # @param context [Hash, Object] the input data for the interactor
  # @param options [Hash] additional options; each key-value pair becomes an instance variable
  def initialize(context, options = {})
    @context = context
    @errors = []
    options.each_pair do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  # @return [Array<String>] collection of error messages
  attr_reader :errors

  # Returns all error messages as a comma-separated string.
  #
  # @return [String] concatenated error messages
  def error_msg
    errors.join(", ")
  end

  # Checks whether the interactor completed without errors.
  #
  # @return [Boolean] true if no errors occurred, false otherwise
  def success?
    @errors.blank?
  end

  # Executes the interactor's business logic.
  #
  # @abstract Subclasses must implement this method with their specific logic.
  # @raise [NotImplementedError] if called on BaseInteractor directly
  # @return [void]
  def run
    raise NotImplementedError
  end

  protected

  # @return [Hash, Object] the input context passed during initialization
  attr_reader :context

  # Marks the interactor as failed by adding an error message.
  #
  # @param error [String] the error message to add
  # @return [Array<String>] the updated errors collection
  def fail!(error)
    @errors << error
  end
end
