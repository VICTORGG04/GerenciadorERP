# controllers/import_controller.rb
# Admin e Assistente podem importar produtos

# Exibe o formulário de importação
get '/import' do
  require_assistant!
  erb :'import/index'
end

# Download do modelo CSV
get '/import/template' do
  require_assistant!
  content_type 'text/csv; charset=utf-8'
  attachment 'modelo_importacao_produtos.csv'
  Import.template_csv
end

# Processa o arquivo enviado
post '/import' do
  require_assistant!

  unless params[:file] && params[:file][:tempfile]
    session[:flash_type] = 'danger'
    session[:flash_msg]  = 'Nenhum arquivo enviado.'
    redirect '/import'
  end

  file      = params[:file]
  tempfile  = file[:tempfile]
  filename  = file[:filename].to_s
  ext       = File.extname(filename).downcase

  unless %w[.xlsx .xls .csv .ods].include?(ext)
    session[:flash_type] = 'danger'
    session[:flash_msg]  = "Formato não suportado: #{ext}. Use .xlsx, .csv ou .ods"
    redirect '/import'
  end

  # Salva o arquivo temporário com a extensão correta
  tmp_path = "/tmp/import_#{Time.now.to_i}#{ext}"
  File.binwrite(tmp_path, tempfile.read)

  result = Import.from_file(tmp_path, user_id: current_user.id)

  # Registra na auditoria
  audit('import', 'import',
    details: "#{result.created} produtos criados, #{result.skipped} ignorados — arquivo: #{filename}"
  )

  File.delete(tmp_path) if File.exist?(tmp_path)

  @result   = result
  @filename = filename
  erb :'import/result'
end
