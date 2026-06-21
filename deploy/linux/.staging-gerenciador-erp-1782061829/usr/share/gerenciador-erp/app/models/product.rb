require_relative 'base'

class Product
  extend BaseModel

  attr_accessor :id, :name, :sku, :quantity, :price, :cost, :unit,
                :category_id, :category_name, :category_color,
                :min_quantity

  def initialize(row)
    @id             = row['id'].to_i
    @name           = row['name']
    @sku            = row['sku']
    @quantity       = row['quantity'].to_i
    @price          = row['price'].to_f
    @cost           = row['cost']&.to_f
    @unit           = row['unit'] || 'un'
    @category_id    = row['category_id']&.to_i
    @category_name  = row['category_name']
    @category_color = row['category_color']
    @min_quantity   = row['min_quantity']&.to_i || 0
  end

  def self.all
    result = db.exec(<<~SQL)
      SELECT
        p.*,
        c.name  AS category_name,
        c.color AS category_color
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      ORDER BY p.name ASC
    SQL
    result.map { |row| new(row) }
  end

  def self.find(id)
    result = db.exec_params(<<~SQL, [id])
      SELECT
        p.*,
        c.name  AS category_name,
        c.color AS category_color
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.id = $1
    SQL
    return nil if result.ntuples.zero?
    new(result[0])
  end

  def self.create(name:, sku:, quantity:, price:, category_id: nil, min_quantity: 0, cost: nil, unit: 'un')
    db.exec_params(
      'INSERT INTO products (name, sku, quantity, price, category_id, min_quantity, cost, unit) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)',
      [name, sku, quantity.to_i, price.to_f, category_id.to_s.empty? ? nil : category_id, min_quantity.to_i, cost.to_s.empty? ? nil : cost.to_f, unit]
    )
  end

  def self.update(id:, name:, sku:, price:, category_id: nil, min_quantity: 0, cost: nil, unit: 'un')
    db.exec_params(
      'UPDATE products SET name=$1, sku=$2, price=$3, category_id=$4, min_quantity=$5, cost=$6, unit=$7 WHERE id=$8',
      [name, sku, price.to_f, category_id.to_s.empty? ? nil : category_id, min_quantity.to_i, cost.to_s.empty? ? nil : cost.to_f, unit, id]
    )
  end

  def profit_margin
    margin
  end

  def self.delete(id)
    db.exec_params('DELETE FROM stock_movements WHERE product_id = $1', [id])
    db.exec_params('DELETE FROM products WHERE id = $1', [id])
  end

  def add_stock(qty)
    DB.exec_params('UPDATE products SET quantity = quantity + $1 WHERE id = $2', [qty.to_i, @id])
  end

  def remove_stock(qty)
    DB.exec_params('UPDATE products SET quantity = quantity - $1 WHERE id = $2', [qty.to_i, @id])
  end

  def set_stock(qty)
    DB.exec_params('UPDATE products SET quantity = $1 WHERE id = $2', [qty.to_i, @id])
  end

  def out_of_stock?
    @quantity <= 0
  end

  def low_stock?
    @quantity > 0 && @quantity <= @min_quantity
  end

  def total_value
    @quantity * @price
  end

  def total_cost
    @quantity * (@cost || 0)
  end

  def margin
    return nil if @cost.nil? || @cost <= 0 || @price <= 0
    ((@price - @cost) / @price * 100).round(1)
  end
end