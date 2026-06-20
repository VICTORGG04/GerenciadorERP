#!/usr/bin/env python3
"""
Processa comprovantes de pagamento via OCR.
Uso: python3 payment_processor.py <caminho_do_arquivo>
Retorna JSON com dados extraídos ou {} em caso de falha.
"""
import json
import re
import sys
from PIL import Image
import pdfplumber
import pytesseract


def extract_text(filepath: str) -> str:
    ext = filepath.lower()
    if ext.endswith('.pdf'):
        text = ""
        with pdfplumber.open(filepath) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
        return text
    elif ext.endswith(('.png', '.jpg', '.jpeg')):
        img = Image.open(filepath)
        return pytesseract.image_to_string(img, lang='por')
    return ""


def parse_payment_data(text: str) -> dict:
    data = {}
    data['raw'] = text[:500]

    valor_match = re.search(r'(?:R\s*\$|valor|total|R\$)\s*([0-9]+[.,][0-9]+)', text, re.IGNORECASE)
    if valor_match:
        data['valor'] = valor_match.group(1).replace(',', '.')

    data_match = re.search(
        r'(\d{2}[/-]\d{2}[/-]\d{2,4}|\d{4}-\d{2}-\d{2})', text
    )
    if data_match:
        data['data'] = data_match.group(1)

    nome_match = re.search(
        r'(?:pagador?|cliente|nome|de)\s*[:\-]?\s*([A-ZÀ-Ú][A-ZÀ-Ú\s]+)', text, re.IGNORECASE
    )
    if nome_match:
        data['pagador'] = nome_match.group(1).strip()

    cnx_ref = re.search(r'(?:cnpj|cpf|doc|documento|ref)\s*[:\-]?\s*([0-9]{2,3}[.][0-9]{3}[.][0-9]{3}[/-]?[0-9]*)', text, re.IGNORECASE)
    if cnx_ref:
        data['documento'] = cnx_ref.group(1).strip()

    return data


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: payment_processor.py <arquivo>"}))
        sys.exit(1)

    filepath = sys.argv[1]
    try:
        text = extract_text(filepath)
        if not text.strip():
            print(json.dumps({}))
            return
        data = parse_payment_data(text)
        print(json.dumps(data, ensure_ascii=False))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == '__main__':
    main()
