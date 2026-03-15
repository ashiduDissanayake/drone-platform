# Tomorrow's Development Plan
## Date: 2026-03-16

---

## 🎯 Priority 1: Configuration Management (CRITICAL)

**Problem:** URLs, IPs, connection strings hardcoded throughout codebase

**Solution:** Centralized configuration system

### Tasks:
- [ ] Create `config/deployment.toml` - Single source of truth
- [ ] Create `config/profiles/` - dev.toml, staging.toml, production.toml
- [ ] Refactor vehicle_adapter to read from config
- [ ] Refactor mission_manager to read from config
- [ ] Remove all hardcoded IPs/URLs from Python code
- [ ] Update SITL manager to use config

### Example Structure:
```toml
# config/deployment.toml
[vehicle]
backend = "ardupilot_sitl"
connection_string = "tcp:127.0.0.1:5760"

[vehicle.timeouts]
connection = 30.0
arming = 60.0
takeoff = 120.0

[simulation]
mode = "cloud"  # "local", "docker", "cloud"
cloud_host = ""  # Filled by Terraform or manually
cloud_port = 5760

[logging]
level = "INFO"
format = "structured"  # "simple", "structured", "json"
```

---

## 🎯 Priority 2: GUI/Simulation Realism (HIGH)

**Problem:** QGC shows "missing parameters", raw interface, not realistic

### Tasks:
- [ ] Research SITL parameter defaults for realistic simulation
- [ ] Create `simulation/realistic-params.parm` - Pre-tuned parameters
- [ ] Document proper QGC setup (which widgets to enable)
- [ ] Test with Gazebo + ArduPilot for 3D visualization
- [ ] Alternative: Use MAVProxy map module instead of QGC

### Research Items:
- [ ] Find standard ArduPilot Copter parameters for SITL
- [ ] Check if Gazebo + SITL works on Mac (or cloud-only)
- [ ] Document GCS options comparison (QGC vs Mission Planner vs MAVProxy)

---

## 🎯 Priority 3: Code Review & Feedback Integration (BLOCKING)

**Status:** Waiting for team reviews

### Action Items:
- [ ] Create review checklist template
- [ ] Document current architecture decisions
- [ ] List known limitations for reviewers
- [ ] Schedule review meeting (if needed)

### Review Focus Areas:
1. **Architecture:** Cloud-edge split design
2. **Code Quality:** Error handling, logging, type hints
3. **Testing:** Unit tests, integration tests needed
4. **Documentation:** README updates, API docs
5. **Security:** Hardcoded secrets, network exposure

---

## 📋 Detailed Task Breakdown

### Morning (Priority 1: Config Management)

| Time | Task | File(s) | Output |
|------|------|---------|--------|
| 9:00-10:30 | Design config schema | `config/*.toml` | Config structure defined |
| 10:30-12:00 | Implement config loader | `interfaces/config.py` | ConfigLoader class |
| 12:00-13:00 | Refactor vehicle_adapter | `adapters/vehicle_adapter/` | Uses config |

### Afternoon (Priority 2: GUI + Priority 3: Reviews)

| Time | Task | File(s) | Output |
|------|------|---------|--------|
| 14:00-15:30 | SITL parameters research | `simulation/` | Realistic params file |
| 15:30-16:30 | Gazebo integration check | Docs/research | Feasibility report |
| 16:30-17:30 | Review prep | `docs/reviews/` | Review checklist |

---

## 🔧 Technical Decisions Needed

### 1. Config Format
- **Option A:** TOML (readable, standard) ← **Recommended**
- **Option B:** YAML (flexible, widely used)
- **Option C:** JSON (machine-readable, not human-friendly)
- **Option D:** Python dataclasses (type-safe, no parsing)

### 2. Config Loading Strategy
- **Option A:** Singleton pattern (global config object)
- **Option B:** Dependency injection (pass config to each component)
- **Option C:** Pydantic Settings (env vars + files) ← **Recommended**

### 3. Environment Handling
- **Option A:** Separate files (`dev.toml`, `prod.toml`)
- **Option B:** Single file with sections (`[env.dev]`, `[env.prod]`)
- **Option C:** Environment variable overrides only

---

## 📥 Review Feedback Collection

Create a file for each reviewer to fill:

```
docs/reviews/
├── REVIEW_TEMPLATE.md      # Copy this for each reviewer
├── review-alice-20240316.md
├── review-bob-20240316.md
└── consolidated-feedback.md  # Summary of all reviews
```

### Review Template:
- Architecture feedback
- Code quality issues
- Security concerns
- Testing gaps
- Documentation needs

---

## ⚠️ Blockers & Dependencies

| Blocker | Status | Resolution |
|---------|--------|------------|
| Team reviews | ⏳ PENDING | Wait for feedback |
| GUI realism | 🔍 RESEARCH | Needs investigation |
| Config format decision | ⏸️ DECIDE | Choose TOML/YAML/JSON |

---

## 🎁 Nice-to-Have (If Time Permits)

- [ ] Add Makefile for common commands
- [ ] Pre-commit hooks (black, ruff, mypy)
- [ ] GitHub Actions CI template
- [ ] Docker Compose for local dev
- [ ] Auto-generate config docs

---

## 📊 Success Criteria

**Tomorrow is successful if:**
1. ✅ No hardcoded IPs/URLs in codebase
2. ✅ Config loads from file(s) correctly
3. ✅ SITL parameters documented (even if not implemented)
4. ✅ Review feedback collected and organized
5. ✅ Clear plan for next sprint

---

## 📝 Notes for Reviewers

**Current State:**
- Cloud SITL working (EC2 + ArduPilot 4.8)
- Vehicle adapter connects via TCP
- Commands: arm, takeoff, goto, land all functional
- QGC connected but GUI minimal

**Known Limitations:**
- Only one TCP connection at a time
- No GUI visualization yet
- Hardcoded configuration
- No automated tests

**Questions for Reviewers:**
1. Is cloud-edge architecture correct approach?
2. Should we prioritize local simulation or cloud?
3. What GCS integration is most important?
4. Security concerns with TCP exposure?

---

*Plan created: 2026-03-15*
*Next update: After review feedback received*
