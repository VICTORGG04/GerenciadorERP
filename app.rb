require 'dotenv/load'
require 'sinatra'
require 'pg'
require 'bcrypt'
require 'openssl'
require 'base64'
require 'socket'
require 'ipaddr'
require 'securerandom'
require 'stripe'
require 'fileutils'
require 'json'

STORAGE_DIR = File.expand_path('storage', __dir__).freeze

# Chave pública Ed25519 — usada para verificar tokens assinados.
# A chave privada fica apenas com o desenvolvedor (chave_privada.pem, gitignored).
ED25519_PUBLIC_KEY = <<~'PEM'
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAhxK+waqxnEOL7liJJZ+I6yJyUVvWN/TvSQREDDS8NrI=
-----END PUBLIC KEY-----
PEM

# LICENSE_SECRET mantido apenas para validar tokens antigos (HMAC-SHA256).
# Tokens novos usam Ed25519.
LICENSE_SECRET = ENV.fetch('LICENSE_SECRET', '2e3ebbbfee26ec5a6d532212b4b02897ecbcec290d5019f3fea10546cdcf1e79').freeze

# ─── Banco de dados ───────────────────────────────────────────────────────────
DB = PG.connect(
  host:     ENV.fetch('DB_HOST',     '127.0.0.1'),
  dbname:   ENV.fetch('DB_NAME',     'gerenciador_estoque'),
  user:     ENV.fetch('DB_USER',     'victor'),
  password: ENV.fetch('DB_PASSWORD', '')
)

# ─── Models ───────────────────────────────────────────────────────────────────
require_relative 'app/models/category'
require_relative 'app/models/product'
require_relative 'app/models/movement'
require_relative 'app/models/order'
require_relative 'app/models/user'
require_relative 'app/models/audit_log'
require_relative 'app/models/import'
require_relative 'app/models/license'
require_relative 'app/models/subscription'

# ─── Configuração ─────────────────────────────────────────────────────────────
configure do
  set :views,         File.expand_path('app/views', __dir__)
  set :public_folder, File.expand_path('public', __dir__)
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET', SecureRandom.hex(64))
  set :bind, ENV.fetch('APP_HOST', '0.0.0.0')
  set :port, ENV.fetch('APP_PORT', 4568).to_i
  set :host_authorization, ->() do
    {
      permitted_hosts: [
        'localhost',
        '127.0.0.1',
        '::1',
        ENV.fetch('ALLOWED_HOST', 'servidoresdesktop.tail313560.ts.net')
      ],
      allow_if: ->(env) {
        host = Rack::Request.new(env).host
        IPAddr.new(host) rescue false
      }
    }
  end
end

# ─── Services ──────────────────────────────────────────────────────────────────
require_relative 'app/services/inventory/add_stock_service'
require_relative 'app/services/inventory/remove_stock_service'
require_relative 'app/services/inventory/adjust_stock_service'
require_relative 'app/services/backups/json_backup_service'
require_relative 'app/services/license/google_sheet_validator'
require_relative 'app/services/email_service'

# ─── Schedulers ───────────────────────────────────────────────────────────────
require_relative 'app/lib/backup_scheduler'
BackupScheduler.start!

require_relative 'app/lib/license_scheduler'
LicenseScheduler.start!

# ─── Helpers ──────────────────────────────────────────────────────────────────
def calculate_expiry(plan, interval)
  case interval
  when 'monthly' then Time.now.to_i + 30 * 86400
  when 'semiannual' then Time.now.to_i + 180 * 86400
  when 'lifetime' then Time.now.to_i + 100 * 365 * 86400
  else Time.now.to_i + 30 * 86400
  end
end

