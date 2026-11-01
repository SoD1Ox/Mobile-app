"""End-to-end smoke test for the Staffing Agency API.

Runs the FastAPI app in-process against a throwaway SQLite DB (seeded first),
exercises every entity's CRUD + search/pagination + RBAC, and prints PASS/FAIL
per check.  Exit code 0 only when all checks pass.

Usage (from backend/):
    python -m scripts.smoke_test
"""

from __future__ import annotations

import os
import sys
import tempfile

# Must be set BEFORE importing the app so settings pick up the override.
_DB_PATH = os.path.join(tempfile.gettempdir(), "agency_smoke.db")
if os.path.exists(_DB_PATH):
    os.remove(_DB_PATH)
os.environ["DATABASE_URL"] = f"sqlite:///{_DB_PATH}"

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, get_engine  # noqa: E402
from app.main import app  # noqa: E402
from scripts.seed import main as seed_main  # noqa: E402

# Create schema in the throwaway SQLite DB, then fill it with seed data.
Base.metadata.create_all(get_engine())
seed_main(force=True)

client = TestClient(app)
PASS, FAIL = 0, 0


def check(name: str, cond: bool, extra: str = "") -> None:
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"  PASS  {name}")
    else:
        FAIL += 1
        print(f"  FAIL  {name}  {extra}")


def login(username: str, password: str) -> dict | None:
    r = client.post("/api/v1/auth/login", json={"username": username, "password": password})
    return r.json() if r.status_code == 200 else None


print("== AUTH ==")
tokens = login("admin", "admin123")
check("login admin", tokens is not None)
at = {"Authorization": f"Bearer {tokens['access_token']}"}
rt = tokens["refresh_token"]

mgr = login("manager", "manager123")
check("login manager", mgr is not None)
mt = {"Authorization": f"Bearer {mgr['access_token']}"}

wrk = login("worker", "worker123")
check("login worker", wrk is not None)
wt = {"Authorization": f"Bearer {wrk['access_token']}"}

r = client.post("/api/v1/auth/login", json={"username": "admin", "password": "wrong"})
check("bad password rejected (401)", r.status_code == 401, f"got {r.status_code}")

r = client.post("/api/v1/auth/refresh", json={"refresh_token": rt})
check("refresh token works", r.status_code == 200 and "access_token" in r.json(), f"got {r.status_code}")

r = client.get("/api/v1/auth/me", headers=at)
check("me returns profile", r.status_code == 200 and r.json()["username"] == "admin")

reg_payload = {
    "username": "newbie", "email": "newbie@example.com",
    "full_name": "Новый Пользователь", "password": "secret123",
}
r = client.post("/api/v1/auth/register", json=reg_payload)
check("register new user", r.status_code in (200, 201), f"got {r.status_code} {r.text[:120]}")
if r.status_code in (200, 201):
    check("registered role forced to worker", r.json().get("role") == "worker", f"got {r.json().get('role')}")

print("== SECURITY / RBAC ==")
for ep in ["/api/v1/companies", "/api/v1/vacancies", "/api/v1/candidates", "/api/v1/applications", "/api/v1/users"]:
    r = client.get(ep)
    check(f"{ep} requires auth (401/403)", r.status_code in (401, 403), f"got {r.status_code}")

r = client.get("/api/v1/users", headers=wt)
check("worker cannot list users (403)", r.status_code == 403, f"got {r.status_code}")
r = client.get("/api/v1/users", headers=at)
check("admin can list users (200)", r.status_code == 200, f"got {r.status_code}")

print("== COMPANIES CRUD ==")
r = client.get("/api/v1/companies?limit=5&offset=0", headers=at)
check("companies paginated", r.status_code == 200 and len(r.json()["items"]) <= 5)
total_companies = r.json()["total"]

r = client.post("/api/v1/companies", headers=mt,
                json={"name": "ДымТест ООО", "industry": "Тесты", "city": "Казань", "email": "t@t.ru"})
check("create company (manager)", r.status_code in (200, 201), f"got {r.status_code} {r.text[:120]}")
cid = r.json()["id"] if r.status_code in (200, 201) else None

if cid:
    r = client.put(f"/api/v1/companies/{cid}", headers=mt,
                   json={"name": "ДымТест ООО", "industry": "Тесты", "city": "Уфа"})
    check("update company", r.status_code == 200 and r.json()["city"] == "Уфа")
    r = client.get(f"/api/v1/companies/{cid}", headers=at)
    check("get single company", r.status_code == 200)

