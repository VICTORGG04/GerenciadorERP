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

    token = License.generate_token(params[:plan], expires, lic.license_ref)
    License.update_token(lic.id, token)

    flash 'ok', "Licença #{lic.license_ref} (#{params[:company_name]}) criada com sucesso!"
    redirect "/licenses/#{lic.id}"
  rescue => e
    @error = "Erro ao criar licença: #{e.message}"
    @license = OpenStruct.new(params)
    erb :'licenses/form'
  end
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
