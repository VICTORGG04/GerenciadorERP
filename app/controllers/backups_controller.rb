require 'json'
require 'time'

get '/backups' do
  require_admin!
  @backup_files = Dir.glob(File.join(__dir__, '..', 'backups', '*.{json,sql.gz}'))
                     .sort
                     .reverse
                     .map { |f| File.basename(f) }

  erb :backups
end

post '/backups/create' do
  require_admin!
  dir = File.join(__dir__, '..', 'backups')
  FileUtils.mkdir_p(dir)

  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  filename  = "backup_#{timestamp}.json"
  filepath  = File.join(dir, filename)

  products   = DB.exec('SELECT * FROM products').map { |r| r }
  categories = DB.exec('SELECT * FROM categories').map { |r| r }
  movements  = DB.exec('SELECT * FROM stock_movements ORDER BY created_at DESC').map { |r| r }

  data = {
    generated_at: Time.now.iso8601,
    products:     products,
    categories:   categories,
    movements:    movements
  }

  File.write(filepath, JSON.pretty_generate(data))

  redirect '/backups?ok=Backup+criado+com+sucesso'
end

get '/backups/download/:filename' do
  require_admin!
  filename = params[:filename].gsub('..', '')
  filepath = File.join(__dir__, '..', 'backups', filename)

  halt 404, 'Arquivo não encontrado' unless File.exist?(filepath)

  send_file filepath,
            filename:    filename,
            type:        'application/octet-stream',
            disposition: 'attachment'
end

post '/backups/delete/:filename' do
  require_admin!
  filename = params[:filename].gsub('..', '')
  filepath = File.join(__dir__, '..', 'backups', filename)

  File.delete(filepath) if File.exist?(filepath)

  redirect '/backups'
end
