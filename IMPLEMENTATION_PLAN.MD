**Prompt Template for LLM Coding Agent: Code Change Implementation**  
**Objective**: Guide the AI to implement code changes thoroughly, ensuring no broken references, outdated imports, or overlooked dependencies.  

---

### **Structured Problem & Solution Document**  
**1. Problem Description**  
- **Summary**: Briefly describe the issue (e.g., "API endpoint fails to validate user input").  
- **Current Behavior**: What does the code do now? Include error messages or logs if applicable.  
- **Expected Behavior**: What should the code do after fixes?  
- **Reproduction Steps**: How to trigger the issue (e.g., "Send a POST request with X payload").  

**2. Solution Plan**  
- **Approach**: High-level strategy (e.g., "Refactor validation logic into a helper function").  
- **Files Affected**: List files/modules needing changes (e.g., `src/api/endpoints.py`, `src/utils/validation.py`).  
- **Changes Per File**:  
  - For each file, specify:  
    - **Code to Add/Modify/Delete** (e.g., "Move validation logic from `endpoints.py` to `validation.py`").  
    - **Impacted Dependencies**: Functions, variables, or imports that will change.  
- **Edge Cases**: Scenarios to handle (e.g., "Empty input fields", "Special characters in payload").  
- **Testing Requirements**: How to verify the fix (e.g., unit tests, manual test cases).  

**3. Implementation Guidelines**  
- **Reference Tracking**:  
  - Ensure all calls to modified functions/classes are updated.  
  - Verify imports (e.g., if a function is moved, update `import` statements across the codebase).  
- **Naming & Style**: Follow existing naming conventions and code style (e.g., PEP8, project-specific rules).  
- **Version Control**: Document changes in small, logical commits (e.g., "Fix: Add input validation helper").  
- **Validation Steps**:  
  - Generate unit/integration tests for new logic.  
  - Check for regressions in dependent modules.  

**4. Checklist for Completeness**  
- [ ] All function/method calls referencing changed code are updated.  
- [ ] Imports are corrected (added/removed/renamed).  
- [ ] Edge cases are addressed with tests or conditional logic.  
- [ ] Code style matches the project’s standards.  
- [ ] Documentation (e.g., docstrings, comments) reflects changes.  
- [ ] Tests pass locally and cover new logic. (optional) 

---

**Example Prompt to LLM**:  
```  
You are tasked with resolving [PROBLEM SUMMARY] in the codebase. Follow this structured plan:  

**Problem**: [Insert problem description].  
**Solution Plan**: [Insert approach, files, and specific changes].  
**Guidelines**:  
1. Update all references to modified functions/classes (e.g., `old_function()` → `new_function()`).  
2. Ensure imports are valid (e.g., update `from module import x` after moving code).  
3. Add tests for [specific edge cases].  

**Response Format**:  
- Use markdown to show file changes (e.g., ````python ... ````).  
- Include a summary of impacted references and dependencies.  
- Confirm completion of the checklist.  
```  

This structure ensures the LLM systematically addresses dependencies, avoids technical debt, and produces production-ready code. Adjust specificity based on the problem!