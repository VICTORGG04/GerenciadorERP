get '/products' do
  @products   = Product.all
  @categories = Category.all
  erb :'products/index'
end

get '/products/new' do
  require_assistant!
  @categories = Category.all
  erb :'products/form'
end

get '/products/:id' do
  @product    = Product.find(params[:id])
  @categories = Category.all
  halt 404, 'Produto não encontrado' unless @product
  erb :'products/show'
end

get '/products/:id/edit' do
  require_assistant!
  @product    = Product.find(params[:id])
  @categories = Category.all
  halt 404, 'Produto não encontrado' unless @product
  erb :'products/form'
end

post '/products' do
  require_assistant!
  begin
    Product.create(
      name:         params[:name],
      sku:          params[:sku],
      quantity:     params[:quantity].to_i,
      price:        params[:price].to_f,
      cost:         params[:cost],
      unit:         params[:unit] || 'un',
      category_id:  params[:category_id].to_s.empty? ? nil : params[:category_id],
      min_quantity: params[:min_quantity].to_i
    )

    qty = params[:quantity].to_i
    if qty > 0
      result = DB.exec("SELECT id FROM products ORDER BY id DESC LIMIT 1")
      pid = result[0]['id']
      Movement.create(product_id: pid, kind: 'in', quantity: qty, reason: 'Estoque inicial', reference: 'CADASTRO')
    end

    redirect '/products'

  rescue PG::UniqueViolation
    @error      = "SKU '#{params[:sku]}' já está em uso. Escolha um SKU diferente."
    @categories = Category.all
    @params     = params
    erb :'products/form'

  rescue => e
    @error      = "Erro ao salvar produto: #{e.message}"
    @categories = Category.all
    @params     = params
    erb :'products/form'
  end
end

post '/products/:id' do
  require_assistant!
  begin
    Product.update(
      id:           params[:id],
      name:         params[:name],
      sku:          params[:sku],
      price:        params[:price].to_f,
      cost:         params[:cost],
      unit:         params[:unit] || 'un',
      category_id:  params[:category_id].to_s.empty? ? nil : params[:category_id],
      min_quantity: params[:min_quantity].to_i
    )
    redirect "/products/#{params[:id]}"

  rescue PG::UniqueViolation
    @error      = "SKU '#{params[:sku]}' já está em uso por outro produto."
    @product    = Product.find(params[:id])
    @categories = Category.all
    @params     = params
    erb :'products/form'

  rescue => e
    @error      = "Erro ao atualizar produto: #{e.message}"
    @product    = Product.find(params[:id])
    @categories = Category.all
    @params     = params
    erb :'products/form'
  end
end

post '/products/:id/add_stock' do
  require_assistant!
  Inventory::AddStockService.call(
    params[:id], params[:quantity],
    reason: params[:reason], reference: params[:reference],
    user_id: current_user.id
  )
  redirect "/products/#{params[:id]}"
rescue ArgumentError => e
  redirect "/products/#{params[:id]}?error=#{Rack::Utils.escape(e.message)}"
end

post '/products/:id/remove_stock' do
  require_assistant!
  Inventory::RemoveStockService.call(
    params[:id], params[:quantity],
    reason: params[:reason], reference: params[:reference],
    user_id: current_user.id
  )
  redirect "/products/#{params[:id]}"
rescue ArgumentError => e
  redirect "/products/#{params[:id]}?error=#{Rack::Utils.escape(e.message)}"
end

post '/products/:id/adjust' do
  require_assistant!
  Inventory::AdjustStockService.call(
    params[:id], params[:quantity],
    reason: params[:reason] || 'Ajuste manual',
    user_id: current_user.id
  )
  redirect "/products/#{params[:id]}"
rescue ArgumentError => e
  redirect "/products/#{params[:id]}?error=#{Rack::Utils.escape(e.message)}"
end

post '/products/:id/delete' do
  require_admin!
  Product.delete(params[:id])
  redirect '/products'
end
