require_relative 'base'
require 'bcrypt'

class User
  extend BaseModel

  attr_accessor :id, :name, :email, :role, :active, :created_at

  # Papéis disponíveis no sistema
  ROLES = {
    'admin'     => 'Administrador',
    'assistant' => 'Assistente',
    'operator'  => 'Operador'
  }.freeze

  def initialize(row)
    @id         = row['id'].to_i
    @name       = row['name']
    @email      = row['email']
    @role       = row['role']
    @active     = row['active'] == 't' || row['active'] == true
    @created_at = row['created_at']
  end

  # ── Autenticação ──────────────────────────────────────────────────────────
  def self.authenticate(email, password)
    result = db.exec_params(
      "SELECT * FROM users WHERE email = $1 AND active = true",
      [email.to_s.strip.downcase]
    )
    return nil if result.ntuples.zero?

    row  = result[0]
    hash = BCrypt::Password.new(row['password_hash'])
    return nil unless hash == password

    new(row)
  end

  # ── CRUD ──────────────────────────────────────────────────────────────────
  def self.all
    result = db.exec("SELECT * FROM users ORDER BY name ASC")
    result.map { |row| new(row) }
  end

  def self.find(id)
    result = db.exec_params("SELECT * FROM users WHERE id = $1", [id])
    return nil if result.ntuples.zero?
    new(result[0])
  end

  def self.create(name:, email:, password:, role: 'operator')
    hash = BCrypt::Password.create(password, cost: 12)
    db.exec_params(
      "INSERT INTO users (name, email, password_hash, role) VALUES ($1, $2, $3, $4)",
      [name.strip, email.strip.downcase, hash, role]
    )
  end

  def self.update(id:, name:, email:, role:)
    db.exec_params(
      "UPDATE users SET name=$1, email=$2, role=$3 WHERE id=$4",
      [name.strip, email.strip.downcase, role, id]
    )
  end

  def self.change_password(id:, password:)
    hash = BCrypt::Password.create(password, cost: 12)
    db.exec_params(
      "UPDATE users SET password_hash=$1 WHERE id=$2", [hash, id]
    )
  end

  def self.toggle_active(id)
    db.exec_params("UPDATE users SET active = NOT active WHERE id=$1", [id])
  end

  # Exclusão permanente do Banco de Dados
  def self.destroy(id)
    db.exec_params("DELETE FROM users WHERE id=$1", [id])
  end

  # ── Permissões ────────────────────────────────────────────────────────────

  # Acesso total
  def admin?
    @role == 'admin'
  end

  # Pode criar/editar produtos, categorias, movimentações e pedidos
  # Não pode: gerenciar usuários, acessar backups, deletar registros
  def assistant?
    @role == 'assistant'
  end

  # Somente consultas, movimentações e pedidos
  def operator?
    @role == 'operator'
  end

  # Admin ou Assistente podem fazer modificações
  def can_edit?
    admin? || assistant?
  end

  def active?
    @active
  end

  # Nome legível do papel
  def role_label
    ROLES[@role] || @role.capitalize
  end

  # Cor do badge do papel (para a interface)
  def role_color
    case @role
    when 'admin'     then 'danger'
    when 'assistant' then 'warning'
    when 'operator'  then 'info'
    else 'secondary'
    end
  end
end
