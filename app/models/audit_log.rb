require_relative 'base'

class AuditLog
  extend BaseModel

  attr_accessor :id, :user_id, :user_name, :action, :table_name,
                :record_id, :details, :ip, :created_at

  # Ações registradas
  ACTIONS = {
    'create'   => '➕ Criou',
    'update'   => '✏️ Editou',
    'delete'   => '🗑️ Deletou',
    'login'    => '🔐 Login',
    'logout'   => '🚪 Logout',
    'import'   => '📥 Importou',
    'backup'   => '💾 Backup',
    'password' => '🔑 Alterou senha'
  }.freeze

  def initialize(row)
    @id         = row['id'].to_i
    @user_id    = row['user_id']&.to_i
    @user_name  = row['user_name'] || 'Sistema'
    @action     = row['action']
    @table_name = row['table_name']
    @record_id  = row['record_id']&.to_i
    @details    = row['details']
    @ip         = row['ip']
    @created_at = row['created_at']
  end

  # ── Registro de auditoria ────────────────────────────────────────────────
  def self.record(user_id:, action:, table_name:, record_id: nil, details: nil, ip: nil)
    user_name = begin
      result = db.exec_params("SELECT name FROM users WHERE id = $1", [user_id])
      result.ntuples.zero? ? 'Desconhecido' : result[0]['name']
    rescue
      'Desconhecido'
    end

    db.exec_params(
      "INSERT INTO audit_logs (user_id, user_name, action, table_name, record_id, details, ip)
       VALUES ($1, $2, $3, $4, $5, $6, $7)",
      [user_id, user_name, action, table_name, record_id, details, ip]
    )
  rescue => e
    # Nunca deixa a auditoria derrubar a aplicação
    warn "[AuditLog] Erro ao registrar: #{e.message}"
  end

  # ── Consultas ────────────────────────────────────────────────────────────
  def self.all(limit: 200, offset: 0)
    result = db.exec_params(
      "SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT $1 OFFSET $2",
      [limit, offset]
    )
    result.map { |row| new(row) }
  end

  def self.by_user(user_id, limit: 100)
    result = db.exec_params(
      "SELECT * FROM audit_logs WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2",
      [user_id, limit]
    )
    result.map { |row| new(row) }
  end

  def self.by_table(table_name, limit: 100)
    result = db.exec_params(
      "SELECT * FROM audit_logs WHERE table_name = $1 ORDER BY created_at DESC LIMIT $2",
      [table_name, limit]
    )
    result.map { |row| new(row) }
  end

  def self.count
    db.exec("SELECT COUNT(*) FROM audit_logs")[0]['count'].to_i
  end

  # ── Helpers de exibição ──────────────────────────────────────────────────
  def action_label
    ACTIONS[@action] || @action
  end

  def table_label
    {
      'products'   => 'Produtos',
      'categories' => 'Categorias',
      'movements'  => 'Movimentações',
      'orders'     => 'Pedidos',
      'users'      => 'Usuários',
      'backups'    => 'Backups',
      'import'     => 'Importação',
      'session'    => 'Sessão'
    }[@table_name] || @table_name&.capitalize || '—'
  end

  def formatted_date
    return '—' unless @created_at
    Time.parse(@created_at.to_s).strftime('%d/%m/%Y %H:%M:%S')
  rescue
    @created_at.to_s
  end
end
