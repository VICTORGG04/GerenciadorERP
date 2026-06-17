require 'rufus-scheduler'
require 'fileutils'

module BackupScheduler
  def self.start!
    scheduler = Rufus::Scheduler.new

    backup_time      = ENV.fetch('BACKUP_TIME', '23:00')
    backup_dir       = ENV.fetch('BACKUP_DIR', './storage/backups')
    retention_days   = ENV.fetch('BACKUP_RETENTION_DAYS', '30').to_i

    FileUtils.mkdir_p(backup_dir)

    # Executa todo dia no horário configurado em .env (padrão 23:00)
    scheduler.cron("#{backup_time.split(':')[1]} #{backup_time.split(':')[0]} * * *") do
      perform_backup(backup_dir, retention_days)
    end

    # Executa um backup na inicialização se não houver nenhum do dia
    today_file = File.join(backup_dir, "backup_#{Date.today.strftime('%Y%m%d')}*.sql.gz")
    unless Dir.glob(today_file).any?
      Thread.new { perform_backup(backup_dir, retention_days) }
    end

    scheduler
  end

  def self.perform_backup(backup_dir, retention_days)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename  = File.join(backup_dir, "backup_#{timestamp}.sql")
    gz_file   = "#{filename}.gz"

    db_host = ENV.fetch('DB_HOST',     '127.0.0.1')
    db_name = ENV.fetch('DB_NAME',     'gerenciador_estoque')
    db_user = ENV.fetch('DB_USER',     'victor')
    db_pass = ENV.fetch('DB_PASSWORD', '')

    # Executa pg_dump com senha via variável de ambiente
    env     = { 'PGPASSWORD' => db_pass }
    cmd     = "pg_dump -h #{db_host} -U #{db_user} -d #{db_name} -f #{filename} --no-password"
    success = system(env, cmd)

    if success && File.exist?(filename)
      # Comprime o backup
      system("gzip -f #{filename}")
      log("[BackupScheduler] ✅ Backup criado: #{gz_file}")

      # Registra no banco de auditoria
      begin
        DB.exec_params(
          "INSERT INTO audit_logs (user_name, action, table_name, details, ip)
           VALUES ($1, $2, $3, $4, $5)",
          ['Sistema', 'backup', 'backups', "Arquivo: #{File.basename(gz_file)}", 'localhost']
        )
      rescue => e
        log("[BackupScheduler] Aviso: não foi possível registrar na auditoria — #{e.message}")
      end

      # Remove backups antigos
      cleanup_old_backups(backup_dir, retention_days)
    else
      log("[BackupScheduler] ❌ Falha ao gerar backup. Verifique se o pg_dump está instalado.")
    end
  rescue => e
    log("[BackupScheduler] ❌ Erro inesperado: #{e.message}")
  end

  def self.cleanup_old_backups(backup_dir, retention_days)
    cutoff = Time.now - (retention_days * 86_400)
    Dir.glob(File.join(backup_dir, '*.sql.gz')).each do |file|
      if File.mtime(file) < cutoff
        File.delete(file)
        log("[BackupScheduler] 🗑️ Backup antigo removido: #{File.basename(file)}")
      end
    end
  end

  def self.log(msg)
    puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{msg}"
    $stdout.flush
  end
end
