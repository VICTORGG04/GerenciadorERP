require 'dotenv/load'
require 'sinatra'
require 'pg'
require 'bcrypt'
require 'openssl'

LICENSE_SECRET = ENV.fetch('LICENSE_SECRET', '2e3ebbbfee26ec5a6d532212b4b02897ecbcec290d5019f3fea10546cdcf1e79').freeze

# ─── Banco de dados ───────────────────────────────────────────────────────────
DB = PG.connect(
  host:     ENV.fetch('DB_HOST',     '127.0.0.1'),
  dbname:   ENV.fetch('DB_NAME',     'gerenciador_estoque'),
  user:     ENV.fetch('DB_USER',     'victor'),
  password: ENV.fetch('DB_PASSWORD', '')
)

# ─── Models ───────────────────────────────────────────────────────────────────
require_relative 'models/category'
require_relative 'models/product'
require_relative 'models/movement'
require_relative 'models/order'
require_relative 'models/user'
require_relative 'models/audit_log'
require_relative 'models/import'

# ─── Configuração ─────────────────────────────────────────────────────────────
configure do
  set :views,         File.expand_path('views', __dir__)
  set :public_folder, File.expand_path('public', __dir__)
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET', SecureRandom.hex(64))
  set :bind, ENV.fetch('APP_HOST', '0.0.0.0')
  set :port, ENV.fetch('APP_PORT', 4568).to_i
end

# ─── Services ──────────────────────────────────────────────────────────────────
require_relative 'services/inventory/add_stock_service'
require_relative 'services/inventory/remove_stock_service'
require_relative 'services/inventory/adjust_stock_service'
require_relative 'services/backups/json_backup_service'

# ─── Backup agendado ──────────────────────────────────────────────────────────
require_relative 'lib/backup_scheduler'
BackupScheduler.start!

# ─── Helpers ──────────────────────────────────────────────────────────────────
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

  # ── Licença HMAC ──────────────────────────────────────────────────────────
  def env_path
    prod_env = '/etc/gerenciador-erp/.env'
    return prod_env if File.exist?(prod_env)
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

  def validate_license!
    token = read_license_token
    return nil unless token

    parts = token.split('.')
    return nil unless parts.length == 3

    plan, expires, signature = parts
    data = "#{plan}.#{expires}"

    expected = OpenSSL::HMAC.hexdigest('SHA256', LICENSE_SECRET, data)
    return nil unless signature == expected
    return nil if Time.now.to_i > expires.to_i

    plan
  end

  def license_expires_at
    token = read_license_token
    return nil unless token
    parts = token.split('.')
    return nil unless parts.length == 3
    Time.at(parts[1].to_i)
  rescue
    nil
  end

  def current_plan
    @_current_plan ||= validate_license! || 'free'
  end

  # ── Planos / Features ────────────────────────────────────────────────────
  FEATURES = {
    'free'       => %w[products dashboard import pwa],
    'gold'       => %w[products dashboard import pwa categories movements android quick_out users],
    'platinum'   => %w[products dashboard import pwa categories movements android quick_out orders reports backup audit users full_stock],
    'enterprise' => %w[products dashboard import pwa categories movements android quick_out orders reports backup audit users full_stock whitelabel source_code training]
  }.freeze

  MAX_PRODUCTS = { 'free' => 50, 'gold' => 500, 'platinum' => 999_999, 'enterprise' => 999_999 }.freeze
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
  pass if request.path_info.start_with?('/login') && validate_license!

  plan = validate_license!
  unless plan
    if read_license_token
      @expired_plan = read_license_token.to_s.split('.')[0] rescue ''
      @expired_at   = license_expires_at&.strftime('%d/%m/%Y') rescue ''
      session.clear
    end
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
require_relative 'controllers/auth_controller'
require_relative 'controllers/dashboard_controller'
require_relative 'controllers/categories_controller'
require_relative 'controllers/products_controller'
require_relative 'controllers/movements_controller'
require_relative 'controllers/orders_controller'
require_relative 'controllers/reports_controller'
require_relative 'controllers/backups_controller'
require_relative 'controllers/audit_controller'
require_relative 'controllers/import_controller'