helpers do
  def h(text)
    Rack::Utils.escape_html(text.to_s)
  end

  def fmt_brl(value)
    return 'R$ 0,00' unless value
    "R$ #{'%.2f' % value.to_f}".gsub('.', ',')
  end

  def nav_active(path)
    request.path_info.start_with?(path) ? 'nav-active' : ''
  end

  def val(field, product, params_fallback)
    params_fallback&.[](field.to_s) || product&.send(field)
  end

  # ── Auth ──────────────────────────────────────────────────────────────────
  def current_user
    return nil unless session[:user_id]
    @current_user ||= User.find(session[:user_id])
  end

  def require_login!
    redirect '/login' unless current_user
  end

  # Somente Admin
  def require_admin!
    require_login!
    halt 403, erb(:'errors/forbidden') unless current_user&.admin?
  end

  # Admin ou Assistente
  def require_assistant!
    require_login!
    halt 403, erb(:'errors/forbidden') unless current_user&.can_edit?
  end

  def admin?
    current_user&.admin?
  end

  def assistant?
    current_user&.assistant?
  end

  def can_edit?
    current_user&.can_edit?
  end

  # ── Flash messages ─────────────────────────────────────────────────────────
  def flash(type, msg)
    session[:flash_type] = type
    session[:flash_msg]  = msg
  end

  def flash_msg
    msg  = session.delete(:flash_msg)
    type = session.delete(:flash_type) || 'info'
    return nil unless msg
    { type: type, msg: msg }
  end

  # ── Licença (Ed25519 + backward compat HMAC) ─────────────────────────────
  FREE_TRIAL_DAYS = 30

  def generate_free_trial!
    expires = Time.now.to_i + FREE_TRIAL_DAYS * 86400
    host = Socket.gethostname rescue 'unknown'
    identifier = "#{host}-#{SecureRandom.hex(4)}"
    data = "free.#{expires}.#{identifier}"
    sig = OpenSSL::HMAC.hexdigest('SHA256', LICENSE_SECRET, data)
    token = "#{data}.#{sig}"
    save_license_token!(token)
    token
  end

  def env_path
    prod_env = '/etc/gerenciador-erp/.env'
    return prod_env if File.exist?(prod_env) && File.writable?(prod_env)
    File.expand_path('.env', settings.root || __dir__)
  end

  def read_license_token
    p = env_path
    return nil unless File.exist?(p)
    File.readlines(p).each do |line|
      return $1.strip if line.strip =~ /\ALICENSE_TOKEN=(.+)\z/
    end
    nil
  rescue
    nil
  end

  def save_license_token!(token)
    p = env_path
    content = File.exist?(p) ? File.read(p) : File.read(File.expand_path('.env.example', settings.root || __dir__))
    if content =~ /^LICENSE_TOKEN=.*$/
      content.sub!(/^LICENSE_TOKEN=.*$/, "LICENSE_TOKEN=#{token}")
    else
      content += "\nLICENSE_TOKEN=#{token}\n"
    end
    File.write(p, content)
    @_license_token = nil
    @_current_plan = nil
  end

  # Valida um token string e retorna hash com dados ou nil.
  # Aceita:
  #   - Ed25519 (assinatura base64url, identificador pode conter dots)
  #   - HMAC-SHA256 legado (assinatura hex 64 chars)
  # Suporta identificadores com pontos (ex: CNPJ 12.345.678/0001-90)
  def validate_token(token)
    parts = token.to_s.split('.')
    return nil unless parts.length >= 3

    plan = parts[0]
    expires = parts[1]
    signature = parts[-1]
    identifier = parts.length > 3 ? parts[2..-2].join('.') : nil
    data = identifier ? "#{plan}.#{expires}.#{identifier}" : "#{plan}.#{expires}"

    if signature =~ /\A[a-f0-9]{64}\z/
      expected = OpenSSL::HMAC.hexdigest('SHA256', LICENSE_SECRET, data)
      return nil unless OpenSSL.secure_compare(expected, signature)
    else
      pub = OpenSSL::PKey.read(ED25519_PUBLIC_KEY)
      sig_bytes = Base64.urlsafe_decode64(signature)
      return nil unless pub.verify(nil, sig_bytes, data)
    end

    return nil if Time.now.to_i > expires.to_i

    {
      plan: plan,
      expires: Time.at(expires.to_i),
      identifier: identifier,
      license_ref: identifier&.match?(/\ALIC-\d+\z/i) ? identifier : nil
    }
  rescue ArgumentError, OpenSSL::PKey::PKeyError
    nil
  end

  def validate_license!
    @_license_data = validate_token(read_license_token)
    @_license_data&.dig(:plan)
  end

  def license_data
    validate_license! if @_license_data.nil?
    @_license_data
  end

  def license_holder
    data = license_data
    return nil unless data
    if data[:license_ref]
      info = license_info
      return info.company_name if info
    end
    data[:identifier]
  end

  def license_info
    ref = license_data&.dig(:license_ref)
    return nil unless ref
    License.find_by_ref(ref)
  rescue
    nil
  end

  def license_expires_at
    license_data&.dig(:expires)
  end

  def current_plan
    @_current_plan ||= validate_license! || 'free'
  end

  # Validação online via Google Sheets
  # Retorna true se OK, false se bloqueado, nil se sem planilha configurada
  def validate_online!
    return nil unless ENV['GOOGLE_SHEET_ID'] && ENV['GOOGLE_SHEET_CREDENTIALS']
    return nil unless File.exist?(ENV['GOOGLE_SHEET_CREDENTIALS'].to_s)

    token = read_license_token
    return nil unless token

    if GoogleSheetValidator.internet?
      result = GoogleSheetValidator.validate(token)
      if result[:valid] == false
        if result[:error] =~ /expirada|revogado|outra máquina/
          @_online_error = result[:error]
          return false
        end
        return true
      end
      GoogleSheetValidator.write_cache(token_hash: Digest::SHA256.hexdigest(token), valid: true)
      true
    else
      cache = GoogleSheetValidator.read_cache
      return false unless cache
      return false if cache[:token_hash] != Digest::SHA256.hexdigest(token)
      elapsed = Time.now.to_i - (cache[:cached_at] || 0)
      if elapsed > 86_400
        @_online_error = 'Sem conexão há mais de 24h'
        return false
      end
      true
    end
  end

  # ── Planos / Features ────────────────────────────────────────────────────
  FEATURES = {
    'free'       => %w[products dashboard import pwa],
    'gold'       => %w[products dashboard import pwa categories movements android quick_out users],
    'platinum'   => %w[products dashboard import pwa categories movements android quick_out orders reports backup audit users full_stock],
    'enterprise' => %w[products dashboard import pwa categories movements android quick_out orders reports backup audit users full_stock whitelabel source_code training]
  }.freeze

  MAX_PRODUCTS = { 'free' => 20, 'gold' => 500, 'platinum' => 999_999, 'enterprise' => 999_999 }.freeze
  MAX_USERS    = { 'free' => 1,  'gold' => 3,   'platinum' => 999_999, 'enterprise' => 999_999 }.freeze

  def feature?(name)
    FEATURES[current_plan]&.include?(name)
  end

  def max_products
    MAX_PRODUCTS[current_plan]
  end

  def max_users
    MAX_USERS[current_plan]
  end

  def plan_label
    { 'free' => 'Free', 'gold' => 'Gold', 'platinum' => 'Platinum', 'enterprise' => 'Enterprise' }[current_plan] || 'Free'
  end

  def plan_color(plan)
    { 'free' => '#565c7a', 'gold' => '#f59e0b', 'platinum' => '#6366f1', 'enterprise' => '#ef4444' }[plan] || '#565c7a'
  end

  # ── Auditoria ─────────────────────────────────────────────────────────────
  def audit(action, table, record_id: nil, details: nil)
    return unless current_user
    AuditLog.record(
      user_id:   current_user.id,
      action:    action,
      table_name: table,
      record_id: record_id,
      details:   details,
      ip:        request.ip
    )
  end
