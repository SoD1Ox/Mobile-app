"""Company service — business logic between API and CompanyRepository."""

from __future__ import annotations

from app.dto.common import Page, PageParams
from app.dto.company import CompanyCreate, CompanyRead, CompanyUpdate
from app.repositories.company import CompanyRepository
from app.services.errors import NotFoundError


class CompanyService:
    def __init__(self, repo: CompanyRepository | None = None) -> None:
        self._repo = repo or CompanyRepository()

    def list_companies(self, params: PageParams) -> Page[CompanyRead]:
        return self._repo.search_paginated(params)

    def get_company(self, company_id: int) -> CompanyRead:
        company = self._repo.get_by_id(company_id)
        if company is None:
            raise NotFoundError(f"Company {company_id} not found")
        return company

    def create_company(self, data: CompanyCreate) -> CompanyRead:
        return self._repo.create(data)

    def update_company(self, company_id: int, data: CompanyUpdate) -> CompanyRead:
        updated = self._repo.update(company_id, data)
        if updated is None:
            raise NotFoundError(f"Company {company_id} not found")
        return updated

    def delete_company(self, company_id: int) -> None:
        if not self._repo.delete(company_id):
            raise NotFoundError(f"Company {company_id} not found")
