# ── Admin: Gerenciamento de Licenças de Clientes ────────────
before '/licenses*' do
  require_admin!
end

get '/licenses' do
  @licenses = License.all
  erb :'licenses/index'
end

get '/licenses/new' do
  @license = nil
  erb :'licenses/form'
end

post '/licenses' do
  token = params[:license_token].to_s.strip

  # Extrair plano e expiry do token, se informado
  if token.empty?
    plan = params[:plan]
    expires = Time.now + (params[:days].to_i * 24 * 3600)
  else
    data = validate_token(token)
    unless data
      @error = 'Token inválido — assinatura não confere ou expirou.'
      @license = OpenStruct.new(params)
      return erb :'licenses/form'
    end

    plan = params[:plan].to_s.empty? ? data[:plan] : params[:plan]
    unless plan == data[:plan]
      @error = "Plano selecionado (#{plan}) não confere com o token (#{data[:plan]})."
      @license = OpenStruct.new(params)
      return erb :'licenses/form'
    end

    expires = data[:expires]
  end

  begin
    lic = License.create(
      plan:                plan,
      company_name:        params[:company_name].strip,
      cnpj:                params[:cnpj]&.strip,
      address_street:      params[:address_street]&.strip,
      address_number:      params[:address_number]&.strip,
      address_complement:  params[:address_complement]&.strip,
      address_neighborhood: params[:address_neighborhood]&.strip,
      address_city:        params[:address_city]&.strip,
      address_state:       params[:address_state]&.strip,
      address_zip:         params[:address_zip]&.strip,
      contact_name:        params[:contact_name]&.strip,
      contact_email:       params[:contact_email]&.strip,
      contact_phone:       params[:contact_phone]&.strip,
      notes:               params[:notes]&.strip,
      expires_at:          expires.strftime('%Y-%m-%d %H:%M:%S')
    )

    unless token.empty?
      License.update_token(lic.id, token)
      existing = read_license_token
      if existing != token && validate_token(token)
        save_license_token!(token)
      end
    end

    flash 'ok', "Licença #{lic.license_ref} cadastrada para #{lic.company_name}!"
    redirect "/licenses/#{lic.id}"
  rescue => e
    @error = "Erro ao cadastrar cliente: #{e.message}"
    @license = OpenStruct.new(params)
    erb :'licenses/form'
  end
end

patch '/licenses/:id/token' do
  @license = License.find(params[:id])
  halt 404, 'Licença não encontrada' unless @license

  token = params[:license_token].to_s.strip
  if token.empty?
    @error = 'Informe o token.'
    return erb :'licenses/show'
  end

  parts = token.split('.')
  if parts.length >= 3
    token_id = parts.length > 3 ? parts[2..-2].join('.') : nil
    if token_id && token_id != @license.license_ref && token_id != @license.cnpj.to_s
      @error = "Token refere-se a #{token_id}, mas esta licença é #{@license.license_ref}."
      return erb :'licenses/show'
    end
  end

  unless validate_token(token)
    @error = 'Token inválido — assinatura não confere ou expirou.'
    return erb :'licenses/show'
  end

  License.update_token(@license.id, token)
  flash 'ok', "Token salvo para #{@license.license_ref} (#{@license.company_name})!"
  redirect "/licenses/#{@license.id}"
end

get '/licenses/:id' do
  @license = License.find(params[:id])
  halt 404, 'Licença não encontrada' unless @license
  erb :'licenses/show'
end

delete '/licenses/:id' do
  lic = License.find(params[:id])
  halt 404 unless lic
  License.destroy(params[:id])
  flash 'ok', "Licença #{lic.license_ref} (#{lic.company_name}) excluída."
  redirect '/licenses'
end
