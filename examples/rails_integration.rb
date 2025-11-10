# Example Rails integration

# app/models/payment.rb
class Payment < ApplicationRecord
  belongs_to :order
  belongs_to :user
  
  enum status: {
    pending: 0,
    authorized: 1,
    account_verified: 2,
    completed: 3,
    failed: 4,
    refunded: 5
  }
  
  validates :order_id, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :transaction_id, uniqueness: true, allow_nil: true
  
  def rma_client
    @rma_client ||= Rma::Payment::Gateway::Client.new
  end
  
  def authorize!
    response = rma_client.authorization.call(
      order.order_number,
      amount,
      user.email
    )
    
    update!(
      transaction_id: response["bfs_bfsTxnId"],
      status: :authorized,
      authorized_at: Time.current
    )
    
    response
  end
  
  def verify_account!(bank_id, account_no)
    response = rma_client.account_inquiry.call(
      transaction_id,
      bank_id,
      account_no
    )
    
    update!(
      status: :account_verified,
      account_holder_name: response["bfs_remitterName"],
      verified_at: Time.current
    )
    
    response
  end
  
  def complete!(otp)
    response = rma_client.debit_request.call(
      transaction_id,
      otp
    )
    
    update!(
      status: :completed,
      completed_at: Time.current
    )
    
    response
  end
end

# app/services/rma_payment_service.rb
class RmaPaymentService
  attr_reader :payment, :errors

  def initialize(payment)
    @payment = payment
    @errors = []
  end

  def process_authorization
    payment.authorize!
    true
  rescue Rma::Payment::Gateway::Error => e
    @errors << e.message
    payment.update(status: :failed, error_message: e.message)
    false
  end

  def process_account_verification(bank_id, account_no)
    payment.verify_account!(bank_id, account_no)
    true
  rescue Rma::Payment::Gateway::Error => e
    @errors << e.message
    payment.update(status: :failed, error_message: e.message)
    false
  end

  def process_completion(otp)
    payment.complete!(otp)
    true
  rescue Rma::Payment::Gateway::Error => e
    @errors << e.message
    payment.update(status: :failed, error_message: e.message)
    false
  end
end

# app/controllers/payments_controller.rb
class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :find_payment, except: [:create]

  def create
    @payment = current_user.payments.build(payment_params)
    @payment.order = current_order
    
    if @payment.save
      service = RmaPaymentService.new(@payment)
      
      if service.process_authorization
        redirect_to account_verification_payment_path(@payment)
      else
        flash[:error] = service.errors.join(', ')
        render :new
      end
    else
      render :new
    end
  end

  def account_verification
    # Show form for bank details
  end

  def verify_account
    service = RmaPaymentService.new(@payment)
    
    if service.process_account_verification(params[:bank_id], params[:account_no])
      redirect_to otp_verification_payment_path(@payment)
    else
      flash[:error] = service.errors.join(', ')
      render :account_verification
    end
  end

  def otp_verification
    # Show form for OTP
  end

  def complete
    service = RmaPaymentService.new(@payment)
    
    if service.process_completion(params[:otp])
      redirect_to payment_success_path(@payment)
    else
      flash[:error] = service.errors.join(', ')
      render :otp_verification
    end
  end

  private

  def find_payment
    @payment = current_user.payments.find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(:amount)
  end
end