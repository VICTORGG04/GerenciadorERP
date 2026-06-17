# models/base.rb
# Todos os models herdam daqui para acessar DB centralizado
module BaseModel
  def db
    DB
  end
end