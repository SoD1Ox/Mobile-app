"""Contact DTOs (contact person of a client)."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class ContactBase(BaseModel):
    full_name: str = Field(min_length=2, max_length=150)
    position: str | None = Field(default=None, max_length=100)
    phone: str | None = Field(default=None, max_length=30)
    email: EmailStr | None = None
    client_id: int = Field(gt=0)


class ContactCreate(ContactBase):
    pass


class ContactUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=150)
    position: str | None = Field(default=None, max_length=100)
    phone: str | None = Field(default=None, max_length=30)
    email: EmailStr | None = None
    client_id: int | None = Field(default=None, gt=0)


class ContactRead(BaseModel):
    id: int
    full_name: str
    position: str | None
    phone: str | None
    email: str | None
    client_id: int

    model_config = ConfigDict(from_attributes=True)
