get '/' do
  @products   = Product.all
  @categories = Category.all
  @movements  = Movement.all.first(10)

  @total_products     = @products.size
  @total_categories   = @categories.size
  @low_stock          = @products.select(&:low_stock?)
  @out_of_stock       = @products.select(&:out_of_stock?)
  @total_stock_value  = @products.sum(&:total_value)

  @products_by_category = Category.all.map do |c|
    { name: c.name, count: @products.count { |p| p.category_id == c.id }, color: c.color }
  end.select { |c| c[:count] > 0 }

  sql_movements = <<~SQL
    SELECT TO_CHAR(created_at, 'DD/MM') AS day,
           COALESCE(SUM(quantity) FILTER (WHERE kind = 'in'), 0) AS entrada,
           COALESCE(SUM(quantity) FILTER (WHERE kind = 'out'), 0) AS saida
    FROM stock_movements
    WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY DATE(created_at), TO_CHAR(created_at, 'DD/MM')
    ORDER BY MIN(created_at)
  SQL
  @movements_by_day = DB.exec(sql_movements).map do |r|
    [r['day'], r['entrada'].to_i, r['saida'].to_i]
  end

  sql_top = <<~SQL
    SELECT p.name, p.sku, COUNT(*) AS mov_count
    FROM stock_movements m
    JOIN products p ON p.id = m.product_id
    GROUP BY p.id, p.name, p.sku
    ORDER BY mov_count DESC
    LIMIT 5
  SQL
  @top_moved = DB.exec(sql_top).map { |r| OpenStruct.new(r) }

  @recent_orders = Order.all.first(5)

  erb :dashboard
end