r = client.post("/api/v1/companies", headers=wt, json={"name": "X", "industry": "Y", "city": "Z"})
check("worker cannot create company (403)", r.status_code == 403, f"got {r.status_code}")

print("== VACANCIES + LARGE DATA ==")
r = client.post("/api/v1/vacancies", headers=mt,
                json={"company_id": cid, "title": "Инженер-испытатель", "city": "Казань",
                      "salary_from": 100000, "salary_to": 150000, "employment_type": "Полная"})
check("create vacancy", r.status_code in (200, 201), f"got {r.status_code} {r.text[:150]}")
vid = r.json()["id"] if r.status_code in (200, 201) else None

r = client.get("/api/v1/vacancies?limit=20&offset=10&search=разработчик", headers=at)
check("vacancy pagination+search", r.status_code == 200 and r.json()["total"] >= 0)
r = client.get("/api/v1/vacancies?limit=20&city=Москва", headers=at)
check("vacancy filter by city", r.status_code == 200)

if vid:
    r = client.put(f"/api/v1/vacancies/{vid}", headers=mt,
                   json={"company_id": cid, "title": "Старший инженер", "city": "Казань",
                         "salary_from": 150000, "employment_type": "Полная"})
    check("update vacancy", r.status_code == 200 and r.json()["title"] == "Старший инженер")

print("== CANDIDATES ==")
r = client.post("/api/v1/candidates", headers=mt,
                json={"full_name": "Тест Тестевич", "email": "tt@example.com",
                      "city": "Казань", "specialization": "Тестирование", "experience_years": 3})
check("create candidate", r.status_code in (200, 201), f"got {r.status_code} {r.text[:150]}")
cand_id = r.json()["id"] if r.status_code in (200, 201) else None

r = client.get("/api/v1/candidates?limit=10&search=Тест", headers=at)
check("candidate search", r.status_code == 200 and any("Тест" in c["full_name"] for c in r.json()["items"]))

if cand_id:
    r = client.post(f"/api/v1/candidates/{cand_id}/comments", headers=mt, json={"text": "Комментарий из смоук-теста"})
    check("add comment to candidate", r.status_code in (200, 201), f"got {r.status_code} {r.text[:150]}")
    r = client.get(f"/api/v1/candidates/{cand_id}/comments", headers=at)
    check("list comments", r.status_code == 200 and any("смоук" in c["text"] for c in r.json()))

print("== APPLICATIONS PIPELINE ==")
if cand_id and vid:
    r = client.post("/api/v1/applications", headers=mt,
                    json={"candidate_id": cand_id, "vacancy_id": vid})
    check("create application", r.status_code in (200, 201), f"got {r.status_code} {r.text[:150]}")
    app_id = r.json()["id"] if r.status_code in (200, 201) else None

    if app_id:
        r = client.patch(f"/api/v1/applications/{app_id}", headers=mt, json={"status": "interview"})
        check("move application stage", r.status_code == 200 and r.json()["status"] == "interview",
              f"got {r.status_code} {r.text[:150]}")
        r = client.delete(f"/api/v1/applications/{app_id}", headers=at)
        check("delete application (admin)", r.status_code == 200)

r = client.get("/api/v1/applications?limit=50&offset=0", headers=at)
check("applications large-data page", r.status_code == 200 and r.json()["total"] > 500,
      f"total={r.json().get('total') if r.status_code == 200 else '?'}")

print("== SKILLS ==")
r = client.get("/api/v1/skills", headers=at)
check("skills list", r.status_code == 200 and len(r.json()) > 0)

print("== CLEANUP / DELETE ==")
if vid:
    r = client.delete(f"/api/v1/vacancies/{vid}", headers=mt)
    check("delete vacancy", r.status_code == 200)
if cid:
    r = client.delete(f"/api/v1/companies/{cid}", headers=mt)
    check("delete company", r.status_code == 200)
if cand_id:
    r = client.delete(f"/api/v1/candidates/{cand_id}", headers=at)
    check("delete candidate (admin)", r.status_code == 200)

print(f"\nRESULT: {PASS} passed, {FAIL} failed")
sys.exit(0 if FAIL == 0 else 1)
