from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional

from sqlalchemy import DateTime, String, Text, func, select
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker


class _Base(DeclarativeBase):
    pass


class FirestoreDocumentStore(_Base):
    __tablename__ = "firestore_documents"

    collection_name: Mapped[str] = mapped_column(String(255), primary_key=True)
    document_id: Mapped[str] = mapped_column(String(255), primary_key=True)
    data: Mapped[Dict[str, Any]] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )


class PGFirestoreClient:
    def __init__(self, engine):
        self._engine = engine
        self._session_factory = sessionmaker(bind=engine, autoflush=False, autocommit=False)
        _Base.metadata.create_all(bind=engine)

    def collection(self, name: str) -> "PGCollectionRef":
        return PGCollectionRef(self, name)


class PGCollectionRef:
    def __init__(self, client: PGFirestoreClient, collection_name: str):
        self._client = client
        self._collection_name = collection_name

    def document(self, doc_id: Optional[str] = None) -> "PGDocumentRef":
        return PGDocumentRef(
            self._client,
            self._collection_name,
            doc_id or uuid.uuid4().hex,
        )

    def add(self, data: Dict[str, Any]):
        ref = self.document()
        ref.set(data)
        return ref, None

    def where(self, field: str, op: str, value: Any) -> "PGQuery":
        return PGQuery(self._client, self._collection_name).where(field, op, value)

    def limit(self, count: int) -> "PGQuery":
        return PGQuery(self._client, self._collection_name).limit(count)

    def stream(self, timeout: Optional[float] = None) -> Iterable["PGDocumentSnapshot"]:
        return PGQuery(self._client, self._collection_name).stream(timeout=timeout)

    def get(self, timeout: Optional[float] = None) -> List["PGDocumentSnapshot"]:
        return list(self.stream(timeout=timeout))


class PGQuery:
    def __init__(self, client: PGFirestoreClient, collection_name: str):
        self._client = client
        self._collection_name = collection_name
        self._filters: list[tuple[str, str, Any]] = []
        self._limit: Optional[int] = None

    def where(self, field: str, op: str, value: Any) -> "PGQuery":
        self._filters.append((field, op, value))
        return self

    def limit(self, count: int) -> "PGQuery":
        self._limit = count
        return self

    def get(self, timeout: Optional[float] = None) -> List["PGDocumentSnapshot"]:
        return list(self.stream(timeout=timeout))

    def stream(self, timeout: Optional[float] = None) -> Iterable["PGDocumentSnapshot"]:
        del timeout
        session = self._client._session_factory()
        try:
            stmt = select(FirestoreDocumentStore).where(
                FirestoreDocumentStore.collection_name == self._collection_name
            )
            for field, op, value in self._filters:
                json_field = FirestoreDocumentStore.data[field]
                if op == "==":
                    stmt = stmt.where(json_field.astext == str(value))
                elif op == "array_contains":
                    stmt = stmt.where(json_field.contains([value]))
                else:
                    raise NotImplementedError(f"Unsupported where op: {op}")

            stmt = stmt.order_by(FirestoreDocumentStore.updated_at.desc())
            if self._limit is not None:
                stmt = stmt.limit(self._limit)
            rows = session.execute(stmt).scalars().all()
            return [
                PGDocumentSnapshot(
                    PGDocumentRef(self._client, row.collection_name, row.document_id),
                    row.data or {},
                    exists=True,
                )
                for row in rows
            ]
        finally:
            session.close()


class PGDocumentRef:
    def __init__(self, client: PGFirestoreClient, collection_name: str, document_id: str):
        self._client = client
        self._collection_name = collection_name
        self.id = document_id

    @property
    def reference(self) -> "PGDocumentRef":
        return self

    def get(self, timeout: Optional[float] = None) -> "PGDocumentSnapshot":
        del timeout
        session = self._client._session_factory()
        try:
            row = session.get(
                FirestoreDocumentStore,
                {
                    "collection_name": self._collection_name,
                    "document_id": self.id,
                },
            )
            if row is None:
                return PGDocumentSnapshot(self, {}, exists=False)
            return PGDocumentSnapshot(self, row.data or {}, exists=True)
        finally:
            session.close()

    def _normalize_payload(self, existing_data: Dict[str, Any], payload: Dict[str, Any]) -> Dict[str, Any]:
        normalized = _json_safe(existing_data)
        payload = _json_safe(payload)
        for key, value in payload.items():
            if value is SERVER_TIMESTAMP:
                normalized[key] = datetime.utcnow().isoformat() + "Z"
                continue
            if _is_array_union(value):
                current = normalized.get(key)
                current_list = current if isinstance(current, list) else []
                additions = _extract_array_union_values(value)
                for item in additions:
                    if item not in current_list:
                        current_list.append(item)
                normalized[key] = current_list
            else:
                normalized[key] = value
        return normalized

    def set(self, data: Dict[str, Any], merge: bool = False) -> None:
        session = self._client._session_factory()
        try:
            row = session.get(
                FirestoreDocumentStore,
                {
                    "collection_name": self._collection_name,
                    "document_id": self.id,
                },
            )
            now = datetime.utcnow()
            if row is None:
                row = FirestoreDocumentStore(
                    collection_name=self._collection_name,
                    document_id=self.id,
                    data={},
                    created_at=now,
                    updated_at=now,
                )
                session.add(row)
            current = row.data or {}
            row.data = self._normalize_payload(current if merge else {}, data if merge else data)
            row.updated_at = now
            session.commit()
        finally:
            session.close()

    def update(self, data: Dict[str, Any]) -> None:
        self.set(data, merge=True)

    def delete(self) -> None:
        session = self._client._session_factory()
        try:
            row = session.get(
                FirestoreDocumentStore,
                {
                    "collection_name": self._collection_name,
                    "document_id": self.id,
                },
            )
            if row is not None:
                session.delete(row)
                session.commit()
        finally:
            session.close()


class PGDocumentSnapshot:
    def __init__(self, ref: PGDocumentRef, data: Dict[str, Any], exists: bool):
        self.reference = ref
        self.id = ref.id
        self._data = data
        self.exists = exists

    def to_dict(self) -> Dict[str, Any]:
        return dict(self._data or {})


def _is_array_union(value: Any) -> bool:
    cls_name = value.__class__.__name__
    return cls_name == "ArrayUnion"


def _extract_array_union_values(value: Any) -> list[Any]:
    for attr in ("values", "_values"):
        if hasattr(value, attr):
            raw = getattr(value, attr)
            if isinstance(raw, list):
                return raw
    return []


def _json_safe(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, datetime):
        return value.isoformat() + "Z"
    if isinstance(value, dict):
        return {str(k): _json_safe(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_json_safe(v) for v in value]

    # Firestore timestamps and similar objects usually expose isoformat().
    isoformat = getattr(value, "isoformat", None)
    if callable(isoformat):
        try:
            return isoformat()
        except Exception:
            pass

    # Firestore document-like values may expose to_dict().
    to_dict = getattr(value, "to_dict", None)
    if callable(to_dict):
        try:
            return _json_safe(to_dict())
        except Exception:
            pass

    return str(value)


class ArrayUnion:
    def __init__(self, values: list[Any]):
        self.values = list(values or [])


class _FirestoreCompatModule:
    ArrayUnion = ArrayUnion


SERVER_TIMESTAMP = object()
_FirestoreCompatModule.SERVER_TIMESTAMP = SERVER_TIMESTAMP
firestore = _FirestoreCompatModule()
