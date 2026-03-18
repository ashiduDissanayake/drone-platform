# Code Review Template

**Reviewer:** _____________  
**Date:** _____________  
**Focus Areas:** Architecture / Code Quality / Security / Testing / Documentation

---

## 🏗️ Architecture Feedback

### Overall Design
- [ ] Cloud-edge split (mission manager on laptop, SITL on cloud) makes sense
- [ ] Component separation (adapter, manager, SITL) is clear
- [ ] Interface boundaries are well-defined
- [ ] Scalability concerns?

### Questions
1. Should we support both local and cloud SITL equally?
2. Is MAVLink the right protocol long-term?
3. How would this scale to multiple drones?

### Suggestions
- 
- 

---

## 💻 Code Quality

### Strengths
- 
- 

### Issues Found
| File | Line | Issue | Severity (H/M/L) |
|------|------|-------|------------------|
| | | | |
| | | | |

### Code Style
- [ ] Consistent formatting
- [ ] Good variable naming
- [ ] Functions are focused and small
- [ ] Error handling is comprehensive

### Type Safety
- [ ] Type hints used appropriately
- [ ] No `Any` types where specific types possible
- [ ] Dataclasses/NamedTuples used where appropriate

---

## 🔒 Security Concerns

### Network Security
- [ ] TCP port 5760 exposed to internet (restricted to IP)
- [ ] No authentication on MAVLink connection
- [ ] SSH key handling is secure
- [ ] No secrets in code

### Suggestions
- 

---

## 🧪 Testing

### Current State
- [ ] Unit tests exist for critical components
- [ ] Integration tests exist
- [ ] No tests (just manual testing)

### Coverage Gaps
- 
- 

### Test Strategy Suggestions
- 

---

## 📚 Documentation

### What's Good
- 

### What's Missing
- [ ] API documentation
- [ ] Architecture diagrams
- [ ] Setup instructions for new developers
- [ ] Troubleshooting guide
- [ ] Configuration reference

### README Quality
- [ ] Clear project description
- [ ] Installation steps work
- [ ] Usage examples provided
- [ ] Directory structure explained

---

## 🐛 Bugs / Issues Found

| # | Description | Location | Repro Steps |
|---|-------------|----------|-------------|
| 1 | | | |
| 2 | | | |

---

## 🎯 Priority Recommendations

### Must Fix Before Release
1. 
2. 

### Should Fix Soon
1. 
2. 

### Nice to Have
1. 
2. 

---

## 💡 Feature Requests

1. 
2. 

---

## 📝 Additional Comments



---

**Overall Rating:** ⭐⭐⭐⭐⭐ / 5

**Ready to merge?** YES / NO / NEEDS CHANGES

