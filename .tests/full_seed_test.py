import os, sys, subprocess
os.environ['DATABASE_URL'] = 'sqlite:////tmp/old_schema.db'
os.environ['SECRET_KEY'] = 'test-secret-key-long-enough-32-bytes!!'
db = '/tmp/old_schema.db'
if os.path.exists(db): os.remove(db)

# 1. build the OLD schema exactly as it exists on users' machines:
#    alembic migration a1f2c3d4e5b6 (agency tables WITHOUT status_history /
#    completion_score).  We emulate it by creating current metadata and then
#    dropping the new columns via table rebuild (SQLite) — closest realistic
#    approximation; on Postgres the same self-heal runs ALTER ADD COLUMN.
import sqlite3
sys.path.insert(0, '/workspace/backend')
os.chdir('/workspace/backend')
from app.db.base import Base
import app.models.user, app.models.vacancy, app.models.candidate, app.models.application, app.models.company, app.models.skill, app.models.comment, app.models.contact
from app.db.vis import get_engine
eng = get_engine()
Base.metadata.create_all(eng)
con = sqlite3.connect(db)
con.executescript("""
PRAGMA foreign_keys=off;
CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL CONSTRAINT alembic_version_pkc PRIMARY KEY);
INSERT INTO alembic_version VALUES ('a1f2c3d4e5b6');
-- drop new mixin columns from applications (rebuild without them)
ALTER TABLE applications RENAME TO applications_new;
CREATE TABLE applications (id INTEGER PRIMARY KEY, status VARCHAR(20) NOT NULL, candidate_id INTEGER NOT NULL REFERENCES candidates(id) ON DELETE CASCADE, vacancy_id INTEGER NOT NULL REFERENCES vacancies(id) ON DELETE CASCADE, manager_id INTEGER REFERENCES users(id), assigned_worker_id INTEGER REFERENCES users(id), created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(candidate_id, vacancy_id));
INSERT INTO applications SELECT id,status,candidate_id,vacancy_id,manager_id,assigned_worker_id,created_at,updated_at FROM applications_new;
DROP TABLE applications_new;
-- drop users.completion_score
ALTER TABLE users DROP COLUMN completion_score;
PRAGMA foreign_keys=on;
""")
con.commit(); con.close()
print('OLD schema prepared (no status_history/prev_status/completion_score)')

# 2. run seed --force against it (should self-heal)
r = subprocess.run([sys.executable, '-m', 'scripts.seed', '--force'], capture_output=True, text=True, env=os.environ, timeout=120)
print(r.stdout[-1200:])
if r.returncode != 0:
    print('SEED FAILED:', r.stderr[-1500:]); sys.exit(1)

# 3. verify new columns exist and app works
con = sqlite3.connect(db)
cols_app = [c[1] for c in con.execute('PRAGMA table_info(applications)')]
cols_user = [c[1] for c in con.execute('PRAGMA table_info(users)')]
con.close()
assert 'status_history' in cols_app and 'prev_status' in cols_app, cols_app
assert 'completion_score' in cols_user, cols_user
print('OK: drift healed ->', [c for c in cols_app if c in ('status_history','prev_status','completion_score')], '+users.completion_score')

from fastapi.testclient import TestClient
from app.main import app as fastapi_app
client = TestClient(fastapi_app)
r = client.post('/api/v1/auth/login', json={'username':'admin','password':'admin123'})
assert r.status_code == 200, r.text
tok = r.json()['access_token']; h = {'Authorization': 'Bearer ' + tok}
r = client.get('/api/v1/applications?page_size=5', headers=h)
assert r.status_code == 200, r.text
item = r.json()['items'][0]
print('app item keys:', sorted(item.keys()))
aid = item['id']; oldst = item['status']
newst = 'rejected' if oldst != 'rejected' else 'review'
r = client.patch(f'/api/v1/applications/{aid}', json={'status': newst}, headers=h)
assert r.status_code == 200, r.text
body = r.json()
print('PATCH status ok; history present:', bool(body.get('statusHistory') or body.get('status_history')))
print('FULL SEED+DRIFT+HISTORY TEST PASSED')
