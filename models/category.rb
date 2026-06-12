require_relative 'base'

class Category
  extend BaseModel

  attr_accessor :id, :name, :color, :products_count

  def initialize(row)
    @id             = row['id'].to_i
    @name           = row['name']
    @color          = row['color'] || '#6366f1'
    @products_count = row['products_count'].to_i
  end

  def self.all
    result = db.exec(<<~SQL)
      SELECT
        c.*,
        COUNT(p.id) AS products_count
      FROM categories c
      LEFT JOIN products p ON p.category_id = c.id
      GROUP BY c.id
      ORDER BY c.name ASC
    SQL
    result.map { |row| new(row) }
  end

  def self.find(id)
    result = db.exec_params('SELECT * FROM categories WHERE id = $1', [id])
    return nil if result.ntuples.zero?
    new(result[0])
  end

  def self.create(name:, color: '#6366f1')
    db.exec_params(
      'INSERT INTO categories (name, color) VALUES ($1, $2)',
      [name.to_s.strip, color || '#6366f1']
    )
  end

  def self.delete(id)
    db.exec_params('DELETE FROM categories WHERE id = $1', [id])
  end
end