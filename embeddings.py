#!/usr/bin/env python3
import os
import sys
import json
import psycopg2
from sentence_transformers import SentenceTransformer

MODEL = 'all-MiniLM-L6-v2'


def connection():
    return psycopg2.connect(
        host=os.environ.get('POSTGRES_HOST', 'db'),
        dbname=os.environ.get('POSTGRES_DB', 'nlsbard'),
        user=os.environ.get('POSTGRES_USER', 'mike'),
        password=os.environ['POSTGRES_PASSWORD']
    )


CHUNK_SIZE = 500

def batch_generate():
    conn = connection()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM books WHERE embedding IS NULL AND language = 'English'")
    total = cur.fetchone()[0]
    if total == 0:
        print("No books need embeddings.")
        conn.close()
        return

    print(f"Generating embeddings for {total} books in chunks of {CHUNK_SIZE}...", flush=True)
    model = SentenceTransformer(MODEL)
    processed = 0

    while True:
        cur.execute("""
            SELECT key, coalesce(title,''), coalesce(author,''), coalesce(blurb,'')
            FROM books WHERE embedding IS NULL AND language = 'English'
            LIMIT %s
        """, (CHUNK_SIZE,))
        rows = cur.fetchall()
        if not rows:
            break

        texts = [f"{r[1]} {r[2]} {r[3]}" for r in rows]
        embeddings = model.encode(texts, batch_size=32, show_progress_bar=False)

        for (key, *_), emb in zip(rows, embeddings):
            cur.execute("UPDATE books SET embedding = %s WHERE key = %s", (emb.tolist(), key))
        conn.commit()

        processed += len(rows)
        print(f"  {processed}/{total} done...", flush=True)

    cur.close()
    conn.close()
    print(f"Complete. {processed} embeddings updated.")


def embed_query(text):
    model = SentenceTransformer(MODEL)
    emb = model.encode([text])[0]
    print(json.dumps(emb.tolist()))


if __name__ == '__main__':
    if '--query' in sys.argv:
        embed_query(sys.argv[sys.argv.index('--query') + 1])
    else:
        batch_generate()
