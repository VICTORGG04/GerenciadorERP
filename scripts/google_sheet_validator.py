#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Google Sheets Validator - Gerenciador ERP
Script Python para operações na planilha de licenças.
Chamado pelo Ruby via: python3 google_sheet_validator.py <action> '<json_data>'
"""

import sys
import os
import json
import hashlib
import socket
from datetime import datetime, timezone

import gspread
from google.oauth2.service_account import Credentials

SHEET_ID = os.environ.get('GOOGLE_SHEET_ID', '')
CREDENTIALS_PATH = os.environ.get('GOOGLE_SHEET_CREDENTIALS', '')
TAB_NAME = 'Licencas'
TAB_CONTESTACOES = 'Contestacoes'

COLUMNS = [
    'token', 'cnpj', 'company', 'plan', 'payment', 'expires', 'status',
    'machine_id', 'hostname', 'ip', 'activated_at',
    'address_street', 'address_number', 'address_complement',
    'address_neighborhood', 'address_city', 'address_state',
    'address_zip', 'contact_name', 'contact_email', 'contact_phone',
    'notes'
]

COLUNAS_CONTESTACOES = [
    'ID', 'CHARGE_ID', 'PAYMENT_INTENT', 'CUSTOMER_EMAIL', 'LICENSE_TOKEN',
    'AMOUNT', 'CURRENCY', 'REASON', 'STATUS', 'EVIDENCE_SUBMITTED',
    'CREATED_AT', 'UPDATED_AT', 'CLOSED_AT', 'NOTES'
]

STORAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'storage')
MID_FILE = os.path.join(STORAGE_DIR, 'machine_id')


def get_client():
    if not SHEET_ID:
        return None, 'GOOGLE_SHEET_ID não configurado'
    if not CREDENTIALS_PATH or not os.path.exists(CREDENTIALS_PATH):
        return None, 'Arquivo de credenciais não encontrado'
    try:
        scopes = ['https://www.googleapis.com/auth/spreadsheets']
        creds = Credentials.from_service_account_file(CREDENTIALS_PATH, scopes=scopes)
        gc = gspread.authorize(creds)
        return gc, None
    except Exception as e:
        return None, f'Erro ao autenticar: {e}'


def get_worksheet(gc):
    try:
        spreadsheet = gc.open_by_key(SHEET_ID)
        return spreadsheet.worksheet(TAB_NAME)
    except Exception as e:
        return None


def get_machine_id():
    os.makedirs(STORAGE_DIR, exist_ok=True)
    if os.path.exists(MID_FILE):
        with open(MID_FILE, 'r') as f:
            return f.read().strip()
    mid = hashlib.sha256(f"{socket.gethostname()}-{os.urandom(16).hex()}".encode()).hexdigest()
    with open(MID_FILE, 'w') as f:
        f.write(mid)
    return mid


def parse_date(s):
    if not s:
        return None
    try:
        from dateutil import parser as dateparser
        return dateparser.parse(s)
    except:
        pass
    for fmt in ('%Y-%m-%d', '%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%d %H:%M:%S'):
        try:
            return datetime.strptime(s, fmt)
        except:
            continue
    return None


def find_last_data_row(ws):
    all_values = ws.get_all_values()
    last_row = 1
    for idx, row in enumerate(all_values):
        if row[0].strip():
            last_row = idx + 1
    return last_row


def action_read_sheet(args):
    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_NAME}" não encontrada'}
    try:
        rows = ws.get_all_values()
        return {'success': True, 'rows': rows}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def action_validate(args):
    token = args.get('token', '').strip()
    if not token:
        return {'success': False, 'error': 'Token não informado'}

    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_NAME}" não encontrada'}

    try:
        all_values = ws.get_all_values()
        idx = None
        for i, row in enumerate(all_values):
            if row[0].strip() == token:
                idx = i
                break

        if idx is None:
            return {'success': False, 'error': 'Token não encontrado na planilha'}

        row = all_values[idx]
        row_num = idx + 1
        row_data = {COLUMNS[j]: row[j].strip() if j < len(row) else '' for j in range(len(COLUMNS))}

        status = row_data.get('status', '')

        if status == 'available':
            expires = parse_date(row_data.get('expires', ''))
            now = datetime.now(timezone.utc)
            if expires and now > expires.replace(tzinfo=timezone.utc):
                ws.update_cell(row_num, 7, 'expired')
                return {'success': False, 'error': 'Licença expirada'}
            row_data['row_num'] = row_num
            return {'success': True, **row_data}

        elif status == 'active':
            mid = get_machine_id()
            sheet_mid = row_data.get('machine_id', '')

            if not sheet_mid or sheet_mid == mid:
                expires = parse_date(row_data.get('expires', ''))
                now = datetime.now(timezone.utc)
                if expires and now > expires.replace(tzinfo=timezone.utc):
                    ws.update_cell(row_num, 7, 'expired')
                    return {'success': False, 'error': 'Licença expirada'}
                row_data['row_num'] = row_num
                return {'success': True, **row_data}
            else:
                return {'success': False, 'error': 'Este token já está ativo em outra máquina'}

        elif status in ('expired', 'revoked', 'upgraded'):
            return {'success': False, 'error': f'Licença {status}'}
        else:
            return {'success': False, 'error': f'Status desconhecido: {status}'}

    except Exception as e:
        return {'success': False, 'error': f'Erro na validação: {e}'}


def action_register_license(args):
    token = args.get('token', '').strip()
    if not token:
        return {'success': False, 'error': 'Token não informado'}

    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_NAME}" não encontrada'}

    try:
        now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        expires_raw = args.get('expires_at', '')
        expires = ''
        if expires_raw:
            d = parse_date(expires_raw)
            if d:
                expires = d.strftime('%Y-%m-%d')

        row = [
            token,
            args.get('cnpj', '').strip(),
            args.get('company_name', '').strip(),
            args.get('plan', '').strip(),
            'nao_pago',
            expires,
            'active',
            '', '', '',
            now,
            args.get('address_street', '').strip(),
            args.get('address_number', '').strip(),
            args.get('address_complement', '').strip(),
            args.get('address_neighborhood', '').strip(),
            args.get('address_city', '').strip(),
            args.get('address_state', '').strip(),
            args.get('address_zip', '').strip(),
            args.get('contact_name', '').strip(),
            args.get('contact_email', '').strip(),
            args.get('contact_phone', '').strip(),
            args.get('notes', '').strip()
        ]

        last_row = find_last_data_row(ws)
        insert_pos = last_row + 1
        ws.insert_row(row, index=insert_pos)
        return {'success': True}

    except Exception as e:
        return {'success': False, 'error': f'Erro ao registrar licença: {e}'}


def action_register_free_trial(args):
    token = args.get('token', '').strip()
    if not token:
        return {'success': False, 'error': 'Token não informado'}

    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_NAME}" não encontrada'}

    try:
        mid = get_machine_id()
        host = socket.gethostname()
        now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        expires = datetime.now(timezone.utc).strftime('%Y-%m-%d')
        from datetime import timedelta
        expires = (datetime.now(timezone.utc) + timedelta(days=30)).strftime('%Y-%m-%d')

        row = [
            token, '', 'Free Trial - Auto', 'free', 'nao_pago', expires,
            'active', mid, host, '', now,
            '', '', '', '', '', '', '', '', '',
            'Trial automático de 30 dias'
        ]

        last_row = find_last_data_row(ws)
        insert_pos = last_row + 1
        ws.insert_row(row, index=insert_pos)
        return {'success': True}

    except Exception as e:
        return {'success': False, 'error': f'Erro ao registrar trial: {e}'}


def action_revoke_token(args):
    token = args.get('token', '').strip()
    if not token:
        return {'success': False, 'error': 'Token não informado'}

    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_NAME}" não encontrada'}

    try:
        all_values = ws.get_all_values()
        idx = None
        for i, row in enumerate(all_values):
            if row[0].strip() == token:
                idx = i
                break

        if idx is None:
            return {'success': False, 'error': 'Token não encontrado'}

        row_num = idx + 1
        ws.update_cell(row_num, 7, 'revoked')
        return {'success': True}

    except Exception as e:
        return {'success': False, 'error': f'Erro ao revogar: {e}'}


def action_activate(args):
    token = args.get('token', '').strip()
    row_num = args.get('row_num', 0)
    if not token or not row_num:
        return {'success': False, 'error': 'Token ou row_num não informado'}

    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_NAME}" não encontrada'}

    try:
        mid = get_machine_id()
        host = socket.gethostname()
        now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

        ws.update_cell(row_num, 7, 'active')
        ws.update_cell(row_num, 8, mid)
        ws.update_cell(row_num, 9, host)
        ws.update_cell(row_num, 11, now)
        return {'success': True}

    except Exception as e:
        return {'success': False, 'error': f'Erro ao ativar: {e}'}


def action_update_payment(args):
    token = args.get('token', '').strip()
    status = args.get('status', '').strip()
    if not token or not status:
        return {'success': False, 'error': 'Token ou status não informado'}

    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_NAME}" não encontrada'}

    try:
        rows = ws.get_all_values()
        for i, row in enumerate(rows):
            if row[0].strip() == token:
                ws.update_cell(i + 1, 5, status)
                log(f'Pagamento atualizado para {status} na linha {i + 1}')
                return {'success': True}
        return {'success': False, 'error': 'Token não encontrado na planilha'}
    except Exception as e:
        return {'success': False, 'error': f'Erro ao atualizar pagamento: {e}'}


def action_update_status(args):
    token = args.get('token', '').strip()
    new_status = args.get('status', '').strip()
    if not token or not new_status:
        return {'success': False, 'error': 'Token ou status não informado'}

    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_NAME}" não encontrada'}

    try:
        rows = ws.get_all_values()
        for i, row in enumerate(rows):
            if row[0].strip() == token:
                ws.update_cell(i + 1, 7, new_status)
                log(f'Status atualizado para {new_status} na linha {i + 1}')
                return {'success': True}
        return {'success': False, 'error': 'Token não encontrado na planilha'}
    except Exception as e:
        return {'success': False, 'error': f'Erro ao atualizar status: {e}'}


def get_contestacoes_worksheet(gc):
    try:
        spreadsheet = gc.open_by_key(SHEET_ID)
        return spreadsheet.worksheet(TAB_CONTESTACOES)
    except Exception as e:
        return None


def find_last_data_row_in_ws(ws):
    all_values = ws.get_all_values()
    last_row = 1
    for idx, row in enumerate(all_values):
        if any(cell.strip() for cell in row):
            last_row = idx + 1
    return last_row


def action_register_dispute(args):
    dispute_id = args.get('id', '').strip()
    if not dispute_id:
        return {'success': False, 'error': 'ID da disputa não informado'}

    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_contestacoes_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_CONTESTACOES}" não encontrada'}

    try:
        now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        row = [
            dispute_id,
            args.get('charge_id', '').strip(),
            args.get('payment_intent', '').strip(),
            args.get('customer_email', '').strip(),
            args.get('license_token', '').strip(),
            args.get('amount', ''),
            args.get('currency', 'brl').strip(),
            args.get('reason', '').strip(),
            args.get('status', 'needs_response').strip(),
            args.get('evidence_submitted', 'nao').strip(),
            args.get('created_at', now),
            now,
            '',
            args.get('notes', '').strip()
        ]

        last_row = find_last_data_row_in_ws(ws)
        insert_pos = last_row + 1
        ws.insert_row(row, index=insert_pos)
        log(f'Disputa {dispute_id} registrada na linha {insert_pos}')
        return {'success': True}
    except Exception as e:
        return {'success': False, 'error': f'Erro ao registrar disputa: {e}'}


def action_update_dispute(args):
    dispute_id = args.get('id', '').strip()
    if not dispute_id:
        return {'success': False, 'error': 'ID da disputa não informado'}

    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_contestacoes_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_CONTESTACOES}" não encontrada'}

    try:
        now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        rows = ws.get_all_values()
        for i, row in enumerate(rows):
            if row[0].strip() == dispute_id:
                row_num = i + 1
                new_status = args.get('status', '').strip()
                if new_status:
                    ws.update_cell(row_num, 9, new_status)
                ws.update_cell(row_num, 12, now)
                log(f'Disputa {dispute_id} atualizada: status={new_status}')
                return {'success': True}
        return {'success': False, 'error': f'Disputa {dispute_id} não encontrada'}
    except Exception as e:
        return {'success': False, 'error': f'Erro ao atualizar disputa: {e}'}


def action_close_dispute(args):
    dispute_id = args.get('id', '').strip()
    if not dispute_id:
        return {'success': False, 'error': 'ID da disputa não informado'}

    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    ws = get_contestacoes_worksheet(gc)
    if ws is None:
        return {'success': False, 'error': f'Aba "{TAB_CONTESTACOES}" não encontrada'}

    try:
        now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        rows = ws.get_all_values()
        for i, row in enumerate(rows):
            if row[0].strip() == dispute_id:
                row_num = i + 1
                new_status = args.get('status', '').strip()
                closed_at = args.get('closed_at', now)
                if new_status:
                    ws.update_cell(row_num, 9, new_status)
                ws.update_cell(row_num, 12, now)
                ws.update_cell(row_num, 13, closed_at)
                log(f'Disputa {dispute_id} encerrada: status={new_status}')
                return {'success': True}
        return {'success': False, 'error': f'Disputa {dispute_id} não encontrada'}
    except Exception as e:
        return {'success': False, 'error': f'Erro ao encerrar disputa: {e}'}


def action_internet(args):
    gc, err = get_client()
    if err:
        return {'success': False, 'error': err}
    try:
        gc.open_by_key(SHEET_ID)
        return {'success': True}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def log(msg):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}", file=sys.stderr)
    sys.stderr.flush()


ACTIONS = {
    'read_sheet': action_read_sheet,
    'validate': action_validate,
    'register_license': action_register_license,
    'register_free_trial': action_register_free_trial,
    'revoke_token': action_revoke_token,
    'activate': action_activate,
    'update_payment': action_update_payment,
    'update_status': action_update_status,
    'register_dispute': action_register_dispute,
    'update_dispute': action_update_dispute,
    'close_dispute': action_close_dispute,
    'internet': action_internet,
}


def main():
    if len(sys.argv) < 2:
        print(json.dumps({'success': False, 'error': 'Uso: google_sheet_validator.py <action> [json_data]'}))
        sys.exit(1)

    action = sys.argv[1]
    if action not in ACTIONS:
        print(json.dumps({'success': False, 'error': f'Ação desconhecida: {action}'}))
        sys.exit(1)

    args = {}
    if len(sys.argv) >= 3:
        try:
            args = json.loads(sys.argv[2])
        except json.JSONDecodeError as e:
            print(json.dumps({'success': False, 'error': f'JSON inválido: {e}'}))
            sys.exit(1)

    result = ACTIONS[action](args)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
