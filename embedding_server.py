#!/usr/bin/env python3
from flask import Flask, request, jsonify
from sentence_transformers import SentenceTransformer
import os

app = Flask(__name__)
_model = None
MODEL = 'all-MiniLM-L6-v2'


def get_model():
    global _model
    if _model is None:
        _model = SentenceTransformer(MODEL)
    return _model


@app.route('/health')
def health():
    return 'ok'


@app.route('/embed', methods=['POST'])
def embed():
    text = request.json['text']
    emb = get_model().encode([text])[0]
    return jsonify({'embedding': emb.tolist()})


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5001, debug=False)
