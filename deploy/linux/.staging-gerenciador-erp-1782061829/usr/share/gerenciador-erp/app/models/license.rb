require_relative 'base'

class License
  extend BaseModel

  PLANOS = %w[gold platinum enterprise].freeze

  def initialize(row)
    @id               = row['id'].to_i
    @license_ref      = row['license_ref']
    @plan             = row['plan']
    @status           = row['status']
    @company_name     = row['company_name']
    @cnpj             = row['cnpj']
    @address_street   = row['address_street']
    @address_number   = row['address_number']
    @address_complement = row['address_complement']
    @address_neighborhood = row['address_neighborhood']
    @address_city     = row['address_city']
    @address_state    = row['address_state']
    @address_zip      = row['address_zip']
    @contact_name     = row['contact_name']
    @contact_email    = row['contact_email']
    @contact_phone    = row['contact_phone']
    @notes            = row['notes']
    @license_token    = row['license_token']
    @expires_at       = row['expires_at']
    @activated_at     = row['activated_at']
    @created_at       = row['created_at']
    @updated_at       = row['updated_at']
  end

  attr_reader :id, :license_ref, :plan, :status, :company_name, :cnpj,
              :address_street, :address_number, :address_complement,
              :address_neighborhood, :address_city, :address_state,
              :address_zip, :contact_name, :contact_email, :contact_phone,
              :notes, :license_token, :expires_at, :activated_at, :created_at, :updated_at

  def expires_at_fmt
    Time.parse(@expires_at).strftime('%d/%m/%Y') rescue @expires_at
  end

  def plan_label
    { 'gold' => 'Gold', 'platinum' => 'Platinum', 'enterprise' => 'Enterprise' }[@plan] || @plan.capitalize
  end

  def status_label
    { 'active' => 'Ativa', 'expired' => 'Expirada', 'cancelled' => 'Cancelada' }[@status] || @status
  end

  def status_pill
    case @status
    when 'active'    then 'pill-green'
    when 'expired'   then 'pill-red'
    when 'cancelled' then 'pill-gray'
    else 'pill-gray'
    end
  end

  def self.all
    result = db.exec("SELECT * FROM licenses ORDER BY created_at DESC")
    result.map { |row| new(row) }
  end

  def self.find(id)
    result = db.exec_params("SELECT * FROM licenses WHERE id = $1", [id])
    return nil if result.ntuples.zero?
    new(result[0])
  end

  def self.find_by_ref(ref)
    result = db.exec_params("SELECT * FROM licenses WHERE license_ref = $1", [ref])
    return nil if result.ntuples.zero?
    new(result[0])
  end

  def self.create(params)
    ref = generate_ref
    db.exec_params(
      "INSERT INTO licenses (license_ref, plan, company_name, cnpj, address_street, address_number, address_complement, address_neighborhood, address_city, address_state, address_zip, contact_name, contact_email, contact_phone, notes, expires_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)",
      [ref, params[:plan], params[:company_name], params[:cnpj],
       params[:address_street], params[:address_number], params[:address_complement],
       params[:address_neighborhood], params[:address_city], params[:address_state],
       params[:address_zip], params[:contact_name], params[:contact_email],
       params[:contact_phone], params[:notes], params[:expires_at]]
    )
    find_by_ref(ref)
  end

  def self.update_token(id, token)
    db.exec_params(
      "UPDATE licenses SET license_token = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2",
      [token, id]
    )
  end

  def self.destroy(id)
    db.exec_params("DELETE FROM licenses WHERE id = $1", [id])
  end

  def self.generate_ref
    count = db.exec("SELECT COUNT(*) FROM licenses")[0]['count'].to_i + 1
    "LIC-#{count.to_s.rjust(3, '0')}"
  end


end
