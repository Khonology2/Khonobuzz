from __future__ import annotations
import traceback
from typing import Dict, Any

from sync_pg import ensure_pg_schema, sync_user_to_postgres
from fastapi_app import db  # reuses initialized Firestore client


def get_onboarding_for_user(user_id: str) -> Dict[str, Any]:
  try:
    # Try by user_id field
    query = (
      db.collection('onboarding')
        .where('user_id', '==', user_id)
        .limit(1)
        .stream()
    )
    for doc in query:
      return doc.to_dict() or {}
  except Exception:
    pass
  try:
    # Fallback to direct document id
    doc = db.collection('onboarding').document(user_id).get()
    if doc.exists:
      return doc.to_dict() or {}
  except Exception:
    pass
  return {}


def main() -> None:
  ensure_pg_schema()
  total = 0
  ok = 0
  failed = 0
  try:
    users_iter = db.collection('users').stream()
    for user_doc in users_iter:
      total += 1
      try:
        uid = user_doc.id
        user_data = user_doc.to_dict() or {}
        onboarding_data = get_onboarding_for_user(uid)
        sync_user_to_postgres(uid, user_data, onboarding_data)
        ok += 1
      except Exception as e:
        failed += 1
        print(f"[ERROR] Backfill for {user_doc.id} failed: {e}\n{traceback.format_exc()}")
  except Exception as outer:
    print(f"[ERROR] Failed to iterate users: {outer}\n{traceback.format_exc()}")
  print(f"Backfill complete. total={total}, ok={ok}, failed={failed}")


if __name__ == "__main__":
  main()
