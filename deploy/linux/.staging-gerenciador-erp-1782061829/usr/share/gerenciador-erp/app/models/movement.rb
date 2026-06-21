require_relative 'base'

class Movement
  extend BaseModel

  attr_accessor :id, :product_id, :product_name, :product_sku, :kind, :quantity, :reason, :reference, :created_at

  def initialize(row)
    @id           = row['id'].to_i
    @product_id   = row['product_id'].to_i
    @product_name = row['product_name']
    @product_sku  = row['product_sku']
    @kind         = row['kind']
    @quantity     = row['quantity'].to_i
    @reason       = row['reason']
    @reference    = row['reference']
    @created_at   = row['created_at']
  end

  def self.all
    result = db.exec(<<~SQL)
      SELECT
        m.*,
        p.name AS product_name,
        p.sku  AS product_sku
      FROM stock_movements m
      JOIN products p ON p.id = m.product_id
      ORDER BY m.created_at DESC
      LIMIT 200
    SQL
    result.map { |row| new(row) }
  end

  def self.filter(date_from: nil, date_to: nil, kind: nil)
    conditions = ["1=1"]
    values     = []

    if date_from
      values << date_from
      conditions << "m.created_at >= $#{values.size}::date"
    end
    if date_to
      values << date_to
      conditions << "m.created_at < ($#{values.size}::date + interval '1 day')"
    end
    if kind
      values << kind
      conditions << "m.kind = $#{values.size}"
    end

    sql = <<~SQL
      SELECT m.*, p.name AS product_name, p.sku AS product_sku
      FROM stock_movements m
      JOIN products p ON p.id = m.product_id
      WHERE #{conditions.join(' AND ')}
      ORDER BY m.created_at DESC
    SQL

    result = values.empty? ? db.exec(sql) : db.exec_params(sql, values)
    result.map { |row| new(row) }
  end

  def self.by_product(product_id)
    result = db.exec_params(<<~SQL, [product_id])
      SELECT m.*, p.name AS product_name, p.sku AS product_sku
      FROM stock_movements m
      JOIN products p ON p.id = m.product_id
      WHERE m.product_id = $1
      ORDER BY m.created_at DESC
    SQL
    result.map { |row| new(row) }
  end

  def self.create(product_id:, kind:, quantity:, reason: nil, reference: nil)
    db.exec_params(
      'INSERT INTO stock_movements (product_id, kind, quantity, reason, reference) VALUES ($1,$2,$3,$4,$5)',
      [product_id, kind, quantity.to_i, reason, reference]
    )
  end
end