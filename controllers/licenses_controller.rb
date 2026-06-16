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
  expires = Time.now + (params[:days].to_i * 24 * 3600)

  begin
    lic = License.create(
      plan:                params[:plan],
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

    flash 'ok', "Cliente #{params[:company_name]} cadastrado como #{lic.license_ref}!"
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
  if parts.length != 4
    @error = 'Token inválido. Deve ter 4 campos separados por ponto.'
    return erb :'licenses/show'
  end

  ref = parts[2]
  unless ref == @license.license_ref
    @error = "Token refere-se a #{ref}, mas esta licença é #{@license.license_ref}."
    return erb :'licenses/show'
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
