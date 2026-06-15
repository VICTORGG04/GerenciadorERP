# controllers/auth_controller.rb

# ── Licença (ativação) ────────────────────────────────────────────
get '/license' do
  redirect '/login' if validate_license!
  erb :'license', layout: false
end

post '/license' do
  token = params[:license_token].to_s.strip
  if token.empty?
    @error = 'Informe o token de licença.'
    return erb(:'license', layout: false)
  end

  parts = token.split('.')
  if parts.length != 3 && parts.length != 4
    @error = 'Token inválido. Verifique se copiou corretamente.'
    return erb(:'license', layout: false)
  end

  plan, expires, *rest = parts
  identifier = rest.length == 2 ? rest[0] : nil
  signature  = rest.last

  data = identifier ? "#{plan}.#{expires}.#{identifier}" : "#{plan}.#{expires}"
  expected = OpenSSL::HMAC.hexdigest('SHA256', LICENSE_SECRET, data)
  if signature != expected
    @error = 'Token inválido ou corrompido. Verifique com o suporte.'
    return erb(:'license', layout: false)
  end

  if Time.now.to_i > expires.to_i
    @error = 'Este token já expirou. Solicite uma nova licença.'
    return erb(:'license', layout: false)
  end

  begin
    save_license_token!(token)
    msg = identifier ? "Licença #{plan.capitalize} ativada para #{identifier}!" : "Licença #{plan.capitalize} ativada com sucesso!"
    flash 'ok', msg
    redirect '/login'
  rescue => e
    @error = "Erro ao salvar licença: #{e.message}. Edite o arquivo .env manualmente."
    erb :'license', layout: false
  end
end

# ── Login ─────────────────────────────────────────────────────────
get '/login' do
  redirect '/' if current_user
  erb :login, layout: false
end

post '/login' do
  user = User.authenticate(params[:email], params[:password])

  if user
    session[:user_id]   = user.id
    session[:user_name] = user.name
    session[:user_role] = user.role
    redirect '/'
  else
    @error = 'E-mail ou senha incorretos.'
    erb :login, layout: false
  end
end

get '/logout' do
  session.clear
  redirect '/login'
end

# ── Gerenciar usuários (apenas admin) ─────────────────────────────
get '/users' do
  require_admin!
  @users = User.all
  erb :'users/index'
end

get '/users/new' do
  require_admin!
  erb :'users/form'
end

post '/users' do
  require_admin!

  # ── Limite por plano ────────────────────────────────────────────
  unless feature?('unlimited_users')
    count = DB.exec("SELECT COUNT(*) FROM users WHERE active = true")[0]['count'].to_i
    if count >= max_users
      @error = "Limite de #{max_users} usuários ativos atingido. Faça upgrade do plano."
      halt erb(:'users/form')
    end
  end

  # ── Validações ──────────────────────────────────────────────────
  if params[:name].to_s.strip.empty?
    @error = 'O nome não pode estar em branco.'
    halt erb(:'users/form')
  end

  unless params[:email] =~ /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
    @error = 'E-mail inválido.'
    halt erb(:'users/form')
  end

  unless User::ROLES.key?(params[:role])
    @error = 'Nível de acesso inválido.'
    halt erb(:'users/form')
  end

  if params[:password].to_s.length < 6
    @error = 'A senha deve ter pelo menos 6 caracteres.'
    halt erb(:'users/form')
  end

  if params[:password] != params[:password_confirm]
    @error = 'As senhas não coincidem.'
    halt erb(:'users/form')
  end

  # ── Criação ─────────────────────────────────────────────────────
  begin
    User.create(
      name:     params[:name],
      email:    params[:email],
      password: params[:password],
      role:     params[:role]
    )
    redirect '/users'
  rescue PG::UniqueViolation
    @error = 'Este e-mail já está cadastrado.'
    erb :'users/form'
  rescue => e
    @error = e.message
    erb :'users/form'
  end
end

# ── Edição de usuário ──────────────────────────────────────────────
get '/users/:id/edit' do
  require_admin!
  @user = User.find(params[:id])
  halt 404 unless @user
  erb :'users/edit'
end

patch '/users/:id' do
  require_admin!
  @user = User.find(params[:id])
  halt 404 unless @user

  # ── Validações ──────────────────────────────────────────────────
  if params[:name].to_s.strip.empty?
    @error = 'O nome não pode estar em branco.'
    @form_params = params
    halt erb(:'users/edit')
  end

  unless params[:email] =~ /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
    @error = 'E-mail inválido.'
    @form_params = params
    halt erb(:'users/edit')
  end

  unless User::ROLES.key?(params[:role])
    @error = 'Nível de acesso inválido.'
    @form_params = params
    halt erb(:'users/edit')
  end

  # ── Atualização ─────────────────────────────────────────────────
  begin
    User.update(
      id:    @user.id,
      name:  params[:name],
      email: params[:email],
      role:  params[:role]
    )
    redirect '/users'
  rescue PG::UniqueViolation
    @error = 'Este e-mail já está cadastrado.'
    @form_params = params
    erb :'users/edit'
  rescue => e
    @error = e.message
    @form_params = params
    erb :'users/edit'
  end
end

post '/users/:id/toggle' do
  require_admin!
  User.toggle_active(params[:id])
  redirect '/users'
end

post '/users/:id/change_password' do
  require_admin!

  # ── Validações ──────────────────────────────────────────────────
  if params[:password].to_s.length < 6
    @users = User.all
    @error = 'A senha deve ter pelo menos 6 caracteres.'
    halt erb(:'users/index')
  end

  if params[:password] != params[:password_confirm]
    @users = User.all
    @error = 'As senhas não coincidem.'
    halt erb(:'users/index')
  end

  User.change_password(id: params[:id], password: params[:password])
  redirect '/users'
end

# ── Excluir usuário permanentemente ───────────────────────────────
delete '/users/:id' do
  require_admin!

  user = User.find(params[:id])
  halt 404 unless user

  # Impede excluir a si mesmo
  if user.id == current_user.id
    @users = User.all
    @error = 'Você não pode excluir sua própria conta.'
    halt erb(:'users/index')
  end

  User.destroy(params[:id])
  redirect '/users'
end