get '/categories' do
  @categories = Category.all
  erb :'categories/index'
end

post '/categories' do
  require_admin!
  name  = params[:name].to_s.strip
  color = params[:color].to_s.strip

  if name.empty?
    @categories = Category.all
    @error = 'Nome é obrigatório.'
    halt erb(:'categories/index')
  end

  Category.create(name: name, color: color)
  redirect '/categories'
end

post '/categories/:id/delete' do
  require_admin!
  Category.delete(params[:id])
  redirect '/categories'
end
