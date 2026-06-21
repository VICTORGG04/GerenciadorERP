require 'ostruct'
require_relative '../models/order'

get '/orders' do
  @orders = Order.all
  erb :'orders/index'
end

get '/orders/new' do
  require_assistant!
  @products = Product.all
  erb :'orders/form'
end

post '/orders' do
  require_assistant!
  product_ids = Array(params[:product_id])
  quantities  = Array(params[:quantity])
  prices      = Array(params[:unit_price])

  items = product_ids.each_index.filter_map do |i|
    qty   = quantities[i].to_i
    price = prices[i].to_f
    pid   = product_ids[i].to_s
    next if pid.empty? || qty <= 0
    { product_id: pid.to_i, quantity: qty, unit_price: price }
  end

  if items.empty?
    @products = Product.all
    @error    = 'Adicione ao menos um item ao pedido.'
    halt erb(:'orders/form')
  end

  begin
    order_id = Order.create(
      customer: params[:customer],
      notes:    params[:notes],
      items:    items
    )
    redirect "/orders/#{order_id}"
  rescue => e
    @products = Product.all
    @error    = e.message
    erb :'orders/form'
  end
end

get '/orders/:id' do
  @order = Order.find(params[:id])
  halt 404, 'Pedido não encontrado' unless @order
  erb :'orders/show'
end

post '/orders/:id/confirm' do
  require_assistant!
  begin
    Order.confirm(params[:id])
    redirect "/orders/#{params[:id]}"
  rescue => e
    @order = Order.find(params[:id])
    @error = e.message
    erb :'orders/show'
  end
end

post '/orders/:id/cancel' do
  require_assistant!
  begin
    Order.cancel(params[:id])
    redirect "/orders/#{params[:id]}"
  rescue => e
    @order = Order.find(params[:id])
    @error = e.message
    erb :'orders/show'
  end
end

get '/quick_out' do
  require_assistant!
  @products = Product.all
  erb :'orders/quick_out'
end

post '/quick_out' do
  require_assistant!
  begin
    Order.quick_out(
      product_id: params[:product_id].to_i,
      quantity:   params[:quantity].to_i,
      reason:     params[:reason].to_s.strip
    )
    redirect '/quick_out?ok=1'
  rescue => e
    @products = Product.all
    @error    = e.message
    erb :'orders/quick_out'
  end
end
