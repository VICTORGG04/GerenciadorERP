# controllers/audit_controller.rb
# Somente Admin pode ver os logs de auditoria

get '/audit' do
  require_admin!

  @page      = (params[:page] || 1).to_i
  @per_page  = 50
  @offset    = (@page - 1) * @per_page
  @total     = AuditLog.count
  @pages     = (@total.to_f / @per_page).ceil

  @filter_user  = params[:user_id]
  @filter_table = params[:table_name]

  @logs = if @filter_user && !@filter_user.empty?
    AuditLog.by_user(@filter_user, limit: @per_page)
  elsif @filter_table && !@filter_table.empty?
    AuditLog.by_table(@filter_table, limit: @per_page)
  else
    AuditLog.all(limit: @per_page, offset: @offset)
  end

  @users = User.all

  erb :'audit/index'
end
