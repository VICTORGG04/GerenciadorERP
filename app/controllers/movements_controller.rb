# controllers/movements_controller.rb

get '/movements' do
  @movements = Movement.all
  erb :'movements/index'
end