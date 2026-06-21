require_relative 'base'

class Order
  extend BaseModel

  attr_accessor :id, :reference, :customer, :notes, :status, :total, :created_at, :items

  def initialize(row)
    @id         = row['id'].to_i
    @reference  = row['reference']
    @customer   = row['customer']
    @notes      = row['notes']
    @status     = row['status']
    @total      = row['total'].to_f
    @created_at = row['created_at']
    @items      = []
  end

  # ── Geração de referência automática ──────────────────────────────
  def self.next_reference
    date = Time.now.strftime('%Y%m%d')
    result = db.exec_params(
      "SELECT COUNT(*) FROM orders WHERE reference LIKE $1",
      ["PED-#{date}-%"]
    )
    seq = result[0]['count'].to_i + 1
    "PED-#{date}-#{'%04d' % seq}"
  end

  # ── Leitura ───────────────────────────────────────────────────────
  def self.all
    result = db.exec(<<~SQL)
      SELECT o.*,
             COUNT(oi.id) AS items_count
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      GROUP BY o.id
      ORDER BY o.created_at DESC
    SQL
    result.map { |row| new(row) }
  end

  def self.filter(date_from: nil, date_to: nil, status: nil)
    conditions = ["1=1"]
    values     = []

    if date_from
      values << date_from
      conditions << "o.created_at >= $#{values.size}::date"
    end
    if date_to
      values << date_to
      conditions << "o.created_at < ($#{values.size}::date + interval '1 day')"
    end
    if status
      values << status
      conditions << "o.status = $#{values.size}"
    end

    sql = <<~SQL
      SELECT o.*, COUNT(oi.id) AS items_count
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      WHERE #{conditions.join(' AND ')}
      GROUP BY o.id
      ORDER BY o.created_at DESC
    SQL

    result = values.empty? ? db.exec(sql) : db.exec_params(sql, values)
    result.map { |row| new(row) }
  end

  def self.find(id)
    result = db.exec_params('SELECT * FROM orders WHERE id = $1', [id])
    return nil if result.ntuples.zero?

    order = new(result[0])

    items = db.exec_params(<<~SQL, [id])
      SELECT oi.*,
             p.name AS product_name,
             p.sku  AS product_sku,
             p.quantity AS stock_available
      FROM order_items oi
      JOIN products p ON p.id = oi.product_id
      WHERE oi.order_id = $1
      ORDER BY oi.id
    SQL

    order.items = items.map { |r| OpenStruct.new(r.merge(
      'quantity'        => r['quantity'].to_i,
      'unit_price'      => r['unit_price'].to_f,
      'subtotal'        => r['subtotal'].to_f,
      'stock_available' => r['stock_available'].to_i
    ))}

    order
  end

  # ── Criação ───────────────────────────────────────────────────────
  # items: [{product_id:, quantity:, unit_price:}]
  def self.create(customer:, notes:, items:)
    raise ArgumentError, 'Nenhum item informado' if items.empty?

    reference = next_reference

    # Valida estoque antes de qualquer escrita
    items.each do |item|
      result = db.exec_params(
        'SELECT name, quantity FROM products WHERE id = $1', [item[:product_id]]
      )
      raise "Produto ##{item[:product_id]} não encontrado" if result.ntuples.zero?

      row = result[0]
      avail = row['quantity'].to_i
      qty   = item[:quantity].to_i

      if avail < qty
        raise "Estoque insuficiente para '#{row['name']}': disponível #{avail}, solicitado #{qty}"
      end
    end

    # Insere o pedido
    order_result = db.exec_params(<<~SQL, [reference, customer, notes])
      INSERT INTO orders (reference, customer, notes)
      VALUES ($1, $2, $3)
      RETURNING id
    SQL
    order_id = order_result[0]['id'].to_i

    total = 0.0

    items.each do |item|
      qty   = item[:quantity].to_i
      price = item[:unit_price].to_f

      db.exec_params(<<~SQL, [order_id, item[:product_id], qty, price])
        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
        VALUES ($1, $2, $3, $4)
      SQL

      total += qty * price
    end

    # Atualiza total no pedido
    db.exec_params('UPDATE orders SET total = $1 WHERE id = $2', [total, order_id])

    order_id
  end

  # ── Confirmar pedido = debitar estoque ────────────────────────────
  def self.confirm(id)
    order = find(id)
    raise 'Pedido não encontrado' unless order
    raise 'Pedido já confirmado ou cancelado' unless order.status == 'pending'

    # Revalida estoque no momento da confirmação
    order.items.each do |item|
      result = db.exec_params(
        'SELECT name, quantity FROM products WHERE id = $1', [item.product_id]
      )
      row   = result[0]
      avail = row['quantity'].to_i

      if avail < item.quantity
        raise "Estoque insuficiente para '#{row['name']}': disponível #{avail}, solicitado #{item.quantity}"
      end
    end

    # Debita estoque e registra movimentações
    order.items.each do |item|
      db.exec_params(
        'UPDATE products SET quantity = quantity - $1 WHERE id = $2',
        [item.quantity, item.product_id]
      )

      db.exec_params(<<~SQL, [item.product_id, item.quantity, order.reference, order.customer])
        INSERT INTO stock_movements (product_id, kind, quantity, reason, reference)
        VALUES ($1, 'out', $2, $3, $4)
      SQL
    end

    db.exec_params("UPDATE orders SET status = 'confirmed' WHERE id = $1", [id])
  end

  # ── Cancelar pedido ───────────────────────────────────────────────
  def self.cancel(id)
    order = find(id)
    raise 'Pedido não encontrado' unless order

    if order.status == 'confirmed'
      # Devolve estoque
      order.items.each do |item|
        db.exec_params(
          'UPDATE products SET quantity = quantity + $1 WHERE id = $2',
          [item.quantity, item.product_id]
        )
        db.exec_params(<<~SQL, [item.product_id, item.quantity, "Cancelamento #{order.reference}"])
          INSERT INTO stock_movements (product_id, kind, quantity, reason, reference)
          VALUES ($1, 'in', $2, $3, $4)
        SQL
      end
    end

    db.exec_params("UPDATE orders SET status = 'cancelled' WHERE id = $1", [id])
  end

  # ── Baixa rápida (sem pedido formal) ─────────────────────────────
  def self.quick_out(product_id:, quantity:, reason:)
    result = db.exec_params(
      'SELECT name, quantity FROM products WHERE id = $1', [product_id]
    )
    raise 'Produto não encontrado' if result.ntuples.zero?

    row   = result[0]
    avail = row['quantity'].to_i
    qty   = quantity.to_i

    if avail < qty
      raise "Estoque insuficiente para '#{row['name']}': disponível #{avail}, solicitado #{qty}"
    end

    ref = "BAIXA-#{Time.now.strftime('%Y%m%d%H%M%S')}"

    db.exec_params(
      'UPDATE products SET quantity = quantity - $1 WHERE id = $2',
      [qty, product_id]
    )

    db.exec_params(<<~SQL, [product_id, qty, reason, ref])
      INSERT INTO stock_movements (product_id, kind, quantity, reason, reference)
      VALUES ($1, 'out', $2, $3, $4)
    SQL
  end

  def pending?   = @status == 'pending'
  def confirmed? = @status == 'confirmed'
  def cancelled? = @status == 'cancelled'
end