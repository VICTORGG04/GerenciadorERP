require_relative 'base'

class Subscription
  extend BaseModel

  attr_reader :id, :license_id, :stripe_subscription_id, :stripe_customer_id,
              :stripe_session_id, :plan, :interval, :status, :license_token,
              :current_period_start, :current_period_end,
              :created_at, :updated_at

  def initialize(row)
    @id = row['id'].to_i
    @license_id = row['license_id']&.to_i
    @stripe_subscription_id = row['stripe_subscription_id']
    @stripe_customer_id = row['stripe_customer_id']
    @stripe_session_id = row['stripe_session_id']
    @plan = row['plan']
    @interval = row['interval']
    @status = row['status']
    @license_token = row['license_token']
    @current_period_start = row['current_period_start']
    @current_period_end = row['current_period_end']
    @created_at = row['created_at']
    @updated_at = row['updated_at']
  end

  def self.create(params)
    db.exec_params(
      "INSERT INTO subscriptions (license_id, stripe_subscription_id, stripe_customer_id, stripe_session_id, plan, interval, status, license_token, current_period_start, current_period_end) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)",
      [params[:license_id], params[:stripe_subscription_id], params[:stripe_customer_id],
       params[:stripe_session_id], params[:plan], params[:interval], params[:status] || 'active',
       params[:license_token], params[:current_period_start], params[:current_period_end]]
    )
    find_by_customer(params[:stripe_customer_id])
  end

  def self.find(id)
    result = db.exec_params("SELECT * FROM subscriptions WHERE id = $1", [id])
    return nil if result.ntuples.zero?
    new(result[0])
  end

  def self.find_by_customer(customer_id)
    result = db.exec_params("SELECT * FROM subscriptions WHERE stripe_customer_id = $1 ORDER BY created_at DESC LIMIT 1", [customer_id])
    return nil if result.ntuples.zero?
    new(result[0])
  end

  def self.find_by_subscription(sub_id)
    result = db.exec_params("SELECT * FROM subscriptions WHERE stripe_subscription_id = $1", [sub_id])
    return nil if result.ntuples.zero?
    new(result[0])
  end

  def self.find_by_session(session_id)
    result = db.exec_params("SELECT * FROM subscriptions WHERE stripe_session_id = $1", [session_id])
    return nil if result.ntuples.zero?
    new(result[0])
  end

  def self.find_by_license(license_id)
    result = db.exec_params("SELECT * FROM subscriptions WHERE license_id = $1 ORDER BY created_at DESC LIMIT 1", [license_id])
    return nil if result.ntuples.zero?
    new(result[0])
  end

  def self.update_status(id, status)
    db.exec_params(
      "UPDATE subscriptions SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2",
      [status, id]
    )
  end

  def self.update_period(id, period_start, period_end)
    db.exec_params(
      "UPDATE subscriptions SET current_period_start = $1, current_period_end = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3",
      [period_start, period_end, id]
    )
  end

  def self.update_token(id, token)
    db.exec_params(
      "UPDATE subscriptions SET license_token = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2",
      [token, id]
    )
  end

  def self.destroy(id)
    db.exec_params("DELETE FROM subscriptions WHERE id = $1", [id])
  end
end
