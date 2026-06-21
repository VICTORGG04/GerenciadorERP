# controllers/reports_controller.rb

require 'csv'

get '/reports' do
  require_login!
  erb :reports
end

# ── Movimentações ─────────────────────────────────────────────────
get '/reports/movements' do
  require_login!

  date_from = params[:date_from].to_s.empty? ? nil : params[:date_from]
  date_to   = params[:date_to].to_s.empty?   ? nil : params[:date_to]
  kind      = params[:kind].to_s.empty?       ? nil : params[:kind]

  @movements = Movement.filter(date_from: date_from, date_to: date_to, kind: kind)
  @date_from = date_from
  @date_to   = date_to
  @kind      = kind

  erb :'reports/movements'
end

get '/reports/movements.csv' do
  require_login!

  date_from = params[:date_from].to_s.empty? ? nil : params[:date_from]
  date_to   = params[:date_to].to_s.empty?   ? nil : params[:date_to]
  kind      = params[:kind].to_s.empty?       ? nil : params[:kind]

  movements = Movement.filter(date_from: date_from, date_to: date_to, kind: kind)

  csv = CSV.generate(encoding: 'UTF-8') do |c|
    c << ['Data', 'Produto', 'SKU', 'Tipo', 'Quantidade', 'Motivo', 'Referência']
    movements.each do |m|
      c << [
        m.created_at.to_s[0, 16].gsub('T', ' '),
        m.product_name,
        m.product_sku,
        m.kind,
        m.quantity,
        m.reason,
        m.reference
      ]
    end
  end

  content_type 'text/csv; charset=utf-8'
  headers['Content-Disposition'] = "attachment; filename=\"movimentacoes_#{Date.today}.csv\""
  "\xEF\xBB\xBF" + csv  # BOM para Excel abrir UTF-8 corretamente
end

# ── Pedidos ───────────────────────────────────────────────────────
get '/reports/orders' do
  require_login!

  date_from = params[:date_from].to_s.empty? ? nil : params[:date_from]
  date_to   = params[:date_to].to_s.empty?   ? nil : params[:date_to]
  status    = params[:status].to_s.empty?     ? nil : params[:status]

  @orders    = Order.filter(date_from: date_from, date_to: date_to, status: status)
  @date_from = date_from
  @date_to   = date_to
  @status    = status

  erb :'reports/orders'
end

get '/reports/orders.csv' do
  require_login!

  date_from = params[:date_from].to_s.empty? ? nil : params[:date_from]
  date_to   = params[:date_to].to_s.empty?   ? nil : params[:date_to]
  status    = params[:status].to_s.empty?     ? nil : params[:status]

  orders = Order.filter(date_from: date_from, date_to: date_to, status: status)

  csv = CSV.generate(encoding: 'UTF-8') do |c|
    c << ['Referência', 'Data', 'Cliente', 'Status', 'Total (R$)']
    orders.each do |o|
      c << [
        o.reference,
        o.created_at.to_s[0, 16].gsub('T', ' '),
        o.customer,
        o.status,
        '%.2f' % o.total
      ]
    end
  end

  content_type 'text/csv; charset=utf-8'
  headers['Content-Disposition'] = "attachment; filename=\"pedidos_#{Date.today}.csv\""
  "\xEF\xBB\xBF" + csv
end

# ── Estoque mínimo / alertas ──────────────────────────────────────
get '/reports/low_stock' do
  require_login!
  @products = Product.all.select { |p| p.low_stock? || p.out_of_stock? }
  erb :'reports/low_stock'
end

get '/reports/low_stock.csv' do
  require_login!

  products = Product.all.select { |p| p.low_stock? || p.out_of_stock? }

  csv = CSV.generate(encoding: 'UTF-8') do |c|
    c << ['Produto', 'SKU', 'Categoria', 'Estoque Atual', 'Estoque Mínimo', 'Status']
    products.each do |p|
      status = p.out_of_stock? ? 'SEM ESTOQUE' : 'ESTOQUE BAIXO'
      c << [p.name, p.sku, p.category_name, p.quantity, p.min_quantity, status]
    end
  end

  content_type 'text/csv; charset=utf-8'
  headers['Content-Disposition'] = "attachment; filename=\"estoque_minimo_#{Date.today}.csv\""
  "\xEF\xBB\xBF" + csv
end