end

# ─── Proteção global ──────────────────────────────────────────────────────────
before do
  pass if request.path_info == '/license'
  pass if request.path_info.start_with?('/public')
  pass if request.path_info.start_with?('/login')
  pass if request.path_info.start_with?('/register')
  pass if request.path_info.start_with?('/webhooks')
  pass if request.path_info == '/stripe'
  pass if request.path_info.start_with?('/plans')
  pass if request.path_info.start_with?('/checkout')
  pass if request.path_info.start_with?('/payment')
  pass if request.path_info == '/success'
  pass if request.path_info.start_with?('/receipts')

  token = read_license_token

  # 1ª vez (sem token): gerar Free trial silenciosamente → permitir login
  if token.nil?
    generate_free_trial!
    @_license_data = validate_token(read_license_token)
    require_login!
    return
  end

  # Token existe: validar assinatura + expiry local
  plan = validate_license!
  if plan.nil?
    @expired_plan = token.split('.')[0] rescue ''
    @expired_at   = license_expires_at&.strftime('%d/%m/%Y') rescue ''
    session.clear
    redirect '/license'
  end

  # Token válido localmente: verificar Google Sheets (se configurado)
  online = validate_online!
  if online == false
    @expired_plan = token.split('.')[0] rescue ''
    @expired_at   = license_expires_at&.strftime('%d/%m/%Y') rescue ''
    session.clear
    flash 'error', @_online_error || 'Licença inválida — verifique o Google Sheets'
    redirect '/license'
  end

  require_login!
end

# ─── Proteção por plano ────────────────────────────────────────────────────────
before '/categories*' do
  halt 403, erb(:'errors/forbidden', layout: :layout) unless feature?('categories')
end

before '/movements*' do
  halt 403, erb(:'errors/forbidden', layout: :layout) unless feature?('movements')
end

before '/orders*' do
  halt 403, erb(:'errors/forbidden', layout: :layout) unless feature?('orders')
end

before '/quick_out*' do
  halt 403, erb(:'errors/forbidden', layout: :layout) unless feature?('quick_out')
end

before '/reports*' do
  halt 403, erb(:'errors/forbidden', layout: :layout) unless feature?('reports')
end

before '/backups*' do
  halt 403, erb(:'errors/forbidden', layout: :layout) unless feature?('backups')
end

before '/audit*' do
  halt 403, erb(:'errors/forbidden', layout: :layout) unless feature?('audit')
end

before '/users*' do
  halt 403, erb(:'errors/forbidden', layout: :layout) unless feature?('users')
end

# ─── Rotas ────────────────────────────────────────────────────────────────────
require_relative 'app/controllers/auth_controller'
require_relative 'app/controllers/dashboard_controller'
require_relative 'app/controllers/categories_controller'
require_relative 'app/controllers/products_controller'
require_relative 'app/controllers/movements_controller'
require_relative 'app/controllers/orders_controller'
require_relative 'app/controllers/reports_controller'
require_relative 'app/controllers/backups_controller'
require_relative 'app/controllers/audit_controller'
require_relative 'app/controllers/import_controller'
require_relative 'app/controllers/licenses_controller'
require_relative 'app/controllers/payments_controller'
require_relative 'app/controllers/webhooks_controller'

# ─── Rota para servir comprovantes ──────────────────────────────────────────
get '/receipts/:filename' do
  file = File.join(STORAGE_DIR, 'receipts', params[:filename])
  halt 404, 'Arquivo não encontrado' unless File.exist?(file)
  send_file file
end
